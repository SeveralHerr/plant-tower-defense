#!/usr/bin/env python3
r"""Guard the local patches this project carries on top of the installed harness.

WHY THIS EXISTS. `/scaffold-godot-harness` refreshes every harness file from the plugin's
templates, in place, without asking. Any local edit is silently reverted -- and this repo
carries three that matter, none of them fixed in the newest release on this machine
(0.66.0):

  * `addons/godot_selftest/dev_tools.gd` -- the exported-build guard (upstream #58, still
    OPEN). Without it the bus polls and the `entry_hook` fires inside a PLAYER'S copy, so
    the hook that skips the title screen for /verify skipped it for every itch.io player.
    That is a shipped-game regression, not a tooling one.
  * `tools/verify_ledger.py` -- `unreachable_static`, which classifies a changed `.gd`
    whose `extends` chain ends at RefCounted/Object as unreachable BY CONSTRUCTION rather
    than as a miss. The worktree/union split beside it HAS been upstreamed and is in
    0.60.0; this half has not.

Cycle 173 measured all fourteen harness files against the release history: twelve are
cleanly stale at 0.38.0 and would simply be updated, and these are the whole reason the
refresh is not a one-command job. A checker is the difference between "someone
remembers" and "the gate says so".

WHICH GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT. None. `name_check` resolves
identifiers, so deleting a whole function it never sees called is clean to it; lint
compiles, and the reverted file compiles perfectly -- it is the upstream file. The unit
suite does not exercise `_passive` under an export template because there is no export
template in a headless run. The defect's whole shape is CORRECT CODE REPLACED BY OTHER
CORRECT CODE, which no correctness gate can object to.

Exit 0 clean, 1 a patch has gone missing, 2 could not run.

# fixture:   a file with the marker / the marker deleted / the file missing entirely /
#            the marker present only inside a comment
# mutations: drop the comment-stripping      -> the comment-only fixture must go red
#            match on `in text` raw          -> same, and it is the bug that shipped first
#            empty the PATCHES table          -> the "nothing to check" NOTE must appear
#                                               and the denominator must read 0
"""

from __future__ import annotations

import argparse
import os
import sys

# The local patches, each keyed by a token that cannot survive the file being reverted.
#
# A MARKER IS CODE, NEVER PROSE. The first draft of this table used a sentence from each
# patch's comment, which would have been satisfied by someone pasting the comment back in
# without the behaviour -- and worse, is exactly the thing a refresh preserves least
# predictably. Every marker below is an identifier or a call that the patch introduces and
# the upstream file does not contain.
PATCHES = [
    {
        "file": "addons/godot_selftest/dev_tools.gd",
        "marker": "_has_cmdline_flag",
        "why": (
            "the exported-build guard (upstream #58, OPEN as of 0.60.0). Without it the "
            "bus polls and entry_hook fires in a PLAYER'S build -- the hook that skips "
            "the title screen for /verify skipped it for every itch.io player"
        ),
        "upstream": "SeveralHerr/godot-selftest-harness#58",
    },
    {
        "file": "tools/verify_ledger.py",
        "marker": "unreachable_static",
        "why": (
            "classifies a changed .gd whose extends chain ends at RefCounted/Object as "
            "unreachable BY CONSTRUCTION rather than as a reach miss. Not in 0.60.0. The "
            "worktree/union split beside it HAS been upstreamed and needs no guard"
        ),
        "upstream": "not yet filed",
    },
    {
        "file": "tools/verify_ledger.py",
        "marker": "_row_dict",
        "why": (
            "`stats` assumed lint/tests/runtime were always objects; three rows already "
            "in this ledger carry a scalar there, and one `.get` on a str took the WHOLE "
            "aggregate down with an AttributeError. The ledger's own read-back was "
            "unavailable to every session while `record` kept appending. Coerces and "
            "COUNTS instead, printing how many rows were affected"
        ),
        "upstream": "not yet filed (G-158)",
    },
    {
        "file": "addons/godot_selftest/dev_tools.gd",
        "marker": "draw_calls_over_budget",
        "why": (
            "`findings` gated fps and orphan growth and nothing else, while "
            "`_cmd_performance` had collected RENDER_TOTAL_DRAW_CALLS_IN_FRAME all "
            "along and `devtools.py` had printed it all along. Nothing read it. fps is "
            "a fact about the MACHINE -- the Cutworm's 2000-draw-call frame reads 165 "
            "fps on this desktop and 8.5 with the body fully out, so an fps_min tuned "
            "anywhere useful is noise on one machine and silence on another. The "
            "draw-call count is the same number everywhere, which is what makes it the "
            "one render metric a project can hold a budget against. Reads "
            "draw_calls_max from devtools_config.json, default 0 = off, and records a "
            "SKIP rather than a silent pass when it is off or when the run is headless"
        ),
        "upstream": "not yet filed (G-159)",
    },
]


