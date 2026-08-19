#!/usr/bin/env python3
r"""mutate.py - a mutation sweep that tells "did not apply" apart from "survived".

NOT A CHECKER, and deliberately not parallel-safe. It WRITES SOURCE FILES in the
working tree (and puts them back), so two of these at once, or one of these beside a
checker reading the same file, corrupt each other. It therefore does not carry the
house contract marker line that check_all.py greps for -- it belongs in that file's
NOT_A_CHECKER list, and it prints a `NOT PROVEN:` line of its own instead, for the
same reason every checker here prints its blind spots.

WHY THIS EXISTS. Four mutations were run against a checker in this repo by hand,
through a shell heredoc. Two printed `MUTATION TEXT NOT FOUND`, because the heredoc ate
a level of backslash escaping: the needle in the transcript said `"\n"` and what reached
Python was a real newline, which is not in the source. A sweep reading only exit codes
would have filed both as SURVIVED -- as evidence that two working guards were dead code.
That is not a weaker answer than the truth; it is the opposite of it. A CRLF checkout is
a second way the same needle silently misses, and this repo is CRLF.

So this tool refuses to say anything about a mutation it did not apply:

    RED          the command failed with the mutation in -- the guard is load-bearing
    SURVIVED     the command passed with the mutation in -- nothing checks that line
    NOT-APPLIED  the needle did not match EXACTLY ONCE. Nothing was written, nothing
                 was run, and nothing is known. This is an exit-2 condition, not a
                 result, and it never counts toward "N mutations killed".

AND THE SAME MISTAKE ON THE WAY OUT. Within an hour of the heredoc incident a second
sweep here recorded all three of its mutations as killed. The command was
`python tools/run_tests.py --godot "$GB" --filter facing`, `--filter` is only accepted
after `--`, so argparse hit an unrecognised option and exited 2 every single time and
not one test ran. `if returncode:` is true for 2. Needle-matched-exactly-once on the way
in does not save you from that, so the exit code is read as three values, never as a
truthiness:

    0 -> SURVIVED     the guard is not load-bearing
    1 -> RED          killed -- check WHICH case failed, using the denominator below
    2 -> BROKEN RUN   proves nothing; fix the invocation and rerun

BOTH ENDS NEED A DENOMINATOR. Every result prints the command's own count line beside
it -- `mirror fixture: 7 case(s), 1 failure(s)` -- so a RED over a suite that selected
nothing is visible as one. When the command prints no such line the tool says so, in
words, rather than reporting a bare verdict over an unknown number of checks.

AND THE BASELINE IS RUN FIRST, UNMUTATED, and the sweep refuses to start if it is not
clean. A red baseline makes every verdict below it meaningless: each mutation "fails"
whatever it does. The restore is re-run at the end for the same reason -- an unmutated
failure after the sweep says the file did not go back, and the tell that caught the
argparse bug above was exactly that restore run coming back non-zero.

HOW IT MATCHES. The file is read with universal-newline translation OFF and normalised
to LF before matching, so a needle written with `\n` matches a CRLF file. The mutated
file is written back in the file's ORIGINAL line-ending convention, and the original
BYTES are restored in a `finally` -- then re-read and compared, because a sweep that
leaves a half-mutated checker behind poisons every gate run after it.

A needle must match exactly once. Not "at least once": a needle matching twice would
mutate whichever occurrence came first, which is a different experiment from the one
written down, and the report would not say so.

USING IT AS A LIBRARY. `run_sweep()` is the whole tool; the CLI is a registry of
targets around it. Import it and drive your own:

    import sys; sys.path.insert(0, "tools")
    from mutate import Mutation, run_sweep
    report = run_sweep(
        Path("tools/my_check.py"),
        [Mutation("strip comments", "    text = _blank(text)", "    pass")],
        [sys.executable, "tools/my_check.py", "--root", str(fixture_dir)],
    )
    sys.exit(report.exit_code())

TARGETS. `--target mirror` runs the six mutations mirror_check.py's docstring has
carried as prose since it was written; `--target self` mutates this file. Both drive
`--fixture NAME`, a mode that builds a synthetic fixture in a temp dir and asserts a
list of properties -- exit 0 all held, 1 one did not. The fixture is the thing a
mutation has to break, so it lives beside the mutations rather than being deleted.

SELF-MUTATION ADDRESSES LINES BY TAG, and cannot do otherwise: a needle written
verbatim into this file would then occur twice in it (once in the code, once in the
mutation list) and the exactly-once guard would correctly refuse it. So the load-bearing
lines here carry a `# self-mutation:<name>` comment, the tag is assembled at runtime
from two pieces, and the transform replaces the whole line. Every other target uses real
source text as its needle, which is the normal case.

    fixture:   see _fixture_mirror() and _fixture_self() below
    mutations: python tools/mutate.py            -- runs every target
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        try:
            _stream.reconfigure(errors="replace")
        except (OSError, ValueError):
            pass

RED = "RED"
SURVIVED = "SURVIVED"
NOT_APPLIED = "NOT-APPLIED"
BROKEN_RUN = "BROKEN RUN"

# Substrings that mark a line as the command's own denominator. Deliberately a short
# hand-kept list of this repo's house shapes rather than a regex over any number: a
# clever matcher would find "1 failure(s)" inside a traceback and call it a count.
DENOM_HINTS = (
    "case(s)", "failure(s)", "finding(s)", "marker(s)", "line(s)", "checker(s)",
    "Assertions:", "Selected:", "Suite:", "test script(s)", "of 2 file(s)",
)

# Assembled, never written whole: see the self-mutation note in the module docstring.
_TAG = "self-mutation:"

# The house contract marker, assembled for the SAME reason and a second one. This file
# is deliberately NOT a checker -- it writes source files -- and check_all.py classifies
# by grepping tools/*.py for that marker, so writing it whole anywhere here (even inside
# a mutation needle aimed at another file) makes check_all report mutate.py as both
# NOT_A_CHECKER and contract-declaring, which is an UNCLASSIFIED contradiction. The
# `contract` target below needs the literal to address a line in suite_reach_check.py.
_MARKER = "NOT " + "COVERED"


def _tag(name: str) -> str:
    return _TAG + name


class Mutation:
    """One (label, needle, transform) experiment against one file.

    `transform` is either the replacement text or a callable taking the matched text.
    `scope` is "needle" (replace what matched) or "line" (replace the whole line the
    needle sits on) -- the latter exists for tag-addressed mutations.
    `expect` is the outcome that means "nothing is wrong". It is RED for every honest
    mutation; anything else demands a `reason`, because a waiver that does not explain
    itself is how a sweep stays green over a hole.
    """

    def __init__(self, label, needle, transform, scope="needle", expect=RED, reason=""):
        if scope not in ("needle", "line"):
            raise ValueError("scope must be 'needle' or 'line', not %r" % scope)
        if expect != RED and not reason:
            raise ValueError("a mutation not expected to go RED must carry a reason: %s" % label)
        self.label = label
        self.needle = needle
        self.transform = transform
        self.scope = scope
        self.expect = expect
        self.reason = reason

    def replacement_for(self, matched: str) -> str:
        return self.transform(matched) if callable(self.transform) else self.transform


class Result:
    def __init__(self, mutation, outcome, returncode=None, matches=None, detail="",
                 denominator="", output=""):
        self.mutation = mutation
        self.outcome = outcome
        self.returncode = returncode
        self.matches = matches
        self.detail = detail
        self.denominator = denominator
        self.output = output

    @property
    def as_expected(self) -> bool:
        return self.outcome == self.mutation.expect


class Report:
    def __init__(self, path, command):
        self.path = path
        self.command = command
        self.results = []
        self.baseline_ok = True
        self.baseline_code = None
        self.baseline_denominator = ""
        self.restore_ok = True
        self.restore_detail = ""
        self.restore_code = None

    def count(self, outcome) -> int:
        return sum(1 for r in self.results if r.outcome == outcome)

    def exit_code(self) -> int:
        # 2 first, and for four separate reasons -- a dirty baseline, a needle that did
        # not apply, a command that could not run, or a file that did not go back. All
        # four mean the sweep did not measure what it claims to have measured, and none
        # of them is a "findings" result.
        if not self.baseline_ok or not self.restore_ok:
            return 2
        if self.count(NOT_APPLIED) or self.count(BROKEN_RUN):
            return 2
        if any(not r.as_expected for r in self.results):
            return 1
        return 0


def normalise(text: str) -> str:
    """CRLF -> LF, so a needle written with \\n matches a CRLF checkout."""
    return text.replace("\r\n", "\n")  # self-mutation:crlf


def read_source(path) -> tuple[str, bool, bytes]:
    """(normalised text, was CRLF, original bytes).

    `newline=""` turns Python's universal-newline translation OFF on purpose, so the
    normalisation above is the thing actually doing the job and can be mutated out.
    mirror_check.py's own history is the argument: a normalisation `open()` was silently
    duplicating survived its mutation, and the comment claiming it mattered was wrong.
    """
    raw = Path(path).read_bytes()
    text = raw.decode("utf-8")
    return normalise(text), (b"\r\n" in raw), raw


def _purge_pyc(path: Path) -> None:
    """Drop any cached bytecode for a file we just rewrote.

    Python's staleness check is (source mtime to the second, source size). A mutation
    that neither changes the file's length nor crosses a second boundary would be
    imported from a stale .pyc and read as SURVIVED. Deleting the cache entry removes
    the whole class of hazard rather than hoping every replacement changes the length.
    """
    cache = path.parent / "__pycache__"
    if not cache.is_dir():
        return
    for pyc in cache.glob(path.stem + ".*.pyc"):
        with contextlib.suppress(OSError):
            pyc.unlink()


def _write_source(path: Path, text: str, crlf: bool) -> None:
    data = text.replace("\n", "\r\n") if crlf else text
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(data)
    _purge_pyc(path)


def _restore(path: Path, original: bytes) -> tuple[bool, str]:
    try:
        path.write_bytes(original)
        _purge_pyc(path)
    except OSError as exc:
        return False, "could not write the original bytes back: %s" % exc
    now = path.read_bytes()
    if now != original:
        return False, "the file on disk does not match the bytes it started with"
    return True, ""


def _span_for(text: str, needle: str, scope: str) -> tuple[int, int]:
    at = text.index(needle)
    if scope == "line":
        start = text.rfind("\n", 0, at) + 1
        end = text.find("\n", at)
        return start, (len(text) if end < 0 else end)
    return at, at + len(needle)


def _run(command, cwd) -> tuple[int, str]:
    env = dict(os.environ)
    # Never leave a .pyc behind for a file that is about to be restored.
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    proc = subprocess.run(
        [str(c) for c in command], cwd=None if cwd is None else str(cwd),
        capture_output=True, text=True, errors="replace", env=env,
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def denominator(text: str) -> str:
    """The command's own count line, or "" if it printed none.

    Searched from the END, because a summary line is the last thing a run prints and an
    earlier finding line can share its vocabulary.
    """
    for line in reversed((text or "").splitlines()):
        stripped = line.strip()
        if any(hint in stripped for hint in DENOM_HINTS):
            return stripped
    return ""


def _verdict(returncode: int) -> str:
    """Three values, never a truthiness. `if returncode:` is true for 2, and 2 is this
    repo's code for "nothing was verified" -- reading it as failure is how a sweep files
    three un-run mutations as killed."""
    if returncode == 0:
        return SURVIVED
    if returncode == 1:  # self-mutation:exit2
        return RED
    return BROKEN_RUN


def _silent(*_args, **_kwargs) -> None:
    return None


def _denominator_line(text: str) -> str:
    found = denominator(text)
    if found:
        return "          denominator: %s" % found
    return ("          denominator: NONE PRINTED -- the command reported no count, so "
            "this verdict is over an unknown number of checks.")


def run_sweep(path, mutations, command, cwd=None, out=print, show_output=False) -> Report:
    """Apply each mutation to `path` in turn, run `command`, restore, and report.

    The UNMUTATED command runs first and the sweep refuses to start if it is not clean:
    against a red baseline every mutation "fails" whatever it does, so every verdict
    below would be a reading of the baseline, not of the mutation.

    Only ever one mutation is in the file at a time. The original bytes go back in a
    `finally`, the restore is verified byte-for-byte, and the unmutated command is run
    once more afterwards -- a sweep that dies half way through would otherwise leave a
    mutated checker in the tree for the next gate to trust, and a non-zero restore run
    is the tell that voids everything above it.
    """
    path = Path(path)
    report = Report(path, command)
    text, crlf, original = read_source(path)
    wrote_any = False

    out("mutate: %s -- %d mutation(s), command: %s"
        % (path.as_posix(), len(mutations), " ".join(str(c) for c in command)))

    base_code, base_out = _run(command, cwd)
    report.baseline_code = base_code
    report.baseline_denominator = denominator(base_out)
    if base_code != 0:  # self-mutation:baseline
        report.baseline_ok = False
        out("  BASELINE NOT CLEAN: the UNMUTATED command exited %d. NO MUTATION WAS RUN."
            % base_code)
        out("          Against a red baseline every mutation 'fails' whatever it does, "
            "so every verdict this sweep could print would be a reading of the baseline.")
        out(_denominator_line(base_out))
        if base_out.strip():
            out("          --- command output ---")
            for line in base_out.strip().splitlines()[-20:]:
                out("          " + line)
        return report
    out("  baseline: clean (exit 0)")
    out(_denominator_line(base_out))

    try:
        for index, mutation in enumerate(mutations, 1):
            count = text.count(mutation.needle)
            if count != 1:  # self-mutation:once
                report.results.append(Result(
                    mutation, NOT_APPLIED, matches=count,
                    detail="the needle matched %d time(s), not exactly once" % count))
                out("  [%d/%d] %-44s %s" % (index, len(mutations), mutation.label, NOT_APPLIED))
                out("          the needle matched %d time(s), not once. NOTHING was run: "
                    "this is not a survivor, it is an unasked question." % count)
                continue

            start, end = _span_for(text, mutation.needle, mutation.scope)
            mutated = text[:start] + mutation.replacement_for(text[start:end]) + text[end:]
            if mutated == text:
                report.results.append(Result(
                    mutation, NOT_APPLIED, matches=count,
                    detail="the replacement is identical to what it replaced"))
                out("  [%d/%d] %-44s %s" % (index, len(mutations), mutation.label, NOT_APPLIED))
                out("          the replacement is byte-identical to the original. A "
                    "mutation that changes nothing cannot survive anything.")
                continue

            _write_source(path, mutated, crlf)
            wrote_any = True
            code, output = _run(command, cwd)
            outcome = _verdict(code)
            report.results.append(Result(mutation, outcome, returncode=code, matches=1,
                                         denominator=denominator(output), output=output))
            note = "" if outcome == mutation.expect else "   <-- UNEXPECTED"
            out("  [%d/%d] %-44s %s (exit %d)%s"
                % (index, len(mutations), mutation.label, outcome, code, note))
            out(_denominator_line(output))
            if outcome == BROKEN_RUN:
                out("          exit %d is not a failure -- it is this repo's code for "
                    "'nothing was verified'. Fix the invocation and rerun; do NOT count "
                    "this as a killed mutation." % code)
            if mutation.expect != RED:
                out("          expected to survive: %s" % mutation.reason)
            if show_output and output.strip():
                for line in output.strip().splitlines()[-20:]:
                    out("          | " + line)
    finally:
        report.restore_ok, report.restore_detail = _restore(path, original)

    if not report.restore_ok:
        out("  RESTORE FAILED: %s -- every verdict above is void until %s is put back "
            "by hand." % (report.restore_detail, path.as_posix()))
    elif wrote_any:
        # The restore run. It caught the argparse bug in the docstring above: the
        # unmutated command has no business being non-zero, so when it is, the file did
        # not go back or the command was never running what you thought.
        code, output = _run(command, cwd)
        report.restore_code = code
        if code == 0:
            out("  restore: clean (exit 0), %d byte(s) put back" % len(original))
            out(_denominator_line(output))
        else:
            report.restore_ok = False
            report.restore_detail = ("the UNMUTATED command exited %d AFTER the restore"
                                     % code)
            out("  RESTORE RUN NOT CLEAN: the unmutated command exited %d after the "
                "file was put back. Every verdict above is void." % code)
            out(_denominator_line(output))
    return report


# --------------------------------------------------------------------------- targets

def _target_mirror():
    """mirror_check.py's six documented mutations, as code instead of prose.

    They were written into that file's docstring after they had cost four sessions the
    same twenty minutes each, which was the right call and still left them unrunnable.
    Each needle below is real source text from mirror_check.py and each must match
    exactly once -- if one stops matching, the tool says NOT-APPLIED and exits 2 rather
    than quietly reporting five of six.
    """
    path = TOOLS / "mirror_check.py"
    command = [sys.executable, str(TOOLS / "mutate.py"), "--fixture", "mirror"]
    mutations = [
        Mutation(
            # The seventh: named in that file's OLDER docstring block, above the six
            # --fix ones. It is here because writing the fixture showed the same seven
            # cases kill it, which is the argument for expressing prose as code -- a
            # mutation nobody can run is a mutation nobody notices is missing.
            "read_block: drop the CRLF normalisation",
            r'    text = text.replace("\r\n", "\n")',
            "    text = text  # mutated: CRLF normalisation dropped",
        ),
        Mutation(
            "write_mirror: drop the CRLF restore",
            "    if dst_crlf:",
            "    if False:  # mutated: CRLF restore dropped",
        ),
        Mutation(
            "write_mirror: take inter-block whitespace from the SOURCE",
            r'    tail_ws = dst[d_span[0]:d_span[1]][len(dst[d_span[0]:d_span[1]].rstrip("\n")):]',
            r'    tail_ws = src[s_span[0]:s_span[1]][len(src[s_span[0]:s_span[1]].rstrip("\n")):]',
        ),
        Mutation(
            "write_mirror: remove the no-block-in-SOURCE refusal",
            "    if s_span is None:",
            "    if False and s_span is None:  # mutated: refusal removed",
        ),
        Mutation(
            "write_mirror: remove the no-heading-in-DESTINATION refusal",
            "    if d_span is None:",
            "    if False and d_span is None:  # mutated: refusal removed",
        ),
        Mutation(
            "main: neuter the truncation guard",
            "    truncated = [w for w in (truncation_warning(os.path.join(root, n)) for n in FILES) if w]",
            "    truncated = []  # mutated: truncation guard neutered",
        ),
        Mutation(
            "main: skip the post-write re-read",
            "        if again_a is not None and again_a == again_b:",
            "        if True:  # mutated: post-write re-read skipped",
            expect=SURVIVED,
            reason=(
                "no fixture can kill it, and that is a fact about the CODE, not the "
                "fixture. write_mirror splices src's block -- which by construction "
                "contains no end marker, since the span ENDS at the first one -- between "
                "dst's prefix and dst's own end marker, so read_block() over the result "
                "returns exactly that block and the re-read compares equal every time. "
                "The one case that used to reach it (a `---` rule inside the block) is "
                "now intercepted by the truncation guard above, which the `---` fixture "
                "case produced. Keep the guard: it defends a future write bug, and it "
                "costs one read. Do NOT write an assertion to 'kill' this -- that would "
                "lock in a redundancy and call it coverage."
            ),
        ),
    ]
    return path, mutations, command


def _target_self():
    """This file's own guards, addressed by tag (see the module docstring)."""
    path = TOOLS / "mutate.py"
    command = [sys.executable, str(path), "--fixture", "self"]
    mutations = [
        Mutation(
            "drop the exactly-once needle assertion",
            _tag("once"),
            "            if False:  # mutated: exactly-once assertion dropped",
            scope="line",
        ),
        Mutation(
            "drop the CRLF normalisation",
            _tag("crlf"),
            "    return text  # mutated: CRLF normalisation dropped",
            scope="line",
        ),
        Mutation(
            "collapse exit 2 into exit 1",
            _tag("exit2"),
            "    if returncode:  # mutated: 2 read as failure instead of as unverified",
            scope="line",
        ),
        Mutation(
            "drop the baseline-clean check",
            _tag("baseline"),
            "    if False:  # mutated: baseline-clean check dropped",
            scope="line",
        ),
    ]
    return path, mutations, command


