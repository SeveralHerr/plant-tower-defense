#!/usr/bin/env python3
"""message_corpus_check.py - every show_message() call site is in Hud.message_corpus().

WHY THIS EXISTS.

`_budget_hud_message_row` prices the widest string the HUD's one message row can be
asked to hold. Its corpus was, for three cycles, a list rebuilt by hand from whatever
the last person found by grepping `show_message(` - and it was wrong every time:

  cycle 41  measured four plant-name messages only; the prep note was 36px wider
  cycle 48  added the prep note; five other producers still unswept
  cycle 51  added three of those five, and left a comment claiming eight call
            sites. There are fourteen.

Each fix was correct about the producer in front of it and silent about the rest,
because "the set of things that reach this row" is not written down anywhere the
budget can read. `Hud.message_corpus()` is now that place. This checker is what makes
it true: it compares the corpus against the call sites, so a producer added without
joining the set is a finding rather than a slow 36px surprise.

Nothing else can see it:

  * lint / name_check / import_check    every one of these call sites RESOLVES. A
                                        message that clips is a correct program.
  * the suite                           `test_no_message_clips_for_any_plant_in_the_
                                        catalogue` sweeps the catalogue through the
                                        four builders - it cannot know about a bare
                                        literal at a call site it has never heard of.
  * the budget itself                   it reports the widest thing IT measured, which
                                        is exactly the number that looks fine when the
                                        corpus is short. A budget over a subset always
                                        reports more headroom than exists.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes no
lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.

    fixture:   7 cases, 20 assertions - all covered / an undeclared literal AND an
               undeclared producer / a format literal ("%d seeds") against its
               filled-in corpus twin / a literal containing a COMMA / an empty corpus
               (exit 2, never clean) / no message_corpus() at all (exit 2) / a project
               with no call sites (says so in words)
    mutations: 7, all red, restore clean - comment-stripping off, literal normalising
               off, empty-corpus guard removed, corpus literals read from the BLANKED
               source, argument span taken from RAW source, declaration guard removed,
               waiver ignored.

TWO OF THOSE MUTATIONS ARE BUGS THIS CHECKER SHIPPED, found by the fixture within
minutes of the first run, and they are kept as mutations so they cannot come back:

  * literals read from the blanked source. Producers are code and must be read with
    string bodies blanked; literals ARE string bodies. Reading both the same way
    reported `1 literal(s)` for a corpus holding five, all hollowed to "" and
    collapsed by the set - and then flagged every one of them as missing.
  * the argument span taken from raw text. `first_arg_span` splits on the first
    top-level comma, and a comma inside a string is still a comma: the opening hint
    ("...on the grass, then grow the first wave.") was cut at `grass,` into an
    unterminated literal that matched nothing. It was reported as absent from a
    corpus it was sitting in.

Both produced FINDINGS rather than silence, which is the good direction to fail in -
but neither was visible from reading the code, and the fixture is what asked.

THE SECOND RULE (added later): a producer's bool VARIANTS, not just its call sites.

The rule above answers "does every show_message() call site resolve to the corpus". It
does not answer "is every string a producer can EMIT in the corpus". A producer with N
bool parameters emits 2**N strings and the budget prices only the ones somebody typed -
which is the same subset-pricing defect this file exists to end, one level down.

`uproot_armed_message` grew a `with_tip` flag and the omission was caught by an
ARITHMETIC accident: a sibling test counts corpus entries per plant and the number moved
from 3 to 4. Nothing checked the thing itself. Running the new rule for the first time
immediately found `next_wave_note(number, pests, boss, weather, last)` - two bools,
priced once of four.

Waivable, because "one combination dominates" is often true and worth recording rather
than padding the corpus to satisfy a counter. next_wave_note IS waived: both flags only
ever `parts.append()`, never substitute, so (true, true) strictly dominates - checked in
the body, not assumed. The waiver may sit on the call's own line or in the comment block
directly above it, since a reason worth reading is usually several lines long.

    fixture:   7 more cases, 13 assertions - no bools / 2 of 2 priced / 1 of 2 / 1 of 4 /
               waived inline / waived in the block above / a waiver separated by real
               code must NOT drift down onto a later call
    mutations: 5, all red - count bools as zero, want 1 instead of 2**N, ignore the
               waiver, let the waiver drift across code, drop variants from the exit code

THE THIRD RULE: a corpus producer nothing calls.

The first rule catches a message the budget never measures. The second catches a string
a producer can emit that nobody priced. This catches the sign flipped: text that IS
priced and can no longer be produced, because its last caller was deleted. The row's
budget reports the widest string in the corpus, so a dead producer sets a ceiling the
game cannot reach - a permanent tax on every future message for a sentence no player
will ever see. `derive-the-list` names the shape: a recorded list with a one-directional
test, where an entry left over from something reshaped sits pointing at nothing.

Clean on this repo the day it was written, which is the honest state to record. Its
value is preventing drift, and the fixture is therefore the whole of its evidence.

    fixture:   4 more cases - every producer has a caller / one nothing calls / one only
               the HUD ITSELF calls (reachable text, not dead) / waived
    mutations: 4, all red - count the corpus body as a caller, count the declaration
               line as a caller, ignore the waiver, drop dead producers from the exit code

Writing it also caught a real defect in this file: the dead-producer rule printed a
`waive:` hint and ignored waivers entirely, because the lookup lived inside the variant
rule's loop. Both rules share `waived_in_corpus()` now - a second copy would have been
the thing that drifted next.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import repo_walk

CORPUS_FUNC = "message_corpus"
CALL = "show_message("
WAIVER = re.compile(r"#\s*message-corpus-check:\s*ok\b")
# A producer named in the corpus as `out.append(name(...))`, and a literal as
# `out.append("...")`. Both forms are what the function actually contains; anything
# else in there is deliberately not part of the contract.
CORPUS_CALL = re.compile(r"out\.append\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(")
CORPUS_LIT = re.compile(r'out\.append\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
LITERAL_ARG = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"')
CALLED_FUNC = re.compile(r"(?:Hud\.)?([A-Za-z_][A-Za-z0-9_]*)\s*\(")


def strip_comments(code: str) -> str:
    """Blank `#` comments and string BODIES, keeping offsets and newlines intact.

    Blanking string bodies matters here for the same reason it matters in every other
    checker in this repo: a rule satisfied by prose is not a rule, and this file's own
    docstring contains the token `show_message(` several times. Escapes are handled --
    a `\\"` inside a literal must not be read as its terminator, which is the bug that
    shipped in a first draft of the repo's other source blanker.
    """
    out = list(code)
    i, n = 0, len(code)
    quote = ""
    while i < n:
        ch = code[i]
        if quote:
            if ch == "\\" and i + 1 < n:
                out[i] = out[i + 1] = " "
                i += 2
                continue
            if ch == quote:
                quote = ""
            elif ch != "\n":
                out[i] = " "
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            while i < n and code[i] != "\n":
                out[i] = " "
                i += 1
            continue
        i += 1
    return "".join(out)


def normalise_literal(text: str) -> str:
    """Collapse a message to its shape, so a format string matches its filled-in twin.

    `"That upgrade costs %d seeds."` at the call site and
    `"That upgrade costs 99999 seeds."` in the corpus are the same message; the corpus
    holds a worst case and the call site holds a template. Comparing them raw is how a
    checker like this ends up demanding the corpus store unrenderable strings.
    """
    text = re.sub(r"%[-+ 0-9.]*[a-zA-Z]", "\x00", text)
    text = re.sub(r"\d+", "\x00", text)
    return re.sub(r"\s+", " ", text).strip()


def first_arg_span(code: str, open_paren: int) -> tuple[int, int]:
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


def read(path: str) -> str:
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read().replace("\r\n", "\n")


def corpus_from(blanked: str, raw: str) -> tuple[set[str], set[str], str]:
    """(producer names, normalised literals, reason it could not be read).

    Takes BOTH the blanked source and the raw one, at the same offsets, because the
    two halves need opposite things. Producers are code, so they are read from the
    blanked text where a `#` comment cannot fake one. Literals ARE string bodies --
    the exact thing blanking destroys -- so they are read from the raw text over the
    same span. A first draft read both from the blanked source and reported
    `1 literal(s)` for a corpus holding five, all of them hollowed to "" and
    collapsed by the set. It found nothing wrong with the project and everything
    wrong with itself, which is the good failure: the denominator said so.
    """
    at = blanked.find("func %s(" % CORPUS_FUNC)
    if at < 0:
        return set(), set(), "no `func %s(` in the HUD source" % CORPUS_FUNC
    end = blanked.find("\nfunc ", at + 1)
    end = end if end > 0 else len(blanked)
    producers = set(CORPUS_CALL.findall(blanked[at:end]))
    literals = {normalise_literal(m) for m in CORPUS_LIT.findall(raw[at:end])}
    return producers, literals, ""


def waived_in_corpus(name: str, blank_lines: list[str], raw_lines: list[str]) -> bool:
    """Is this producer's corpus line waived, inline or in the block directly above it?

    Shared by the variant rule and the dead-producer rule, which is not tidiness: the
    first draft of the dead-producer rule printed a `waive:` hint and then ignored
    waivers entirely, because the lookup lived inside the other rule's loop. The fixture
    caught it, and a second copy would have been the thing that drifted next.

    Contiguous comment lines only, so a waiver cannot drift down from an unrelated block
    further up the function.
    """
    for i, line_blank in enumerate(blank_lines):
        if not re.search(r"\b%s\s*\(" % re.escape(name), line_blank):
            continue
        for j in range(i, -1, -1):
            if WAIVER.search(raw_lines[j]):
                return True
            if j < i and not raw_lines[j].lstrip().startswith("#"):
                break
    return False


def bool_variant_findings(blanked: str, raw: str) -> list[tuple[str, int, int, int]]:
    """[(producer, bool params, appearances, wanted)] for producers priced too few times.

    A producer with N bool parameters can emit 2**N different strings, and the row's
    budget prices only the ones somebody typed into the corpus. `uproot_armed_message`
    grew a `with_tip` flag in cycle 61 and the omission was caught by an ARITHMETIC
    accident -- a sibling test counts entries per plant and the number moved from 3 to
    4. Nothing was checking the thing itself, which is the same subset-pricing defect
    the corpus was built in cycle 52 to end, one level down.

    Live example at the time of writing: `next_wave_note(number, pests, boss, weather,
    last)` has TWO bools and appears once. Whether `(true, true)` dominates the other
    three is a real argument -- both flags only ADD clauses -- but it was an argument
    nobody had written down, which is exactly the state this tool exists to convert
    into either a fix or a stated reason.

    Waivable per corpus line, because "one combination dominates" is often true and is
    worth recording rather than padding the corpus to satisfy a counter.
    """
    at = blanked.find("func %s(" % CORPUS_FUNC)
    if at < 0:
        return []
    end = blanked.find("\nfunc ", at + 1)
    end = end if end > 0 else len(blanked)
    body_blank, body_raw = blanked[at:end], raw[at:end]
    out: list[tuple[str, int, int, int]] = []
    for name in sorted(set(CORPUS_CALL.findall(body_blank))):
        sig = re.search(r"func\s+%s\s*\(((?:[^)]|\n)*)\)" % re.escape(name), blanked)
        if sig is None:
            continue
        bools = len(re.findall(r":\s*bool\b", sig.group(1)))
        if bools == 0:
            continue
        wanted = 2 ** bools
        blank_lines, raw_lines = body_blank.split("\n"), body_raw.split("\n")
        waived = waived_in_corpus(name, blank_lines, raw_lines)
        seen = 0
        for line_blank in blank_lines:
            if re.search(r"\b%s\s*\(" % re.escape(name), line_blank):
                seen += 1
        if not waived and seen < wanted:
            out.append((name, bools, seen, wanted))
    return out


def dead_producer_findings(hud_path: str, files: list[str], producers: set[str]) -> list[str]:
    """Corpus producers that nothing outside the corpus ever calls.

    THE THIRD DIRECTION, and the one with the sign flipped. The call-site rule catches a
    message the budget never measures. The variant rule catches a string a producer can
    emit that nobody priced. This catches the opposite: text that is priced and can no
    longer be produced, because its last caller was deleted.

    That is not harmless. The row's budget reports the widest string in the corpus, so a
    dead producer can set a ceiling the game cannot reach — a permanent tax on every
    future message for a sentence no player will ever see. `derive-the-list` names this
    exact shape: a recorded list with a one-directional test, where an entry left over
    from something reshaped sits pointing at nothing.

    A call inside `message_corpus()` itself does not count, or every producer would look
    alive by virtue of being priced. Nor does the `static func` line that declares it.
    Everything else counts, including a call from elsewhere in the HUD — a producer used
    only by `_paint_message_row` is reachable text, not dead.
    """
    dead: list[str] = []
    try:
        hud_raw = read(hud_path)
        hud_blank = strip_comments(hud_raw)
    except (OSError, UnicodeDecodeError):
        return dead
    span = (0, 0)
    at = hud_blank.find("func %s(" % CORPUS_FUNC)
    if at >= 0:
        end = hud_blank.find("\nfunc ", at + 1)
        span = (at, end if end > 0 else len(hud_blank))
    corpus_blank = hud_blank[span[0]:span[1]].split("\n")
    corpus_raw = hud_raw[span[0]:span[1]].split("\n")
    for name in sorted(producers):
        # The same waiver the variant rule honours, through the same helper — the
        # first draft of this rule printed a `waive:` hint and ignored waivers
        # entirely, because the lookup lived inside the other rule's loop.
        if waived_in_corpus(name, corpus_blank, corpus_raw):
            continue
        calls = 0
        for path in files:
            try:
                code = strip_comments(read(path))
            except (OSError, UnicodeDecodeError):
                continue
            for m in re.finditer(r"\b%s\s*\(" % re.escape(name), code):
                if os.path.abspath(path) == os.path.abspath(hud_path):
                    if span[0] <= m.start() < span[1]:
                        continue
                    line_start = code.rfind("\n", 0, m.start()) + 1
                    if re.match(r"\s*(static\s+)?func\b", code[line_start:m.start()]):
                        continue
                calls += 1
        if calls == 0:
            dead.append(name)
    return dead


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--hud", default=os.path.join("game", "hud.gd"))
    ap.add_argument("--sources", default="game")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    hud_path = os.path.join(root, args.hud)
    if not os.path.isfile(hud_path):
        print("message_corpus_check: no %s - cannot run." % args.hud, file=sys.stderr)
        return 2
    try:
        hud_raw = read(hud_path)
        producers, literals, why = corpus_from(strip_comments(hud_raw), hud_raw)
    except (OSError, UnicodeDecodeError) as exc:
        print("message_corpus_check: cannot read %s (%s)" % (hud_path, exc), file=sys.stderr)
        return 2
    if why:
        print("message_corpus_check: %s - cannot run." % why, file=sys.stderr)
        return 2
    # An empty corpus matches nothing, so every call site would be a finding -- which
    # looks like a catastrophe rather than like a broken checker, and is the single
    # most confusing way for this tool to fail. Say it plainly instead.
    if not producers and not literals:
        print("message_corpus_check: %s() is empty - cannot run. It declares no "
              "producers and no literals, so there is nothing to check call sites "
              "against." % CORPUS_FUNC, file=sys.stderr)
        return 2

    src_root = os.path.join(root, args.sources)
    files = []
    for dirpath, dirnames, filenames in os.walk(src_root):
        # src_root is root/--sources (game/), never the repo root. Shared rule
        # anyway; see repo_walk for why the immunity is not this file's to keep.
        repo_walk.prune(dirpath, dirnames, src_root)
        files.extend(os.path.join(dirpath, f) for f in sorted(filenames) if f.endswith(".gd"))

    findings, sites, waived = [], 0, 0
    for path in sorted(files):
        try:
            raw = read(path)
        except (OSError, UnicodeDecodeError):
            continue
        code = strip_comments(raw)
        raw_lines = raw.split("\n")
        for m in re.finditer(re.escape(CALL), code):
            # The declaration itself is not a call site.
            line_start = code.rfind("\n", 0, m.start()) + 1
            # `func show_message(` is the declaration, not a call site. Comparing
            # the stripped prefix to "func " could never match -- strip() removes the
            # very space it tested for -- so hud.gd's own signature was reported as
            # an uncovered caller until the fixture asked why.
            if code[line_start:m.start()].strip() == "func":
                continue
            sites += 1
            line_no = code.count("\n", 0, m.start()) + 1
            if WAIVER.search(raw_lines[line_no - 1]):
                waived += 1
                continue
            a_start, a_end = first_arg_span(code, m.end() - 1)
            arg = code[a_start:a_end]
            if LITERAL_ARG.match(arg):
                # The blanked code proves it IS a literal and gives the span; the raw
                # text over that same span is what the literal actually says.
                real = LITERAL_ARG.match(raw[a_start:a_end])
                shape = normalise_literal(real.group(1) if real else "")
                if shape in literals:
                    continue
                findings.append((path, line_no, "a literal absent from %s()" % CORPUS_FUNC,
                                 (real.group(1) if real else "<unreadable>")[:60]))
                continue
            named = {n for n in CALLED_FUNC.findall(arg)}
            if named & producers:
                continue
            findings.append((path, line_no, "calls none of the corpus's producers",
                             arg.strip().replace("\n", " ")[:60]))

    variants = bool_variant_findings(strip_comments(hud_raw), hud_raw)
    dead = dead_producer_findings(hud_path, files, producers)
    print("message_corpus_check: %d .gd file(s) under %s, %d %s() call site(s), "
          "%d waived; corpus declares %d producer(s) and %d literal(s); "
          "%d finding(s) + %d unpriced variant(s) + %d dead producer(s)"
          % (len(files), args.sources, sites, CALL[:-1], waived,
             len(producers), len(literals), len(findings), len(variants), len(dead)))
    if sites == 0:
        print("  NOTE: nothing to check -- no %s() call site was found at all. That is "
              "a clean result only if this project genuinely has none; if it has some, "
              "the scan is looking in the wrong place (--sources)." % CALL[:-1])
    for path, line_no, why_it_fails, snippet in findings:
        print("FINDING: %s:%d %s -- `%s`"
              % (os.path.relpath(path, root), line_no, why_it_fails, snippet))
        print("  fix: add it to Hud.%s(), beside the producers it belongs with. A "
              "format string goes in filled to its widest (\"%%d\" -> \"99999\"); the "
              "checker compares shapes, not text." % CORPUS_FUNC)
        print("  waive: add `# %s: ok - <reason>` on the call's own line -- for text "
              "assembled from data no static caller can reach." % "message-corpus-check")
    for name, bools, seen, wanted in variants:
        print("FINDING: %s() takes %d bool parameter(s), so it can emit %d different "
              "strings, and %s() prices %d of them."
              % (name, bools, wanted, CORPUS_FUNC, seen))
        print("  fix: append the missing combination(s) beside the one already there. "
              "The row's budget measures what the FORMAT allows, so a variant nobody "
              "typed is a variant nobody priced.")
        print("  waive: add `# message-corpus-check: ok - <reason>` on that corpus "
              "line -- \"one combination dominates\" is often true and is worth "
              "writing down rather than padding the corpus to satisfy a counter. "
              "It may sit on the call's own line or in the comment block directly "
              "above it, because a reason worth reading is usually several lines.")
    for name in dead:
        print("FINDING: %s() is priced by %s() and called by nothing else."
              % (name, CORPUS_FUNC))
        print("  fix: delete it, or find the caller that was removed. A producer the game "
              "can no longer emit still sets the row's ceiling, which is a permanent tax "
              "on every future message for a sentence no player will ever see.")
        print("  waive: add `# message-corpus-check: ok - <reason>` on its corpus line or "
              "in the comment block above it -- for text reached only through a path this "
              "reads as a waived call site.")
    print("  NOT COVERED: this reads source, not a running tree. It cannot see a "
          "message built at runtime from data (a refusal string, a name from a save), "
          "it does not know the row's WIDTH -- that is the budget's job, and a corpus "
          "can be complete and still too wide -- and it cannot tell whether a corpus "
          "literal is still reachable from anywhere. Nor does it compile: only "
          "import_check.py and lint_project.gd do, and neither is parallel-safe.")
    return 1 if findings or variants or dead else 0


if __name__ == "__main__":
    sys.exit(main())
