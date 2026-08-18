#!/usr/bin/env python3
r"""sfx_call_check.py - the ids the game PLAYS and the ids `Sfx.SOUNDS` declares are one set.

WHY THIS EXISTS.

`test_every_event_id_the_call_sites_use_is_in_the_table` (test/unit/test_combat.gd)
opens with a hand-typed array whose comment calls it "the event ids the CALL SITES
use". It is checked against `Sfx.SOUNDS` -- every entry has a row, and the two are the
same length -- and it is never checked against a call site at all. So the docstring's
claim is prose, and the guard has a hole shaped exactly like the thing it describes:

  * add a cue WITH a SOUNDS row and forget the test array -> the size assertion fires.
    Loud, immediate, and paid ten times in this repo's history (git log -L over that
    array: 34f436b, 2a162f3, 388db1a, 6117da4, 075fce9, a2f91d9, 6dbbe19, 5e6f766,
    488b687, 5a7bfe8, f9d068e). That direction works, and this tool does not replace it.
  * add a cue with NO SOUNDS row -> `Sfx.play(Sfx.NEW_CUE)` compiles, resolves, runs,
    returns false and is silent forever. The test only sees it if somebody hand-added
    the constant to the array, which is the edit they just failed to make. Nothing
    fires. This is the primary hole.
  * delete a cue's last call site -> the row, its stream, and its `VOLUME_DB`/`PITCH`/
    `REPEAT_MS` tuning stay. The suite stays green over a sound the game cannot emit,
    and `test_no_two_events_are_the_same_sound` keeps spending uniqueness budget on it.

Nothing else can see either of those:

  * lint / name_check / import_check   every one of these call sites RESOLVES. A cue
                                       with no table row is a correct program.
  * the suite                          `Sfx.play()` is gated off headless
                                       (`should_play` -> false), so no test can watch a
                                       call site play anything. The tests assert the
                                       TABLES, and a table is what is being doubted.
  * the hand-typed array               it is one of the two sides being compared. It
                                       cannot be the check on itself.

The tool is the second side `derive-the-list` asks for: the game source says what is
played, the tables say what is playable, and this compares them in both directions.

WHY THE ARRAY IN THE TEST STAYS HAND-TYPED.

Deriving it from `Sfx.SOUNDS` would leave the test asserting that SOUNDS equals SOUNDS.
`.claude/skills/derive-the-list/SKILL.md` has the section: when deriving would remove
the second side, the hand-typing IS the check. The array stays, with a comment saying
so, and the half it cannot reach -- the call sites -- lives here instead.

RESOLVING ONE LEVEL OF INDIRECTION IS NOT OPTIONAL, AND HISTORY SAYS SO.

The one time this repo ever removed an `Sfx.play(Sfx.X)` line for real, in 5a7bfe8:

    -   Sfx.play(Sfx.PEST_KILLED)
    +   Sfx.play(Sfx.kill_event_for(pest.husk_multiplier()))

A checker matching only `Sfx.play(Sfx.<CONST>)` would have called PEST_KILLED dead on
the exact commit that made it more alive, and PEST_KILLED_HARD absent from the game.
So an argument that calls a function declared in sfx.gd is resolved by scanning that
function's body for event constants -- one level, and the tool says so out loud. Every
`Sfx.play(` argument that resolves to no id at all is a FINDING, not a silence, because
an argument the matcher stepped over is how the other two rules go quietly wrong.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes no
lock, stdlib only. Exit codes follow the house contract: 0 clean, 1 findings, 2 could
not run.

THE SOURCE BLANKER IS BORROWED, DELIBERATELY. See the import below: this file owns no
copy of `strip_comments`/`first_arg_span`. They come from `tools/gdsource.py`, and this
file asks for `strings=BLANK` rather than taking the default. Both halves matter on this
corpus -- `game/nettle.gd:240` and `game/chomp_flower.gd:441` both write `Sfx.play()`
inside a COMMENT, and counting either as a call site puts an unresolvable argument into
the run; a `Sfx.play(` inside a string literal would do the same, which is what the
BLANK mode is for and what the KEEP default would let through.

    fixture:   13 cases, run out of tree, baseline exit 1 with exactly 5 findings -
               a covered id / a played id with no SOUNDS row / a SOUNDS row nothing plays
               / a PITCH key that is not a SOUNDS key / two ids reached only through a
               one-level helper / a ternary passing TWO ids in one call / a call site
               that is only a COMMENT, in two files / a const named in a COMMENT inside a
               helper body / an argument two levels down / an id computed away from the
               call into a local / a dead row waived from the block above / a dead row
               waived INLINE / a call with EMPTY parentheses. Plus two cannot-run cases:
               no SOUNDS table (exit 2) and no call site anywhere (exit 2).
    mutations: 13, all RED, restore clean. Measured 2026-08-17; four of them run against
               the REAL corpus (`[repo]`, baseline exit 0 / 0 findings) and not only
               against a fixture built to make them go red.
               comment-stripping off (sfx.gd)     -> -1: the comment inside mystery_cue()
                                                     naming ALPHA makes the helper
                                                     "resolve" and its finding vanish
               comment-stripping off (call sites) -> +-0 BY COUNT, two different findings
                                                     by text; see below.
                                           [repo] -> +3: the `Sfx.play()` written inside
                                                     a comment in nettle.gd:240,
                                                     chomp_flower.gd:441 and sfx.gd:234
                                                     each become a call site with no
                                                     argument
               helper resolution off              -> +3: ECHO_HARD/ECHO_SOFT go dead AND
                                                     echo_for() goes unresolved
               helper bodies unreadable    [repo] -> +3: PEST_KILLED and PEST_KILLED_HARD
                                                     go dead and game.gd:949 goes
                                                     unresolved -- the 5a7bfe8 shape
               read only the FIRST identifier
                 in the argument                  -> +2 on the fixture (4 gained, 2 lost:
                                                     the ternary's second id goes dead)
                                           [repo] -> +24, i.e. every id in the game:
                                                     `Sfx` is the first token and it is
                                                     noise, so nothing resolves at all
               tuning-table rule dropped          -> -1: the stale PITCH key unseen
               unresolved args not in findings    -> -2: the exit code stops reporting
                                                     what the matcher stepped over
               waiver regex never matches         -> +2: both waived rows fire
               waiver allowed to drift across
                 real code                        -> -2: one waiver silences the rest of
                                                     the file, which is a shipped bug in
                                                     another checker here
               `sites == 0` falls through         -> exit 2 becomes exit 1 with 6
                                                     findings: a mis-pointed --sources
                                                     reads as a catastrophe, not a
                                                     broken invocation

THE SURVIVOR THAT WAS NOT ONE, kept because it cost a wrong verdict for one round:
`comment-stripping off at the call sites` first read SURVIVED against a finding COUNT.
It made a commented `Sfx.play(Sfx.CHARLIE)` keep CHARLIE alive (-1) and a commented
`Sfx.play(Sfx.GHOST_CUE)` a live unresolved argument (+1), and 5 == 5. Two bugs summing
to zero, reported as evidence that a load-bearing guard was dead code. Compare the
finding TEXT, not the count, when mutating this tool.

The same round produced two more corrections worth keeping. Against the REAL corpus
that mutation was a genuine survivor, because the three commented `Sfx.play()` here all
have EMPTY parentheses and an empty argument reported nothing at all -- a hole in the
tool, found by a mutation rather than by the fixture; `resolve_arg` now names it. And
`helper resolution off` came back NOT-APPLIED, not SURVIVED, because the needle
contained `\b` and a shell heredoc ate a backslash level: assert every needle matches
exactly once, and prefer a needle with no backslashes in it.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import repo_walk

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

# The shared source blanker, which now lives in tools/gdsource.py. The fallback that
# stood here until plant-tower-defense-g1j9 landed imported message_corpus_check's own
# copy; that copy no longer exists, so the fallback would have raised rather than
# fallen back. Removed rather than repointed.
#
# `strings=BLANK` is NOT the default and must be passed. gdsource.strip_comments
# defaults to KEEP, which leaves string BODIES intact -- and the two modes differ on 40
# of this repo's 44 game/*.gd files. This file was written and mutation-tested against
# the blanking behaviour, so taking the default would silently count a `Sfx.play(`
# written inside a string literal as a real call site.
from gdsource import BLANK, first_arg_span, strip_comments

CALL = "Sfx.play("
TABLE = "SOUNDS"
WAIVER = re.compile(r"#\s*sfx-call-check:\s*ok\b")

# `const PLANT_PLACED := &"plant_placed"`. Read from the BLANKED source, where a
# commented-out constant cannot pretend to exist; the `&"` survives blanking because
# only the string BODY is hollowed, so the pattern still anchors.
CONST_DECL = re.compile(r'^const ([A-Z_][A-Z0-9_]*)\s*:=\s*&"', re.M)
# The same declaration read from RAW, for the value, so a `&"literal"` argument can be
# resolved back to the constant that spells it.
CONST_VALUE = re.compile(r'^const ([A-Z_][A-Z0-9_]*)\s*:=\s*&"((?:[^"\\]|\\.)*)"', re.M)
DICT_DECL = re.compile(r"^const ([A-Z_][A-Z0-9_]*)\s*(?::\s*Dictionary\s*)?=\s*\{", re.M)
DICT_KEY = re.compile(r"^\s*([A-Z_][A-Z0-9_]*)\s*:", re.M)
FUNC_DECL = r"^(?:static\s+)?func\s+%s\s*\("
IDENT = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*(\()?")
NAME_LITERAL = re.compile(r'&"((?:[^"\\]|\\.)*)"')

# Tokens that appear inside an argument and are not an identifier the tool should try
# to resolve. `Sfx` is the qualifier itself; the rest is GDScript grammar that shows up
# in a ternary or a cast.
NOISE = frozenset({
    "Sfx", "if", "else", "elif", "and", "or", "not", "in", "is", "as", "true", "false",
    "null", "self", "var", "await", "func", "return",
})


def read(path: str) -> str:
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read().replace("\r\n", "\n")


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def rel(path: str, root: str) -> str:
    return os.path.relpath(path, root).replace(os.sep, "/")


def dict_span(blanked: str, name: str):
    """(start, end) of `const NAME ... = {` .. the `\n}` that closes it, or None.

    Taken from the blanked source so a table inside a commented-out block is not a
    table. The close is the first line-initial `}`, which is how every dictionary in
    this project's sources is written; a nested one would end the span early, and that
    can only ever make the read SMALLER -- so the key count is printed as a denominator
    rather than trusted.
    """
    for m in DICT_DECL.finditer(blanked):
        if m.group(1) != name:
            continue
        end = blanked.find("\n}", m.end())
        return m.start(), (end if end > 0 else len(blanked))
    return None


def dict_keys(blanked: str, span) -> list:
    """[(key, offset)] for the bare-identifier keys of the dictionary at `span`."""
    start, end = span
    out = []
    for m in DICT_KEY.finditer(blanked[start:end]):
        out.append((m.group(1), start + m.start(1)))
    return out


def func_body(blanked: str, name: str) -> str:
    """The body of `func NAME(` in the blanked source, up to the next top-level func."""
    decl = re.search(FUNC_DECL % re.escape(name), blanked, re.M)
    if decl is None:
        return ""
    rest = blanked[decl.end():]
    nxt = re.search(r"^(?:static\s+)?func\s", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def depth_at(text: str) -> list:
    """Bracket depth before each character of `text`, for the depth-0 rule below."""
    out, depth = [], 0
    for ch in text:
        if ch in ")]}":
            depth -= 1
        out.append(depth)
        if ch in "([{":
            depth += 1
    return out


def resolve_arg(arg_blank: str, arg_raw: str, consts: dict, values: dict,
                sfx_blank: str) -> tuple:
    """(ids reached by this argument, the reasons it could not be fully resolved).

    THE MATCHER, and the place to read when a count looks wrong. Three rules, each of
    which exists because the obvious version of this function was wrong on the real
    corpus before the fixture was ever written:

    EVERY identifier, not the first. A ternary puts two constants in one call --
    `Sfx.play(Sfx.RUN_WON if victory else Sfx.RUN_LOST)` (game/game.gd:1045) -- and a
    line-oriented extraction of this exact pattern is a documented past mistake here.

    DEPTH 0 ONLY. `Sfx.play(Sfx.kill_event_for(pest.husk_multiplier()))` has `pest` and
    `husk_multiplier` inside the helper's own parentheses: they are the helper's
    argument, not a cue. Counting them made the first run of this tool report three
    findings against a file that is correct.

    A CALL AT DEPTH 0 IS FOLLOWED ONE LEVEL. If sfx.gd declares the function, its body
    is scanned for event constants; if it does not, or the body names none, that is a
    real gap and is reported even when a sibling term did resolve. A BARE identifier
    that is not a constant is only reported when the argument yielded nothing at all --
    beside a resolved id it is a ternary's condition, and nothing static separates
    `victory` from a variable holding a cue.
    """
    ids, unresolved = set(), []
    if not arg_blank.strip():
        # `Sfx.play()` with nothing in it. Not hypothetical: with comment-stripping
        # disabled, `game/nettle.gd:240` and `game/chomp_flower.gd:441` both become
        # exactly this, and an empty argument that reported nothing let a broken
        # blanker look like a working one on the real corpus.
        return ids, ["the call has no argument at all"]
    depths = depth_at(arg_blank)

    def at_top(offset: int) -> bool:
        return offset < len(depths) and depths[offset] == 0

    for m in NAME_LITERAL.finditer(arg_raw):
        if not at_top(m.start()):
            continue
        name = values.get(m.group(1))
        if name is not None:
            ids.add(name)
        else:
            unresolved.append('the literal &"%s", which no event constant spells'
                              % m.group(1)[:32])
    bare = []
    for m in IDENT.finditer(arg_blank):
        token = m.group(1)
        if token in NOISE or not at_top(m.start(1)):
            continue
        if m.group(2) is None:
            if token in consts:
                ids.add(token)
            else:
                bare.append(token)
            continue
        body = func_body(sfx_blank, token)
        reached = {c for c in consts if re.search(r"\b%s\b" % re.escape(c), body)} if body else set()
        if reached:
            ids |= reached
        elif body:
            unresolved.append("`%s()` is declared in the sound file but its body names "
                              "no event id" % token)
        else:
            unresolved.append("`%s()` is not declared in the sound file, so its return "
                              "value cannot be followed" % token)
    if not ids and bare:
        unresolved.append("`%s` is not an event constant, so this argument names no cue "
                          "the tool can see" % ", ".join(bare))
    return ids, unresolved


def waived(raw_lines: list, line_no: int) -> bool:
    """Is line `line_no` (1-based) waived, inline or by the comment block above it?

    Contiguous comment lines only, so a waiver cannot drift down from an unrelated
    block further up the file -- the same rule, and the same reason, as
    message_corpus_check's.
    """
    i = line_no - 1
    if i < 0 or i >= len(raw_lines):
        return False
    if WAIVER.search(raw_lines[i]):
        return True
    for j in range(i - 1, -1, -1):
        if not raw_lines[j].lstrip().startswith("#"):
            return False
        if WAIVER.search(raw_lines[j]):
            return True
    return False


def gd_files(root: str, sources: str) -> list:
    src_root = os.path.join(root, sources)
    files = []
    for dirpath, dirnames, filenames in os.walk(src_root):
        repo_walk.prune(dirpath, dirnames, src_root)
        files.extend(os.path.join(dirpath, f) for f in sorted(filenames) if f.endswith(".gd"))
    return sorted(files)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--sfx", default=os.path.join("game", "sfx.gd"))
    # `game` and NOT the whole repo, on purpose. test/unit/test_combat.gd contains
    # `Sfx.play(Sfx.PEST_KILLED)`; counting a test as a call site would let the suite
    # keep a cue alive that the GAME can no longer emit, which is the defect the
    # dead-row rule exists to find.
    ap.add_argument("--sources", default="game")
    ap.add_argument("--quiet", action="store_true",
                    help="print the summary and findings, skip the per-id inventory")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    sfx_path = os.path.join(root, args.sfx)
    if not os.path.isfile(sfx_path):
        print("sfx_call_check: no %s - cannot run." % args.sfx, file=sys.stderr)
        return 2
    try:
        sfx_raw = read(sfx_path)
    except (OSError, UnicodeDecodeError) as exc:
        print("sfx_call_check: cannot read %s (%s)" % (sfx_path, exc), file=sys.stderr)
        return 2
    sfx_blank = strip_comments(sfx_raw, strings=BLANK)
    # CONST_DECL needs the `&` of `&"..."` -- the StringName prefix is what separates an
    # event id from an ordinary String const, and BLANK blanks the prefix along with the
    # body. So the declarations are matched against a comments-only pass, where the `&`
    # survives. The offsets are the SAME string index either way: gdsource is exactly
    # length-preserving in every mode, which is what makes reading one pass and
    # measuring against the other legitimate rather than a coincidence.
    sfx_decls = strip_comments(sfx_raw)

    consts = {m.group(1): line_of(sfx_blank, m.start()) for m in CONST_DECL.finditer(sfx_decls)}
    values = {m.group(2): m.group(1) for m in CONST_VALUE.finditer(sfx_raw)}
    if not consts:
        print("sfx_call_check: %s declares no `const X := &\"...\"` event ids - cannot "
              "run. There is nothing for a call site to name." % args.sfx, file=sys.stderr)
        return 2
    span = dict_span(sfx_blank, TABLE)
    if span is None:
        print("sfx_call_check: no `const %s` in %s - cannot run. That table is what "
              "call sites are compared against." % (TABLE, args.sfx), file=sys.stderr)
        return 2
    table = dict_keys(sfx_blank, span)
    if not table:
        print("sfx_call_check: `const %s` in %s is empty - cannot run. Every call site "
              "would be a finding, which looks like a catastrophe rather than like a "
              "broken checker." % (TABLE, args.sfx), file=sys.stderr)
        return 2
    table_keys = {k for k, _ in table}

    # Every other dictionary in sfx.gd that shares at least one key with SOUNDS is a
    # per-event tuning table, and a key it holds that SOUNDS does not is a row nothing
    # will ever read: `VOLUME_DB.get(event, 0.0)` swallows a stale key in silence. The
    # "shares a key" rule is what keeps this from reading a dictionary keyed by
    # something else entirely; the ones it declined to read are counted below.
    tuning, declined = [], []
    for m in DICT_DECL.finditer(sfx_blank):
        name = m.group(1)
        if name == TABLE:
            continue
        other = dict_span(sfx_blank, name)
        if other is None:
            continue
        keys = dict_keys(sfx_blank, other)
        if keys and {k for k, _ in keys} & table_keys:
            tuning.append((name, keys))
        else:
            declined.append(name)

    files = gd_files(root, args.sources)
    sfx_lines = sfx_raw.split("\n")
    played: dict = {}
    sites = waived_sites = direct = through = 0
    unresolved: list = []
    for path in files:
        try:
            raw = read(path)
        except (OSError, UnicodeDecodeError):
            continue
        code = strip_comments(raw, strings=BLANK)
        raw_lines = raw.split("\n")
        for m in re.finditer(re.escape(CALL), code):
            sites += 1
            line_no = line_of(code, m.start())
            if waived(raw_lines, line_no):
                waived_sites += 1
                continue
            a_start, a_end = first_arg_span(code, m.end() - 1)
            ids, missed = resolve_arg(code[a_start:a_end], raw[a_start:a_end],
                                      consts, values, sfx_blank)
            if "(" in code[a_start:a_end]:
                through += 1
            else:
                direct += 1
            for event in ids:
                played.setdefault(event, []).append((path, line_no))
            for reason in missed:
                unresolved.append((path, line_no, reason))

    # Before any finding is computed, because with no call sites at all EVERY row is
    # "dead" and the run would print a page of findings that are really one broken
    # invocation. A zero denominator says so in words and returns 2: nothing verified.
    if sites == 0:
        print("sfx_call_check: %d .gd file(s) under %s/, 0 %s call site(s) - CANNOT RUN. "
              "%s declares %d event id(s) and none of them was compared against "
              "anything. Either this project plays no sound, or --sources points at the "
              "wrong tree."
              % (len(files), args.sources, CALL[:-1], args.sfx.replace(os.sep, "/"),
                 len(table_keys)), file=sys.stderr)
        print("  NOT COVERED: everything. This run resolved no call site, so the clean "
              "half of the comparison never happened.", file=sys.stderr)
        return 2

    findings: list = []
    for event in sorted(played):
        if event in table_keys:
            continue
        path, line_no = played[event][0]
        findings.append((
            "%s:%d" % (rel(path, root), line_no),
            "plays `%s`, which has no `%s` row" % (event, TABLE),
            "add a row to Sfx.%s. Without one `play()` returns false and the cue is "
            "silent forever -- the failure mode this whole file exists for." % TABLE,
        ))
    dead = []
    for event, offset in table:
        if event in played:
            continue
        line_no = line_of(sfx_blank, offset)
        if waived(sfx_lines, line_no):
            continue
        dead.append(event)
        findings.append((
            "%s:%d" % (args.sfx.replace(os.sep, "/"), line_no),
            "`%s` has a %s row and no `%s` call site reaches it"
            % (event, TABLE, CALL[:-1]),
            "delete the row (and its tuning rows), or find the call site that was "
            "removed. A cue the game cannot emit still owns a stream and still spends "
            "the uniqueness budget the pitch/volume tables are checked against.",
        ))
    for name, keys in tuning:
        for key, offset in keys:
            if key in table_keys:
                continue
            line_no = line_of(sfx_blank, offset)
            if waived(sfx_lines, line_no):
                continue
            findings.append((
                "%s:%d" % (args.sfx.replace(os.sep, "/"), line_no),
                "`%s` tunes `%s`, which is not a `%s` key" % (name, key, TABLE),
                "delete it or fix the name. `%s.get(event, <default>)` returns the "
                "default for a key nothing looks up, so a stale row here is a tuning "
                "value that silently does nothing." % name,
            ))
    for path, line_no, reason in unresolved:
        findings.append((
            "%s:%d" % (rel(path, root), line_no),
            "this %s argument was stepped over -- %s" % (CALL[:-1], reason),
            "pass a constant, or a helper declared in %s whose body names the ids (the "
            "tool follows one level). An argument it cannot follow is an id missing "
            "from every count above, so the dead-row rule may name that id next."
            % args.sfx.replace(os.sep, "/"),
        ))

    print("sfx_call_check: %d .gd file(s) under %s/, %d %s call site(s) (%d naming a "
          "constant directly, %d through a helper), %d waived; %s declares %d event id(s) "
          "and %d const(s); %d id(s) reached, %d unresolved argument(s); %d tuning "
          "table(s) read, %d declined; %d finding(s)"
          % (len(files), args.sources, sites, CALL[:-1], direct, through, waived_sites,
             args.sfx.replace(os.sep, "/"), len(table_keys), len(consts), len(played),
             len(unresolved), len(tuning), len(declined), len(findings)))
    if declined:
        print("  NOTE: %d dictionar(y/ies) in %s share no key with %s and were NOT read "
              "as per-event tuning: %s. That is correct only if they are keyed by "
              "something other than an event id."
              % (len(declined), args.sfx.replace(os.sep, "/"), TABLE, ", ".join(sorted(declined))))
    if unresolved and dead:
        print("  READ THESE TWO TOGETHER: %d argument(s) below resolved to no id, and %d "
              "row(s) are reported dead. An id reached only through an argument the "
              "matcher stepped over lands in BOTH lists -- fix or waive the unresolved "
              "arguments before deleting anything." % (len(unresolved), len(dead)))
    for where, what, fix in findings:
        print("FINDING: %s %s" % (where, what))
        print("  fix: %s" % fix)
        print("  waive: add `# sfx-call-check: ok - <reason>` on that line or in the "
              "comment block directly above it.")
    if not args.quiet:
        print("  inventory: " + ", ".join(
            "%s x%d" % (event, len(played[event])) for event in sorted(played)))
    print("  NOT COVERED: this reads source, not a running tree, and it matches the "
          "literal token `%s`. Ask what a call it would step over looks like -- these, "
          "all of them silently absent from every count above:" % CALL)
    print("    1. an aliased or reflected call -- `var f := Sfx.play` then `f(id)`, "
          "`Sfx.call(&\"play\", id)`, a Callable stored in a table.")
    print("    2. an id that is not a constant token -- `StringName(\"pest_\" + kind)`, "
          "`CUES[state]`, anything assembled at runtime.")
    print("    3. more than ONE level of indirection. `%s%s.helper(...))` is followed "
          "into `helper`'s body; a helper that returns what a SECOND function computes "
          "is not." % (CALL, "Sfx"))
    print("    4. an id computed away from the call -- `var e := Sfx.kill_event_for(m)` "
          "on one line and `%se)` on the next. The argument span holds only `e`, so "
          "this is reported as unresolved rather than followed." % CALL)
    print("    5. a SECOND id hiding beside a resolved one in the same argument. Only "
          "depth-0 tokens are read, and a bare identifier there is called an operand "
          "once any sibling term resolved -- nothing static separates a ternary's "
          "`victory` from a variable holding a cue.")
    print("    6. a call site outside --sources (%s/). test/ is excluded deliberately: "
          "a test playing a cue does not make the GAME able to." % args.sources)
    print("    7. reachability. It sees that a call site exists, never that anything "
          "runs it -- a cue played only from dead code counts as alive here.")
    print("    8. the table's values. Whether a stream path exists and loads is "
          "test_every_sound_the_game_can_play_actually_loads's job, not this one's.")
    print("    Nor does it compile: only import_check.py and lint_project.gd do that, "
          "and neither is parallel-safe.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