def _target_contract():
    """suite_reach_check.py's house contract, asked as behaviour instead of as text.

    WHY THIS TARGET EXISTS (plant-tower-defense-qewq). A GDScript test --
    test_selftest.gd's `test_the_suite_reach_checker_still_declares_its_house_contract`
    -- pins that contract with four `source.contains(NEEDLE)` calls. That is the
    cycle-91 shape: it asserts the PRESENCE of a token where the property wanted is
    about the CODE. `"suite-reach-check: ok"` occurs twice in that checker and BOTH
    occurrences are help text; the parser is `WAIVER_RE = re.compile(r"suite-reach-
    check:\\s*ok\\b")`, which does not contain the literal at all. Delete the waiver
    outright and the text guard stays green.

    So this target asks the behavioural question the text guard cannot, and the
    mutations below are the proof rather than the argument: M1 deletes the parser and
    goes RED here while the text guard would not have moved, and M4 deletes one of the
    two help-text occurrences and is EXPECTED to survive -- the MARKER_COLOR failure
    run for real, on a token that stays alive because a second copy of it does.
    """
    path = TOOLS / "suite_reach_check.py"
    command = [sys.executable, str(TOOLS / "mutate.py"), "--fixture", "contract"]
    mutations = [
        Mutation(
            "the documented waiver comment stops being matched",
            r'WAIVER_RE = re.compile(r"#+[ \t]*suite-reach-check:\s*ok\b")',
            r'WAIVER_RE = re.compile(r"mutated: this waiver matches nothing")',
        ),
        Mutation(
            "the waiver goes back to matching the marker anywhere, comment or not",
            r'WAIVER_RE = re.compile(r"#+[ \t]*suite-reach-check:\s*ok\b")',
            r'WAIVER_RE = re.compile(r"suite-reach-check:\s*ok\b")',
        ),
        Mutation(
            "a missing project root reports clean instead of could-not-run",
            '        print("suite_reach_check: no project.godot at %s - cannot run." % root,\n'
            '              file=sys.stderr)\n'
            '        return 2',
            '        print("suite_reach_check: no project.godot at %s - cannot run." % root,\n'
            '              file=sys.stderr)\n'
            '        return 0  # mutated: could-not-run collapsed into clean',
        ),
        Mutation(
            "the blind-spot line stops being printed",
            '    print("  ' + _MARKER + ': naming is a floor, not exercise. A test that writes "',
            '    print("  (mutated away) naming is a floor, not exercise. A test that writes "',
        ),
        Mutation(
            "one of the two waiver mentions is deleted",
            '              "    waive: add `# suite-reach-check: ok - <reason>` in its body or on "',
            '              "    waive: see the file-level note above; this line no longer says how, on "',
            expect=SURVIVED,
            reason=(
                "the cycle-91 MARKER_COLOR shape, run rather than described. The "
                "token survives in the OTHER help line, so the presence floor -- "
                "`contains(\"suite-reach-check: ok\")`, which is what the GDScript "
                "test actually asserts -- cannot see this go, and neither can the "
                "presence case in this fixture. Nothing behavioural moved either, "
                "because the parser was not touched. That is the point: presence is "
                "the wrong question, and the fixture's waiver-matches case is the "
                "right one. Do NOT 'fix' this by asserting an occurrence COUNT -- "
                "that pins the help text's formatting, not the waiver."
            ),
        ),
    ]
    return path, mutations, command


