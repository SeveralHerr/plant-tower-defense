#!/usr/bin/env python3
"""run_tests.py - run run_tests.gd and refuse to report PASS over an aborted test.

Why this exists (gh#27 / moving-in:G-050, reported independently by two projects the
same day): a test method that hits a runtime error part-way through is reported [PASS].
Godot coerces an aborted coroutine's return value to the declared return type's
default -- "" for a `-> String` test -- which is byte-for-byte identical to a genuine
pass. run_tests.gd's own PASS/FAIL tally reads that return value and cannot tell the
difference; a real run was measured passing on a `-> String` test whose body raised
`SCRIPT ERROR: Invalid operands 'float' and 'Nil' in operator '+'` and never reached its
own assertions. [VACUOUS] does not catch this either: it only fires when a test executed
ZERO assertions, and an abort part-way through has usually already executed some -- the
more dangerous case, because the assertion count looks healthy.

The signal cannot come from inside run_tests.gd. GDScript has no way to observe its own
process's stderr after the fact, and the coerced return value is the only channel back
from an aborted coroutine -- which is exactly the channel that lies. So this wrapper
runs the suite as a subprocess, captures stdout+stderr together (in the order Godot
wrote them, matching import_check.py's proven approach for the identical reason:
`--import`'s exit code lies about parse errors the same way run_tests.gd's tally lies
about aborts), counts SCRIPT ERROR / USER SCRIPT ERROR lines, and refuses to let a
nonzero count pass through as a clean run -- regardless of what run_tests.gd itself
reported.

Exit codes follow the harness convention (`import_check.py`, `lint_project.gd`):
    0  the suite ran, run_tests.gd reported success, AND no error line was emitted
    1  run_tests.gd reported failures, OR it reported success but errors were emitted
       during the run (the exact case this tool exists to catch)
    2  could not run at all: no Godot binary, no project.godot, no output captured,
       Godot crashed, or the run timed out

Usage:
    python tools/run_tests.py                          # run the whole suite
    python tools/run_tests.py -- --filter foo           # passthrough args to run_tests.gd
    python tools/run_tests.py -- --file test_player.gd
    python tools/run_tests.py --json                    # this wrapper's own verdict as JSON

(`python` on Windows -- `python3` there is a Microsoft Store alias stub that satisfies
`command -v` and then refuses to run.)

Godot binary resolution matches `import_check.py`:
    --godot flag  ->  $GODOT_BIN  ->  `godot_bin` in
    tools/gates_config.json
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# harness-version: 0.38.0
HARNESS_VERSION = "0.38.0"

# The runtime-error prefixes Godot emits for a GDScript that raised mid-execution.
# Deliberately narrower than import_check.py's FAILURE_SIGNALS: "Parse Error" /
# "Failed to load script" / "Compilation failed" are load-time signals import_check.py
# already owns, and including them here would flag a test suite for a defect that
# belongs to a different gate's report. A runtime abort prints "SCRIPT ERROR" (an
# unhandled engine error, e.g. "Invalid operands 'float' and 'Nil'") or
# "USER SCRIPT ERROR" (a push_error() call) -- either way, code that was running when
# the harness's own tally says nothing went wrong.
FAILURE_SIGNALS = ("SCRIPT ERROR", "USER SCRIPT ERROR")
# gh#35 / moving-in:G-058: a plain engine `ERROR:` line is COUNTED, never gated. A
# 313-test suite emitted `Array is in read-only state.` on every run for a whole
# cycle while reporting 312/312 clean; the test passed for the wrong reason from the
# day it was written. Zero is not the right threshold - the reporter measured a
# clean baseline of exactly two legitimate ERROR: lines (a deliberate push_error
# under test, and the dummy renderer's null texture in a failed-capture test) - so
# this prints the number and lets a reader see it move.
_ENGINE_ERROR_RE = re.compile(r"^\s*(?:USER )?ERROR:\s*(.*)$")

_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
_AT_RE = re.compile(r"^\s+at: ")


def _read_harness_config(project_path: Path) -> dict:
    """tools/gates_config.json as a dict; {} when unreadable.

    Deliberately duplicated from import_check.py rather than imported --
    see import_check.py's identical helper for why the copy is cheaper than the coupling.
    """
    cfg_path = project_path / "tools" / "gates_config.json"
    try:
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def _resolve_godot(args, project_path: Path) -> Path:
    """--godot -> $GODOT_BIN -> config godot_bin. Exits 2 when there is no usable binary."""
    config = _read_harness_config(project_path)
    godot = args.godot or os.environ.get("GODOT_BIN") or str(config.get("godot_bin", "") or "")
    if not godot:
        print("Error: no Godot binary found. Pass --godot PATH, set $GODOT_BIN, or set "
              '"godot_bin" in tools/gates_config.json.', file=sys.stderr)
        sys.exit(2)
    godot_path = Path(godot).expanduser()
    if not godot_path.is_file():
        print(f"Error: Godot binary not found: {godot_path}", file=sys.stderr)
        sys.exit(2)
    return godot_path


def scan_output(text: str):
    """Return [(line_no, line, at), ...] for every runtime-error line in the log.

    Same shape as import_check.py's scan_output: the continuation "   at: ..." line is
    attached to the finding above it rather than reported separately.
    """
    findings = []
    lines = text.splitlines()
    for index, raw in enumerate(lines):
        line = _ANSI_RE.sub("", raw).rstrip()
        if not any(s in line for s in FAILURE_SIGNALS):
            continue
        detail = ""
        if index + 1 < len(lines):
            nxt = _ANSI_RE.sub("", lines[index + 1]).rstrip()
            if _AT_RE.match(nxt):
                detail = nxt.strip()
        findings.append({"line_no": index + 1, "text": line.strip(), "at": detail})
    return findings


def scan_engine_errors(text: str):
    """[(line_no, text, at)] for every plain `ERROR:` line that is not one of
    FAILURE_SIGNALS' lines (those are gated separately)."""
    out = []
    lines = text.splitlines()
    for index, raw in enumerate(lines):
        line = _ANSI_RE.sub("", raw).rstrip()
        m = _ENGINE_ERROR_RE.match(line)
        if not m or any(sig in line for sig in FAILURE_SIGNALS):
            continue
        detail = ""
        if index + 1 < len(lines):
            nxt = _ANSI_RE.sub("", lines[index + 1]).rstrip()
            if _AT_RE.match(nxt):
                detail = nxt.strip()
        out.append({"line_no": index + 1, "text": line.strip(), "at": detail})
    return out


