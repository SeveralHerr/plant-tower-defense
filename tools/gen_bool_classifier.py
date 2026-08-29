#!/usr/bin/env python3
"""Generate a GDScript boolean-input classifier and its matching unit test
block from one JSON spec, so the branch table and the assertions that check
it are derived from the same source and cannot drift apart (the
derive-the-list pattern applied to code generation instead of to a runtime
list).

A spec describes an ordered list of cases; each case is a partial
assignment of the function's boolean params ("when") mapped to the GDScript
expression to return ("value"). Cases are tried in order, first match wins
-- exactly like the hand-written if-chains this project already writes for
functions such as Hud.plant_button_tint and Hud.threat_color. A case with an
empty "when" is the unconditional default and must be last.

Usage:
    python tools/gen_bool_classifier.py SPEC.json --print-func
    python tools/gen_bool_classifier.py SPEC.json --print-test
    python tools/gen_bool_classifier.py SPEC.json --write-func game/hud.gd
    python tools/gen_bool_classifier.py SPEC.json --write-test test/unit/test_selftest.gd
    python tools/gen_bool_classifier.py SPEC.json --check-func game/hud.gd --check-test test/unit/test_selftest.gd

The GDScript body and the test body are both derived from `cases` --
edit the spec, regenerate both, nothing is hand-typed in two places.

`--write-func`/`--write-test` splice the generated block between a pair of
marker comments in the target file:

    # GEN:<function>:BEGIN
    ...generated lines replaced here on every --write...
    # GEN:<function>:END

so regenerating is `git diff`-visible and never a manual copy/paste --
the two places that can drift are reduced to the one spec. `--check-*`
compares instead of writing and exits 1 on any mismatch (for a gate); use it
in `/verify` or a pre-commit hook wherever a *.json spec here changes.

WHAT THIS DOES NOT COVER -- deliberately phrased without the contract marker
`check_all.py` discovers checkers by, which is the same resolution citation_rebind.py
and gen_pulse_cue.py reached. A tool carrying that marker is run as a checker, bare;
this one cannot run bare (every mode needs a spec path), so it is registered in
check_all.py's NOT_A_CHECKER instead and must not also declare the marker -- carrying
both makes it UNCLASSIFIED, which is that gate correctly refusing to guess.

The blind spot itself: this is a GENERATOR. It makes a branch table and its assertions
derive from one spec so the two cannot drift; it says nothing about whether the spec is
RIGHT. A case list that is complete, ordered, internally consistent and describes the
WRONG behaviour generates a function and a test that agree with each other perfectly and
are both wrong -- and that test can never fail, because it came from the same source as
the code it checks. Generating both halves buys you no independent witness; it only
guarantees they say the same thing. It compiles nothing either: only import_check.py and
lint_project.gd do that, and neither is parallel-safe.

`--check-func`/`--check-test` do honour the 0-same/1-drifted exit convention, and they
are the real gate -- run them from /verify or a hook wherever a spec here changes.
"""

from __future__ import annotations

import argparse
import itertools
import json
import re
import sys
from pathlib import Path
from typing import Any


def _cond_expr(param_names: list[str], when: dict[str, bool]) -> str:
    if not when:
        return "true"
    parts = []
    for name in param_names:
        if name not in when:
            continue
        parts.append(name if when[name] else f"not {name}")
    return " and ".join(parts)


def generate_function(spec: dict[str, Any]) -> str:
    name = spec["function"]
    params = spec["params"]  # list of [name, type]
    return_type = spec.get("return_type", "Color")
    param_names = [p[0] for p in params]
    sig = ", ".join(f"{p[0]}: {p[1]}" for p in params)
    lines = [f"static func {name}({sig}) -> {return_type}:"]
    cases = spec["cases"]
    for i, case in enumerate(cases):
        when = case.get("when", {})
        value = case["value"]
        is_last = i == len(cases) - 1
        if not when and is_last:
            lines.append(f"\treturn {value}")
            continue
        cond = _cond_expr(param_names, when)
        lines.append(f"\tif {cond}:")
        lines.append(f"\t\treturn {value}")
    return "\n".join(lines) + "\n"


def _matches(when: dict[str, bool], witness: dict[str, bool]) -> bool:
    return all(witness[k] == v for k, v in when.items())


def _witness_for(param_names: list[str], cases: list[dict[str, Any]], index: int) -> dict[str, bool]:
    """The smallest boolean assignment that reaches `cases[index]` when the
    cases are evaluated in order as a real if-chain -- i.e. it satisfies
    cases[index]'s own `when` and does NOT satisfy any earlier case's `when`.
    Raises if the spec has no such assignment (an earlier case fully shadows
    this one, which means the spec itself is wrong, not just the codegen)."""
    when = cases[index].get("when", {})
    free = [p for p in param_names if p not in when]
    for combo in itertools.product([False, True], repeat=len(free)):
        witness = dict(when)
        witness.update(dict(zip(free, combo)))
        if any(_matches(cases[j].get("when", {}), witness) for j in range(index)):
            continue
        return witness
    raise ValueError(
        f"case {index} ({when!r}) is unreachable -- every assignment satisfying "
        "it is already claimed by an earlier case"
    )


