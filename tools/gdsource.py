#!/usr/bin/env python3
r"""gdsource.py - one GDScript source blanker for every tools/ checker, plus its test.

WHY THIS EXISTS.

Six checkers under `tools/` each carried their own copy of "blank `#` comments and
string bodies, preserving offsets":

    group_leak_check.strip_comments      comments truncated, string bodies KEPT
    world_control_check.strip_code       byte-identical to the above, and its
                                         docstring says it removes string bodies,
                                         which it has never done
    suite_reach_check.strip_comments     comments blanked, bodies kept
    suite_reach_check.blank_strings      a second pass, a regex, bodies + quotes gone
    save_persist_check.strip_comments    comments blanked, bodies AND quotes blanked
    settle_read_check.strip_comments     comments blanked, bodies blanked, quotes kept
    message_corpus_check.strip_comments  as settle_read, but character-oriented

Four differences across six copies, and none of them announced: whether a comment is
truncated or padded, whether string bodies survive, whether the quote delimiters
survive, and whether an unterminated literal is contained at the newline or swallows
the rest of the file. That last one is not hypothetical -- cycle 97 spent several
minutes treating `suite_reach_check` as broken because a stray literal newline inside
a string made its regex blanker eat 1018 characters, hiding four symbols that were
sitting in plain sight. The repo had already been bitten once before that by an
escape-blind blanker reading `'...entry[\"key\"]'` as live code.

So: one implementation, three modes, and a `--self-test` of the transform on inputs
written out by hand. A statistic over the real corpus is the guard that cannot fail
(a deliberately broken blanker still left ~70% of characters intact, and no threshold
separates 74.7% from 70.3%); nine lines of known-in, known-out does not have that
problem.

THE MODES.

    KEEP    comments blanked; strings untouched, body and delimiters and prefix.
            For a rule that reads a literal's contents -- a group name, a res:// path.
    BLANK   comments blanked; string BODIES blanked, quote delimiters kept, a
            `r`/`&`/`^` prefix blanked. The quotes stay so a caller can still see
            that a literal was there.
    ERASE   as BLANK, and the quote delimiters go too. For an identifier scan that
            wants a literal to leave no trace at all.

Every mode is EXACTLY length-preserving and newline-count-preserving, in characters,
so an offset into the result indexes the same character of the raw source. That is
what lets a caller take spans from the blanked text and contents from the raw text,
which is the rule that `message_corpus_check` got wrong in both directions on its
first run.

WHAT IT HANDLES.

    ''' and \"\"\" blocks (newlines inside them survive)
    ' and " strings
    the r"" raw prefix (no escape processing) and the &"" / ^"" StringName and
      NodePath prefixes
    backslash escapes outside raw strings, including a backslash-newline
      continuation, whose newline is emitted so no line number after it shifts
    an UNTERMINATED single-line literal, which stops at the newline instead of
      swallowing the file -- the cycle-97 defect, fixed at the source

WHICH CHECKERS THE BLANKED-REGION BLIND SPOT REACHES.

A blanked region hides tokens, and a checker that reports a token ABSENT will then
accuse the wrong thing. `suite_reach_check` did exactly that in cycle 97 and now says
so in its findings (see its `blanked_token_note`). The other five were checked:

    group_leak / world_control   safe from the ACCUSATION, not from the miss. They
                                 report patterns they FOUND, so a hidden region can
                                 only cost a false negative, never a wrong cause.
    save_persist / settle_read   susceptible in principle: both report a call that
                                 lacks a guard, and a guard inside a hidden region
                                 reads as absent. Neither has been observed doing it.
    message_corpus / meta_key    susceptible, and message_corpus has already done it
                                 once -- a literal cut at a comma matched nothing and
                                 was reported missing from a corpus it was in.

None of them has grown the note clause, because the ROOT cause is fixed here rather
than reported better there: an unterminated single-line literal now costs one line
instead of the rest of the file. What is left is an unterminated `\"\"\"` block, which
Godot will not parse either, and which `suite_reach_check` will name if it sees one.
If a second checker starts producing puzzling absences, the clause is 30 lines and it
belongs there, not copied.

NOT A LIBRARY-ONLY FILE. It declares the house contract marker on purpose and
`check_all.py` therefore runs it, bare, every cycle. Bare, it runs `--self-test`.
That is deliberate: the alternative -- listing it in `NOT_A_CHECKER` like
`repo_walk.py` -- leaves the one guard that protects six checkers as a command
nobody has a reason to type. The defect class it gates is "the shared blanker has
drifted from its specification", which is invisible to every other tool here
precisely because they all now depend on it.

    fixture:   the self-test IS the fixture, and it is permanent rather than
               written-and-deleted. 40 cases: identity, comments, a `#` inside a
               literal, an unbalanced quote inside a COMMENT, escaped quotes, the
               `[\"key\"]` case that shipped broken, single quotes, a triple-quoted
               block, an unterminated literal, the &"" prefix, a raw string, the
               three modes against each other, length/newline preservation,
               first_arg_span over a comma inside a literal and over nested parens,
               normalise_literal, and blanked_regions.
    mutations: 6, all RED, restore clean. Run by hand -- there is no tools/mutate.py
               in this repo yet. Read the COUNT beside each, not just the verdict:

               drop the escape handling in the body loop   -> 3 of 40. The `\"` case
                 and the `[\"key\"]` case that shipped broken here once.
               drop the `#` branch entirely                -> 4 of 40
               truncate the comment instead of padding it  -> 7 of 40. The largest,
                 and rightly: offset preservation is the whole point of the module.
               let an unterminated literal run to EOF      -> 1 of 40, and only the
                 hand-written cycle-97 case catches it. The length/newline
                 preservation cases DO NOT: a runaway literal copies the newline
                 through as a body character, so the totals still balance while the
                 rest of the file is blanked. That single case is the guard, and
                 nothing weaker would do -- which is the argument for known-in,
                 known-out over any statistic.
               make BLANK and ERASE identical              -> 2 of 40
               stop preserving newlines in a triple block  -> 3 of 40

Parallel-safe by construction: stdlib only, opens no project, writes nothing to
`.godot/`, takes no lock. Exit codes follow the house contract: 0 clean, 1 findings
(a self-test failure IS a finding, and an actionable one), 2 could not run.
"""