def blank_comments(text: str, hash_comments: bool) -> str:
    """Blank comment bodies, preserving offsets and line count.

    Offsets are preserved so a caller can slice the RAW text at the same positions -- the
    idiom this repo's other checkers use. `hash_comments` picks `#` (GDScript, Python)
    which is both languages here; the parameter exists so the choice is explicit at the
    call site rather than assumed.
    """
    out = []
    in_str = None
    escaped = False
    in_comment = False
    for ch in text:
        if in_comment:
            out.append("\n" if ch == "\n" else " ")
            if ch == "\n":
                in_comment = False
            continue
        if in_str:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == in_str:
                in_str = None
            continue
        if ch in ('"', "'"):
            in_str = ch
            out.append(ch)
            continue
        if hash_comments and ch == "#":
            in_comment = True
            out.append(" ")
            continue
        out.append(ch)
    return "".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--quiet", action="store_true", help="findings only")
    args = ap.parse_args()

    root = args.root
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("harness_patch_check: no project.godot under %s -- nothing verified" % root)
        return 2

    findings = []
    checked = 0
    for patch in PATCHES:
        path = os.path.join(root, patch["file"])
        if not os.path.isfile(path):
            findings.append(
                "%s is MISSING entirely, so its local patch cannot be there either.\n"
                "  fix: restore it from git, then re-check. %s"
                % (patch["file"], patch["why"])
            )
            continue
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                raw = fh.read()
        except OSError as exc:
            print("harness_patch_check: cannot read %s (%s) -- nothing verified"
                  % (patch["file"], exc))
            return 2
        checked += 1
        # Comments blanked, because a reverted file that still carries the patch's
        # explanatory comment (a merge that kept the prose and dropped the code) is
        # exactly the case a raw `in` test would call clean.
        code = blank_comments(raw, hash_comments=True)
        if patch["marker"] not in code:
            findings.append(
                "%s no longer contains `%s` in CODE -- the local patch is gone.\n"
                "  why it matters: %s\n"
                "  upstream: %s\n"
                "  fix: this is almost certainly /scaffold-godot-harness reverting a local\n"
                "       edit. Recover the patch from git history (it is in every commit\n"
                "       before the refresh), re-apply it, and only then keep the refresh."
                % (patch["file"], patch["marker"], patch["why"], patch["upstream"])
            )

    if not args.quiet:
        print("harness_patch_check: %d of %d guarded harness file(s) readable, "
              "%d finding(s)" % (checked, len(PATCHES), len(findings)))
        if not PATCHES:
            print("  NOTE: nothing to check -- the patch table is empty. That is a clean "
                  "result only if this project carries no local harness edits, which is "
                  "worth confirming against the /verify skill's drift procedure rather "
                  "than assumed.")
        print("  NOT COVERED: this asks whether a MARKER is present, not whether the "
              "patch still WORKS -- a refresh that kept the function and changed what "
              "calls it passes here. It knows nothing about harness files this table "
              "does not name, and the table is hand-maintained: a local edit made and "
              "not added here is unguarded, which is the failure this tool cannot see "
              "by construction. Nor does it compile anything -- only import_check.py and "
              "lint_project.gd do that, and neither is parallel-safe.")
    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