def generate_test(spec: dict[str, Any]) -> str:
    name = spec["function"]
    owner = spec.get("class", "")
    params = spec["params"]
    param_names = [p[0] for p in params]
    cases = spec["cases"]
    call_prefix = f"{owner}.{name}" if owner else name
    lines = [
        f"# Generated by tools/gen_bool_classifier.py from a spec -- one assertion",
        f"# per case in the spec, in spec order, so a case added to the branch",
        f"# table and forgotten in the test (or the reverse) fails this block.",
    ]
    for i, case in enumerate(cases):
        witness = _witness_for(param_names, cases, i)
        args = ", ".join(str(witness[p]).lower() for p in param_names)
        desc = case.get("desc", json.dumps(case.get("when", {})))
        raw_value = case["value"]
        # A bare constant name (no "." already in it, e.g. not `Color.WHITE`)
        # is a member of `owner` -- the generated function body is a method
        # ON that class so it reads unqualified there, but the test lives in
        # a different class and needs the same constant written qualified.
        value = f"{owner}.{raw_value}" if owner and "." not in raw_value else raw_value
        lines.append(
            f'err = _T.assert_eq({call_prefix}({args}), {value}, '
            f'"{name}: {desc}")'
        )
        lines.append("if err != \"\": return err")
    return "\n".join(lines) + "\n"


def _spliced(target_text: str, marker: str, body: str) -> str:
    """`target_text` with the block between `# GEN:{marker}:BEGIN` and
    `# GEN:{marker}:END` replaced by `body`, re-indented to match the BEGIN
    marker's own indentation (so a block spliced at file scope and one
    spliced inside a function body both come out looking hand-written)."""
    begin_re = re.compile(rf"^([ \t]*)# GEN:{re.escape(marker)}:BEGIN[ \t]*$", re.MULTILINE)
    end_re = re.compile(rf"^[ \t]*# GEN:{re.escape(marker)}:END[ \t]*$", re.MULTILINE)
    begin = begin_re.search(target_text)
    if begin is None:
        raise SystemExit(f"no '# GEN:{marker}:BEGIN' marker found")
    end = end_re.search(target_text, begin.end())
    if end is None:
        raise SystemExit(f"'# GEN:{marker}:BEGIN' found but no matching END marker")
    indent = begin.group(1)
    new_body = "".join(f"{indent}{line}\n" if line else "\n" for line in body.rstrip("\n").split("\n"))
    return target_text[: begin.end() + 1] + new_body + target_text[end.start() :]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("spec", type=Path)
    ap.add_argument("--print-func", action="store_true")
    ap.add_argument("--print-test", action="store_true")
    ap.add_argument("--write-func", type=Path, metavar="FILE",
                     help="splice the generated function into FILE at its GEN:<function>:BEGIN/END markers")
    ap.add_argument("--write-test", type=Path, metavar="FILE",
                     help="splice the generated test block into FILE at its GEN:<function>:BEGIN/END markers")
    ap.add_argument("--check-func", type=Path, metavar="FILE",
                     help="like --write-func but only checks FILE already matches; exits 1 on mismatch")
    ap.add_argument("--check-test", type=Path, metavar="FILE",
                     help="like --write-test but only checks FILE already matches; exits 1 on mismatch")
    args = ap.parse_args()

    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    marker = spec["function"]
    stale = False

    if args.print_func:
        print(generate_function(spec))
    if args.print_test:
        print(generate_test(spec))
    if not any([args.print_func, args.print_test, args.write_func, args.write_test,
                args.check_func, args.check_test]):
        print(generate_function(spec))
        print(generate_test(spec))

    targets = [
        ("func", args.write_func or args.check_func, generate_function(spec), args.check_func is not None),
        ("test", args.write_test or args.check_test, generate_test(spec), args.check_test is not None),
    ]
    for kind, path, body, check_only in targets:
        if path is None:
            continue
        current = path.read_text(encoding="utf-8")
        updated = _spliced(current, marker, body)
        if check_only:
            if updated != current:
                print(f"STALE: {path} does not match {args.spec} -- regenerate with --write-{kind}",
                      file=sys.stderr)
                stale = True
            continue
        if updated != current:
            path.write_text(updated, encoding="utf-8")
            print(f"wrote {path} (marker GEN:{marker})")
        else:
            print(f"{path} already matches {args.spec} (marker GEN:{marker})")

    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