import argparse
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

# The three modes. Named constants rather than bare strings so a typo at a call site
# is an AttributeError at import time and not a silently different blanking.
KEEP = "keep"
BLANK = "blank"
ERASE = "erase"
MODES = (KEEP, BLANK, ERASE)


def strip_comments(text, strings=KEEP, spans=None):
    """GDScript source with `#` comments blanked and string bodies per `strings`.

    Exactly length-preserving and newline-preserving in every mode, so an index into
    the result indexes the same character of `text`. See the module docstring for the
    mode table and for what this handles.

    If `spans` is a list, every comment and literal this finds is appended to it as
    `(start, end, kind)` with `kind` either "comment" or "string" -- the scanner's own
    account of what it decided, rather than a second parse of its output. Callers need
    that: a blanked literal spanning lines is indistinguishable, in the OUTPUT, from
    several one-line ones, because the newlines inside it are preserved. See
    `literal_spans`.
    """
    if strings not in MODES:
        raise ValueError("strings must be one of %r, got %r" % (MODES, strings))
    keep_body = strings == KEEP
    keep_quote = strings != ERASE

    def record(start, end, kind):
        if spans is not None:
            spans.append((start, end, kind))

    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "\n":
            out.append("\n")
            i += 1
            continue
        if ch == "#":
            # Comments first and unconditionally, so an unbalanced quote inside one
            # (`# he said "hi`) cannot open a literal that eats the rest of the file.
            j = text.find("\n", i)
            if j < 0:
                j = n
            out.append(" " * (j - i))
            record(i, j, "comment")
            i = j
            continue
        if ch in "\"'" or (ch in "r&^" and i + 1 < n and text[i + 1] in "\"'"):
            opened_at = i
            raw = False
            if ch in "r&^":
                raw = ch == "r"
                # The prefix is part of the literal, not an operator. KEEP leaves the
                # source alone; the blanking modes drop it so `&"pests"` cannot read
                # as a stray `&`.
                out.append(ch if keep_body else " ")
                i += 1
                ch = text[i]
            triple = text[i:i + 3] in ('"""', "'''")
            quote = text[i:i + 3] if triple else ch
            out.append(quote if keep_quote else " " * len(quote))
            i += len(quote)
            while i < n:
                c = text[i]
                if c == "\\" and not raw and i + 1 < n:
                    # A `\"` inside a literal is not its terminator. Reading it as one
                    # leaves the tail of the string parsed as live code, which is the
                    # bug that shipped here once and which no good-file/bad-file
                    # fixture can surface -- it corrupts both files identically.
                    # A backslash-NEWLINE is two characters one of which is a line
                    # break; emit the break or every line number after it is off.
                    if keep_body:
                        out.append(text[i:i + 2])
                    else:
                        out.append(" \n" if text[i + 1] == "\n" else "  ")
                    i += 2
                    continue
                if text.startswith(quote, i):
                    break
                if c == "\n" and not triple:
                    # An unterminated single-line literal: Godot will not parse this
                    # file at all. Stop at the newline rather than swallowing the rest
                    # of the file into the literal -- cycle 97 lost four symbols and
                    # several minutes to a blanker that did not.
                    out.append("\n")
                    i += 1
                    break
                out.append(c if (keep_body or c == "\n") else " ")
                i += 1
            if text.startswith(quote, i):
                out.append(quote if keep_quote else " " * len(quote))
                i += len(quote)
            record(opened_at, i, "string")
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def literal_spans(text):
    """[(start, end, kind)] for every comment and string literal, kind-tagged.

    One pass of the same scanner that does the blanking, so the two can never
    disagree about where a literal begins and ends. This is the question a caller
    cannot answer from the blanked TEXT: newlines inside a multi-line literal are
    preserved, so a `\"\"\"` block over forty lines and forty one-line strings blank to
    output that differs from the raw source in exactly the same places. Only the
    scanner knows it was one literal, and this is it saying so.
    """
    spans = []
    strip_comments(text, KEEP, spans)
    return spans


