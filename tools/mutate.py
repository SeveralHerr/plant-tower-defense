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

# Assembled, never written whole: see the self-mutation note in the module docstring.
_TAG = "self-mutation:"


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
    def __init__(self, mutation, outcome, returncode=None, matches=None, detail=""):
        self.mutation = mutation
        self.outcome = outcome
        self.returncode = returncode
        self.matches = matches
        self.detail = detail

    @property
    def as_expected(self) -> bool:
        return self.outcome == self.mutation.expect


class Report:
    def __init__(self, path, command):
        self.path = path
        self.command = command
        self.results = []
        self.restore_ok = True
        self.restore_detail = ""

    def count(self, outcome) -> int:
        return sum(1 for r in self.results if r.outcome == outcome)

    def exit_code(self) -> int:
        # 2 first: a NOT-APPLIED or a bad restore means the sweep did not measure what
        # it claims to have measured, and that is never a "findings" result.
        if self.count(NOT_APPLIED) or not self.restore_ok:
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


def _verdict(returncode: int) -> str:
    return SURVIVED if returncode == 0 else RED


def _silent(*_args, **_kwargs) -> None:
    return None


def run_sweep(path, mutations, command, cwd=None, out=print) -> Report:
    """Apply each mutation to `path` in turn, run `command`, restore, and report.

    Only ever one mutation is in the file at a time. The original bytes go back in a
    `finally`, and the restore is verified -- a sweep that dies half way through would
    otherwise leave a mutated checker in the tree for the next gate to trust.
    """
    path = Path(path)
    report = Report(path, command)
    text, crlf, original = read_source(path)

    out("mutate: %s -- %d mutation(s), command: %s"
        % (path.as_posix(), len(mutations), " ".join(str(c) for c in command)))

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
            code, _output = _run(command, cwd)
            outcome = _verdict(code)
            report.results.append(Result(mutation, outcome, returncode=code, matches=1))
            note = "" if outcome == mutation.expect else "   <-- UNEXPECTED"
            out("  [%d/%d] %-44s %s (exit %d)%s"
                % (index, len(mutations), mutation.label, outcome, code, note))
            if mutation.expect != RED:
                out("          expected to survive: %s" % mutation.reason)
    finally:
        report.restore_ok, report.restore_detail = _restore(path, original)

    if not report.restore_ok:
        out("  RESTORE FAILED: %s -- every verdict above is void until %s is put back "
            "by hand." % (report.restore_detail, path.as_posix()))
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
    ]
    return path, mutations, command


TARGETS = {"mirror": _target_mirror, "self": _target_self}


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

    try:
        cases.check("a needle matching twice is NOT-APPLIED, not SURVIVED", case_needle_twice)
        cases.check("a needle matching zero times is NOT-APPLIED", case_needle_absent)
        cases.check("a killed mutation reads RED", case_red)
        cases.check("an unchecked line reads SURVIVED", case_survived)
        cases.check("an LF needle matches a CRLF file", case_crlf_needle)
        cases.check("the subject's bytes are restored exactly", case_restore)
        cases.check("a no-op replacement is NOT-APPLIED", case_noop_replacement)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    return cases.report()


FIXTURES = {"mirror": _fixture_mirror, "self": _fixture_self}


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
        report = run_sweep(path, mutations, command, cwd=TOOLS.parent)
        expected_survivors = sum(1 for r in report.results if r.mutation.expect == SURVIVED)
        print("  %d mutation(s): %d RED, %d SURVIVED (%d of them expected), %d NOT-APPLIED"
              % (len(report.results), report.count(RED), report.count(SURVIVED),
                 expected_survivors, report.count(NOT_APPLIED)))
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