def _user_state_before(project_path: Path):
    """plant-tower-defense:G-048c: record user:// before the suite so the wrapper can
    say which files the SUITE wrote. Four tests staged low scores through a real
    `record_score()` -> `_save()` and destroyed both high scores across two runs while
    every test restored the in-memory values and the suite said ALL TESTS PASSED.
    Uses tools/userstate.py's user-dir resolution and stat helpers when they are beside
    this file; absent, the check is skipped and says so."""
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import userstate  # noqa: WPS433 - shipped beside this file
        user_dir = userstate.get_user_data_path(project_path)
    except Exception as exc:  # noqa: BLE001 - advisory; never block the suite on this
        return None, "user:// writes: not checked (%s: %s)" % (type(exc).__name__, exc)
    n = userstate.stat_take(project_path, user_dir)
    return userstate, "%d file(s) in %s" % (n, user_dir)


def _user_state_entry(state_mod, project_path: Path) -> str:
    """plant-tower-defense:G-149 / -xdp7: name the files that were ALREADY under user://
    when the suite started.

    The `user:// writes` line below reports what the suite CHANGED, and it was telling the
    truth -- `0 file(s) changed` -- while eleven save tests failed on a
    `user://headless_scratch.save` some earlier headless process had left behind. A run
    that inherits poisoned state and a run that starts clean are byte-identical in that
    output, because the poison is READ at autoload time and never written. Reading the
    writes line is what pointed the diagnosis AWAY from user:// for the first several
    minutes. This is the other half of the same os.scandir: what was there to be read.

    Advisory, always. It cannot know whether a pre-existing file mattered; it can only
    stop the question from being invisible.
    """
    if state_mod is None:
        return "user:// on entry: not checked (no user-dir resolution available)"
    try:
        user_dir = state_mod.get_user_data_path(project_path)
        names = sorted(p.name for p in Path(user_dir).iterdir() if p.is_file())
    except Exception as exc:  # noqa: BLE001 - advisory; never block the suite on this
        return "user:// on entry: not checked (%s: %s)" % (type(exc).__name__, exc)
    if not names:
        return "user:// on entry: 0 pre-existing file(s) in %s" % user_dir
    return ("user:// on entry: %d pre-existing file(s) in %s -- %s. A suite result can "
            "depend on these; they are read at autoload time and a run that inherits one "
            "looks identical in the writes line below (advisory)"
            % (len(names), user_dir, ", ".join(names)))