def first_arg_span(code, open_paren):
    """(start, end) of the first argument at a call whose `(` is at `open_paren`.

    Returns a SPAN rather than text, and must be given the BLANKED source. Both of
    those are the same lesson: run over raw source, this splits on the first comma it
    sees, and a comma inside a string literal is still a comma. The opening hint --
    "Plant your free Corn Cobbler on the grass, then grow the first wave." -- was cut
    at `grass,` into an unterminated literal that matched nothing, and was reported as
    absent from a corpus it was sitting in. Slice the raw text with the blanked span;
    `strip_comments` preserves offsets exactly so the two stay aligned.
    """
    depth, i, n = 0, open_paren, len(code)
    start = open_paren + 1
    while i < n:
        ch = code[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                return start, i
        elif ch == "," and depth == 1:
            return start, i
        i += 1
    return start, n


def normalise_literal(text):
    """Collapse a message to its shape, so a format string matches its filled-in twin.

    `"That upgrade costs %d seeds."` at the call site and
    `"That upgrade costs 99999 seeds."` in the corpus are the same message; the corpus
    holds a worst case and the call site holds a template. Comparing them raw is how a
    checker like this ends up demanding the corpus store unrenderable strings.
    """
    text = re.sub(r"%[-+ 0-9.]*[a-zA-Z]", "\x00", text)
    text = re.sub(r"\d+", "\x00", text)
    return re.sub(r"\s+", " ", text).strip()


def blanked_regions(raw, blanked):
    """Maximal [start, end) spans where `blanked` differs from `raw`.

    The other half of "spans come from the blanked text, contents come from the raw
    text". A checker that reports a token as ABSENT is making a claim about the
    blanked view; this is how it asks the raw view whether the token was there all
    along and got blanked -- which turns "no test names this" into "your test file has
    an unterminated string literal", the finding cycle 97 needed and did not get.

    Raises ValueError on a length mismatch, because a caller that lost offset
    alignment must not get plausible-looking spans back.
    """
    if len(raw) != len(blanked):
        raise ValueError("raw and blanked differ in length (%d vs %d); the offsets "
                         "are not aligned and no span computed from them is valid"
                         % (len(raw), len(blanked)))
    spans = []
    start = None
    for i, (a, b) in enumerate(zip(raw, blanked)):
        if a != b:
            if start is None:
                start = i
        elif start is not None:
            spans.append((start, i))
            start = None
    if start is not None:
        spans.append((start, len(raw)))
    return spans


# ---------------------------------------------------------------------------
# The direct test of the transform. Known-in, known-out, written out by hand.
# Not a statistic over the real corpus: that is the guard that cannot fail.

# (label, input, mode, expected output)
STRIP_CASES = [
    ("identity: plain code is untouched",
     "var x := 1\nvar y := 2\n", KEEP,
     "var x := 1\nvar y := 2\n"),

    ("comment blanked, not truncated",
     "var x := 1  # why\nvar y := 2\n", KEEP,
     "var x := 1       \nvar y := 2\n"),

    ("whole-line comment",
     "# a note\nvar x := 1\n", KEEP,
     "        \nvar x := 1\n"),

    ("a # inside a literal is not a comment",
     'var s := "a # b"\n', KEEP,
     'var s := "a # b"\n'),

    ("a # inside a literal is not a comment (BLANK)",
     'var s := "a # b"\n', BLANK,
     'var s := "     "\n'),

    ("an unbalanced quote inside a COMMENT opens nothing",
     '# he said "hi\nvar x := 1\n', BLANK,
     '             \nvar x := 1\n'),

    ("escaped quote does not terminate the literal",
     'var s := "a\\"b"\nvar y := 2\n', BLANK,
     'var s := "    "\nvar y := 2\n'),

    ("the case that shipped broken: entry[\\\"key\\\"]",
     "var s := 'set_meta(entry[\\\"key\\\"])'\nvar y := 2\n", BLANK,
     "var s := '                        '\nvar y := 2\n"),

    ("single-quoted literal",
     "var s := 'abc'\n", ERASE,
     "var s :=      \n"),

    ("BLANK keeps the delimiters, ERASE does not",
     'var s := "abc"\n', BLANK,
     'var s := "   "\n'),

    ("triple-quoted block: newlines inside it survive",
     'var s := """one\ntwo"""\nvar y := 2\n', BLANK,
     'var s := """   \n   """\nvar y := 2\n'),

    ("unterminated single-line literal stops at the newline",
     'var s := "oops\nfunc row_count() -> int:\n', BLANK,
     'var s := "    \nfunc row_count() -> int:\n'),

    ("&\"\" StringName prefix: prefix blanked, quotes kept",
     'const S := &"speed_requested"\n', BLANK,
     'const S :=  "               "\n'),

    ("&\"\" StringName prefix survives KEEP intact",
     'const S := &"speed_requested"\n', KEEP,
     'const S := &"speed_requested"\n'),

    ("raw string: the backslash is not an escape",
     'var s := r"a\\" + "b"\n', BLANK,
     'var s :=  "  " + " "\n'),

    ("backslash-newline continuation keeps its line break",
     'var s := "a\\\nb"\nvar y := 2\n', BLANK,
     'var s := "  \n "\nvar y := 2\n'),

    ("KEEP leaves an escaped quote exactly as written",
     'var s := "a\\"b"\n', KEEP,
     'var s := "a\\"b"\n'),

    ("comment after a literal containing a quote",
     'var s := "a\\"b"  # note\n', ERASE,
     "var s := " + " " * 14 + "\n"),
]

# (label, input) -- every mode must preserve length and newline count exactly.
PRESERVE_CASES = [
    ("mixed source", 'func f() -> void:\n\t# note "x\n\tvar s := "a\\"b, c"  # tail\n'),
    ("unterminated literal", 'var s := "oops\nvar t := "fine"\n'),
    ("triple block", 'var s := """a\nb\nc"""\n'),
]

# (label, RAW code, index of the `(`, expected RAW text of the first argument).
# The span is taken from the BLANKED text and the text is sliced out of the RAW one,
# which is the house rule these two functions exist to make possible. Written this
# way on purpose: `f("a, b", 2)` scanned raw splits at the comma inside the literal,
# which is the exact bug message_corpus_check shipped, so a case that fed raw text in
# and expected the right answer out would be asserting the bug.
SPAN_CASES = [
    ("a comma inside a literal is not an argument separator",
     'f("a, b", 2)', 1, '"a, b"'),
    ("nested parens", 'f(g(1, 2), 3)', 1, 'g(1, 2)'),
    ("single argument", 'f("x")', 1, '"x"'),
    ("unclosed call runs to the end", 'f("x"', 1, '"x"'),
]

# (label, a, b, equal?)
NORMALISE_CASES = [
    ("a %d template equals its filled-in twin",
     "That upgrade costs %d seeds.", "That upgrade costs 99999 seeds.", True),
    ("whitespace collapses", "a   b\tc", "a b c", True),
    ("leading and trailing space stripped", "  hi  ", "hi", True),
    ("different words stay different", "buy corn", "buy peas", False),
]

# (label, source, expected [(start, end, kind)])
SPAN_KIND_CASES = [
    ("a plain literal", 'x = "ab"\n', [(4, 8, "string")]),
    ("a comment", 'x = 1  # hi\n', [(7, 11, "comment")]),
    ("a # inside a literal belongs to the literal",
     'x = "a # b"\n', [(4, 11, "string")]),
    ("a quote inside a comment opens nothing",
     '# he said "hi\nx = 1\n', [(0, 13, "comment")]),
    ("the &\"\" prefix is part of the literal's span",
     'x = &"ab"\n', [(4, 9, "string")]),
    # The case the whole thing exists for: ONE literal over three lines. Blanked
    # output cannot say this -- the newlines inside it survive, so the differing
    # runs look like three separate one-line literals.
    ("a triple-quoted block is ONE span, not one per line",
     'x = """a\nb\nc"""\n', [(4, 15, "string")]),
    ("an unterminated single-line literal ends at the newline",
     'x = "oops\ny = 1\n', [(4, 10, "string")]),
    ("an unterminated triple block runs to the end",
     'x = """oops\ny = 1\n', [(4, 18, "string")]),
    ("two literals on one line are two spans",
     'f("a", "b")\n', [(2, 5, "string"), (7, 10, "string")]),
]

# (label, raw, blanked, expected spans)
REGION_CASES = [
    ("identical texts have no blanked region", "abcd", "abcd", []),
    ("one run", 'x"ab"', 'x"  "', [(2, 4)]),
    ("two runs", 'a"b"c"d"', 'a" "c" "', [(2, 3), (6, 7)]),
    ("a trailing run reaches the end", 'ab', 'a ', [(1, 2)]),
]


def self_test(verbose=True):
    """Return the number of failures, printing each case. A broken transform means
    every finding every checker that imports this printed is unverified.

    `verbose=False` drops the per-case lines and keeps the denominators. A FAILING
    case still prints in full either way -- a quiet mode that can hide the one thing
    the tool exists to say is not a quiet mode, it is a broken one.
    """
    fails = 0
    cases = 0

    def say(line):
        if verbose:
            print(line)

    for label, src, mode, want in STRIP_CASES:
        cases += 1
        got = strip_comments(src, mode)
        ok = got == want
        if not ok:
            fails += 1
        (print if not ok else say)(
            "  %-6s strip_comments/%-5s %s" % ("ok" if ok else "FAIL", mode, label))
        if not ok:
            print("         in   %r" % src)
            print("         want %r" % want)
            print("         got  %r" % got)

    for label, src in PRESERVE_CASES:
        for mode in MODES:
            cases += 1
            got = strip_comments(src, mode)
            ok = len(got) == len(src) and got.count("\n") == src.count("\n")
            if not ok:
                fails += 1
            (print if not ok else say)(
                "  %-6s preserve/%-5s      %s (len %d/%d, lines %d/%d)"
                % ("ok" if ok else "FAIL", mode, label, len(got), len(src),
                   got.count("\n"), src.count("\n")))

    for label, code, paren, want in SPAN_CASES:
        cases += 1
        start, end = first_arg_span(strip_comments(code, BLANK), paren)
        got = code[start:end]
        ok = got == want
        if not ok:
            fails += 1
        (print if not ok else say)("  %-6s first_arg_span       %s (%r/%r)"
                                   % ("ok" if ok else "FAIL", label, got, want))

    for label, a, b, want in NORMALISE_CASES:
        cases += 1
        got = normalise_literal(a) == normalise_literal(b)
        ok = got == want
        if not ok:
            fails += 1
        (print if not ok else say)("  %-6s normalise_literal    %s (%s/%s)"
                                   % ("ok" if ok else "FAIL", label, got, want))

    for label, src, want in SPAN_KIND_CASES:
        cases += 1
        got = literal_spans(src)
        ok = got == want
        if not ok:
            fails += 1
        (print if not ok else say)("  %-6s literal_spans        %s (%r/%r)"
                                   % ("ok" if ok else "FAIL", label, got, want))

    for label, raw, blanked, want in REGION_CASES:
        cases += 1
        got = blanked_regions(raw, blanked)
        ok = got == want
        if not ok:
            fails += 1
        (print if not ok else say)("  %-6s blanked_regions      %s (%r/%r)"
                                   % ("ok" if ok else "FAIL", label, got, want))

    cases += 1
    try:
        blanked_regions("abc", "ab")
        ok = False
    except ValueError:
        ok = True
    if not ok:
        fails += 1
    (print if not ok else say)(
        "  %-6s blanked_regions      a length mismatch raises rather than guessing"
        % ("ok" if ok else "FAIL"))

    print("")
    print("gdsource: %d hand-written case(s) over the shared blanker, %d failure(s)"
          % (cases, fails))
    print("          %d strip_comments case(s), %d x %d preservation case(s), "
          "%d arg-span, %d normalise, %d literal-span, %d region"
          % (len(STRIP_CASES), len(PRESERVE_CASES), len(MODES), len(SPAN_CASES),
             len(NORMALISE_CASES), len(SPAN_KIND_CASES), len(REGION_CASES) + 1))
    if cases == 0:
        print("NOTE: nothing to check -- the case tables are empty. An empty self-test "
              "is not a clean self-test.")
    return fails


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--self-test", action="store_true",
                    help="run the known-in/known-out test of the transform (the "
                         "default, and the only thing this tool does)")
    ap.add_argument("--quiet", action="store_true",
                    help="the summary and the NOT COVERED line only, no per-case lines")
    args = ap.parse_args(argv)
    _ = args.self_test  # accepted for symmetry with the other tools; always runs

    fails = self_test(verbose=not args.quiet)

    print("NOT COVERED: this tests the shared blanker against inputs written out by "
          "hand; it says nothing whatsoever about the repo's own source, and a clean "
          "run here is not a clean run of any checker that imports it. It is a lexer, "
          "not a parser: it does not know GDScript grammar, so a construct it has "
          "never been shown -- a literal form Godot adds, a `#` in a position nobody "
          "has written yet -- is blanked by the rules above and not by the language's. "
          "Nor does it compile anything: only import_check.py and lint_project.gd do "
          "that, and neither is parallel-safe.")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
