#!/usr/bin/env python3
"""test_return_check.py - find a test that computes a failure and then throws it away.

THE DEFECT, and it shipped. `test_the_sport_badge_stays_clear_of_the_health_bar_and_
never_pulses_away` ended `return ""` where it meant `return err`. Everything after the
first block ran, computed real answers, assigned them to `err` -- and the function
returned a pass regardless. The badge overlapped the health bar by four pixels on every
damaged sport for as long as that test existed, and the assertion that said so was
failing on every single run while the suite printed `[PASS]`.

WHICH GATE WOULD HAVE CAUGHT THIS, AND WHY NONE DOES

`run_tests.gd`'s `[VACUOUS]` marker is the closest thing, and it cannot: it fires when a
test executes ZERO of its own `_T.assert_*` calls. This test executed nine. They all ran,
several of them failed, and their verdicts were assigned to a variable the function then
declined to return. `run_tests.py` catches the other silent-pass shape -- a coroutine
aborted by a runtime error, whose return value is coerced to `""` -- but nothing aborted
here; the code did exactly what it said. Lint compiles the file and it compiles.
`suite_reach_check` asks whether a symbol is NAMED by a test, which it was. There is no
runtime signal at all, because from the runner's side a swallowed failure and a genuine
pass are the same three bytes.

WHAT IT LOOKS FOR

The house idiom for a `-> String` test is that `err` carries the verdict and every
assignment to it is followed either by a guard that returns it, or by the function ending
in `return err`. So the finding is: a `func test_*(...) -> String` that assigns `err`,
whose LAST return statement is the literal `""`, with no `return err` anywhere between
that final assignment and that return. At that point the last thing the test measured
provably cannot reach the runner.

Measured across this repo when it was written: 1144 `-> String` test functions, 58 of
which end in `return ""` after assigning `err` -- and 54 of those are correct, because a
`return err` guard sits between. Distinguishing the 58 from the 4 is the entire job, and
a cruder rule (`ends in return ""`) would have reported all 58 and been ignored.

NOT a style rule. `return ""` at the end of a test is fine and idiomatic; what is not
fine is `return ""` after a measurement nothing consumed.
"""

import argparse
import os
import re
import sys

TEST_DIR = "test"

FUNC = re.compile(r"^func (test_\w+)\s*\(.*\)\s*->\s*String:")
ASSIGN = re.compile(r"^\s+(?:var\s+)?err\s*(?::\s*String\s*)?=")
RET_ERR = re.compile(r"^\s+return\s+err\b")
RET_LIT = re.compile(r'^\s+return\s+""\s*$')
RET_ANY = re.compile(r"^\s+return\b")

WAIVER = re.compile(r"#\s*test-return-check:\s*ok\s*-\s*\S")

## Comments are stripped before matching, for the reason
## `.claude/skills/house-static-checker` gives: a rule satisfied by prose is not a rule,
## and this repo has already been bitten by a scan that matched the comment explaining
## why a token was absent. A `# return err` in a docstring must not count as a guard.
## Blanking preserves offsets, so the waiver is looked for in the RAW line at the same
## index -- checking it after the strip would find nothing, which is a bug that shipped
## in a first draft of `group_leak_check`.
COMMENT = re.compile(r"#.*$")


def strip_comment(line):
    return COMMENT.sub(lambda m: " " * len(m.group(0)), line)


