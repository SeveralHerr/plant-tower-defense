#!/usr/bin/env python3
r"""`%` binds tighter than `+`, so a format applied to a concatenated string formats
only its LAST piece.

    _T.assert_true(longest <= 4,
        "the longest label is %d characters -- 'free' is "
            + "the ceiling, and a five-figure price is a different bar" % longest)

That compiles, resolves, lints clean and ships. At runtime GDScript formats the SECOND
literal -- which has no specifier -- so it emits

    ERROR: String formatting error: not all arguments converted during string formatting.

and the message the reader finally sees still carries a raw `%d`. The fix is one pair of
brackets around the concatenation, and the repo has 650 correctly-bracketed sites to copy
from; the shape at risk (a `%` whose left operand is a bare `+` chain) numbered 36 when
this was written, one of them wrong.

WHICH EXISTING GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOESN'T. None of them, and that is
the reason this file exists.

  * `name_check.py` resolves identifiers. Every name here resolves; the defect is in an
    operator's precedence, which is not a name.
  * `lint_project.gd` compiles the script. This IS valid GDScript -- `String % Variant` is
    a legal expression whose operands happen to be the wrong ones -- so the compile is
    clean at 0 errors and 0 warnings.
  * `import_check.py` registers class names and compiles no function body at all.
  * The unit suite is the only thing that sees it, and only as a line in the stderr the
    runner prints under `Engine errors: N ... (advisory)`. Advisory is the right call for
    that number in general and is exactly what buried this one: an assertion message is
    only BUILT when the assertion runs, so the error fires on every suite run and says
    nothing about which of 28,000 assertions produced it, and a defect of this shape in a
    branch the suite does not reach is silent forever.

THE RULE, stated as the checker applies it. For every binary `%` in live code, take the
expression to its left within the same bracket depth and split it on same-depth `+`. A
term that already carries its own same-depth `%` is spoken for and is skipped -- that
shape is deliberate and there is one in this repo (a width claim that formats a number
into one half and a name into the other). If any REMAINING earlier term contains a format
specifier, that specifier is unreachable by this `%`: report it.

The tail term is not examined at all, and that is what keeps the rule quiet. A `%` whose
last piece carries the specifiers is doing what its author meant whether or not earlier
pieces are plain prose.

NOT COVERED: this reads source, not a running tree. It cannot see a specifier COUNT that
disagrees with the argument array (`"%s %s" % [x]`), the mirror-image error
(`"%s" % x + " tail"`, where the format lands before the concatenation and is usually
harmless), a format assembled through a variable rather than a literal, or `%` used as
modulo on something that is a String at runtime. Nor does it compile anything -- only
import_check.py and lint_project.gd do that, and neither is parallel-safe.

NOT COVERED by --self-test specifically: the .gd fixtures prove the RULES fire on
synthetic bytes, and the `blank()` table beside them pins the lexer on seven controlled
inputs. Neither says the tool copes with the SHAPE of real source -- a file where a
mis-lex three hundred lines up is what produces the finding. The plain run over the repo
is the only thing that covers that, and it is what found the multi-line-literal bug the
whole fixture set had missed. Run it, do not only run --self-test.

# fixture:   bare-concat bug / bracketed concat / two-part format / no concat / modulo /
#            specifier inside a comment / specifier inside a blanked string body /
#            a `+` in a group that closes first / a literal spanning a line break
#            plus 7 known-in/known-out cases for blank() itself
# mutations: skip the "already formatted" test    -> the two-part fixture goes red (false +)
#            examine the tail term as well        -> the bracketed fixture goes red
#            drop comment blanking                -> the comment fixture goes red
#            drop string-body blanking            -> the in-string `+ "..." %` goes red
#            never prune on a closing bracket      -> the closed-group fixture goes red
#            end a literal at the line break       -> a blank() case goes red
#            treat an unterminated literal as fine -> a blank() case goes red
#              Those last two SURVIVE the .gd fixtures and are killed only by the
#              known-in/known-out table beside them, which is the argument for having it:
#              a fixture exercises the blanker THROUGH the rule, and the rule can be right
#              about a file the blanker read wrongly.
#            drop the `p > start` filter           -> SURVIVES, and it is an equivalent
#              mutant rather than a coverage gap: a `+` recorded before `start` pairs into
#              a REVERSED slice, and `text[a:b]` with b < a is "", which no specifier can
#              match. Kept anyway. Nothing GUARANTEES that -- it is an accident of Python
#              slicing, not an invariant elsewhere in this file -- so the filter is what
#              states the intent ("only the `+`s inside my own term") rather than leaving
#              it to an empty string.
"""

import argparse
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import repo_walk  # noqa: E402

SPEC = re.compile(r"%[-+ #0-9.*]*[dsfvxXcob]")
WAIVER = re.compile(r"#\s*format-concat-check:\s*ok\b")
OPENERS = "([{"
CLOSERS = ")]}"