TARGETS = {"contract": _target_contract, "mirror": _target_mirror, "self": _target_self}


# -------------------------------------------------------------------------- fixtures

class _Cases:
    """A tiny assertion collector that always prints its own denominator.

    `N case(s), M failure(s)` is the number a mutation has to move. A fixture that
    reports "ok" without saying over how many cases is the empty-denominator failure
    the house checker contract exists to prevent, and a mutation sweep reading it would
    inherit that blindness one level up.
    """

    def __init__(self, name):
        self.name = name
        self.total = 0
        self.failures = []

    def check(self, label, fn):
        self.total += 1
        try:
            ok, detail = fn()
        except Exception as exc:  # noqa: BLE001 - a raising fixture case IS a failure
            ok, detail = False, "raised %s: %s" % (type(exc).__name__, exc)
        if not ok:
            self.failures.append((label, detail))

    def report(self) -> int:
        for label, detail in self.failures:
            print("  FAILED: %s -- %s" % (label, detail))
        print("%s fixture: %d case(s), %d failure(s)" % (self.name, self.total, len(self.failures)))
        return 1 if self.failures else 0


def _write_text(path: Path, text: str, crlf: bool = False) -> None:
    data = text.replace("\n", "\r\n") if crlf else text
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(data)


def _read_norm(path: Path) -> str:
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read().replace("\r\n", "\n")