def _user_state_after(state_mod, project_path: Path) -> str:
    diff = state_mod.stat_diff(project_path)
    if diff is None:
        return "user:// writes: not checked (no record)"
    changed, created, deleted, user_dir = diff
    total = len(changed) + len(created) + len(deleted)
    if not total:
        return "user:// writes: 0 file(s) changed by the suite (%s)" % user_dir
    parts = []
    if changed:
        parts.append("changed: " + ", ".join(changed))
    if created:
        parts.append("created: " + ", ".join(created))
    if deleted:
        parts.append("deleted: " + ", ".join(deleted))
    return ("user:// writes: %d file(s) changed by the suite in %s -- %s. A suite that "
            "writes a file no test named a path for is driving production state; point "
            "the save path at a temp file in the test, or expect the developer's real "
            "save to change (advisory)" % (total, user_dir, "; ".join(parts)))


def run_suite(godot_path: Path, project_path: Path, log_path: Path, passthrough, timeout: int,
              env=None):
    """Run the suite with stdout+stderr going to log_path. Returns Godot's exit code.

    Output goes to a file, never subprocess.PIPE -- see import_check.py's run_import
    for why (an unread pipe stalls Godot on Windows; a non-console build often prints
    nothing to a live terminal at all, so the file is the only honest read either way).

    `env=None` inherits this process's environment unchanged (subprocess.run's own
    default) -- callers that want to add or override a variable pass a full copy of
    `os.environ` with their change applied, per SAVE_PATH_ENV below.
    """
    cmd = [str(godot_path), "--headless", "--path", str(project_path),
           "--script", "res://tools/run_tests.gd"]
    if passthrough:
        cmd += ["--"] + list(passthrough)
    with log_path.open("w", encoding="utf-8") as log_f:
        proc = subprocess.run(cmd, stdout=log_f, stderr=subprocess.STDOUT,
                              cwd=str(project_path), timeout=timeout, env=env)
    return proc.returncode


# plant-tower-defense-l6zo: the env var RunConfig.resolved_save_path (game/run_config.gd)
# already honours, and already beats its own headless default -- see that function's
# docstring. Naming it here rather than importing run_config.gd keeps this wrapper
# Godot-version-agnostic; it is a plain OS environment variable name, not GDScript.
SAVE_PATH_ENV = "PLANT_TD_SAVE_PATH"


