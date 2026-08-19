#!/usr/bin/env python3
"""Positive control for heredoc_survey.py -- does it detect damage it should?

A zero from a sweep is only worth reading if the sweep can produce a non-zero.
Run from the repo root: python <this file>

THREE SECTIONS, and the second is the one plant-tower-defense-n228 added.

  1. HAND-WRITTEN CASES. Known-in, known-out. Each carries the incident it stands for.
  2. THE OLD RULE, KEPT AND ASSERTED TO FAIL. Section 1 alone cannot record WHY the
     detector was replaced -- a passing control looks the same whichever rule is behind
     it. So the retired rule stays here, and the cycle-125 line is asserted to be
     invisible to it and visible to the shipped one. That pair is the finding, pinned.
  3. DERIVED CORPUS. Sections 1 and 2 are seven lines somebody chose. The question
     "what fraction of the prose in this repo would survive losing its marker" cannot be
     answered by chosen examples, so this takes every comment line in every tracked .gd
     file, deletes the marker, and measures. It is the number that moved: 6.3% -> 99.0%.

This file imports the detectors from heredoc_survey rather than restating them. It used
to carry its own copy of PROSE and CODE_TOKEN, which is a control that tests a
transcription: the day the survey changed, both halves would still have passed.
"""
import io
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / "tools"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gdsource  # noqa: E402
import heredoc_survey as survey  # noqa: E402

NL = chr(10)
Q = chr(34)
BS = chr(92)


def sig_a(text):
    return len(list(survey.signature_a(text)))


def sig_b(text):
    return len(list(survey.signature_b(text)))


# ---------------------------------------------------------------------------
# 1. HAND-WRITTEN CASES
# ---------------------------------------------------------------------------
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

    # plant-tower-defense-n228. THE ACTUAL CYCLE-125 INCIDENT, transcribed from the bead.
    # The rule in place when it happened missed it twice over: the line starts with a
    # lowercase word because it is the middle of a wrapped sentence, and it cites two
    # function names, which the old CODE_TOKEN read as proof the line was code.
    ("SIG B: the cycle-125 line -- mid-sentence, and citing functions",
     '## the ladder is virtual because' + NL
     + '\treason Hud.selection_level_names() is -- upgrade_ladder() is an instance'
     + NL + '\tpass' + NL, 0, 1),

    # A comment naming a function is the single most common shape in this repo. If a
    # citation is enough to hide a line, SIGNATURE B does not cover this codebase.
    ("SIG B: a one-line comment citing a function loses its marker",
     'func f() -> void:' + NL
     + '\tsee selection_level_names() for the list of names it returns' + NL
     + '\tpass' + NL, 0, 1),

    # The counterweight to the two above. Real code that MENTIONS several identifiers
    # in one line must stay silent, or the recall was bought with noise.
    ("valid GDScript with many identifiers is NOT damage",
     'func f(a: int, b: String) -> void:' + NL
     + '\tvar c := Hud.selection_level_names()' + NL
     + '\tif not c.is_empty() and c is Array:' + NL
     + '\t\tprint(' + Q + 'hello world friend of mine' + Q + ')' + NL, 0, 0),
]

# Valid GDScript that a naive "two words in a row" rule would flag. Every one of these
# is legal and must produce zero. The Godot 3 spellings are here because history holds
# them: `setget set_thing, get_thing` is two bare identifiers to a scanner that has
# never heard of 3.x, and it is the reason GD_KEYWORDS carries the 3.x names.
AWKWARD_BUT_VALID = [
    '@export var speed: float = 3.0',
    '@onready var hud := $HUD as Control',
    'static func make(a: int, b: String = ' + Q + 'x' + Q + ') -> Node:',
    '\tvar arr: Array[StringName] = [&' + Q + 'a' + Q + ', &' + Q + 'b' + Q + ']',
    '\tfor i in range(3):',
    '\t\t\tState.IDLE when ready:',
    '\tawait get_tree().create_timer(0.5).timeout',
    '\tassert(a == b, ' + Q + 'a must equal b here now' + Q + ')',
    'class_name Foo extends RefCounted',
    '\tsignal thing_happened(who: Node, what: String)',
    '\tenum Kind { RED, GREEN, BLUE }',
    '\tif not is_instance_valid(n) and n is Node2D:',
    '\t\treturn true if ok else false',
    '\tvar f := func(x): return x + 1',
    '\tprints(' + Q + 'hello there world friend' + Q + ', a, b)',
    '\tvar x = preload(' + Q + 'res://a.gd' + Q + ').new()',
    '\tself.position += Vector2(1, 2)',
    '\tsuper._ready()',
    '\tabstract func thing() -> void:',
    '\texport(int) var legacy = 3',
    '\tsetget set_thing, get_thing',
    '\tremote func rpc_thing():',
]

# ---------------------------------------------------------------------------
# 2. THE RETIRED RULE, KEPT SO THE REASON FOR THE CHANGE CAN BE ASSERTED
# ---------------------------------------------------------------------------
OLD_PROSE = re.compile(r"^[ \t]*[A-Z][a-z]+(?: [A-Za-z,'-]+){2,}[.:,]?[ \t]*$")
OLD_CODE_TOKEN = re.compile(
    r"[=(){}\[\]:;]|->|\bfunc\b|\bvar\b|\bconst\b|\breturn\b")

