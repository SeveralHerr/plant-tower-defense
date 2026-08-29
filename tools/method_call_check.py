#!/usr/bin/env python3
r"""Calls a method that does not exist, on a receiver whose PROJECT class is known.

Cycle 159 wrote `game.run_over()` where `Game` has no such method, and it was clean to
`name_check`, clean to `import_check`, and clean to `lint_project.gd` at 0 errors and 0
warnings. It failed at runtime and nowhere else.

WHY NO EXISTING GATE CATCHES IT, measured in cycle 162 rather than assumed:

  * Godot's analyzer DOES hard-error on an unknown method for a BUILTIN type.
    `var d: Dictionary` then `d.no_such()` is `Parse Error: Function "no_such()" not
    found in base Dictionary`, exit 1, no settings required.
  * It does NOT for an Object-derived type. `var n: Node2D` then `n.no_such_engine_method()`
    is exit 0, silent. Any Object may gain a method at runtime — a script, a `set_script`,
    a dynamic dispatch — so the analyzer cannot refuse it, and this is a language decision
    rather than a gap in the harness.
  * `debug/gdscript/warnings/unsafe_method_access` is NOT the missing switch. It fires on a
    call through a **Variant-typed** receiver, which is the opposite case: it warns when the
    type is UNKNOWN, and says nothing when the type is known and the method is absent.
    Cycle 160 enabled it and measured no change, which is now explained rather than filed.

So the only thing that can close this is a checker that resolves the call itself, and it
can only do so where the receiver's type is written down and the class is one of ours.
That is this file, and its narrowness is deliberate: it reports where it is CERTAIN and
prints the size of what it skipped, rather than guessing across an inheritance chain it
cannot see.

WHAT IT CHECKS. A receiver whose type is declared in source as a project `class_name` —
`var g: Game = …`, a parameter `func f(b: Board)`, or a field `var board: Board` — and a
call `g.something()` where `something` is declared nowhere in that class or its project
ancestors. Everything else is skipped and counted.

WHAT IT DELIBERATELY SKIPS, each for a reason a false positive would otherwise cost:
  * a class whose `extends` leaves the project (`extends Node2D`) — the method may be an
    engine member, and resolving those needs the API index this tool does not load;
  * `_`-prefixed engine callbacks and anything reached via `call()`, `callv()`,
    `has_method()` or a Callable — dynamic by construction;
  * a receiver whose declared type is `Variant`, absent, or inferred with `:=`;
  * every autoload, since `RunConfig.foo()` resolves through a node path rather than a type.

GATING, and the reasoning is house-static-checker's: a finding here has exactly one
correct response — the method does not exist, so either the call or the class is wrong.
There is no legitimate leave-it-alone case, so a red run is always actionable.

# Its own history is the fixture, and each step is reproducible by reverting one thing:
#   stop at the project boundary        -> 0 calls resolved of 2214. Honest, and worthless.
#   check ENGINE-typed receivers too    -> 29 findings, every one `var _dev: Node` holding
#                                          the DevTools autoload. That is the language
#                                          working, not a bug, and is why the guard exists.
#   drop INDEX_OMITS                    -> 4 findings, all `board.free()`. `free` is a real
#                                          Object method the 4.7.1 index does not list,
#                                          while `queue_free` is. Measured, not guessed.
#   plant `game.run_over()` back        -> the exact bug from cycle 159, named with its
#                                          file, line, receiver and class. This is the
#                                          regression test: if that stops firing, so has
#                                          the checker.
"""
import argparse
import glob
import gzip
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gdsource

CLASSNAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.M)
EXTENDS_RE = re.compile(r"^\s*extends\s+([A-Za-z_]\w*)", re.M)
FUNC_RE = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)\s*\(", re.M)
CONST_RE = re.compile(r"^\s*const\s+(\w+)", re.M)
VAR_RE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)?(?:static\s+)?var\s+(\w+)", re.M)
SIGNAL_RE = re.compile(r"^\s*signal\s+(\w+)", re.M)

# `var g: Game`, `var board: Board = ...`, and parameters `f(b: Board, c: int)`.
TYPED_VAR_RE = re.compile(r"\bvar\s+(\w+)\s*:\s*([A-Z]\w*)\b")
TYPED_PARAM_RE = re.compile(r"\b(\w+)\s*:\s*([A-Z]\w*)\s*(?=[,)=])")
CALL_RE = re.compile(r"\b(\w+)\s*\.\s*(\w+)\s*\(")