def scratch_save_env(project_path: Path, state_mod) -> tuple:
    """Decide this run's save path and return (env_or_None, message).

    THE DECISION (plant-tower-defense-l6zo): `run_tests.py` DOES set `PLANT_TD_SAVE_PATH`
    automatically, to a pid-derived path, one per invocation -- FOR concurrent fan-out
    lanes (the cycle skill's parallel form, `references/fan-out.md`) no longer sharing
    `RunConfig.HEADLESS_SAVE_PATH` (`user://headless_scratch.save`); two `run_tests.py`
    processes at once currently stage state through that one shared file, and `user://`
    cannot be isolated at all (harness gh#28 -- `launch --isolated` isolates the bus
    only). AGAINST: a per-run temp path loses "it's one known file you can cat" for a
    failing run's save state after the fact.

    The middle answer the bead itself proposes, taken rather than skipped: the path is
    KEPT (nothing here deletes it, before or after the run) and PRINTED, so a failing
    run still names exactly the file its state is in -- inspectable, just not at a fixed
    name. Trade accepted: the file this prints is `user://headless_scratch.pid<PID>.save`
    and OS pids recycle, so a kept-forever file from a much earlier run COULD be adopted
    by a later run that draws the same pid. Judged acceptable because `run_tests.gd`
    itself runs one process per invocation for at most a handful of minutes, making a
    same-pid collision within that window exceedingly unlikely, and because the file is
    still a real save this build wrote and can read -- not corruption, at worst a stale
    prior run's numbers, and the printed path makes it a checkable one.

    THE DEFAULT DOES NOT MOVE. `RunConfig.HEADLESS_SAVE_PATH` stays what a bare
    `godot --headless --script res://tools/lint_project.gd` -- no wrapper, no env var --
    resolves to; only a caller that goes through THIS wrapper gets a private path,
    exactly the way `PLANT_TD_SAVE_PATH` was designed to be beaten only by an explicit
    choice.

    A caller that has already set `PLANT_TD_SAVE_PATH` itself (its own env, before
    invoking this wrapper) is left alone -- that caller named what it wants, which is
    precisely `resolved_save_path`'s own top-priority rule, and this wrapper overriding
    it would be the same mistake the bead is about in miniature.
    """
    existing = os.environ.get(SAVE_PATH_ENV, "")
    if existing:
        return None, ("%s already set by the caller: %s (left unchanged)"
                       % (SAVE_PATH_ENV, existing))
    rel_path = "user://headless_scratch.pid%d.save" % os.getpid()
    env = os.environ.copy()
    env[SAVE_PATH_ENV] = rel_path
    abs_hint = ""
    if state_mod is not None:
        try:
            user_dir = state_mod.get_user_data_path(project_path)
            abs_hint = " (%s)" % (Path(user_dir) / rel_path.replace("user://", "", 1))
        except Exception:  # noqa: BLE001 - the hint is advisory; the env var is what matters
            abs_hint = ""
    return env, ("Save state for this run: %s%s -- kept after the run, not deleted"
                 % (rel_path, abs_hint))


_ASSERT_RE = re.compile(r"\b_T\s*\.\s*assert\w*\s*\(")
_EXECUTED_RE = re.compile(r"^\s*Assertions:\s*(\d+)\s+executed", re.M)


def declared_assertions(project_path):
    """(count, files) of `_T.assert_*(` call sites written across the test dir.

    moving-in:G-054 / gh#27: run_tests.gd counts assertions EXECUTED and cannot know
    how many a method contains, so a method that aborts after its first assert reads
    as a pass with one assertion. Measured on a real four-method file, written-vs-
    executed came out 4/2, 2/1, 2/1, 2/2 - the three aborts separated cleanly from
    the one genuine pass. Counted with the same word-bounded pattern coverage_check.py
    uses, over comment/string-blanked source, so a doc-comment mentioning
    `_T.assert_eq` is not a declaration. Advisory only: it is printed, never gated.
    """
    cfg = project_path / "tools" / "gates_config.json"
    test_dir = "res://test/unit"
    try:
        test_dir = str(json.loads(cfg.read_text(encoding="utf-8")).get("test_dir") or test_dir)
    except (OSError, ValueError):
        pass
    root = project_path / test_dir.replace("res://", "", 1)
    if not root.is_dir():
        return 0, 0
    blank = None
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import coverage_check  # shipped beside this file
        blank = coverage_check._blank_strings_and_comments
    except Exception:  # noqa: BLE001 - counting is advisory; fall back to raw text
        blank = None
    count = files = 0
    for path in sorted(root.rglob("*.gd")):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if blank is not None:
            try:
                text = blank(text)[0]
            except Exception:  # noqa: BLE001
                pass
        count += len(_ASSERT_RE.findall(text))
        files += 1
    return count, files