# ---- mirror fixture

_MIRROR_END = "# Project Instructions for AI Agents"


def _mirror_pair(root: Path, name: str, src: str, dst: str, dst_crlf: bool = False) -> Path:
    d = root / name
    d.mkdir()
    _write_text(d / "CLAUDE.md", src)
    _write_text(d / "AGENTS.md", dst, crlf=dst_crlf)
    return d


def _run_mirror_main(mod, argv) -> tuple[int, str]:
    old = sys.argv
    sys.argv = ["mirror_check.py"] + list(argv)
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = mod.main()
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else 1
    finally:
        sys.argv = old
    return code, buf.getvalue()


def _fixture_mirror() -> int:
    sys.path.insert(0, str(TOOLS))
    import mirror_check as mc  # noqa: WPS433 - shipped beside this file

    root = Path(tempfile.mkdtemp(prefix="mutate_mirror_"))
    cases = _Cases("mirror")

    def case_crlf():
        src = ("# Head\n\n# workflow\n\nalpha\nbeta\n\n" + _MIRROR_END + "\n\nsrc tail\n")
        dst = "# Head\n\n# workflow\n\nalpha\nDIFFERENT\n\n---\n\ndst tail\n"
        d = _mirror_pair(root, "crlf", src, dst, dst_crlf=True)
        code, out = _run_mirror_main(mc, ["--root", str(d), "--quiet", "--fix"])
        raw = (d / "AGENTS.md").read_bytes()
        if code != 0:
            return False, "expected --fix to exit 0, got %d (%s)" % (code, out.strip()[:160])
        if b"beta" not in raw:
            return False, "the block was never generated into the destination"
        if b"\r\n" not in raw:
            return False, "the destination was CRLF and --fix rewrote the whole file as LF"
        return True, ""

    def case_tail_whitespace():
        src = "# workflow\n\nalpha\nbeta\n" + _MIRROR_END + "\n\ntail\n"
        dst = "# workflow\n\nalpha\nZZZ\n\n\n---\n\ntail\n"
        d = _mirror_pair(root, "tailws", src, dst)
        code, out = _run_mirror_main(mc, ["--root", str(d), "--quiet", "--fix"])
        if code != 0:
            return False, "expected --fix to exit 0, got %d (%s)" % (code, out.strip()[:160])
        after = _read_norm(d / "AGENTS.md")
        if "beta\n\n\n---\n" not in after:
            return False, ("the destination's own inter-block whitespace was not "
                           "preserved; got %r" % after)
        return True, ""

    def case_refuse_source():
        src = "# Head\n\nthis file carries no workflow block at all\n"
        dst = "# workflow\n\nalpha\n\n---\n\ntail\n"
        d = _mirror_pair(root, "refusesrc", src, dst)
        before = (d / "AGENTS.md").read_bytes()
        changed, message = mc.write_mirror(str(d / "CLAUDE.md"), str(d / "AGENTS.md"))
        if changed:
            return False, "it generated a block FROM a file that has none: %s" % message
        if "refusing to generate FROM" not in message:
            return False, "refused, but not for the documented reason: %s" % message
        if (d / "AGENTS.md").read_bytes() != before:
            return False, "it refused and wrote the destination anyway"
        return True, ""

    def case_refuse_destination():
        src = "# workflow\n\nalpha\n\n" + _MIRROR_END + "\n"
        dst = "# Head\n\nno heading here, nowhere to put a block\n"
        d = _mirror_pair(root, "refusedst", src, dst)
        before = (d / "AGENTS.md").read_bytes()
        changed, message = mc.write_mirror(str(d / "CLAUDE.md"), str(d / "AGENTS.md"))
        if changed:
            return False, "it guessed where the block belonged: %s" % message
        if "refusing to guess" not in message:
            return False, "refused, but not for the documented reason: %s" % message
        if (d / "AGENTS.md").read_bytes() != before:
            return False, "it refused and wrote the destination anyway"
        return True, ""

    def case_truncation():
        body = "# workflow\n\nalpha\n\n---\n\n%s\n\n" + _MIRROR_END + "\n\ntail\n"
        d = _mirror_pair(root, "truncated", body % "beta", body % "gamma")
        code, out = _run_mirror_main(mc, ["--root", str(d)])
        if "TRUNCATED" not in out:
            return False, ("a horizontal rule inside the block truncated the comparison "
                           "to two identical stubs and it reported: %s" % out.strip()[:200])
        if code != 1:
            return False, "the truncation was reported but the exit code was %d" % code
        return True, ""

    def case_post_write_reread():
        src = "# workflow\n\nalpha\nbeta\n\n" + _MIRROR_END + "\n"
        dst = "# workflow\n\nalpha\nOLD\n\n---\n\ntail\n"
        d = _mirror_pair(root, "reread", src, dst)
        code, out = _run_mirror_main(mc, ["--root", str(d), "--quiet", "--fix"])
        if code != 0:
            return False, "expected --fix to exit 0, got %d (%s)" % (code, out.strip()[:160])
        if "re-checked from disk" not in out:
            return False, "--fix reported success without re-reading the file it wrote"
        return True, ""

    def case_identical_no_write():
        same = "# workflow\n\nalpha\nbeta\n\n" + _MIRROR_END + "\n\ntail\n"
        d = _mirror_pair(root, "identical", same, same)
        before = (d / "AGENTS.md").read_bytes()
        code, out = _run_mirror_main(mc, ["--root", str(d), "--quiet", "--fix"])
        if code != 0:
            return False, "two identical blocks reported %d (%s)" % (code, out.strip()[:160])
        if (d / "AGENTS.md").read_bytes() != before:
            return False, "--fix rewrote a file that already matched"
        return True, ""

    try:
        cases.check("a CRLF destination stays CRLF after --fix", case_crlf)
        cases.check("inter-block whitespace comes from the destination", case_tail_whitespace)
        cases.check("refuses to generate FROM a file with no block", case_refuse_source)
        cases.check("refuses to guess where a missing heading went", case_refuse_destination)
        cases.check("a `---` rule inside the block is reported, not compared", case_truncation)
        cases.check("--fix re-reads from disk before reporting success", case_post_write_reread)
        cases.check("identical blocks are left alone", case_identical_no_write)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    return cases.report()