# Reached dynamically; a name passed to any of these is not a call site.
DYNAMIC = {"call", "callv", "call_deferred", "has_method", "connect", "emit_signal",
           "rpc", "rpc_id", "bind", "get", "set", "get_indexed", "set_indexed",
           "call_thread_safe", "call_deferred_thread_group"}

# Real Object methods the cached API index does not list, measured rather than guessed:
# `Object` carries 60 members in the 4.7.1 index and `free` is not among them, while
# `queue_free` (a Node method) is. These are engine built-ins ClassDB does not expose as
# ordinary methods, so without this list the checker reports `board.free()` as missing --
# which it did, four times, on its first honest run. Named here rather than widened into
# a "skip anything short" heuristic: a list can be checked, a heuristic cannot.
INDEX_OMITS = {"free", "new"}


def engine_index():
    """Engine class -> set of member names, following `inherits`.

    The SAME cache name_check.py builds and refreshes, read rather than rebuilt: two
    copies of an engine API would be two answers to "does Node have this", and the
    stale one always wins an argument it should lose. Returns ({}, reason) when the
    cache is absent, and the caller reports that as COULD NOT RUN rather than as a
    clean sweep -- without it this checker resolves almost nothing, which is exactly
    what its first draft did.
    """
    home = os.path.expanduser("~")
    pattern = os.path.join(home, "AppData", "Local", "godot-selftest-harness", "api",
                           "engine_api_*.json.gz")
    hits = sorted(glob.glob(pattern))
    if not hits:
        hits = sorted(glob.glob(os.path.join(
            home, ".cache", "godot-selftest-harness", "api", "engine_api_*.json.gz")))
    if not hits:
        return {}, "no engine API index; run `python tools/name_check.py --refresh-api`"
    try:
        with gzip.open(hits[-1], "rt", encoding="utf-8") as fh:
            raw = json.load(fh)
    except Exception as exc:                                  # noqa: BLE001
        return {}, "engine API index unreadable (%s)" % exc
    classes = raw.get("classes", {})
    resolved = {}

    def members_of(name, seen=None):
        seen = seen or set()
        if name in resolved:
            return resolved[name]
        if name not in classes or name in seen:
            return set()
        seen.add(name)
        entry = classes[name]
        out = set(entry.get("members", []))
        parent = entry.get("inherits", "")
        if parent:
            out |= members_of(parent, seen)
        resolved[name] = out
        return out

    for name in classes:
        members_of(name)
    return resolved, os.path.basename(hits[-1])


