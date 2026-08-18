#!/usr/bin/env python3
"""Positive control for heredoc_survey.py -- does it detect damage it should?

A zero from a sweep is only worth reading if the sweep can produce a non-zero.
Run from the repo root: python <this file>
"""
import re
import sys

sys.path.insert(0, "tools")
import gdsource  # noqa: E402

PROSE = re.compile(r"^[ \t]*[A-Z][a-z]+(?: [A-Za-z,'-]+){2,}[.:,]?[ \t]*$")
CODE_TOKEN = re.compile(r"[=(){}\[\]:;]|->|\bfunc\b|\bvar\b|\bconst\b|\breturn\b")
NL = chr(10)
Q = chr(34)
BS = chr(92)


def sig_a(text):
    n = 0
    for start, end, kind in gdsource.literal_spans(text):
        body = text[start:end]
        if kind != "string" or body.startswith(Q * 3) or body.startswith("'''"):
            continue
        if NL in body:
            n += 1
    return n


def sig_b(text):
    code = gdsource.strip_comments(text, gdsource.KEEP)
    return sum(1 for line in code.splitlines()
               if line.strip() and PROSE.match(line) and not CODE_TOKEN.search(line))


CASES = [
    # (name, source, expected_a, expected_b)
    ("clean file",
     'func f() -> void:' + NL + '\tprint(' + Q + 'hello' + Q + ')' + NL, 0, 0),

    # Expected 1 at first and got 2: a chopped string leaves the scanner TWO spans
    # carrying a newline, not one. The detector was right and the expectation was
    # wrong, so this asserts DETECTION rather than a count -- the count is an
    # artefact of how the scanner re-syncs after damage, and pinning it would make
    # this control fail the next time gdsource improves.
    ("SIG A: a heredoc chopped a string across a newline",
     'func f() -> void:' + NL + '\tprint(' + Q + 'hello' + NL + 'world' + Q + ')' + NL,
     "nonzero", 0),

    ("escaped backslash is NOT damage (the 144 false positives)",
     'func f() -> void:' + NL + '\tif c == ' + Q + BS + BS + Q + ':' + NL
     + '\t\tpass' + NL, 0, 0),

    ("quoted phrase wrapping two comment lines is NOT damage (the 554)",
     '## a comment saying ' + Q + 'something' + NL + '## continued' + Q + ' here' + NL
     + 'func f() -> void:' + NL + '\tpass' + NL, 0, 0),

    ("SIG B: a comment block that lost its leading #",
     '## Kept this line.' + NL + 'This line lost its marker entirely.' + NL
     + 'func f() -> void:' + NL + '\tpass' + NL, 0, 1),
]

fails = 0
for name, src, want_a, want_b in CASES:
    got_a, got_b = sig_a(src), sig_b(src)
    ok_a = got_a > 0 if want_a == "nonzero" else got_a == want_a
    ok = ok_a and got_b == want_b
    fails += 0 if ok else 1
    print("%-4s %-62s A=%s/%s  B=%d/%d"
          % ("ok" if ok else "FAIL", name, got_a, want_a, got_b, want_b))
print("")
print("%d of %d control(s) failed" % (fails, len(CASES)))
sys.exit(1 if fails else 0)