def read_text(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def test_scripts(root):
    out = []
    base = os.path.join(root, TEST_DIR)
    if not os.path.isdir(base):
        return out
    for d, _dirs, files in os.walk(base):
        for f in sorted(files):
            if f.endswith(".gd"):
                out.append(os.path.join(d, f))
    return sorted(out)


def scan(path, raw):
    """(functions seen, functions ending in a literal after assigning err, findings)."""
    raw_lines = raw.split("\n")
    lines = [strip_comment(l) for l in raw_lines]
    starts = [i for i, l in enumerate(lines) if FUNC.match(l)]
    findings = []
    shape = 0
    for n, i in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        body = lines[i:end]
        raw_body = raw_lines[i:end]
        last_ret = None
        for j in range(len(body) - 1, -1, -1):
            if RET_ANY.match(body[j]):
                last_ret = j
                break
        if last_ret is None or not RET_LIT.match(body[last_ret]):
            continue
        last_assign = None
        for j in range(last_ret - 1, -1, -1):
            if ASSIGN.match(body[j]):
                last_assign = j
                break
        if last_assign is None:
            continue
        shape += 1
        # A guard between the last measurement and the final return is what makes the
        # literal correct: by then `err` has already been returned if it held anything.
        if any(RET_ERR.match(body[k]) for k in range(last_assign, last_ret)):
            continue
        if any(WAIVER.search(l) for l in raw_body):
            continue
        findings.append({
            "path": path,
            "line": i + 1,
            "name": FUNC.match(body[0]).group(1),
            "assign_line": i + last_assign + 1,
            "assign": raw_body[last_assign].strip(),
            "return_line": i + last_ret + 1,
        })
    return len(starts), shape, findings


FIXTURE = '''extends RefCounted
var _T
func test_a_guard_makes_the_literal_correct() -> String:
	var err: String = _T.assert_true(true, "first")
	if err != "":
		return err
	return ""
func test_the_last_measurement_is_thrown_away() -> String:
	var err: String = _T.assert_true(true, "first")
	if err != "":
		return err
	if err == "":
		err = _T.assert_true(false, "this verdict reaches nobody")
	return ""
'''


def run_fixture():
    """Prove the scan actually fails, on source that is never written to disk.

    A checker nobody has watched fail is a checker nobody knows works. Two functions
    that differ ONLY in whether a guard sits after the last assignment, so this pins the
    discriminating rule and not merely "it finds something".
    """
    seen, shape, findings = scan("(fixture)", FIXTURE)
    ok = (seen == 2 and shape == 2 and len(findings) == 1
          and findings[0]["name"] == "test_the_last_measurement_is_thrown_away")
    print("fixture: %d function(s), %d of the shape, %d finding(s) -- %s"
          % (seen, shape, len(findings), "PASS" if ok else "FAIL"))
    if not ok:
        for f in findings:
            print("  unexpected: %s" % f["name"])
        return 1
    print("  the guarded twin is NOT reported, so the rule under test is the guard and"
          " not the literal return.")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: .)")
    ap.add_argument("--fixture", action="store_true",
                    help="run the synthetic fixture instead of the tree, and exit")
    args = ap.parse_args(argv)

    if args.fixture:
        return run_fixture()

    scripts = test_scripts(args.root)
    if not scripts:
        print("test_return_check: could not run -- no %s/ with .gd files under %s"
              % (TEST_DIR, os.path.abspath(args.root)))
        return 2

    funcs = 0
    shape = 0
    findings = []
    for path in scripts:
        f, s, hits = scan(os.path.relpath(path, args.root), read_text(path))
        funcs += f
        shape += s
        findings.extend(hits)

    print("test_return_check: %d test script(s), %d `-> String` test function(s), "
          "%d of them end in `return \"\"` after assigning err, %d finding(s)"
          % (len(scripts), funcs, shape, len(findings)))
    if funcs == 0:
        print("NOTE: nothing to check -- no `-> String` test function was found. That is a\n"
              "      clean result only if this suite does not use the err-carrying idiom.")
    elif shape == 0:
        print("NOTE: nothing to check -- no function has the shape at all, so the\n"
              "      discriminating rule never ran. Clean only if that is expected.")
    print("NOT COVERED: this reads source, not a running suite. It sees only the LAST\n"
          "             assignment before the LAST return; an err discarded in the middle\n"
          "             of a function and overwritten later is invisible, and so is a\n"
          "             verdict assigned to any name other than `err`. It says nothing\n"
          "             about whether a returned verdict is CORRECT, only that it can\n"
          "             reach the runner. Nor does it compile anything -- only\n"
          "             import_check.py and lint_project.gd do that, and neither is\n"
          "             parallel-safe.")
    for f in findings:
        print("FINDING: %s:%d `%s` assigns err at line %d and then returns the literal\n"
              "         \"\" at line %d, so that verdict cannot reach the runner. A failure\n"
              "         there prints [PASS].\n"
              "  last measurement: %s\n"
              "  fix: end the function `return err`, or guard the assignment with\n"
              "       `if err != \"\": return err` before the literal return.\n"
              "  waive: add `# test-return-check: ok - <reason>` in the function body."
              % (f["path"], f["line"], f["name"], f["assign_line"], f["return_line"],
                 f["assign"][:100]))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