# ---- self fixture

_SUBJECT = "# a stand-in for a checker under test\nEXIT=0\nTAIL marker\n"

# Reads the subject and exits with the digit it names, after printing a denominator.
_PROBE = (
    "import sys\n"
    "text = open(sys.argv[1], encoding='utf-8', newline='').read()\n"
    "code = int(text.split('EXIT=')[1][0])\n"
    "print('subject probe: 1 marker(s), %d finding(s)' % code)\n"
    "sys.exit(code)\n"
)


def _subject(root: Path, name: str, text: str = _SUBJECT, crlf: bool = False) -> Path:
    path = root / (name + ".txt")
    _write_text(path, text, crlf=crlf)
    return path


def _probe(path: Path):
    return [sys.executable, "-c", _PROBE, str(path)]


def _sweep(path: Path, needle, replacement) -> Report:
    return run_sweep(path, [Mutation("case", needle, replacement)], _probe(path), out=_silent)


def _fixture_self() -> int:
    root = Path(tempfile.mkdtemp(prefix="mutate_self_"))
    cases = _Cases("self")

    def expect(report, outcome, what):
        got = report.results[0].outcome
        if got != outcome:
            return False, "%s: expected %s, got %s" % (what, outcome, got)
        return True, ""

    def case_needle_twice():
        path = _subject(root, "twice", "EXIT=0\nTAIL\nTAIL\n")
        before = path.read_bytes()
        report = _sweep(path, "TAIL", "GONE")
        ok, why = expect(report, NOT_APPLIED, "a needle matching twice")
        if not ok:
            return False, (why + " -- a mutation applied to whichever occurrence came "
                           "first is a different experiment from the one written down")
        if report.results[0].returncode is not None:
            return False, "the command was run for a mutation that was never applied"
        if path.read_bytes() != before:
            return False, "the file was written for a mutation that did not apply"
        return True, ""

    def case_needle_absent():
        path = _subject(root, "absent")
        report = _sweep(path, "NO SUCH TEXT", "x")
        return expect(report, NOT_APPLIED, "a needle matching zero times")

    def case_red():
        path = _subject(root, "red")
        report = _sweep(path, "EXIT=0", "EXIT=1")
        return expect(report, RED, "a mutation the command fails on")

    def case_survived():
        path = _subject(root, "survived")
        report = _sweep(path, "TAIL marker", "TAIL marker (moved)")
        return expect(report, SURVIVED, "a mutation the command passes over")

    def case_crlf_needle():
        path = _subject(root, "crlf", crlf=True)
        report = _sweep(path, "EXIT=0\nTAIL", "EXIT=1\nTAIL")
        ok, why = expect(report, RED, "a needle spanning a newline in a CRLF file")
        if not ok:
            return False, (why + " -- an LF needle must match a CRLF file, or a CRLF "
                           "checkout silently reads as 'this code is not present'")
        return True, ""

    def case_restore():
        path = _subject(root, "restore", crlf=True)
        before = path.read_bytes()
        report = _sweep(path, "EXIT=0", "EXIT=1")
        if not report.restore_ok:
            return False, "restore reported failure: %s" % report.restore_detail
        if path.read_bytes() != before:
            return False, "the subject's bytes changed across the sweep (CRLF lost?)"
        return True, ""

    def case_noop_replacement():
        path = _subject(root, "noop")
        report = _sweep(path, "EXIT=0", "EXIT=0")
        return expect(report, NOT_APPLIED, "a replacement identical to what it replaced")

    def case_broken_run():
        path = _subject(root, "broken")
        report = _sweep(path, "EXIT=0", "EXIT=2")
        ok, why = expect(report, BROKEN_RUN, "a command exiting 2")
        if not ok:
            return False, (why + " -- `if returncode:` is true for 2, and 2 means "
                           "nothing was verified, not that the mutation was killed")
        if report.exit_code() != 2:
            return False, "a BROKEN RUN was reported but the sweep exited %d" % report.exit_code()
        return True, ""

    def case_baseline_dirty():
        path = _subject(root, "dirtybase", "EXIT=1\nTAIL marker\n")
        report = _sweep(path, "TAIL", "GONE")
        if report.baseline_ok:
            return False, "a command failing UNMUTATED was accepted as a baseline"
        if report.results:
            return False, ("%d mutation(s) were run against a red baseline, where every "
                           "one of them 'fails' whatever it does" % len(report.results))
        if report.exit_code() != 2:
            return False, "a dirty baseline exited %d, not 2" % report.exit_code()
        return True, ""

    def case_denominator():
        path = _subject(root, "denom")
        report = _sweep(path, "EXIT=0", "EXIT=1")
        got = report.results[0].denominator
        if "marker(s)" not in got:
            return False, ("the command's own count line was not carried onto the "
                           "result; got %r" % got)
        return True, ""

    try:
        cases.check("a needle matching twice is NOT-APPLIED, not SURVIVED", case_needle_twice)
        cases.check("a needle matching zero times is NOT-APPLIED", case_needle_absent)
        cases.check("a killed mutation reads RED", case_red)
        cases.check("an unchecked line reads SURVIVED", case_survived)
        cases.check("an LF needle matches a CRLF file", case_crlf_needle)
        cases.check("the subject's bytes are restored exactly", case_restore)
        cases.check("a no-op replacement is NOT-APPLIED", case_noop_replacement)
        cases.check("exit 2 is BROKEN RUN, not RED", case_broken_run)
        cases.check("a dirty baseline stops the sweep before it starts", case_baseline_dirty)
        cases.check("each result carries the command's own denominator", case_denominator)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    return cases.report()