def gd_files(root, subs):
    out = []
    for sub in subs:
        base = os.path.join(root, sub)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            for name in sorted(filenames):
                if name.endswith(".gd"):
                    out.append(os.path.join(dirpath, name))
    return sorted(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    engine, api_source = engine_index()
    if not engine:
        print("method_call_check: COULD NOT RUN -- %s. Without it every class extending "
              "an engine type is unresolvable, which in a Godot game is nearly all of "
              "them; the first draft of this checker resolved 0 calls of 2214 for "
              "exactly that reason, and a clean run in that state would be a lie."
              % api_source)
        return 2

    files = gd_files(args.root, ["game"])
    if not files:
        print("method_call_check: COULD NOT RUN -- no .gd files under game/ or "
              "Nothing was checked; this is not a clean result.")
        return 2

    # --- what each project class declares, and what it extends
    declares = {}     # class_name -> set of member names
    extends = {}      # class_name -> base name (project or engine)
    owner = {}        # class_name -> file
    blanked = {}
    for p in files:
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            code = gdsource.strip_comments(fh.read(), strings=gdsource.BLANK)
        blanked[p] = code
        cn = CLASSNAME_RE.search(code)
        if not cn:
            continue
        name = cn.group(1)
        owner[name] = os.path.relpath(p, args.root).replace("\\", "/")
        ex = EXTENDS_RE.search(code)
        extends[name] = ex.group(1) if ex else ""
        members = set()
        for rx in (FUNC_RE, CONST_RE, VAR_RE, SIGNAL_RE):
            members |= set(rx.findall(code))
        declares[name] = members

    def resolvable(name, seen=None):
        """Every member `name` can answer to: its own, its project ancestors', and the
        engine members of whatever it ultimately extends. None when the chain reaches a
        base the engine index does not know, which is the only case left where a member
        could exist and this tool cannot see it.

        THE FIRST DRAFT STOPPED AT THE PROJECT BOUNDARY and resolved 0 calls of 2214,
        because in a Godot game essentially every class extends an engine type. That is
        the denominator rule earning its place: the checker was honest, printed its own
        zero, and was worthless. The engine index is what makes it a checker."""
        seen = seen or set()
        if name in seen:
            return set()
        seen.add(name)
        if name not in declares:
            # Not one of ours: an engine class, and the index is authoritative for it.
            return set(engine[name]) if name in engine else None
        base = extends.get(name, "")
        inherited = resolvable(base, seen) if base else set()
        if inherited is None:
            return None
        return set(declares[name]) | inherited

    findings = []
    checked_calls = 0
    skipped_receiver = 0
    skipped_engine_recv = 0
    skipped_class = 0
    for p in files:
        code = blanked[p]
        rel = os.path.relpath(p, args.root).replace("\\", "/")
        types = {}
        for m in TYPED_VAR_RE.finditer(code):
            types[m.group(1)] = m.group(2)
        for m in TYPED_PARAM_RE.finditer(code):
            types.setdefault(m.group(1), m.group(2))
        for m in CALL_RE.finditer(code):
            recv, method = m.group(1), m.group(2)
            if method in DYNAMIC or method in INDEX_OMITS:
                continue
            cls = types.get(recv)
            if cls is None:
                skipped_receiver += 1
                continue
            if cls not in declares:
                # An ENGINE-typed receiver, and it must be skipped however well the API
                # index knows that class. `var _dev: Node` holding the DevTools autoload
                # is the shape: the declared type is Node, the object carries a script,
                # and `_dev.register_command()` is correct. Godot permits exactly this,
                # which is why the analyzer stays silent for Object-derived types at all.
                # The first draft reported 29 findings and every one was this.
                skipped_engine_recv += 1
                continue
            members = resolvable(cls)
            if members is None:
                skipped_class += 1
                continue
            checked_calls += 1
            if method not in members:
                line = code.count("\n", 0, m.start()) + 1
                findings.append(
                    "%s:%d calls `%s.%s()` and %s (%s) declares no `%s`.\n"
                    "  fix: the method or the call is wrong -- there is no third case. "
                    "This fails at RUNTIME and at no gate, which is why it is checked "
                    "here.\n"
                    "  note: %s extends %s, and every member of that chain -- project "
                    "and engine both -- was resolved, so this is an absence rather than a "
                    "gap in what could be seen."
                    % (rel, line, recv, method, cls, owner.get(cls, "?"), method,
                       cls, extends.get(cls) or "nothing"))

    print("method_call_check: %d call(s) on a receiver whose PROJECT class is fully "
          "known were resolved, %d finding(s). Skipped and counted: %d call(s) on a "
          "receiver with no written-down type, %d on an ENGINE-typed receiver (which may "
          "carry any script), %d on a class whose chain the API index does not know. "
          "%d project class(es) declared across %d file(s), engine members from %s."
          % (checked_calls, len(findings), skipped_receiver, skipped_engine_recv,
             skipped_class, len(declares), len(files), api_source))
    if not args.quiet:
        for f in findings:
            print("FINDING: %s" % f)
    print("  NOT COVERED: this resolves a call ONLY where the receiver's declared type is "
          "one of THIS PROJECT's class_names. An ENGINE-typed receiver is skipped and "
          "counted however well the index knows that class, because a Node-typed variable "
          "may hold any script -- `var _dev: Node` carrying the DevTools autoload is the "
          "shape, and an earlier draft reported 29 findings that were all exactly that. "
          "It does not "
          "check ARGUMENTS, arity or return types; it does not follow `:=`; and it says "
          "nothing about autoloads, which resolve through a node path rather than a "
          "type. The engine half is only as good as the cached API index (%s), which "
          "name_check.py owns -- a stale one would report a member added by a newer "
          "Godot as missing. Godot itself catches this class only for BUILTIN receivers "
          "(`Dictionary`, "
          "`Array`): for any Object-derived type the analyzer stays silent by design, "
          "since a method may arrive at runtime -- measured in cycle 162, and the reason "
          "no engine setting closes this. Nor does it compile: only import_check.py and "
          "lint_project.gd do that, and neither is parallel-safe." % api_source)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