class Unlexable(Exception):
    """A quote this blanker could not close. Nothing after it was read correctly."""


def blank(text):
    """Return text with comment bodies and string bodies replaced by spaces.

    Offsets are preserved exactly, so a span found in the blanked text slices the raw
    text at the same place -- which is how the contents of a literal are read back after
    its structure has been found. Handles `\\"` and `\\\\`, because a blanker that does
    not is a blanker that reads `entry[\\"key\\"]` as live code.

    A STRING LITERAL MAY CONTAIN A REAL NEWLINE, and this cost the first draft nine false
    findings. `test/unit/test_placement.gd:6423` splits on a newline written as one:

        for line: String in text.split("
        "):

    A blanker that ends a literal at the line break reads the closing quote on the next
    line as an OPENING one, and every bracket after it is counted with the sense inverted
    -- so this file's bracket depth never returned to zero again, and a `%` five hundred
    lines further on was handed a term that began mid-statement. Nothing about that looked
    like a lexing bug in the output; it looked like nine findings on one line.

    So a literal runs to its matching quote however many lines that takes, and a quote
    with no partner raises rather than guessing: an unlexable file is a file this tool
    verified nothing about, which is exit 2 and not a clean pass.
    """
    out = list(text)
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "#":
            while i < n and text[i] != "\n":
                out[i] = " "
                i += 1
            continue
        if ch in "\"'":
            quote = ch
            # A triple quote is its own delimiter; `""` immediately followed by a third
            # quote is not an empty string next to a stray one.
            triple = text[i:i + 3] == ch * 3
            close = ch * 3 if triple else ch
            i += 3 if triple else 1
            closed = False
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    out[i] = " "
                    out[i + 1] = " "
                    i += 2
                    continue
                if text[i:i + len(close)] == close:
                    i += len(close)
                    closed = True
                    break
                if text[i] != "\n":
                    out[i] = " "
                i += 1
            if not closed:
                raise Unlexable("unterminated %s literal at offset %d (line %d)"
                                % (quote, i, text.count("\n", 0, i) + 1))
            continue
        i += 1
    return "".join(out)


def _line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def _enclosing_function(text, pos):
    best = "<file scope>"
    for m in re.finditer(r"^(?:static\s+)?func\s+(\w+)", text[:pos], re.MULTILINE):
        best = m.group(1)
    return best


def findings_for(text, b):
    """Every unreachable specifier in one file, as (line, func, term_excerpt).

    Takes the blanked text rather than blanking again: spans come from `b` and contents
    come from `text`, at identical offsets, and nothing here ever scans raw source for
    structure.
    """
    # Where each currently-open bracket started, so a `%` can find its own term's left
    # edge: everything back to `stack[-1]`, or to the start of the statement at depth 0.
    stack = []
    marks = []
    # Positions of `+` and of an already-applied `%`, at the CURRENT depth only. Flat
    # lists pruned when a bracket closes, rather than a dict keyed by depth: an entry
    # deeper than the `%` was inside a group that has since closed and is pruned here, and
    # one shallower sits before `start` and is filtered there. A depth key on top of those
    # two can never disagree with them -- a mutation that removed it changed no result,
    # which is what said to delete the key rather than write a test for it.
    plus = []
    pct = []
    for i, ch in enumerate(b):
        if ch in OPENERS:
            stack.append(i)
        elif ch in CLOSERS:
            opener = stack.pop() if stack else -1
            plus = [p for p in plus if p < opener]
            pct = [p for p in pct if p < opener]
        elif ch == "\n" and not stack:
            plus = []
            pct = []
        elif ch == "+":
            plus.append(i)
        elif ch == "%":
            start = stack[-1] + 1 if stack else b.rfind("\n", 0, i) + 1
            same = [p for p in plus if p > start]
            if same:
                marks.append((i, start, same, [p for p in pct if p > start]))
            pct.append(i)

    out = []
    for pos, start, pluses, earlier_pct in marks:
        # Split [start, pos) into terms on the same-depth `+`s. The tail term -- after the
        # last `+` -- is the one this `%` actually formats, and is deliberately not read.
        edges = [start] + [p + 1 for p in pluses]
        for a, b_end in zip(edges, pluses):
            term_raw = text[a:b_end]
            if any(a <= q < b_end for q in earlier_pct):
                continue  # already formatted by its own `%`; a deliberate two-part message
            if not SPEC.search(term_raw):
                continue
            line = _line_of(text, a)
            if WAIVER.search(text.split("\n")[line - 1]):
                continue
            # From the term's first LITERAL, not from `start`: `start` is the enclosing
            # bracket, so an excerpt taken from there opens with the call's earlier
            # arguments and buries the piece the finding is about.
            quote = b[a:b_end].find('"')
            excerpt = " ".join(term_raw[quote if quote >= 0 else 0:].split())[:78]
            out.append((line, _enclosing_function(text, a), excerpt))
            break
    return out