# ---- contract fixture

def _run_module_main(mod, argv0, argv) -> tuple[int, str]:
    """Call a checker's argv-reading `main()` with a chosen argv, capturing output."""
    old = sys.argv
    sys.argv = [argv0] + list(argv)
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = mod.main()
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else 1
    finally:
        sys.argv = old
    return code, buf.getvalue()


# The waiver comment the checker's own help text tells a reader to write. Written out
# here as a USER would type it, not copied from the parser -- copying the parser would
# make this case a tautology, which is the failure the whole target is about.
_WAIVER_AS_DOCUMENTED = "# suite-reach-check: ok - the marker is asserted by name below"

# The needle list the GDScript test uses. Kept here so a mutation report can SHOW which
# form it killed: the text floor, or the behaviour underneath it.
_CONTRACT_NEEDLES = (_MARKER + ":", "return 2", "NOTE: nothing to check",
                     "suite-reach-check: ok")


def _fixture_contract() -> int:
    sys.path.insert(0, str(TOOLS))
    import suite_reach_check as sr  # noqa: WPS433 - shipped beside this file

    source = (TOOLS / "suite_reach_check.py").read_text(encoding="utf-8")
    root = Path(tempfile.mkdtemp(prefix="mutate_contract_"))
    cases = _Cases("contract")

    def case_presence_floor():
        # The GDScript test's own question, restated so the sweep can demonstrate what
        # it does and does not see. It is a floor and it is recorded as one.
        missing = [n for n in _CONTRACT_NEEDLES if n not in source]
        if missing:
            return False, "the contract needles %r are gone from the source" % (missing,)
        return True, ""

    def case_waiver_matches_what_the_help_advertises():
        # The property the floor above cannot ask. Both help lines could stay word for
        # word while the parser was deleted, and `contains` would report clean.
        if sr.WAIVER_RE.search(_WAIVER_AS_DOCUMENTED) is None:
            return False, ("the checker tells a reader to write %r and its own "
                           "WAIVER_RE does not match that -- a documented waiver that "
                           "does nothing is worse than no waiver"
                           % _WAIVER_AS_DOCUMENTED)
        if sr.WAIVER_RE.search("# nothing to do with this checker") is not None:
            return False, "WAIVER_RE matches a comment that is not a waiver at all"
        return True, ""

    def case_waiver_is_actually_consulted():
        # And that the parser is WIRED IN: a declaration carrying the documented
        # comment must come back waived. Driven through the real scanner, so deleting
        # the `WAIVER_RE.search(...)` call site fails here even with the regex intact.
        body = ("extends Node\n\n\nfunc do_a_thing() -> void:\n\t%s\n\tpass\n"
                % _WAIVER_AS_DOCUMENTED)
        # (blanked, raw): the waiver is a COMMENT, so the scanner reads it out of the
        # raw half. Passing the same text twice would let a blanker bug pass unseen.
        decls = sr.declarations(sr.strip_comments(body), body)
        waived = [d for d in decls if d[1] == "do_a_thing" and d[3]]
        if not decls:
            return False, "the scanner found no declaration in the fixture script at all"
        if not waived:
            return False, ("a declaration carrying the documented waiver comment came "
                           "back UNWAIVED (%r) -- the regex exists but nothing asks it"
                           % (decls,))
        return True, ""

    def case_a_mention_is_not_a_waiver():
        # CYCLE 126's INCIDENT, transplanted into GDScript. citation_check.py's --beads
        # waiver was a bare substring, and the FIRST bead that feature closed waived
        # ITSELF: its close reason contained the sentence explaining the waiver. 468
        # beads became 467, three citations left the denominator, the exit code stayed
        # 0, and nothing said a word.
        #
        # The same text really does live in .gd in this repo -- `test_selftest.gd:7612`
        # holds `["suite-reach-check: ok", "the waiver, which has to be greppable to be
        # usable"]` inside a test method, because a test that pins a checker's contract
        # has to name that checker's marker. So: a declaration that MERELY NAMES the
        # marker in a string literal must come back UNWAIVED. This is the case that
        # goes red if WAIVER_RE loses its `#+[ \t]*` prefix, and it is the only one
        # here that can -- `case_waiver_is_actually_consulted` above passes either way,
        # because a looser regex still matches the documented comment.
        mention = ('extends Node\n\n\nfunc names_the_marker() -> void:\n'
                   '\tvar needles := ["suite-reach-check: ok", "greppable"]\n'
                   '\tprint(needles)\n')
        decls = sr.declarations(sr.strip_comments(mention), mention)
        hits = [d for d in decls if d[1] == "names_the_marker"]
        if not hits:
            return False, "the scanner found no declaration in the mention fixture"
        if hits[0][3]:
            return False, ("a declaration that only NAMES the marker in a string "
                           "literal came back WAIVED. This is the cycle-126 shape: "
                           "the text explaining a waiver trips it, findings leave the "
                           "denominator, and the exit code does not move. WAIVER_RE "
                           "must require the marker to open a comment.")
        return True, ""

    def case_missing_root_is_could_not_run():
        empty = root / "no_project"
        empty.mkdir(exist_ok=True)
        code, out = _run_module_main(sr, "suite_reach_check.py", ["--root", str(empty)])
        if code != 2:
            return False, ("a root with no project.godot exited %d, not 2. 0 there is "
                           "'clean over nothing', which is the one result this "
                           "contract exists to forbid (%s)" % (code, out.strip()[:160]))
        return True, ""

    def case_not_covered_is_printed_not_merely_present():
        # `contains` cannot tell a printed line from a line of prose about it. This
        # can: the marker has to sit inside a print() call.
        at = source.find(_MARKER + ":")
        if at < 0:
            return False, "the %s marker is gone" % _MARKER
        head = source.rfind("print(", 0, at)
        newline = source.rfind("\n", 0, at)
        if head < 0 or head < newline:
            return False, ("the %s marker is in the source but not inside a print() "
                           "call -- a contract line nobody prints is prose" % _MARKER)
        return True, ""

    try:
        cases.check("the four contract needles are still in the source (the FLOOR)",
                    case_presence_floor)
        cases.check("the waiver the help text advertises is one WAIVER_RE matches",
                    case_waiver_matches_what_the_help_advertises)
        cases.check("and a declaration carrying it comes back waived",
                    case_waiver_is_actually_consulted)
        cases.check("but a declaration that only NAMES the marker in a string does not",
                    case_a_mention_is_not_a_waiver)
        cases.check("a root with no project.godot exits 2, not 0",
                    case_missing_root_is_could_not_run)
        cases.check("the blind-spot marker sits inside a print(), not in prose",
                    case_not_covered_is_printed_not_merely_present)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    return cases.report()


