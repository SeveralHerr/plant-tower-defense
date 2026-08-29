#!/usr/bin/env python3
r"""rng_seed_check.py - every random stream a run draws from must be pinnable.

WHY THIS EXISTS, and what was actually wrong.

`Game` held three streams. Two had public setters -- `WaveDirector.set_seed` and
`SeedBank.set_seed` -- and the third, `Game._cross_rng`, had none. It was constructed
at `game/game.gd:218`, drawn from at `_tick_cross_breeding`, and mentioned in exactly
those two places across `game/` and `test/`. Godot 4's
`RandomNumberGenerator` randomizes its seed on construction, so every run threw a
different set of sports and nothing anywhere could pin them.

The stream's own header said the opposite, in so many words:

    A seed that reproduces one run has to reproduce both, which is what two streams
    give and one does not.

Two streams give that only if BOTH are pinnable. `CrossBreeder.roll` even takes the
generator as a PARAMETER, with a header explaining that it does so precisely to be
pinnable -- the pure half did its part and the owner never wired it. The defect was
found by writing a driver (plant-tower-defense-t5yy.1) that had to seed its own copy
of the stream to make a run reproducible at all, i.e. by someone hitting it, three
cycles after the comment promising it was written. See plant-tower-defense-4n66.

THE RULE. For every `RandomNumberGenerator` field declared in a scanned file, some
line in that same file must write `<field>.seed`. That is the whole check. A field
whose only writes are `.randomize()` is a stream no caller can pin, whatever any
comment beside it says.

WHY IN THE SAME FILE. A `RandomNumberGenerator` held in a `var _x` is private to its
script -- GDScript's leading underscore is a convention, but a field declared in one
class is not addressable as a field of another, so a seeder for it can only be
written where it is declared. "Pinnable" and "has a `.seed` write in this file" are
therefore the same statement, not an approximation of it. That is also why the check
does not care whether the writer is `set_seed`, `set_run_seed` or an inline
assignment in `_init`: naming is a house convention, reachability is the property.

WHAT IT DOES NOT CHECK, beyond the NOT COVERED line at the bottom: whether anything
CALLS the seeder. Nothing in this game fixes a run's seed today -- all three setters
have test and tool callers only -- and that is an open design call recorded in
`Game._cross_rng`'s block, not a defect this gate should assert about. The property
here is narrower and permanent: a stream that CANNOT be pinned is a stream no future
run-seed feature can reach, and it is invisible until someone tries.

Nothing else in the toolchain can see it:

  * `lint_project.gd` / the suite: a field with no setter is valid, compiling code.
  * the orphan pass: it warns about a public function nothing calls. This is the
    mirror image -- a MISSING function, which no scan for unreferenced symbols has a
    category for.
  * `coverage_check.py`: its defect classes are engine-shaped (layout, signals,
    orphans). "Unpinnable randomness" is not one of them.
  * a reader of `game.gd`: the block above the field asserted the guarantee held.
    That is what kept it alive -- the prose was the thing being wrong.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes
no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.

    fixture:   `--self-test` -- ten cases: a seeded field / an unseeded one (the
               historical failure) / a field seeded by an inline assignment rather than
               a named setter / a `.seed` write that is only a COMMENT (must still be a
               finding, which is the case a naive grep gets wrong, since the whole
               defect was a comment claiming what the code did not do) / a `.seed`
               write inside a STRING / a typed declaration seeded later / a typed
               declaration never seeded / a file with no streams at all / two streams
               in one file, one of each / a `==` read-back, which is not a write.
    mutations: RUN THEM: `python tools/mutate.py --target rng_seed`. Five, all RED, and
               the sweep is what produced the tenth fixture case: "drop the typed-
               declaration half of DECL" SURVIVED at first, because with that half gone
               `streams_in` finds nothing and "no streams" and "one seeded stream" both
               report `[]`. Only an UNSEEDED typed declaration tells them apart, and the
               nine cases written by hand did not contain one. The fixture also carries
               a tenth case the `--self-test` list cannot: the zero-stream refusal is
               about the SCAN, not the rule, so it lives in `mutate.py`'s fixture.
    denominator: prints how many files were scanned and how many streams were found.
               `0 streams` is reported as a REFUSAL (exit 2), not a pass: a scan root
               that matches nothing is the failure mode this repo's own gates warn
               about most, and a checker over an empty set is the cheapest possible
               green.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gdsource  # noqa: E402
import repo_walk  # noqa: E402

# Where a run's streams live. Deliberately not the whole repo: `tools/run_sim.gd` is a
# driver that seeds its own copy by hand, and a test fixture holding a throwaway
# generator is not a stream a run draws from.
SCAN_DIRS = ("game",)

# `var _rng := RandomNumberGenerator.new()` and `var _rng: RandomNumberGenerator = ...`
# and the bare typed declaration. One pattern, because all three declare a field this
# script owns and can therefore seed.
DECL = re.compile(
    r"^[ \t]*(?:@\w+[^\n]*\n[ \t]*)?var[ \t]+([A-Za-z_]\w*)[ \t]*"
    r"(?::[ \t]*RandomNumberGenerator\b|:=[ \t]*RandomNumberGenerator\.new[ \t]*\()",
    re.MULTILINE,
)


def streams_in(text):
    """[(field, line)] for every RandomNumberGenerator field declared in `text`.

    Reads the BLANKED source, so a declaration inside a comment or a string is not a
    stream. That direction matters less than the seed scan below -- a commented-out
    field is not a real one either way -- but the two passes must agree about what
    counts as code or a field can be found and its seeder missed, or the reverse.
    """
    code = gdsource.strip_comments(text, gdsource.ERASE)
    out = []
    for match in DECL.finditer(code):
        out.append((match.group(1), code.count("\n", 0, match.start()) + 1))
    return out


def seed_writes(text, field):
    """True if some line of CODE assigns `<field>.seed`.

    THE BLANKING IS THE POINT OF THIS FUNCTION. The defect that produced this checker
    was a comment that described a guarantee the code did not provide, and a grep for
    `_cross_rng.seed` over raw source would have matched the very paragraph that was
    lying. A checker that can be satisfied by writing about the fix is worse than no
    checker, because it converts a false comment into a green gate.

    `=` only, not `==`: reading the seed back is not seeding it. (`RandomNumberGenerator`
    has no compound assignment worth allowing here -- `seed +=` on a generator is not a
    way to pin a run, it is a way to pin it to something the caller cannot state.)
    """
    blanked = gdsource.strip_comments(text, gdsource.ERASE)
    pattern = re.compile(r"\b" + re.escape(field) + r"\.seed[ \t]*=(?!=)")
    return pattern.search(blanked) is not None


def scan(root):
    """(findings, files_scanned, streams_found, refusal)."""
    findings, files, streams = [], 0, 0
    for scan_dir in SCAN_DIRS:
        base = os.path.join(root, scan_dir)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = repo_walk.prune(dirpath, dirnames, root)
            for name in sorted(filenames):
                if not name.endswith(".gd"):
                    continue
                path = os.path.join(dirpath, name)
                if repo_walk.excluded(path, root):
                    continue
                try:
                    with open(path, "r", encoding="utf-8", newline="") as fh:
                        text = fh.read()
                except (OSError, UnicodeDecodeError) as exc:
                    return [], files, streams, "cannot read %s (%s)" % (path, exc)
                files += 1
                rel = os.path.relpath(path, root).replace("\\", "/")
                for field, line in streams_in(text):
                    streams += 1
                    if not seed_writes(text, field):
                        findings.append((rel, line, field))
    return findings, files, streams, ""


# -- self-test ---------------------------------------------------------------
#
# Known-in / known-out, in this file, for the reason gdsource.py's own docstring
# gives: a statistic over the real corpus cannot fail. Every case below is a shape
# the repo has held or could hold, and the third and fourth are the ones that decide
# whether this gate is worth having at all.
_CASES = [
    ("seeded by a named setter", """