def _utf8_console() -> None:
    """gh#34: the client inherits the Windows console's cp1252 stdout, so any verb
    echoing game text with a glyph outside it (a Back button reading "\u2190 Back",
    a key legend using arrows) died with UnicodeEncodeError - and the traceback read
    as "this verb is broken on this node", not "the reporting is". `errors="replace"`
    rather than bare utf-8: a console that genuinely cannot render a glyph shows `?`
    and keeps going, instead of trading one crash for another."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError, ValueError):
            pass


def main():
    _utf8_console()
    parser = argparse.ArgumentParser(
        description="Run run_tests.gd and fail the run when it emitted a runtime error "
                    "it did not itself notice.",
        epilog="Exit codes: 0 clean, 1 the suite failed OR emitted an error under a "
               "reported pass, 2 could not run. Args after -- pass through to "
               "run_tests.gd (--filter, --file, --json, ...).")
    parser.add_argument("--project", "-p", help="Path to Godot project", default=".")
    parser.add_argument("--godot", help="Godot binary (else $GODOT_BIN, else config godot_bin)")
    parser.add_argument("--timeout", type=int, default=900,
                        help="Seconds to wait for the suite before giving up (default: 900)")
    parser.add_argument("--json", action="store_true",
                        help="Emit this wrapper's own verdict as JSON instead of prose "
                             "(independent of any --json passed through to run_tests.gd)")
    parser.add_argument("passthrough", nargs=argparse.REMAINDER,
                        help="Args after -- are forwarded to run_tests.gd verbatim")
    args = parser.parse_args()

    passthrough = list(args.passthrough)
    if passthrough and passthrough[0] == "--":
        passthrough = passthrough[1:]

    project_path = Path(args.project).expanduser().resolve()
    if not (project_path / "project.godot").is_file():
        print(f"Error: no project.godot in {project_path}. Run from the project root "
              "or pass --project/-p.", file=sys.stderr)
        sys.exit(2)

    godot_path = _resolve_godot(args, project_path)

    log_dir = project_path / ".gates"
    log_dir.mkdir(exist_ok=True)
    log_path = log_dir / "tests.log"

    state_mod, user_before = _user_state_before(project_path)
    # Taken BEFORE the suite and printed after it, beside the writes line it completes.
    user_entry = _user_state_entry(state_mod, project_path)
    # plant-tower-defense-l6zo: a pid-derived PLANT_TD_SAVE_PATH per invocation, kept and
    # printed -- see scratch_save_env's docstring for the full decision and reasoning.
    save_env, save_message = scratch_save_env(project_path, state_mod)
    print(save_message)
    try:
        godot_rc = run_suite(godot_path, project_path, log_path, passthrough, args.timeout,
                              env=save_env)
    except subprocess.TimeoutExpired:
        print(f"Error: the suite did not finish within {args.timeout}s; partial output "
              f"in {log_path}. Nothing was verified.", file=sys.stderr)
        sys.exit(2)
    except OSError as exc:
        print(f"Error: could not run {godot_path}: {exc}", file=sys.stderr)
        sys.exit(2)

    try:
        captured = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"Error: the suite ran but its log could not be read back ({exc}). "
              "Nothing was verified.", file=sys.stderr)
        sys.exit(2)

    if not captured.strip():
        print(f"Error: Godot exited {godot_rc} but wrote no output to {log_path}, so "
              "the suite could not be checked. On Windows use the *_console.exe build.",
              file=sys.stderr)
        sys.exit(2)

    # Print run_tests.gd's own output unchanged -- the per-test [PASS]/[FAIL]/[VACU]
    # listing and denominators are correct and worth keeping exactly as they read.
    print(captured, end="" if captured.endswith("\n") else "\n")

    findings = scan_output(captured)
    engine_errors = scan_engine_errors(captured)
    user_writes = _user_state_after(state_mod, project_path) if state_mod else user_before
    # run_tests.gd's own exit code: 0 all passed, 1 failures/vacuous, 2 could not run.
    # A nonzero error count overrides a reported 0 -- that is the entire point of this
    # wrapper -- but never downgrades a run_tests.gd exit 2 (could not run at all).
    if godot_rc == 2:
        exit_code = 2
    elif findings or godot_rc != 0:
        exit_code = 1
    else:
        exit_code = 0

    if args.json:
        print(json.dumps({
            "harness_version": HARNESS_VERSION,
            "project": str(project_path),
            "godot": str(godot_path),
            "godot_exit_code": godot_rc,
            "log": str(log_path),
            "error_count": len(findings),
            "errors": findings,
            "engine_error_count": len(engine_errors),
            "engine_errors": engine_errors,
            "user_on_entry": user_entry,
            "user_writes": user_writes,
            "save_state": save_message,
            "exit": exit_code,
        }, indent=2))
        sys.exit(exit_code)

    # `exit_code`, computed once above, is the only source of truth from here down --
    # every branch below only decides what to PRINT, never re-derives exit_code, so a
    # future edit to the decision cannot diverge from the exit it actually takes.
    if findings:
        print("")
        print(f"Errors: {len(findings)} emitted during the suite "
              f"(run_tests.gd itself reported exit {godot_rc})")
        for finding in findings[:40]:
            print(f"  {log_path.name}:{finding['line_no']}: {finding['text']}")
            if finding["at"]:
                print(f"      {finding['at']}")
        if len(findings) > 40:
            print(f"  ... and {len(findings) - 40} more line(s); full output: {log_path}")
        if godot_rc == 0:
            print("run_tests.gd reported ALL TESTS PASSED, but an aborted coroutine "
                  "returns \"\" for a -> String test -- identical to a genuine pass. "
                  "At least one test above did not finish; treat the run as FAILED.")
    elif godot_rc != 0:
        # run_tests.gd already explains its own failure/vacuous tally in the output
        # printed above; nothing to add except the exit code it earned.
        pass
    else:
        print(f"Errors: 0 emitted during the suite. Full log: {log_path}")

    # gh#35: engine ERROR: lines, counted, never gated (see _ENGINE_ERROR_RE).
    if engine_errors:
        print(f"Engine errors: {len(engine_errors)} ERROR: line(s) emitted (advisory - some are "
              "legitimate for a test exercising a failure path; watch this number MOVE):")
        for e in engine_errors[:10]:
            print(f"  {log_path.name}:{e['line_no']}: {e['text']}")
            if e["at"]:
                print(f"      {e['at']}")
        if len(engine_errors) > 10:
            print(f"  ... and {len(engine_errors) - 10} more; full log: {log_path}")
    else:
        print("Engine errors: 0 ERROR: line(s) emitted")
    # plant-tower-defense:G-149: what was already under user:// for the suite to READ.
    print(user_entry)
    # plant-tower-defense:G-048c: what the suite wrote under user://.
    print(user_writes)

    # moving-in:G-054: written-vs-executed assertion count, suite level, advisory.
    # Skipped under --filter/--file, where the denominator is not the whole dir.
    selected = any(tok in ("--filter", "--file") or tok.startswith(("--filter=", "--file="))
                   for tok in passthrough)
    m = _EXECUTED_RE.search(captured)
    if not selected and m:
        declared, nfiles = declared_assertions(project_path)
        executed = int(m.group(1))
        if declared:
            line = f"Declared: {declared} assertion call site(s) across {nfiles} test file(s); {executed} executed"
            if executed < declared:
                line += (f" -- {declared - executed} written but not run this suite: a test that "
                         "aborted before reaching them, or a branch nothing exercised (advisory)")
            elif executed > declared:
                line += " (loops or helpers run some sites more than once)"
            print(line)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