FIXTURES = {"contract": _fixture_contract, "mirror": _fixture_mirror,
            "self": _fixture_self}


# ------------------------------------------------------------------------------ main

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Run a mutation sweep and report RED / SURVIVED / NOT-APPLIED.",
        epilog="Exit codes: 0 every mutation landed as expected, 1 an unexpected "
               "survivor, 2 a mutation did not apply or the restore failed -- which "
               "means nothing was measured, not that nothing was wrong.")
    ap.add_argument("--target", action="append", choices=sorted(TARGETS),
                    help="which registered sweep to run (repeatable; default: all)")
    ap.add_argument("--fixture", choices=sorted(FIXTURES),
                    help="run one target's fixture once, unmutated. This is what the "
                         "sweeps invoke as their command; run it by hand to see what "
                         "a mutation has to break.")
    ap.add_argument("--list", action="store_true", help="list the registered targets")
    ap.add_argument("--show-output", action="store_true",
                    help="print the tail of the command's output under each mutation, "
                         "so you can read WHICH case went red rather than trusting that "
                         "one did")
    args = ap.parse_args(argv)

    if args.fixture:
        return FIXTURES[args.fixture]()

    if args.list:
        for name in sorted(TARGETS):
            path, mutations, _cmd = TARGETS[name]()
            print("%-8s %-24s %d mutation(s)" % (name, path.name, len(mutations)))
        return 0

    names = args.target or sorted(TARGETS)
    worst = 0
    for name in names:
        path, mutations, command = TARGETS[name]()
        print("=== target: %s" % name)
        report = run_sweep(path, mutations, command, cwd=TOOLS.parent,
                           show_output=args.show_output)
        expected_survivors = sum(1 for r in report.results if r.mutation.expect == SURVIVED)
        # The denominator of the sweep itself: N declared, N run. They differ whenever a
        # needle stopped matching, which is the failure this whole tool exists for.
        print("  %d of %d declared mutation(s) ran: %d RED, %d SURVIVED (%d expected), "
              "%d NOT-APPLIED, %d BROKEN RUN"
              % (len(report.results), len(mutations), report.count(RED),
                 report.count(SURVIVED), expected_survivors,
                 report.count(NOT_APPLIED), report.count(BROKEN_RUN)))
        if not report.baseline_ok:
            print("  0 of %d declared mutation(s) ran: the baseline was not clean."
                  % len(mutations))
        worst = max(worst, report.exit_code())
        print("")

    print("NOT PROVEN: a RED here says the command's result MOVED when that line "
          "changed -- not that the change was semantically meaningful, and not that any "
          "particular assertion is the one that caught it. Read which fixture case went "
          "red. A SURVIVED says nothing checks that line in THIS command's fixture; it "
          "is not a claim about the whole suite. And this tool compiles nothing and runs "
          "no engine: only import_check.py and lint_project.gd do that, and neither is "
          "parallel-safe, which is also why this one must never run beside them.")
    return worst


if __name__ == "__main__":
    sys.exit(main())