var _rng := RandomNumberGenerator.new()


func set_seed(value: int) -> void:
\t_rng.seed = value
""", []),
    ("no seeder at all -- the historical failure", """
var _cross_rng := RandomNumberGenerator.new()


func tick() -> void:
\tCrossBreeder.roll(_plants, board, _cross_rng)
""", ["_cross_rng"]),
    ("seeded inline, no named setter", """
var _rng := RandomNumberGenerator.new()


func _init() -> void:
\t_rng.seed = 7
""", []),
    ("only a COMMENT claims it is seeded", """
## A seed that reproduces one run reproduces this too: _rng.seed = value.
var _rng := RandomNumberGenerator.new()
""", ["_rng"]),
    ("only a STRING contains the seed write", """
var _rng := RandomNumberGenerator.new()


func hint() -> String:
\treturn "call _rng.seed = value to pin it"
""", ["_rng"]),
    ("typed declaration, assigned later", """
var _rng: RandomNumberGenerator = null


func start(value: int) -> void:
\t_rng = RandomNumberGenerator.new()
\t_rng.seed = value
""", []),
    # Added after `mutate.py --target rng_seed` reported the "drop the typed-declaration
    # half of DECL" mutation as SURVIVED. The seeded typed case above could not kill it:
    # with that half gone `streams_in` finds nothing, and "no streams" and "one seeded
    # stream" both report []. Only an UNSEEDED typed declaration tells them apart.
    ("typed declaration, never seeded", """