CYCLE_125 = ('\treason Hud.selection_level_names() is -- upgrade_ladder() is an instance')


def old_sig_b(line):
    return bool(line.strip()) and bool(OLD_PROSE.match(line)) \
        and not OLD_CODE_TOKEN.search(line)


# ---------------------------------------------------------------------------
# 3. DERIVED CORPUS
# ---------------------------------------------------------------------------
# Floor, not the measurement. Measured 99.0% (27,473 of 27,755) at the time of writing;
# the floor sits well below so that editing a comment cannot turn this red, while a
# narrowing of the detector still would. The precision floor is exact on purpose: a
# single false positive over the repo's own working code is a finding, not drift.
RECALL_FLOOR = 90.0
WORDS = re.compile(r"[A-Za-z][A-Za-z'-]*")


def derived_corpus():
    """Every prose-shaped comment line in every tracked .gd file, marker deleted.

    That deletion IS the defect: one line of a comment block losing its '#' is what
    happened in cycles 97, 111 and 125. So this corpus is not a sample of damage, it is
    the whole population of lines that COULD take this damage, generated from the real
    thing rather than imagined.
    """
    paths = [p.strip() for p in subprocess.run(
        ["git", "ls-files", "*.gd"], cwd=str(REPO), capture_output=True, text=True,
        errors="replace", check=True).stdout.splitlines() if p.strip()]
    damaged, statements = [], []
    for rel in paths:
        try:
            text = io.open(str(REPO / rel), encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for line in text.splitlines():
            s = line.lstrip()
            if not s.startswith("#"):
                continue
            body = s.lstrip("#")
            body = body[1:] if body.startswith(" ") else body
            if body.strip() and len(WORDS.findall(body)) >= 3:
                damaged.append(line[:len(line) - len(s)] + body)
        for line in gdsource.strip_comments(text, gdsource.ERASE).splitlines():
            if line.strip():
                statements.append(line)
    return damaged, statements


def main():
    fails = 0

    print("1. HAND-WRITTEN CASES")
    for name, src, want_a, want_b in CASES:
        got_a, got_b = sig_a(src), sig_b(src)
        ok_a = got_a > 0 if want_a == "nonzero" else got_a == want_a
        ok = ok_a and got_b == want_b
        fails += 0 if ok else 1
        print("%-4s %-62s A=%s/%s  B=%d/%d"
              % ("ok" if ok else "FAIL", name, got_a, want_a, got_b, want_b))

    bad = [s for s in AWKWARD_BUT_VALID if sig_b(s + NL)]
    fails += len(bad)
    print("%-4s %-62s   %d/%d silent"
          % ("ok" if not bad else "FAIL", "valid GDScript that must NOT be flagged",
             len(AWKWARD_BUT_VALID) - len(bad), len(AWKWARD_BUT_VALID)))
    for s in bad:
        print("       FALSE POSITIVE on: %s" % s.strip())

    print("")
    print("2. THE RETIRED RULE (asserted to fail, which is why it was retired)")
    old_saw_it = old_sig_b(CYCLE_125)
    new_sees_it = sig_b(CYCLE_125 + NL) > 0
    ok = (not old_saw_it) and new_sees_it
    fails += 0 if ok else 1
    print("%-4s the cycle-125 line: old rule %s, shipped rule %s"
          % ("ok" if ok else "FAIL",
             "SAW it" if old_saw_it else "missed it",
             "sees it" if new_sees_it else "MISSES it"))

    print("")
    print("3. DERIVED CORPUS (this repo's own comments, marker deleted)")
    damaged, statements = derived_corpus()
    if not damaged or not statements:
        # A zero denominator says so in words rather than passing.
        print("COULD NOT RUN -- the derived corpus is empty (%d damaged, %d statement "
              "lines). That is not a clean result." % (len(damaged), len(statements)))
        print("")
        print("%d of %d control(s) failed" % (fails, len(CASES) + 2))
        return 2

    caught = sum(1 for line in damaged if survey.prose_at_statement_position(
        gdsource.strip_comments(line, gdsource.ERASE)))
    recall = 100.0 * caught / len(damaged)
    fp = [line for line in statements if survey.prose_at_statement_position(line)]

    ok_r = recall >= RECALL_FLOOR
    fails += 0 if ok_r else 1
    print("%-4s recall    %d of %d comment lines detected once the marker is gone "
          "= %.1f%% (floor %.1f%%)"
          % ("ok" if ok_r else "FAIL", caught, len(damaged), recall, RECALL_FLOOR))

    ok_p = not fp
    fails += 0 if ok_p else 1
    print("%-4s precision %d false positive(s) over %d real statement lines"
          % ("ok" if ok_p else "FAIL", len(fp), len(statements)))
    for line in fp[:10]:
        print("       FALSE POSITIVE on: %s" % line.strip()[:88])

    print("")
    print("%d of %d control(s) failed" % (fails, len(CASES) + 4))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
