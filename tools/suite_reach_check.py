#!/usr/bin/env python3
"""suite_reach_check.py - which of the game's public surface does the test suite
never so much as name?

WHY THIS EXISTS.

Every gate in this repo prints a denominator except the one that matters most.
`run_tests.gd` prints `Suite: 7 test script(s)` and `Assertions: 8718 executed`;
lint prints `Shaders: N of M compiled OK`; the four static checkers print `N of M`.
None of them prints anything about the *game*. A suite of 371 green tests that
never once writes the token `StickySundew` reads exactly like one that hammers it.

Nothing else in the toolchain can answer this:

  * `run_tests.gd` counts assertions. 8718 assertions all aimed at `Board` is
    8718 assertions. It has no notion of a target.
  * `coverage_check.py` asks which *defect classes* are exercised (`ui_layout`,
    `orphan_growth`, ...). That is a different axis entirely: a project can cover
    every class it lists and still have four scripts nothing tests.
  * `lint_project.gd`'s `Orphans:` pass asks "does anything in the project
    reference this public function". `Hud.refresh()` is called by `game.gd`, so
    lint is satisfied. Whether a *test* ever names it is a question lint does not
    ask, and the two answers differ for 31 functions at HEAD.
  * `name_check.py` resolves identifiers; a name that resolves is a name that
    exists, not a name anyone tests.
  * the bridge's `scripts-seen` verb answers "was this file loaded in this
    session". See WHY STATIC below - that number is not the one you want.

WHY STATIC, AND NOT `scripts-seen`.

`scripts-seen` reports what the running game loaded. Three things make it the
wrong denominator here, and only the third is about convenience:

  1. It measures loading, not testing. `game.gd` builds the whole tree and the
     plant subclasses are constructed by `Game._make_plant()`, so *starting the
     game* loads essentially every script in `game/`. An observed run would
     report ~100% reach on a suite that asserted nothing, which is the exact
     failure mode this tool exists to make impossible.
  2. It is session-scoped and non-reproducible. The number depends on how far
     the session got before you asked, so two agents get two answers and neither
     is wrong.
  3. It needs a running game, which means it is not parallel-safe, and this
     project's workflow fans agents out.

The question worth gating on is not "did this file get loaded" but "did anybody
write a test that names this thing". That is a property of the source, and the
source is what this reads.

WHAT IT COUNTS, AND WHAT THAT IS WORTH.

A game symbol is REACHED if its identifier appears anywhere in the test tree,
outside comments and outside string bodies. A game *file* is REACHED if its
`class_name`, its autoload name from `project.godot`, or its `res://` path
appears there.

Naming is a floor, not proof of exercise, and it is deliberately the weakest
claim that is still worth making. If a test writes `WaveDirector.reset()` this
tool calls `reset` reached whether the test asserts anything about the result or
not. What it can say with certainty is the negative: if the token never appears,
no test in this repo can possibly be asserting anything about that symbol. Every
finding here is therefore a true statement about the suite; the clean side of the
ledger is the optimistic one.

The file-level pass is nearly saturated in this project (27 of 27 named at HEAD)
and is kept only so a newly added script that nobody tests cannot slip in
silently. The symbol-level pass is where the real answer lives.

`const` is reported but does NOT gate. Most constants in this codebase are
drawing details - `PIP_RIM_COLOR`, `SCALLOP_STEP`, `JAW_HALF_WIDTH` - that no
sane test would ever name, and gating on 216 of those would bury the 48 findings
that are actually worth acting on. Counts are printed per file, ranked; `--consts`
lists them.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`,
takes no lock, stdlib only. Exit codes follow the house contract: 0 clean, 1
findings, 2 could not run.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# A declaration at indent 0, optionally preceded by annotations on the same line.
DECL_RE = re.compile(
    r"^(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+)*"
    r"(?:static\s+)?(func|var|const|signal)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
# Anything else that opens a new top-level span: an inner class, a bare
# annotation line, class_name/extends/enum. Used only to bound a declaration.
TOPLEVEL_RE = re.compile(r"^[@A-Za-z_]")
CLASS_NAME_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
RES_PATH_RE = re.compile(r"res://[A-Za-z0-9_/\.\-]+")
STRING_RE = re.compile(r'"""(?:.|\n)*?"""|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
AUTOLOAD_RE = re.compile(
    r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"\*?(res://[^"]+)"', re.M)
WAIVER_RE = re.compile(r"suite-reach-check:\s*ok\b")

GATING_KINDS = ("func", "signal", "var")
ADVISORY_KINDS = ("const",)
# Non-.gd files that can hold a live reference to a GDScript symbol as plain text:
# a `.tscn` node/signal binding, project.godot's autoload and input maps, and the
# harness's devtools_config.json, whose `entry_hook.method` is the only caller of
# TitleScreen.skip_to_game() anywhere in the repo.
TEXT_REF_EXT = (".tscn", ".tres", ".json", ".godot", ".cfg")
SKIP_DIRS = (".godot", ".git", ".beads", "__pycache__")
# Additionally kept OUT of the text-reference corpus. `.devtools/` is where the
# bridge dumps `scene-tree` and `scripts-seen` replies, and a node dump lists every
# property of every node -- letting it count as a reference would rescue almost any
# symbol from the "nothing calls this" tag using a scratch file from someone's last
# session. `.claude/` and `.codex/` are tooling config, not the product.
SKIP_TEXT_DIRS = (".devtools", ".claude", ".codex")

DEFAULT_BASELINE = os.path.join("tools", "suite_reach_baseline.json")


def strip_comments(text: str) -> str:
    """Comments blanked, string bodies kept, line count and line length preserved.

    Length-preserving so a later `STRING_RE.sub` and the line/column arithmetic
    both still index the original source.

    Comments go first and unconditionally. This repo has been bitten by a source
    scan that matched the very comment explaining why a token was absent, and
    this file would be the worst offender of all if it did not: `game/game.gd`
    says "a Sunflower never touches a pest at all" in prose, `game/pest.gd`
    mentions `ChompFlower.GRAB_RADIUS` in a doc comment, and this docstring names
    `StickySundew`, `WaveDirector.reset` and `PIP_RIM_COLOR` while explaining that
    nothing tests them. A scan that read prose would call all of those reached.
    """
    out = []
    for line in text.splitlines():
        cut = None
        in_s = None
        i = 0
        while i < len(line):
            c = line[i]
            if in_s:
                if c == "\\":
                    i += 2
                    continue
                if c == in_s:
                    in_s = None
            elif c in "\"'":
                in_s = c
            elif c == "#":
                cut = i
                break
            i += 1
        out.append(line if cut is None else line[:cut] + " " * (len(line) - cut))
    return "\n".join(out)


def blank_strings(code: str) -> str:
    """String bodies blanked, everything else and every offset intact.

    Separate from strip_comments because the two serve opposite needs. Identifier
    matching must not see string bodies -- `"Sticky Sundew"` in a HUD label is not
    a reference to the class. Path matching must see them, because a `res://` path
    is only ever written inside one. So callers run this for the identifier pass
    and skip it for the path pass, over source that has already lost its comments
    either way.
    """
    return STRING_RE.sub(lambda m: " " * len(m.group(0)), code)


def gd_files(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def read(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def autoload_names(root: str) -> dict[str, str]:
    """{res:// path -> autoload singleton name} out of project.godot.

    Without this the tool's headline finding at HEAD was `game/run_config.gd is
    named by no test`, which is false: it is the `RunConfig` autoload and
    test_economy.gd handles it seventeen times. An autoload name is a global
    identifier that is not a `class_name` and appears nowhere in the script that
    defines it, so nothing in the .gd source can reveal it.
    """
    out: dict[str, str] = {}
    try:
        text = read(os.path.join(root, "project.godot"))
    except (OSError, UnicodeDecodeError):
        return out
    block = text.split("[autoload]")
    if len(block) < 2:
        return out
    body = block[1].split("\n[")[0]
    for m in AUTOLOAD_RE.finditer(body):
        out[m.group(2)] = m.group(1)
    return out


def token_lines(code: str) -> dict[str, set[int]]:
    """{identifier -> set of 1-based lines it appears on}, strings already blanked.

    Line-resolved so a declaration can be excluded from its own reference count.
    A file-level `name in tokens` test would call every symbol referenced, since
    the declaration itself contains the name.
    """
    out: dict[str, set[int]] = {}
    for n, line in enumerate(code.splitlines(), start=1):
        for tok in IDENT_RE.findall(line):
            out.setdefault(tok, set()).add(n)
    return out


def text_ref_corpus(root: str, exclude: str) -> str:
    """Every scene/resource/config file concatenated, as raw text.

    Read raw, strings and all, because that is the only form a reference takes in
    these: `"method": "skip_to_game"` in devtools_config.json is the entry hook
    the harness calls, and it is the ONLY caller of that function in the repo. A
    .gd-only reference scan calls it dead, which is the wrong advice to print
    next to a real finding.
    """
    chunks = []
    excl = os.path.abspath(exclude)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames
                       if d not in SKIP_DIRS and d not in SKIP_TEXT_DIRS]
        if os.path.abspath(dirpath) == excl \
                or os.path.abspath(dirpath).startswith(excl + os.sep):
            continue
        for fn in sorted(filenames):
            if fn.endswith(TEXT_REF_EXT):
                try:
                    chunks.append(read(os.path.join(dirpath, fn)))
                except (OSError, UnicodeDecodeError):
                    continue
    return "\n".join(chunks)


def declarations(code: str, raw: str) -> list[tuple[str, str, int, bool]]:
    """[(kind, name, 1-based line, waived)] for indent-0 public declarations.

    Indent 0 only, which drops the members of an inner `class Foo:` block. That
    is deliberate: an inner class's members are not part of the file's global
    surface and a test reaches them through the outer name.

    A leading underscore means private by GDScript convention and is skipped --
    including the `_ready`/`_draw` virtuals, which a test calls only by accident.

    The waiver is a comment, so it is looked for in `raw`; strip_comments would
    have eaten it. It counts if it appears anywhere in the declaration's span,
    which for a `func` is its body and for a `const` is its own line.
    """
    lines = code.splitlines()
    raw_lines = raw.splitlines()
    decls: list[tuple[str, str, int]] = []
    bounds: list[int] = []
    for idx, line in enumerate(lines):
        if not TOPLEVEL_RE.match(line):
            continue
        bounds.append(idx)
        m = DECL_RE.match(line)
        if m and not m.group(2).startswith("_"):
            decls.append((m.group(1), m.group(2), idx))

    out = []
    for kind, name, idx in decls:
        nxt = [b for b in bounds if b > idx]
        end = nxt[0] if nxt else len(lines)
        span = "\n".join(raw_lines[idx:end])
        out.append((kind, name, idx + 1, WAIVER_RE.search(span) is not None))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--source", default="game",
                    help="game source tree to measure (default: game)")
    ap.add_argument("--tests", default="test",
                    help="test tree that does the reaching (default: test)")
    ap.add_argument("--baseline", default=None,
                    help="JSON of already-known findings; only NEW ones gate. "
                         "Defaults to %s when that file exists." % DEFAULT_BASELINE)
    ap.add_argument("--no-baseline", action="store_true",
                    help="ignore the default baseline; every finding gates")
    ap.add_argument("--baseline-write", default=None,
                    help="write today's findings to PATH and exit 0")
    ap.add_argument("--consts", action="store_true",
                    help="list the advisory unreached const(s) instead of counting them")
    ap.add_argument("--quiet", action="store_true",
                    help="suppress the pre-existing listing (the summary still prints)")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("suite_reach_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2

    src_root = os.path.join(root, args.source)
    test_root = os.path.join(root, args.tests)
    for label, path in (("source", src_root), ("test", test_root)):
        if not os.path.isdir(path):
            print("suite_reach_check: no %s tree at %s - cannot run. Nothing was "
                  "checked; this is not a pass." % (label, path), file=sys.stderr)
            return 2

    src_paths = gd_files(src_root)
    test_paths = gd_files(test_root)
    if not src_paths:
        print("suite_reach_check: no .gd files under %s - cannot run. Nothing was "
              "checked; this is not a pass." % src_root, file=sys.stderr)
        return 2
    if not test_paths:
        print("suite_reach_check: no .gd files under %s - cannot run. A game with "
              "no tests reaches nothing, and reporting that as 0%% is not the same "
              "as being able to measure it." % test_root, file=sys.stderr)
        return 2

    # --- what the tests name -------------------------------------------------
    test_tokens: set[str] = set()
    test_paths_named: set[str] = set()
    test_string_tokens: set[str] = set()
    for path in test_paths:
        try:
            raw = read(path)
        except (OSError, UnicodeDecodeError) as exc:
            print("suite_reach_check: cannot read %s (%s) - cannot run."
                  % (path, exc), file=sys.stderr)
            return 2
        code = strip_comments(raw)
        test_paths_named.update(RES_PATH_RE.findall(code))
        test_tokens.update(IDENT_RE.findall(blank_strings(code)))
        # Identifiers that occur ONLY inside string bodies. Not counted as reach --
        # a HUD caption reading "Sticky Sundew" is not a test of anything -- but
        # counted separately, because `has_method("announce_wave")` is a real if
        # weak reference and this is how many findings that costs. Printing the
        # number is the honest alternative to quietly picking one policy.
        for m in STRING_RE.finditer(code):
            test_string_tokens.update(IDENT_RE.findall(m.group(0)))
    test_string_tokens -= test_tokens

    autoloads = autoload_names(root)
    text_refs = text_ref_corpus(root, test_root)

    # --- the game's surface --------------------------------------------------
    files: list[dict] = []
    for path in src_paths:
        try:
            raw = read(path)
        except (OSError, UnicodeDecodeError) as exc:
            print("suite_reach_check: cannot read %s (%s) - cannot run."
                  % (path, exc), file=sys.stderr)
            return 2
        rel = os.path.relpath(path, root).replace("\\", "/")
        code = strip_comments(raw)
        cm = CLASS_NAME_RE.search(code)
        files.append({
            "rel": rel,
            "class_name": cm.group(1) if cm else None,
            "autoload": autoloads.get("res://" + rel),
            "decls": declarations(code, raw),
        })

    # --- who references what, product-side ------------------------------------
    # Every .gd in the project EXCEPT the test tree. Tests are the numerator of the
    # reach question, so counting them here would make "does the product itself use
    # this" unanswerable. Line-resolved so a declaration cannot reference itself.
    prod_refs: dict[str, dict[str, set[int]]] = {}
    test_abs = os.path.abspath(test_root)
    for path in gd_files(root):
        if os.path.abspath(path).startswith(test_abs + os.sep):
            continue
        try:
            code = strip_comments(read(path))
        except (OSError, UnicodeDecodeError):
            continue
        prod_refs[os.path.relpath(path, root).replace("\\", "/")] = \
            token_lines(blank_strings(code))

    def referenced_in_product(rel: str, name: str, line: int) -> bool:
        for other, toks in prod_refs.items():
            hits = toks.get(name)
            if not hits:
                continue
            if other != rel or hits - {line}:
                return True
        return re.search(r"\b%s\b" % re.escape(name), text_refs) is not None

    # --- file-level ----------------------------------------------------------
    file_findings = []
    for f in files:
        handles = [h for h in (f["class_name"], f["autoload"]) if h]
        reached = any(h in test_tokens for h in handles) \
            or ("res://" + f["rel"]) in test_paths_named
        if not reached:
            how = ", ".join(handles) if handles else "no class_name and no autoload"
            file_findings.append((f["rel"], how))

    # --- symbol-level --------------------------------------------------------
    declared = {k: 0 for k in GATING_KINDS + ADVISORY_KINDS}
    waived = 0
    gating: list[dict] = []
    advisory: list[dict] = []
    for f in files:
        for kind, name, line, is_waived in f["decls"]:
            if kind not in declared:
                continue
            declared[kind] += 1
            if name in test_tokens:
                continue
            if is_waived:
                waived += 1
                continue
            item = {
                "key": "%s::%s::%s" % (f["rel"], kind, name),
                "rel": f["rel"], "kind": kind, "name": name, "line": line,
                "dead": not referenced_in_product(f["rel"], name, line),
                "string_only": name in test_string_tokens,
            }
            (gating if kind in GATING_KINDS else advisory).append(item)

    # --- baseline ------------------------------------------------------------
    if args.baseline_write:
        payload = {
            "note": "Findings suite_reach_check.py knew about when this was written. "
                    "Only findings NOT listed here gate. Shrinking this file is the "
                    "point; regenerate with --baseline-write after you have written "
                    "the tests, never to make a new gap go quiet.",
            "files": sorted(rel for rel, _ in file_findings),
            "symbols": sorted(i["key"] for i in gating),
        }
        out_path = os.path.join(root, args.baseline_write) \
            if not os.path.isabs(args.baseline_write) else args.baseline_write
        try:
            with open(out_path, "w", encoding="utf-8") as fh:
                json.dump(payload, fh, indent=2)
                fh.write("\n")
        except OSError as exc:
            print("suite_reach_check: cannot write baseline %s (%s)."
                  % (out_path, exc), file=sys.stderr)
            return 2
        print("suite_reach_check: wrote %d file + %d symbol finding(s) to %s"
              % (len(payload["files"]), len(payload["symbols"]), args.baseline_write))
        return 0

    base_files: set[str] = set()
    base_symbols: set[str] = set()
    base_path = None
    if not args.no_baseline:
        cand = args.baseline or DEFAULT_BASELINE
        cand_abs = cand if os.path.isabs(cand) else os.path.join(root, cand)
        if os.path.isfile(cand_abs):
            try:
                data = json.loads(read(cand_abs))
                base_files = set(data.get("files", []))
                base_symbols = set(data.get("symbols", []))
                base_path = cand
            except (OSError, ValueError) as exc:
                print("suite_reach_check: baseline %s is unreadable (%s). Refusing "
                      "to treat an unreadable baseline as an empty one - that would "
                      "silently turn every finding into a new one." % (cand, exc),
                      file=sys.stderr)
                return 2
        elif args.baseline:
            print("suite_reach_check: baseline %s does not exist - cannot run. "
                  "Write one with --baseline-write." % cand, file=sys.stderr)
            return 2

    new_files = [(rel, how) for rel, how in file_findings if rel not in base_files]
    pre_files = [(rel, how) for rel, how in file_findings if rel in base_files]
    new_syms = [i for i in gating if i["key"] not in base_symbols]
    pre_syms = [i for i in gating if i["key"] in base_symbols]
    fixed = sorted(base_symbols - {i["key"] for i in gating})

    # --- report --------------------------------------------------------------
    named_files = len(files) - len(file_findings)
    print("suite_reach_check: %d game script(s) in %s, %d test script(s) in %s; "
          "%d of %d game script(s) named by a test."
          % (len(files), args.source, len(test_paths), args.tests,
             named_files, len(files)))
    print("  Public surface at indent 0: %d func, %d signal, %d var, %d const."
          % (declared["func"], declared["signal"], declared["var"], declared["const"]))
    print("  Never named by any test: %d func, %d signal, %d var (gating), "
          "%d const (advisory), %d waived."
          % (sum(1 for i in gating if i["kind"] == "func"),
             sum(1 for i in gating if i["kind"] == "signal"),
             sum(1 for i in gating if i["kind"] == "var"),
             len(advisory), waived))
    if base_path:
        print("  Baseline %s: %d pre-existing, %d NEW, %d since fixed."
              % (base_path.replace("\\", "/"), len(pre_syms) + len(pre_files),
                 len(new_syms) + len(new_files), len(fixed)))
    else:
        print("  Baseline: none in play -- every finding below gates.")

    if declared["func"] == 0 and declared["signal"] == 0 and declared["var"] == 0:
        print("  NOTE: nothing to check -- no script under %s declares a public "
              "func, signal or var at indent 0. A zero denominator looks exactly "
              "like a pass and is not one." % args.source)
    if not test_tokens:
        print("  NOTE: the test tree yielded no identifiers at all after stripping "
              "comments and strings. Every symbol would be reported unreached; "
              "that is a broken scan, not a result.")
    string_only = [i for i in gating if i["string_only"]]
    if string_only:
        print("  NOTE: %d of the finding(s) below appear in the test tree ONLY "
              "inside a string literal (%s). Those are not counted as reach -- a "
              "caption reading \"Sticky Sundew\" tests nothing -- but "
              "has_method(\"x\") is a real if weak reference, so this is the size "
              "of the policy's cost, printed rather than hidden."
              % (len(string_only),
                 ", ".join(sorted(i["name"] for i in string_only)[:6])))
    if named_files == len(files):
        print("  NOTE: the file-level pass is saturated -- every game script is "
              "named somewhere. That is a weak clean: it says each file has been "
              "mentioned, not that it has been tested. The symbol counts above "
              "are the number to read.")

    print("  NOT COVERED: naming is a floor, not exercise. A test that writes "
          "`WaveDirector.reset()` and asserts nothing counts as reach here, so the "
          "clean side of this ledger is optimistic and only the findings are "
          "certain. Matching is by bare token and namespace-blind: three scripts "
          "declare `get_viewport_height`, so one test naming any of them credits "
          "all three, and a symbol sharing a name with an unrelated local variable "
          "in a test is credited too -- this tool over-credits reach and therefore "
          "under-reports. It reads indent 0 only, so members of an inner `class` "
          "block, `enum` entries and anything a GDExtension registers are invisible "
          "to it. It says nothing about whether a reached symbol is asserted "
          "correctly, nothing about `.tscn` node wiring, and it does not know the "
          "bridge exists -- a symbol driven only through a devtools_ext verb reads "
          "as unreached. Nor does it compile anything -- only import_check.py and "
          "lint_project.gd do that, and neither is parallel-safe.")

    if advisory:
        by_file: dict[str, list[str]] = {}
        for i in advisory:
            by_file.setdefault(i["rel"], []).append(i["name"])
        ranked = sorted(by_file.items(), key=lambda kv: (-len(kv[1]), kv[0]))
        print("  ADVISORY (const, never gates): %d unreached const(s) across %d "
              "file(s). Most are drawing details no test should name; a few are "
              "balance numbers that maybe should be. Ranked:"
              % (len(advisory), len(ranked)))
        for rel, names in ranked if args.consts else ranked[:5]:
            if args.consts:
                print("      %-32s %2d  %s" % (rel, len(names), ", ".join(sorted(names))))
            else:
                print("      %-32s %2d" % (rel, len(names)))
        if not args.consts and len(ranked) > 5:
            print("      ... %d more file(s); --consts lists every name."
                  % (len(ranked) - 5))

    if fixed:
        print("  PROGRESS: %d baselined symbol(s) are now named by a test (%s). "
              "Re-run --baseline-write to lock the improvement in."
              % (len(fixed), ", ".join(f.split("::")[-1] for f in fixed[:6])
                 + (", ..." if len(fixed) > 6 else "")))

    if pre_files or pre_syms:
        if args.quiet:
            print("  PRE-EXISTING: %d baselined finding(s), listing suppressed."
                  % (len(pre_files) + len(pre_syms)))
        else:
            by_file: dict[str, list[str]] = {}
            for rel, _ in pre_files:
                by_file.setdefault(rel, []).append("<the whole file>")
            for i in pre_syms:
                by_file.setdefault(i["rel"], []).append(
                    "%s %s%s" % (i["kind"], i["name"],
                                 " [unreferenced]" if i["dead"] else ""))
            print("  PRE-EXISTING (baselined, not gating) -- %d symbol(s) no test "
                  "names, by file:" % (len(pre_files) + len(pre_syms)))
            for rel in sorted(by_file):
                print("      %-32s %s" % (rel, ", ".join(sorted(by_file[rel]))))

    for rel, how in new_files:
        print("  FINDING: %s is a game script no test names. Nothing in %s "
              "mentions %s, nor the literal \"res://%s\". No test in this repo can "
              "be asserting anything about it.\n"
              "    fix: write a check in test/unit/test_selftest.gd that names the "
              "type and asserts something about it -- see the CompostMeter tests at "
              "the top of that file for the shape.\n"
              "    waive: add `# suite-reach-check: ok - <reason>` to the file."
              % (rel, args.tests, how, rel))
    for i in new_syms:
        dead = (" Nothing else in the project references it either -- no .gd outside "
                "the test tree, no .tscn, no config file -- so this may be dead code "
                "rather than a test gap. Check lint's Orphans: pass before writing a "
                "test for it.") if i["dead"] else ""
        print("  FINDING: %s:%d %s `%s` is public and no test names it.%s\n"
              "    fix: name it in a check under test/unit/ -- calling it and "
              "asserting the result, or for a signal, connecting to it and "
              "asserting it fired.\n"
              "    waive: add `# suite-reach-check: ok - <reason>` in its body or on "
              "its line."
              % (i["rel"], i["line"], i["kind"], i["name"], dead))

    return 1 if (new_files or new_syms) else 0


if __name__ == "__main__":
    sys.exit(main())