var _rng: RandomNumberGenerator = null


func start() -> void:
	_rng = RandomNumberGenerator.new()
""", ["_rng"]),
    ("no streams in the file", """
var lives: int = 10


func _ready() -> void:
\tpass
""", []),
    ("two streams, one seeded and one not", """
var _a := RandomNumberGenerator.new()
var _b := RandomNumberGenerator.new()


func set_seed(value: int) -> void:
\t_a.seed = value
""", ["_b"]),
    ("read-back is not a seed write", """
var _rng := RandomNumberGenerator.new()


func is_pinned(value: int) -> bool:
\treturn _rng.seed == value
""", ["_rng"]),
]


def self_test(verbose=True):
    bad = 0
    for label, text, expected in _CASES:
        got = [field for field, _ in streams_in(text) if not seed_writes(text, field)]
        ok = got == expected
        if not ok:
            bad += 1
        if verbose or not ok:
            print("  %-4s %-46s expected %s, got %s"
                  % ("ok" if ok else "FAIL", label, expected, got))
    print("  self-test: %d of %d case(s) passed." % (len(_CASES) - bad, len(_CASES)))
    return 0 if bad == 0 else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))))
    parser.add_argument("--self-test", action="store_true",
                        help="run the fixture cases instead of the repo scan")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    findings, files, streams, refusal = scan(args.root)
    if refusal:
        print("rng_seed_check: COULD NOT RUN -- %s" % refusal, file=sys.stderr)
        return 2

    print("rng_seed_check: %d finding(s) over %d stream(s) in %d .gd file(s) under %s"
          % (len(findings), streams, files, "/, ".join(SCAN_DIRS) + "/"))
    print("  NOT COVERED: this asks whether each stream CAN be pinned, never whether "
          "anything pins it -- nothing in this game fixes a run's seed today, and that "
          "is an open design call (see Game._cross_rng's block), not a finding here. It "
          "does not check that a seeder seeds EVERY stream a run owns "
          "(Game.set_run_seed's own block is the argument for one call, and no gate "
          "enforces it), that two runs on one seed actually agree -- "
          "test_selftest.gd holds that claim -- or that a generator is used at all. "
          "Streams outside %s are out of scope by construction, which includes "
          "tools/run_sim.gd's hand-seeded copy."
          % ("/, ".join(SCAN_DIRS) + "/"))

    if streams == 0:
        sys.stdout.flush()
        print("rng_seed_check: REFUSING to pass over zero streams. The scan matched %d "
              "file(s) and found no RandomNumberGenerator field in any of them, which "
              "is either a moved scan root or a declaration shape DECL no longer "
              "matches. A gate over an empty set is the cheapest possible green."
              % files, file=sys.stderr)
        return 2

    for rel, line, field in findings:
        print("  FINDING: %s:%d declares `%s`, a random stream nothing in that file can "
              "seed.\n"
              "    Godot randomizes a RandomNumberGenerator on construction, so this "
              "stream draws differently every run and no seed can pin it. A comment "
              "beside it promising reproducibility is how the last one survived three "
              "cycles (plant-tower-defense-4n66).\n"
              "    fix: write `%s.seed` somewhere in that file -- a `set_seed(value)` "
              "in the shape WaveDirector and SeedBank use -- and, if the owner holds "
              "more than one stream, seed them all from one call so a caller cannot pin "
              "two of three."
              % (rel, line, field, field))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