def _gd_files(root):
    """Every .gd under `root`, with agent worktrees and .godot pruned by repo_walk.

    `repo_walk` and not a hand-rolled exclusion: agent worktrees live at
    `.claude/worktrees/<lane>/` INSIDE the repo, so an unguarded walk sees N+1 copies of
    every file during a fan-out, and an exclusion written against an absolute path breaks
    the other way when the tool is run from inside a lane.
    """
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        repo_walk.prune(dirpath, dirnames, root)
        for name in sorted(filenames):
            if name.endswith(".gd"):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


def scan(root):
    files = 0
    sites = 0
    concat_sites = 0
    found = []
    for path in _gd_files(root):
        try:
            text = open(path, encoding="utf-8").read()
        except (OSError, UnicodeDecodeError) as exc:
            print("ERROR: cannot read %s: %s" % (path, exc))
            return None
        files += 1
        try:
            b = blank(text)
        except Unlexable as exc:
            print("ERROR: cannot lex %s: %s -- nothing in this file was checked, and a "
                  "desynced quote makes every bracket after it count the wrong way."
                  % (path, exc))
            return None
        sites += b.count("%")
        # The at-risk shape, counted on the BLANKED text so a `+ "..." %` written inside a
        # string literal or a comment is not counted as code. This is the denominator that
        # matters: `0 finding(s)` is only reassuring beside a non-zero count here.
        concat_sites += len(re.findall(r'\+\s*"[^"\n]*"\s*%\s*[\[\w]', b))
        for line, func, excerpt in findings_for(text, b):
            found.append((os.path.relpath(path, root).replace("\\", "/"), line, func, excerpt))
    return files, sites, concat_sites, found


FIXTURE = {
    "bad_bare.gd": '''
func f(n: int) -> String:
\treturn _T.assert_true(n <= 4,
\t\t"zorbat count is %d and the tail carries none of it "
\t\t\t+ "so this trailing clause is what gets formatted" % n)
''',
    "good_bracketed.gd": '''
func f(n: int) -> String:
\treturn _T.assert_true(n <= 4,
\t\t("zorbat count is %d and the tail carries none of it "
\t\t\t+ "so this trailing clause is inside the brackets") % n)
''',
    "good_two_part.gd": '''
func f(a: float, b: float, s: String) -> String:
\treturn _T.assert_true(a <= b,
\t\t"zorbat width %.0fpx of %.0f -- "
\t\t\t% [a, b]
\t\t\t+ "\\"%s\\". Shorten it." % s)
''',
    "good_no_concat.gd": '''
func f(n: int) -> String:
\treturn "zorbat count is %d" % n
''',
    "good_modulo.gd": '''
func f(n: int) -> int:
\tvar bump: int = n + 3
\treturn bump % 7
''',
    "good_in_comment.gd": '''
func f(n: int) -> String:
\t# A comment mentioning "%d and " + "a tail" % n, which is prose and not code.
\treturn "zorbat %d" % n
''',
    # A literal that spans a line break, with real code after it. If the blanker ends the
    # literal at the break, the closing quote reads as an opening one and every bracket
    # after it is counted inverted -- so the assertion further down is handed a term that
    # starts mid-statement. This is the case that produced nine findings on one line
    # against the real repo, and it is here because the plain run found it and the
    # original fixture could not have.
    "good_split_across_lines.gd": '''
func f(text: String, n: int) -> String:
\tvar code: String = ""
\tfor line: String in text.split("
"):
\t\tcode += line
\treturn _T.assert_eq(code.length(), n,
\t\t("zorbat length is %d and this piece is inside the brackets "
\t\t\t+ "so the tail needs nothing of its own") % n)
''',
    # A `+` inside a group that CLOSES before the `%` belongs to that group, not to the
    # `%`'s own term. Described rather than spelled out: naming the rule inside the
    # artifact under test is how a fixture disarms itself.
    "good_closed_group.gd": '''
func f(n: int) -> String:
\tvar head: String = zorbat("a %d piece " + "and its bracketed tail", n)
\treturn head + "plain" % n
''',
    "good_in_string.gd": '''
func f(n: int) -> String:
\tvar sample: String = "the shape is: \\"%d \\" + \\"tail\\" % n"
\treturn sample + str(n)
''',
}

# (fixture file, must-appear substring). Asserted per rule, not by count alone: a total
# that stays at 1 while this rule falls silent and another double-fires is exactly what a
# count cannot see.
EXPECTED = [("bad_bare.gd", "zorbat count is %d")]


# Known-in / known-out for the blanker, written out by hand.
#
# Here rather than only in the .gd fixtures because a fixture tests the blanker through
# the whole rule, and the rule can be right about a file the blanker read wrongly: both
# lexer mutations below (`end a literal at the line break`, `treat an unterminated literal
# as fine`) SURVIVED the .gd fixtures and are killed here. A statistic over the real
# corpus would not have done it either -- a blanker leaving 70% of characters intact
# passes any threshold you would think to write.
#
# `None` for the expected output means "must raise Unlexable".
BLANK_CASES = [
    ('a = "hi" + b', 'a = "  " + b'),
    ('a = "say \\"hi\\"" + b', 'a = "          " + b'),  # escaped quotes are body, not delimiter
    ('a = 1 # "hi" (\n b = 2', 'a = 1         \n b = 2'),  # a comment cannot open a bracket
    ('x = t.split("\n")', 'x = t.split("\n")'),  # a real newline INSIDE a literal survives as one
    ('x = "a\nb" + c', 'x = " \n " + c'),  # ...and the literal keeps running past it
    ('x = """a "b" c""" + d', 'x = """       """ + d'),  # a triple quote is one delimiter
    ('x = "unterminated', None),
]


def _check_blank():
    ok = True
    for src, want in BLANK_CASES:
        try:
            got = blank(src)
        except Unlexable:
            got = None
        if got != want:
            print("self-test: FAILED -- blank(%r)\n            got  %r\n            want %r"
                  % (src, got, want))
            ok = False
    print("self-test: blank() over %d known-in/known-out case(s): %s"
          % (len(BLANK_CASES), "PASS" if ok else "FAIL"))
    return ok


def self_test():
    blank_ok = _check_blank()
    with tempfile.TemporaryDirectory() as tmp:
        for name, body in FIXTURE.items():
            with open(os.path.join(tmp, name), "w", encoding="utf-8") as handle:
                handle.write(body)
        result = scan(tmp)
        if result is None:
            print("self-test: FAILED -- the scan could not run")
            return 2
        files, _sites, _concat, found = result
        print("self-test: %d synthetic file(s), %d finding(s)" % (files, len(found)))
        for rel, line, func, excerpt in found:
            print("  %s:%d %s -- %s" % (rel, line, func, excerpt))
        ok = blank_ok
        for name, needle in EXPECTED:
            hit = [f for f in found if f[0] == name and needle in f[3]]
            if len(hit) != 1:
                print("self-test: FAILED -- %s should fire exactly once on %r, fired %d"
                      % (name, needle, len(hit)))
                ok = False
        extra = [f for f in found if not f[0].startswith("bad_")]
        if extra:
            print("self-test: FAILED -- false positive(s) on the good fixtures:")
            for rel, line, func, excerpt in extra:
                print("  %s:%d %s -- %s" % (rel, line, func, excerpt))
            ok = False
        print("self-test: %s" % ("PASS" if ok else "FAIL"))
        return 0 if ok else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=None, help="repo root (default: this tool's parent)")
    parser.add_argument("--self-test", action="store_true",
                        help="run the synthetic fixture instead of the repo and exit")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    root = args.root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("format_concat_check: cannot run -- no project.godot under %s" % root)
        return 2
    result = scan(root)
    if result is None:
        return 2
    files, sites, concat_sites, found = result

    if files == 0:
        print("NOTE: nothing to check -- no .gd file was found under %s. That is a clean "
              "result only if you expected none." % root)
        print("NOT COVERED: see this tool's docstring.")
        return 2

    print("format_concat_check: %d .gd file(s), %d `%%` operator(s) in live code, "
          "%d of them applied to a bare `+` chain, %d finding(s)"
          % (files, sites, concat_sites, len(found)))
    if sites == 0:
        print("NOTE: nothing to check -- not one `%` survived comment and string blanking. "
              "That is a clean result only if you expected none.")
    for rel, line, func, excerpt in found:
        print("FINDING: %s:%d %s -- this `%%` formats only the LAST piece of the "
              "concatenation, so the specifier(s) in an earlier piece are never filled in "
              "and GDScript emits `String formatting error: not all arguments converted`."
              % (rel, line, func))
        print("         unreachable piece: %s" % excerpt)
        print("  fix: bracket the whole concatenation before the `%`, "
              "`(\"a %s \" + \"b\") %% x` -- see test/unit/test_selftest.gd's "
              "assert_true calls for 650 worked examples.")
        print("  waive: add `# format-concat-check: ok - <reason>` on the piece's own line.")
    print("NOT COVERED: this reads source, not a running tree. It cannot see a specifier "
          "count that disagrees with the argument array, the mirror-image "
          "`\"%s\" %% x + \" tail\"`, a format assembled through a variable, or `%%` used "
          "as modulo on a String. Nor does it compile anything -- only import_check.py and "
          "lint_project.gd do that, and neither is parallel-safe.")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
