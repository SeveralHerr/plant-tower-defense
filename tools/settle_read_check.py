#!/usr/bin/env python3
"""settle_read_check.py - a test that reads a settle-volatile value straight after
`_T.instantiate_scene()` is asserting against however many frames the harness
happened to pump, which is a number no test states and no doc promises.

WHY THIS EXISTS.

`_T.instantiate_scene` pumps `UI_SETTLE_FRAMES` frames (currently 2, in
tools/run_tests.gd) and then returns. Anything in the hosted tree that acts on
entering the tree has therefore ALREADY ACTED by the time the test body's first
line runs - a loaded CornCobbler has fired a volley, a Pest has walked, a clock
has advanced. The frame count is an implementation detail of the harness; no test
declares a dependency on it, and nothing checks one.

`test_hosting_a_loaded_cob_puts_kernels_in_the_group_before_the_test_acts` is the
worked case. It asserted the volley had landed BY THE TIME instantiate_scene
returned. It passed alone and in the suite for two cycles, then went red when four
unrelated tests were appended and the timing shifted - which is precisely the
accident that test had been written to document. It now awaits a bounded
condition instead (test/unit/test_board.gd:739-748), and that is the fix this tool
names.

WHAT COUNTS AS SETTLE-VOLATILE, AND WHAT DOES NOT.

Not every read after hosting is exposed, and a tool that says so is noise. Three
classes are volatile, and each is DERIVED from game/ rather than hardcoded, so it
tracks the game instead of this docstring:

  A. a tree-global group census - `get_nodes_in_group()` is populated by whatever
     is in the tree, including nodes this test's own hosting spawned during the
     settle frames.
  B. an ACCUMULATOR - a member `+=`/`-=`'d inside the transitive `_process` /
     `_physics_process` closure of a game script (`run_seconds`, `_prep_left`,
     `_elapsed`...). An accumulator never converges: one more frame is always a
     different value.
  C. a physics-driven transform - `.position` / `.global_position` on a variable
     typed as a class whose `_physics_process` writes its own position (Kernel,
     Pest). Same reason: it never stops.

Deliberately NOT volatile, and the distinction is the whole point of the tool:

  * `Control.size`, `.position` on a Control, `.text`, `.visible`. Layout
     CONVERGES, and pumping it to convergence is exactly what UI_SETTLE_FRAMES
     exists to do. Reading a Control's size after instantiate_ui is the harness's
     documented contract, not a defect. Flagging it would have produced 106
     findings here, none of them real.
  * `Array.size()`. `plants.size()` is not `Control.size`.
  * constants, static function results, and a declared property the test set
     itself.

WHAT COUNTS AS A GUARD.

An `await` is NOT automatically a fix, and this tool refuses to treat one as such.
`await tree.process_frame` is still a guessed frame count - just a different guess
from the harness's. Only a BOUNDED CONDITION - loop until the thing you are
waiting for is true, with a counter cap - is a guard, because it states what it is
waiting for instead of how long. Five forms are accepted, all five already in use
in this repo:

  1. bounded condition await - `while cond and n < N: await ...`  (the preferred
     fix; test_board.gd:741)
  2. exact pin - `assert_eq(pests.size(), 1)`, `assert_float_eq(k.position.x, x)`.
     Not provenance, but a LOUD guard: if a settle frame moved the value the test
     goes red rather than measuring a stranger. Only EXACT equality counts;
     `assert_gt(size, 0)` is refused on the same grounds group_leak_check refuses
     it, namely that it was true every single time the original defect was green.
     (test_board.gd:658, test_combat.gd:1603, test_combat.gd:3865)
  3. baseline capture - read the value into a local and assert on the DELTA
     against a later read. A shifted frame count moves both sides equally.
     (test_combat.gd:167, test_economy.gd:332, and the instance-id diffs)
  4. test-assigned - the test writes the member itself before reading it, so
     whatever the settle frames did is overwritten. (test_selftest.gd:3200)
  5. exclusion diff - a loop over the group that steps over a node the test is
     HOLDING (`for p in ...: if p != early: late = p`). `!= null` does NOT count:
     a null check skips nothing the settle frames put there.
     (test_selftest.gd:173, test_selftest.gd:1291)

A whole-set `for` that never carries the loop variable out is not judged at all: a
stranger the settle frames added can only make an existence flag MORE true, so
`saw_pest_bar` is monotone in the group's size. Whether that stranger should be
there at all is group_leak_check's question, not this one.

Nothing else in the toolchain can see this:

  * `name_check.py` resolves identifiers. `get_nodes_in_group` resolves; WHEN it
    was called relative to a pumped frame is not a name question.
  * `lint_project.gd` / `import_check.py` type-check. Both sides of the bad read
    are correctly typed.
  * `group_leak_check.py` is the closest neighbour and is a different rule: it
    asks whether a test can say WHICH node it got out of a group. This asks
    whether the value was even settled when it was read - and it fires on
    accumulators and transforms, where no group is involved at all.
  * `run_tests.gd` catches a VACUOUS pass. This is the opposite: every assertion
    ran and passed, against a value that happened to have settled that time.
  * a runtime run cannot help. The defect IS that the run passes; it only shows
    up when an unrelated test shifts the timing, months later.

THE SECOND RULE: A TREE READ INSIDE A CORPSE WINDOW.

Same defect, a different clock. Cycle 73 measured that a killed Pest survives its own
kill by 18 process frames; `UI_SETTLE_FRAMES` pumps 2 (tools/run_tests.gd). `Pest.kill()`
never frees anything - it sets `_alive = false`, emits `died`, and hands the body to a
`tween_interval(death_linger())` whose floor is 1.0s (game/pest.gd:1602, `_play_death`).
So between the kill and the free there is a window, measured in frames nobody declared,
in which the corpse is STILL a valid instance and STILL a member of the "pests" group -
and a test reading the tree in that window gets an answer it did not mean to ask for.

A `.kill()` or a `.queue_free()` on a named variable OPENS such a window, textually, to
the end of the function. `free()` does not and is deliberately not tracked: `free()` is
immediate, `_T.free_ui` calls it, and there is no window to be wrong about.

Two reads are exposed inside a window:

  D. a LIVENESS read of the node that was killed - `is_instance_valid(x)`,
     `x.is_inside_tree()`. At zero frames this is TRUE whatever the linger is, because
     `queue_free()` defers to the end of the frame; at N frames it depends on N against
     a game constant. Neither is a question the test asked. `is_instance_valid` alone
     can only ever distinguish `queue_free()` from a synchronous `free()`.
  E. a CENSUS - `get_nodes_in_group`, `get_first_node_in_group`, `get_child_count`,
     `get_children`. The corpse is still in the group, so the count includes it and an
     iteration visits it.

Note that E is BROADER than the group rule above, on purpose. There, a whole-set `for`
that only sets an existence flag is not judged, because a stranger the settle frames
added can only make an existence claim MORE true. That argument does not survive a
kill: the corpse is not a stranger, it is the node the test just removed, and a loop
that reads `child.species` off it is reading a dead node's state.

WHAT COUNTS AS A GUARD IN A CORPSE WINDOW. Four forms, all four already in this repo:

  A. paired queued flag - `is_instance_valid(x) and not x.is_queued_for_deletion()`.
     `is_queued_for_deletion()` is the half that can actually be false, so the pair
     goes red when the corpse's lifetime moves. This is the repo's own idiom:
     test_combat.gd:5202, test_placement.gd:216, test_placement.gd:240.
  B. bounded condition await NAMING THE KILLED VARIABLE - `while is_instance_valid(pest)
     and ... and frames < 600: await ...` (test_combat.gd:5206). Stricter than the
     bounded-await guard the first rule accepts, which is structural and does not check
     that the loop waits for the thing being read - a weakness that rule's own NOT
     COVERED line admits. Here the name is required.
  C. exclusion by name or by instance id - the census steps over the node it just
     killed (`if p != early`, test_selftest.gd:2530; `if node != plain`,
     test_selftest.gd:218) or over a set of ids captured before the removal
     (`not before.has(pest.get_instance_id())`, test_selftest.gd:9251) - or filters
     corpses explicitly with `is_alive()` / `is_queued_for_deletion()`.
  D. a waiver THAT SAYS WHY.

The waiver got stricter for both rules at the same time, and this is the change most
likely to surprise: `# settle-read-check: ok` with no reason after it is now a FINDING
in its own right rather than a silent pass. Both waivers standing in the repo when that
landed already carried a reason (test_combat.gd:4500, test_placement.gd:1332), so the
tightening cost nothing and closes the hole where a waiver silences a rule without
recording a single word about why it was safe to.

WHAT THE CORPSE RULE FOUND WHEN IT WAS WRITTEN. 19 removal calls across the suite; 6
functions read the tree inside a window; 5 were guarded, by three different forms. The
one finding was `test_selftest.gd:634`, in a test named
`..._lingers_before_freeing`, asserting `is_instance_valid(pest)` zero frames after
`pest.kill()` under the message "the corpse lingers on screen instead of vanishing
instantly". That assertion cannot fail for the reason its message gives: delete
`tween_interval(death_linger())` from `_play_death` entirely and it stays green.
`test_combat.gd:5202`, two frames later and paired with `is_queued_for_deletion()`,
is the same claim written so that it can go red.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`,
takes no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could
not run.

    fixture:   `python tools/settle_read_check.py --fixture`. KEPT, not written and
               deleted: FIXTURE_SOURCE below is 13 synthetic functions producing 7
               expected findings, and it is what the mutations are re-run against
               after every edit to this file. Each case is asserted on three things,
               not one - the finding COUNT, which guard NAME cleared it, and whether
               it was in the denominator at all - because "cleared by a guard" and
               "never counted" are different results a count alone cannot separate.
               Cases: a naked `is_instance_valid` after a kill (BAD), the same paired
               with `is_queued_for_deletion` (good), a naked one after `queue_free`
               (BAD), a bounded loop naming the killed var (good), a bounded loop
               naming a DIFFERENT var (BAD - the strictness the settle rule lacks), a
               census excluding by name (good), a census with an id baseline (good), a
               census with `!= null` only (BAD - a null check steps over nothing), a
               naked census (BAD), a liveness read of a var nobody killed (good - not
               in any window), a read BEFORE the kill (good - order within the function
               is the whole rule), a waiver with a reason (good), and a waiver without
               one (BAD, twice: the waiver is unexplained AND the read it was hiding
               is unguarded).
    mutations: 5, all RED, restore clean (13/13, 7 findings, repo back to 1). Read the
               COUNT beside each, not the verdict:

               make the corpse window whole-file instead of        -> 1 of 13 fixture,
                 order-scoped (`killed = list(removals)`)             repo 1 -> 4.
                 The repo number is the one that matters here: three of this suite's
                 reads sit textually ABOVE the kill in their function, so order
                 scoping is load-bearing on the real corpus and not only on the
                 fixture.
               accept any `!= <word>` as an exclusion               -> 2 of 13, repo
                 (drop the killed-name requirement)                    unchanged.
                 Two, not one, and the second is the point: the id-baseline case is
                 still CLEARED but by the wrong guard, which only the guard-NAME
                 column catches. A count-only fixture would have called it a pass.
               drop the killed-name requirement from guard B       -> 1 of 13, repo
                 (use BOUNDED_AWAIT_RE, i.e. behave like the          unchanged.
                 settle rule)
               accept a reasonless waiver (loosen WAIVER_RE        -> 1 of 13, repo
                 back to a bare `ok` with no reason clause)           unchanged.
               stop blanking comments (`code = raw`)               -> 1 of 13, repo
                                                                      1 -> 2.
                 Both directions in one mutation. In the fixture it CLEARS a real
                 finding, because a comment saying `if p != early` about an exclusion
                 the loop does not do reads as the exclusion. In the repo it INVENTS
                 one at test_board.gd:661. The clearing direction is the dangerous
                 half and the one a good-file/bad-file pair cannot show.

               Three of the five leave the repo count untouched. That is not those
               guards being dead: it is this suite not currently containing a case
               that exercises them, which is exactly what the fixture is the
               denominator for.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource
import repo_walk

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
EXTENDS_RE = re.compile(r"^extends\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
MEMBER_RE = re.compile(r"^\s*(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
CALL_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")

# `_prep_left -= delta`, `run_seconds += delta`. A plain `=` is excluded on
# purpose: assigning a computed layout value converges, incrementing never does.
INCREMENT_RE = re.compile(r"^\s*(?:self\.)?([A-Za-z_][A-Za-z0-9_]*)\s*(?:\+|-)=", re.M)
# `position += _velocity * delta` inside _physics_process makes the CLASS a mover.
MOVER_RE = re.compile(r"^\s*(?:self\.)?(?:global_position|position)\s*(?:\+|-)?=", re.M)

HOSTING_RE = re.compile(r"\b(?:instantiate_scene|instantiate_ui)\s*\(")
GROUP_RE = re.compile(
    r"\b(?:get_nodes_in_group|get_first_node_in_group)\s*\(\s*(?:\"([^\"]*)\"|'([^']*)')?")

# A guard, form 1. `while <cond>` (or `for`) whose body awaits: the loop states
# WHAT it waits for. A bare `await tree.process_frame` matches nothing here, by
# design - it is a guessed frame count, not a condition.
BOUNDED_AWAIT_RE = re.compile(
    r"^([ \t]*)(?:while|for)\b[^\n]*:[ \t]*\n(?:[^\n]*\n){0,20}?\1[ \t]+[^\n]*\bawait\b", re.M)
# Bare awaits, counted and reported but NEVER accepted as a guard.
BARE_AWAIT_RE = re.compile(r"\bawait\b[^\n]*")

# Escape hatch for a body whose settling this regex cannot follow. A reason is
# REQUIRED: `# settle-read-check: ok - <why>`. A waiver that says only "ok" silences a
# rule and records nothing about why that was safe, which is the one thing a waiver is
# for. Both waivers standing in the repo when this tightened already carried a reason,
# so it cost nothing; a reasonless one is reported below as a finding of its own rather
# than being quietly honoured.
#
# The marker must also OPEN A COMMENT, which is what the paragraph above already
# WROTE (`# settle-read-check: ok - <why>`) and what the regex did not require.
# Matched against the raw function body, so unanchored it fired on the marker inside
# a STRING LITERAL too -- and `test/unit/test_selftest.gd:7612` already writes
# `["suite-reach-check: ok", "the waiver, which has to be greppable to be usable"]`
# inside a test method, because a test that pins a checker's contract must name that
# checker's marker. This checker scans `test/`. Write that test for this marker and
# the function goes quiet with no finding and no change in exit code -- cycle 126's
# citation_check.py incident, where a bead waived itself with the sentence explaining
# the waiver, in GDScript. Both waivers standing in the repo
# (`test/unit/test_combat.gd:4519`, `test/unit/test_placement.gd:1332`) already open
# their own comment, so this costs nothing.
WAIVER_RE = re.compile(r"#+[ \t]*settle-read-check:\s*ok\b\s*[-:]\s*\S")
ANY_WAIVER_RE = re.compile(r"#+[ \t]*settle-read-check:\s*ok\b")

# -- the corpse rule ---------------------------------------------------------
#
# `kill()` and `queue_free()` open a window; `free()` does not, and is deliberately
# absent. `free()` is immediate (`_T.free_ui` uses it), so there is no undeclared
# frame count to be wrong about.
REMOVAL_RE = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*(kill|queue_free)\s*\(")
LIVENESS_CALL_RE = re.compile(
    r"\bis_instance_valid\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)")
LIVENESS_METHOD_RE = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*is_inside_tree\s*\(")
QUEUED_RE = re.compile(r"\bis_queued_for_deletion\s*\(")
CENSUS_RE = re.compile(
    r"\b(get_nodes_in_group|get_first_node_in_group|get_child_count|get_children)\s*\(")
# A loop that filters corpses out by asking whether they are one.
CORPSE_FILTER_RE = re.compile(
    r"\b(?:is_queued_for_deletion|is_alive|is_instance_valid)\s*\(")

# Typed locals, for form C. `var k := Kernel.new()` and `var p: Pest = _pest(...)`.
DECL_INFER_RE = re.compile(
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*new\s*\(")
DECL_TYPED_RE = re.compile(
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*=")


# Comments blanked, string BODIES blanked, quote delimiters kept (gdsource.BLANK),
# with the line count and every offset preserved.
#
# Every part of that matters. Comments go because this repo has already shipped a
# check that matched the prose explaining why a token was absent - and the docstrings
# on the very tests this tool judges say `get_nodes_in_group` out loud while
# explaining that they do not do the bad thing.
#
# String BODIES are blanked rather than kept, unlike group_leak_check, because this
# rule never needs a string's contents: an assertion message reading "position after
# the wave" must not register as a read of `.position`. The quotes are KEPT so the
# blanked span is still visibly a string.
#
# The comment is PADDED, not truncated. Every offset into the stripped text must index
# the same character in the raw text, because the raw text is where the group-name
# literal still exists to be reported. A truncating stripper made this tool's first
# output read `get_nodes_in_group("     ")`.
#
# Escapes are handled. A blanker that does not understand `\"` reads the tail of an
# escaped string as live code, which is an error a good-file/bad-file fixture cannot
# surface because it corrupts both files identically. That is now one of the cases in
# `python tools/gdsource.py`, which is where all of this lives.


def split_functions(code: str, raw: str) -> list[tuple[str, int, str, str]]:
    """[(name, 1-based start line, stripped body, raw body)].

    Function-scoped, not file-scoped: a bounded await in one test must not excuse
    a naked read in the next, and one waiver must not silence a whole file. Both
    bodies are returned because the rule is judged on the stripped one (so prose
    can never satisfy it) while the waiver is a COMMENT and survives only in the
    raw one. strip_comments preserves the line count, so one slice indexes both.
    """
    lines = code.splitlines()
    raw_lines = raw.splitlines()
    starts: list[tuple[str, int]] = []
    for idx, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if m:
            starts.append((m.group(1), idx))
    out = []
    for i, (name, idx) in enumerate(starts):
        end = starts[i + 1][1] if i + 1 < len(starts) else len(lines)
        out.append((name, idx + 1, "\n".join(lines[idx:end]),
                    "\n".join(raw_lines[idx:end])))
    return out


def gd_files(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Called on test/ and game/, never the repo root. Shared rule anyway; the
        # immunity belongs to the caller's argument, not to this function.
        repo_walk.prune(dirpath, dirnames, root)
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def volatile_vocabulary(game_root: str) -> tuple[set[str], set[str], list[str]]:
    """(accumulator member names, mover class names, notes).

    Derived from the game, never hardcoded, so a new countdown or a new projectile
    is covered the day it is written rather than the day someone remembers to edit
    this file. Walks the transitive self-call closure of every `_process` /
    `_physics_process` in `game_root`.
    """
    notes: list[str] = []
    if not os.path.isdir(game_root):
        return set(), set(), ["no game tree at %s" % game_root]

    scripts: dict[str, dict] = {}
    for path in gd_files(game_root):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                code = gdsource.strip_comments(fh.read(), gdsource.BLANK)
        except (OSError, UnicodeDecodeError) as exc:
            notes.append("unreadable %s (%s)" % (path, exc))
            continue
        cm = CLASS_RE.search(code)
        em = EXTENDS_RE.search(code)
        funcs = {n: b for n, _, b, _ in split_functions(code, code)}
        scripts[path] = {
            "cls": cm.group(1) if cm else None,
            "base": em.group(1) if em else None,
            "funcs": funcs,
            "members": set(m.group(1) for m in MEMBER_RE.finditer(code)),
        }

    accumulators: set[str] = set()
    movers: set[str] = set()
    for data in scripts.values():
        funcs = data["funcs"]
        work = [n for n in ("_process", "_physics_process") if n in funcs]
        if not work:
            continue
        seen: set[str] = set()
        is_mover = False
        while work:
            name = work.pop()
            if name in seen:
                continue
            seen.add(name)
            body = funcs.get(name, "")
            for m in INCREMENT_RE.finditer(body):
                # Only DECLARED members. A local `var gained` incremented in a
                # helper is not something a test can read off a node, and letting
                # locals in is what turned `position` into a global accumulator
                # and produced a wall of false positives on Control layout.
                if m.group(1) in data["members"]:
                    accumulators.add(m.group(1))
            if MOVER_RE.search(body):
                is_mover = True
            for m in CALL_RE.finditer(body):
                if m.group(1) in funcs:
                    work.append(m.group(1))
        if is_mover and data["cls"]:
            movers.add(data["cls"])

    # Subclasses of a mover move too.
    changed = True
    while changed:
        changed = False
        for data in scripts.values():
            if data["cls"] and data["cls"] not in movers and data["base"] in movers:
                movers.add(data["cls"])
                changed = True

    if not accumulators:
        notes.append("no accumulator found in any _process closure under %s" % game_root)
    if not movers:
        notes.append("no class moves itself in _physics_process under %s" % game_root)
    return accumulators, movers, notes


def typed_locals(body: str, wanted: set[str]) -> set[str]:
    """Local variables declared as one of `wanted`."""
    out: set[str] = set()
    for m in DECL_INFER_RE.finditer(body):
        if m.group(2) in wanted:
            out.add(m.group(1))
    for m in DECL_TYPED_RE.finditer(body):
        if m.group(2) in wanted:
            out.add(m.group(1))
    return out


def _block_after(region: str, offset: int) -> str:
    """The indented block belonging to the line at `offset` (a `for` body)."""
    lines = region[:offset].split("\n")
    head_idx = len(lines) - 1
    all_lines = region.split("\n")
    head = all_lines[head_idx]
    indent = len(head) - len(head.lstrip())
    out = []
    for line in all_lines[head_idx + 1:]:
        if line.strip() and (len(line) - len(line.lstrip())) <= indent:
            break
        out.append(line)
    return "\n".join(out)


def _group_use(region: str, m: "re.Match[str]") -> str:
    """How this group read is USED: "census", "selection", or "" (iteration only).

    The distinction decides whether the read is settle-volatile at all. A count or
    an index depends on exactly what the settle frames put in the group. A plain
    `for` over the whole set does not: a stranger the settle frames added can only
    make an existence claim MORE true, never less, so `saw_pest_bar` is monotone
    in the group's size. (Whether that stranger should be there at all is
    group_leak_check's question, not this one - keeping the two scopes apart is
    what lets both be trusted.)
    """
    line_start = region.rfind("\n", 0, m.start()) + 1
    line_end = region.find("\n", m.start())
    line = region[line_start:line_end if line_end != -1 else len(region)]
    tail = region[m.end():m.end() + 200]

    fm = re.match(r"^\s*for\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^\n]*?)?\s+in\b", line)
    if fm:
        body = _block_after(region, m.start())
        loop_var = fm.group(1)
        # A loop that carries the LOOP VARIABLE out to an outer name is picking one
        # node out of the set, and which one it picks depends on what the settle
        # frames put there. `saw_pest_bar = true` is not that: it is an existence
        # flag, and a stranger the settle frames added can only make an existence
        # claim more true. Requiring the loop variable on the right-hand side is
        # what separates the two.
        if re.search(r"^\s+[A-Za-z_][A-Za-z0-9_.]*\s*=(?!=)[^\n]*\b%s\b"
                     % re.escape(loop_var), body, re.M):
            return "selection"
        return ""
    if re.search(r"^\s*\)?\s*\.\s*size\s*\(", tail) or re.search(r"^\s*\)?\s*\[", tail):
        return "census"
    am = re.search(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=\n]*)?:?=[^\n]*$", line)
    if am:
        var = am.group(1)
        rest = region[m.end():]
        if re.search(r"\b%s\s*\.\s*size\s*\(" % re.escape(var), rest):
            return "census"
        if re.search(r"\b%s\s*\[" % re.escape(var), rest):
            return "census"
    return ""


def volatile_reads(region: str, raw_region: str, accumulators: set[str],
                   movers_vars: set[str]) -> list[tuple[int, int, str, str]]:
    """[(offset, end, kind, expression)] - every settle-volatile READ in `region`.

    `end` is the offset just past the matched expression. It exists because the
    baseline-capture guard searches the text AFTER the read for a second read of
    the same value, and searching from `offset + 1` let `k.position` find its own
    `.position` one character later and declare itself baselined. That silently
    cleared every mover-transform finding; the fixture caught it.

    A read, not a write: `game._prep_left = 9.0` is the test setting the value and
    must not be reported as reading it.

    `raw_region` is only ever used to NAME the group in the report. strip_comments
    blanks string bodies, so the literal is gone from `region` - and reporting
    `get_nodes_in_group("     ")` was the first thing this tool got wrong. It
    preserves column widths, so the same offset indexes both.
    """
    found: list[tuple[int, str, str]] = []
    for m in GROUP_RE.finditer(region):
        use = _group_use(region, m)
        if not use:
            continue
        rm = GROUP_RE.match(raw_region, m.start())
        lit = None
        if rm is not None:
            lit = rm.group(1) if rm.group(1) is not None else rm.group(2)
        found.append((m.start(), m.end(), "group " + use,
                      "get_nodes_in_group(%s)" % (('"%s"' % lit) if lit else "<expr>")))
    for prop in sorted(accumulators):
        for m in re.finditer(r"\.(%s)\b(?!\s*(?:\+|-|\*|/)?=(?!=))" % re.escape(prop), region):
            found.append((m.start(), m.end(), "accumulator", ".%s" % prop))
    for var in sorted(movers_vars):
        pat = r"\b%s\s*\.\s*(global_position|position)\b(?!\s*(?:\+|-|\*|/)?=(?!=))" % re.escape(var)
        for m in re.finditer(pat, region):
            found.append((m.start(), m.end(), "transform", "%s.%s" % (var, m.group(1))))
    found.sort()
    return found


def guard_for(region: str, upto: int, end: int, kind: str, expr: str) -> str:
    """Name the guard covering the read at `upto`, or "" if there is none."""
    before = region[:upto]
    # Form 1: a bounded condition await ANYWHERE in the function after hosting -
    # not merely before the read. The canonical fix reads the value first and then
    # loops until it is what the test is waiting for (test_board.gd:739-748), so a
    # before-only search never fires on the very pattern it exists to bless. The
    # mutation harness proved that: disabling this guard changed nothing, because
    # the one fixture case it should have cleared was being cleared by baseline
    # capture instead.
    if BOUNDED_AWAIT_RE.search(region):
        return "bounded condition await"
    # Form 4: the test assigned this member itself before reading it.
    if kind == "accumulator":
        prop = expr.lstrip(".")
        if re.search(r"\.%s\s*(?:\+|-|\*|/)?=(?!=)" % re.escape(prop), before):
            return "test-assigned before the read"
    if kind == "transform":
        var, prop = expr.split(".", 1)
        if re.search(r"\b%s\s*\.\s*%s\s*(?:\+|-|\*|/)?=(?!=)"
                     % (re.escape(var), re.escape(prop)), before):
            return "test-assigned before the read"
    # Form 5: exclusion diff - the loop skips a node the test itself holds, so
    # whatever the settle frames put in the group is stepped over by name.
    # `for p in ...: if p != early: late = p`
    if kind == "group selection":
        body = _block_after(region, upto)
        # `!= null` is a null check, not an exclusion: it steps over nothing the
        # settle frames put there. Only a comparison against a name the test is
        # HOLDING is provenance. The mutation harness caught this by forcing every
        # whole-set loop to count as a selection and finding the fixture STILL
        # clean - because `if node != null` was reading as a diff.
        for em in re.finditer(r"\bif\b[^\n]*!=\s*([A-Za-z_][A-Za-z0-9_]*)", body):
            if em.group(1) not in ("null", "true", "false"):
                return "exclusion diff (loop skips a node the test holds)"
        if re.search(r"\bhas\s*\([^\n]*get_instance_id", body) or "get_instance_id" in body:
            return "exclusion diff (instance-id diff)"
    # Form 3: baseline capture - the same volatile value is read again later, so
    # the assertion is a delta and a shifted frame count moves both sides equally.
    tail = region[end:]
    if kind.startswith("group"):
        if GROUP_RE.search(tail):
            return "baseline capture (group read twice, delta or id diff)"
    else:
        needle = expr if kind == "accumulator" else "." + expr.split(".", 1)[1]
        if re.search(re.escape(needle) + r"\b", tail):
            return "baseline capture (value read twice)"
    # Form 2: an exact pin within the next few lines. `assert_eq(x, <literal>)`
    # goes RED if a settle frame moved the value, so it cannot pass on a stranger.
    # Only EXACT equality counts. assert_gt / assert_true are refused on the same
    # grounds group_leak_check refuses assert_gt(size, 0): "more than zero" was
    # true every single time the original defect was green.
    # The window starts at the beginning of the READ'S OWN LINE, not at the read.
    # `return _T.assert_float_eq(k.position.x, ...)` puts the assert call name to
    # the LEFT of the read, so a window starting at the read cannot see what is
    # asserting on it - which made the pin silently unmatchable for transforms.
    win_start = region.rfind("\n", 0, upto) + 1
    window = region[win_start:upto + 400]
    if re.search(r"assert_eq\s*\([^\n]*?\.\s*size\s*\(\s*\)\s*,\s*-?\d+", window):
        return "exact pin (assert_eq on an exact count)"
    if kind == "accumulator":
        prop = re.escape(expr.lstrip("."))
        if re.search(r"assert(?:_float)?_eq\s*\([^,\n]*\.%s\s*,\s*[-\w.\"']+" % prop, window):
            return "exact pin (assert_eq on an exact value)"
    if kind == "transform":
        var, prop = expr.split(".", 1)
        # `assert_float_eq(kernel.position.x, from.x, 0.001)` is a loud guard: if a
        # settle frame moved the node the test goes red, which is exactly what
        # test_combat.gd:3865 is asserting on purpose. Missing this made the tool's
        # only other real-repo finding a false positive.
        if re.search(r"assert(?:_float)?_eq\s*\(\s*%s\s*\.\s*%s\b"
                     % (re.escape(var), re.escape(prop)), window):
            return "exact pin (assert_eq on an exact position)"
    return ""


def waiver_finding(raw_body: str, rel: str, start_line: int, fname: str) -> str:
    """A `settle-read-check: ok` with no reason after it, as a finding. "" if fine.

    Read from the RAW body, because strip_comments blanks the comment the waiver lives
    in - the bug that shipped in group_leak_check's first draft. Factored out so the
    fixture below exercises this exact function rather than a copy of it that could
    drift from what `main` actually runs.
    """
    if ANY_WAIVER_RE.search(raw_body) and not WAIVER_RE.search(raw_body):
        return (
            "%s:%d %s() carries a `settle-read-check: ok` waiver that does not say why. "
            "A waiver is the record of a judgement this tool could not make; without "
            "the reason it is just the rule turned off.\n"
            "    fix: write `# settle-read-check: ok - <reason>`. Worked examples: "
            "test/unit/test_combat.gd:4500, test/unit/test_placement.gd:1332.\n"
            "    waive: there is no waiver for a missing waiver reason."
            % (rel, start_line, fname))
    return ""


def _statement_at(region: str, offset: int) -> str:
    """The whole statement containing `offset`, continuation lines included.

    The pairing guard asks whether `is_queued_for_deletion()` sits in the SAME
    expression as the liveness read, and the repo's own idiom routinely splits that
    expression over two lines:

        err = _T.assert_true(is_instance_valid(pest) and not pest.is_queued_for_deletion(),
            "a corpse is still on the board two frames after the kill")

    A one-physical-line window misses the pair whenever the message wraps, which would
    report the single best-written case in the repo as the defect. So: start of the
    read's own line, then forward while parentheses are still open. Depth is clamped at
    zero so a read on a continuation line cannot run the scan backwards off the end.
    """
    start = region.rfind("\n", 0, offset) + 1
    depth = 0
    i = start
    n = len(region)
    while i < n:
        ch = region[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth = max(0, depth - 1)
        elif ch == "\n" and depth == 0:
            break
        i += 1
    return region[start:i]


def _bounded_wait_names(region: str, var: str) -> bool:
    """A `while`/`for` whose HEAD names `var` and whose body awaits.

    Stricter than BOUNDED_AWAIT_RE, which the first rule uses and whose own NOT COVERED
    line admits it accepts any bounded loop in the function regardless of what the loop
    is waiting for. Inside a corpse window the name is cheap to require and is the whole
    difference between "this test waits for THIS body to leave" and "this test waits for
    something, and also reads a corpse".
    """
    pat = re.compile(r"^[ \t]*(?:while|for)\b[^\n]*\b%s\b[^\n]*:" % re.escape(var), re.M)
    for m in pat.finditer(region):
        if "await" in _block_after(region, m.end()):
            return True
    return False


def _census_scope(region: str, offset: int) -> str:
    """The census read's own statement plus, if it heads a loop, that loop's body.

    A census is guarded by what the code around it does with the members - an
    exclusion, an id diff, a corpse filter - and for a `for` head that lives in the
    body rather than on the line.
    """
    return _statement_at(region, offset) + "\n" + _block_after(region, offset)


def corpse_findings(body: str, raw_body: str, start_line: int, rel: str,
                    fname: str) -> tuple[list[str], dict[str, int], bool]:
    """(findings, guards used, whether this function opened a corpse window).

    Order WITHIN the function is the entire rule: a `.kill()` in one test and an
    `is_instance_valid` in the next are unrelated, and so are a read at line 10 and a
    kill at line 20. Both directions have to hold, which is why the removal list is
    filtered by offset at every read rather than collected per function.
    """
    guards: dict[str, int] = {}
    findings: list[str] = []
    removals = [(m.start(), m.group(1), m.group(2)) for m in REMOVAL_RE.finditer(body)]
    if not removals:
        return findings, guards, False

    waived = bool(WAIVER_RE.search(raw_body))
    exposed: list[tuple[int, str, str, str]] = []

    for m in LIVENESS_CALL_RE.finditer(body):
        exposed.append((m.start(), "liveness", "is_instance_valid(%s)" % m.group(1),
                        m.group(1)))
    for m in LIVENESS_METHOD_RE.finditer(body):
        exposed.append((m.start(), "liveness", "%s.is_inside_tree()" % m.group(1),
                        m.group(1)))
    for m in CENSUS_RE.finditer(body):
        exposed.append((m.start(), "census", "%s()" % m.group(1), ""))
    exposed.sort()

    read_any = False
    for offset, kind, expr, var in exposed:
        killed = [r for r in removals if r[0] < offset]
        if not killed:
            continue
        killed_names = [r[1] for r in killed]
        if kind == "liveness" and var not in killed_names:
            # A liveness read of a node nothing in this function removed. Whatever it
            # is asserting, it is not asserting it against a corpse.
            continue
        read_any = True
        if waived:
            guards["waiver (with a reason)"] = guards.get("waiver (with a reason)", 0) + 1
            continue

        guard = ""
        if kind == "liveness":
            if QUEUED_RE.search(_statement_at(body, offset)):
                guard = "paired queued flag (is_queued_for_deletion in the same expression)"
            elif _bounded_wait_names(body, var):
                guard = "bounded condition await naming the killed node"
        else:
            scope = _census_scope(body, offset)
            for name in sorted(set(killed_names)):
                if re.search(r"!=\s*%s\b" % re.escape(name), scope) or \
                        re.search(r"\b%s\s*!=" % re.escape(name), scope):
                    guard = "exclusion by name (steps over the node it removed)"
                    break
            if not guard and "get_instance_id" in scope:
                guard = "instance-id baseline (a set captured before the removal)"
            if not guard and CORPSE_FILTER_RE.search(scope):
                guard = "corpse filter (the loop asks whether each member is one)"
            if not guard:
                for name in sorted(set(killed_names)):
                    if _bounded_wait_names(body, name):
                        guard = "bounded condition await naming the killed node"
                        break
        if guard:
            guards[guard] = guards.get(guard, 0) + 1
            continue

        removed_at, removed_var, removed_how = killed[-1]
        line_no = start_line + body[:offset].count("\n")
        kill_line = start_line + body[:removed_at].count("\n")
        findings.append(
            "%s:%d %s() reads %s (%s) inside the corpse window opened by "
            "%s.%s() at line %d, with nothing stating how many frames have passed. "
            "kill() frees nothing: it hands the body to a tween whose interval is a "
            "game constant (game/pest.gd `_play_death`, floor 1.0s), and queue_free() "
            "defers to the end of the frame. So the corpse is still a valid instance "
            "and still a member of its groups, and the answer here is whatever that "
            "undeclared frame count produced -- at zero frames it cannot be false at "
            "all.\n"
            "    fix: pair the read with the half that CAN fail -- "
            "`is_instance_valid(x) and not x.is_queued_for_deletion()` "
            "(test/unit/test_combat.gd:5202, test/unit/test_placement.gd:216) -- or "
            "await a bounded condition that names the node "
            "(test/unit/test_combat.gd:5206), or, for a census, step over what you "
            "removed by name (test/unit/test_selftest.gd:2530) or by instance id "
            "(test/unit/test_selftest.gd:9251).\n"
            "    waive: add `# settle-read-check: ok - <reason>` in the body. The "
            "reason is required."
            % (rel, line_no, fname, expr, kind, removed_var, removed_how, kill_line))

    return findings, guards, read_any


# ---------------------------------------------------------------------------
# The corpse rule's fixture, kept rather than written-and-deleted.
#
# gdsource.py's self-test makes the argument: the fixture is written once, but the
# MUTATIONS are what you re-run after every edit to the checker, and re-deriving a
# deleted fixture is most of the cost of writing it the first time. This one is
# thirteen functions of synthetic GDScript that never reaches Godot, asserted through
# `corpse_findings` and `waiver_finding` themselves - the same functions `main` calls,
# not a copy that could drift from them.
#
# It deliberately contains PROSE naming `is_queued_for_deletion` and `!= early` in
# comments explaining what the function does NOT do, so that a checker which stops
# blanking comments clears a real finding instead of only inventing a false one. That
# is the direction of failure a good-file/bad-file pair cannot show.

FIXTURE_SOURCE = '''extends Node


func test_bad_naked_liveness_after_kill() -> String:
	var pest: Pest = _pest()
	pest.kill()
	# Prose, not code: this deliberately does NOT call is_queued_for_deletion(), and a
	# checker that stops blanking comments reads this sentence as the guard.
	return _T.assert_true(is_instance_valid(pest), "the corpse lingers")


func test_good_paired_queued_flag() -> String:
	var pest: Pest = _pest()
	pest.kill()
	return _T.assert_true(is_instance_valid(pest) and not pest.is_queued_for_deletion(),
		"a corpse is still on the board, and has not been queued away either")


func test_bad_naked_liveness_after_queue_free() -> String:
	var pest: Pest = _pest()
	pest.queue_free()
	return _T.assert_true(is_instance_valid(pest), "still there")


func test_good_bounded_loop_names_the_killed_node() -> String:
	var pest: Pest = _pest()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	pest.kill()
	var frames: int = 0
	while is_instance_valid(pest) and frames < 600:
		await tree.process_frame
		frames += 1
	return _T.assert_true(frames < 600, "it does leave")


func test_bad_bounded_loop_names_a_different_node() -> String:
	var pest: Pest = _pest()
	var director: Node = _director()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	pest.kill()
	var frames: int = 0
	while director.is_spawning() and frames < 600:
		await tree.process_frame
		frames += 1
	return _T.assert_true(is_instance_valid(pest), "the corpse outlived the wave")


func test_good_census_excludes_by_name() -> String:
	var early: Pest = _pest()
	early.queue_free()
	var late: Pest = null
	for p: Node in get_tree().get_nodes_in_group("pests"):
		if p != early:
			late = p as Pest
	return _T.assert_true(late != null, "the later pest was found")


func test_good_census_uses_an_id_baseline() -> String:
	var queen: Pest = _pest()
	var before: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("pests"):
		before[node.get_instance_id()] = true
	queen.kill()
	var brood: Array[Pest] = []
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var pest := node as Pest
		if pest != null and not before.has(pest.get_instance_id()):
			brood.append(pest)
	return _T.assert_eq(brood.size(), 2, "she left exactly the brood she declares")


func test_bad_census_only_checks_null() -> String:
	var early: Pest = _pest()
	early.kill()
	var seen: int = 0
	for p: Node in get_tree().get_nodes_in_group("pests"):
		# The exclusion this loop does NOT do would read `if p != early`.
		if p != null:
			seen += 1
	return _T.assert_eq(seen, 1, "one pest is left")


func test_bad_naked_census() -> String:
	var pest: Pest = _pest()
	pest.kill()
	var live: int = get_tree().get_nodes_in_group("pests").size()
	return _T.assert_eq(live, 0, "the board is clear")


func test_good_liveness_of_a_node_nobody_killed() -> String:
	var pest: Pest = _pest()
	var host: Node2D = _host()
	pest.kill()
	return _T.assert_true(is_instance_valid(host), "the host outlives its pest")


func test_good_read_before_the_kill() -> String:
	var pest: Pest = _pest()
	var err: String = _T.assert_true(is_instance_valid(pest), "a live pest is valid")
	pest.kill()
	return err


func test_good_waiver_with_a_reason() -> String:
	# settle-read-check: ok - the pest is never inside a tree here, so kill() takes
	# the immediate branch and there is no linger to be wrong about.
	var pest: Pest = _pest()
	pest.kill()
	return _T.assert_true(is_instance_valid(pest), "still an object")


func test_bad_waiver_without_a_reason() -> String:
	# settle-read-check: ok
	var pest: Pest = _pest()
	pest.kill()
	return _T.assert_true(is_instance_valid(pest), "still an object")


func test_bad_marker_named_in_a_string_is_not_a_waiver() -> String:
	var needles: Array = ["settle-read-check: ok - this is the marker, quoted"]
	var pest: Pest = _pest()
	pest.kill()
	return _T.assert_true(is_instance_valid(pest) and needles.size() == 1, "still there")
'''

# name -> (expected findings, a substring of the guard that must have cleared it,
#          whether the function should be IN the corpse denominator at all)
#
# The third column is a separate claim from the second and the reason both are here:
# "cleared by a guard" and "never counted" are different results that a findings count
# alone cannot tell apart, and a rule that quietly stops seeing a whole class of read
# would otherwise look exactly like a rule whose guards all fired.
FIXTURE_EXPECT = {
    "test_bad_naked_liveness_after_kill": (1, None, True),
    "test_good_paired_queued_flag": (0, "paired queued flag", True),
    "test_bad_naked_liveness_after_queue_free": (1, None, True),
    "test_good_bounded_loop_names_the_killed_node": (0, "bounded condition await", True),
    "test_bad_bounded_loop_names_a_different_node": (1, None, True),
    "test_good_census_excludes_by_name": (0, "exclusion by name", True),
    "test_good_census_uses_an_id_baseline": (0, "instance-id baseline", True),
    "test_bad_census_only_checks_null": (1, None, True),
    "test_bad_naked_census": (1, None, True),
    "test_good_liveness_of_a_node_nobody_killed": (0, None, False),
    "test_good_read_before_the_kill": (0, None, False),
    "test_good_waiver_with_a_reason": (0, "waiver", True),
    "test_bad_waiver_without_a_reason": (2, None, True),
    # CYCLE 126's INCIDENT, as GDScript. citation_check.py's --beads waiver was a bare
    # substring and the first bead the feature closed waived ITSELF, on the sentence
    # explaining the waiver: 468 beads became 467, three citations left the
    # denominator, exit code stayed 0, nothing said a word. The .gd version is not
    # hypothetical -- `test/unit/test_selftest.gd:7612` already writes
    # `["suite-reach-check: ok", "the waiver, ..."]` inside a test method, because a
    # test that pins a checker's contract has to name that checker's marker. This
    # checker scans `test/`.
    #
    # So: the marker QUOTED IN A STRING waives nothing, and the naked read underneath
    # it is still reported. Drop the `#+[ \t]*` from WAIVER_RE and this case goes to 0
    # findings and red; ANY_WAIVER_RE loses it too, so it does not turn into a
    # reasonless-waiver finding either.
    "test_bad_marker_named_in_a_string_is_not_a_waiver": (1, None, True),
}


def run_fixture(verbose: bool = True) -> int:
    """Run the corpse rule over FIXTURE_SOURCE. Returns the failure count.

    Every function in the fixture must appear in FIXTURE_EXPECT and vice versa, so a
    case added to one and not the other is a failure rather than a silently unchecked
    function - the input set is a denominator too.
    """
    code = gdsource.strip_comments(FIXTURE_SOURCE, gdsource.BLANK)
    funcs = split_functions(code, FIXTURE_SOURCE)
    fails = 0
    total_found = 0

    seen = set(name for name, _, _, _ in funcs)
    for extra in sorted(seen - set(FIXTURE_EXPECT)):
        print("  FAIL   fixture function %s() has no entry in FIXTURE_EXPECT" % extra)
        fails += 1
    for missing in sorted(set(FIXTURE_EXPECT) - seen):
        print("  FAIL   FIXTURE_EXPECT names %s(), which is not in the fixture" % missing)
        fails += 1

    for fname, start_line, body, raw_body in funcs:
        if fname not in FIXTURE_EXPECT:
            continue
        want_n, want_guard, want_counted = FIXTURE_EXPECT[fname]
        finds, guards, counted = corpse_findings(
            body, raw_body, start_line, "fixture.gd", fname)
        if waiver_finding(raw_body, "fixture.gd", start_line, fname):
            finds = finds + ["<waiver has no reason>"]
        got_n = len(finds)
        total_found += got_n
        guard_names = ", ".join(sorted(guards)) or "-"
        ok = got_n == want_n and counted == want_counted
        if want_guard is not None:
            ok = ok and any(want_guard in g for g in guards)
        if not ok:
            fails += 1
        line = ("  %-6s %-46s %d finding(s) (want %d), counted=%s (want %s), "
                "guards: %s"
                % ("ok" if ok else "FAIL", fname, got_n, want_n, counted,
                   want_counted, guard_names))
        if not ok or verbose:
            print(line)

    print("")
    print("settle_read_check fixture: %d synthetic function(s), %d finding(s) "
          "(want %d), %d failure(s)"
          % (len(funcs), total_found,
             sum(v[0] for v in FIXTURE_EXPECT.values()), fails))
    if not funcs:
        print("NOTE: nothing to check -- FIXTURE_SOURCE parsed to zero functions. An "
              "empty fixture is not a clean fixture.")
        fails += 1
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--tests", default="test", help="test tree to scan (default: test)")
    ap.add_argument("--game", default="game",
                    help="game tree the volatile vocabulary is derived from")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fixture", action="store_true",
                    help="run the 13-function synthetic fixture for the corpse rule "
                         "instead of scanning the repo, and exit 1 on any mismatch")
    args = ap.parse_args()

    if args.fixture:
        fails = run_fixture(verbose=not args.quiet)
        print("  NOT COVERED: the fixture exercises the CORPSE rule only. It says "
              "nothing about the settle rule above it, nothing about this repo's own "
              "tests, and nothing about the volatile vocabulary derived from game/ -- "
              "a clean fixture is a statement about the rule, not about the corpus.")
        return 1 if fails else 0

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("settle_read_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2

    test_root = os.path.join(root, args.tests)
    if not os.path.isdir(test_root):
        print("settle_read_check: no test tree at %s - cannot run." % test_root,
              file=sys.stderr)
        return 2

    paths = gd_files(test_root)
    if not paths:
        print("settle_read_check: no .gd files under %s - cannot run. Nothing was "
              "checked; this is not a pass." % test_root, file=sys.stderr)
        return 2

    accumulators, movers, notes = volatile_vocabulary(os.path.join(root, args.game))
    if not accumulators and not movers:
        print("settle_read_check: derived NO volatile vocabulary from %s (%s) - the "
              "group rule would still run but two of three rules would be silently "
              "empty, which reads as a pass. Cannot run."
              % (os.path.join(root, args.game), "; ".join(notes) or "no reason given"),
              file=sys.stderr)
        return 2

    scripts = 0
    fns_total = 0
    fns_hosting = 0
    fns_reading = 0
    guarded: dict[str, int] = {}
    waived = 0
    bare_await_only = 0
    findings: list[str] = []

    # The corpse rule's own denominator. Kept separate from the settle rule's on
    # purpose: the two scan different populations (every function versus only the ones
    # that host a scene), and one summed number would let an empty corpus on either
    # side hide behind the other's.
    removal_calls = 0
    fns_removing = 0
    fns_corpse_reading = 0
    corpse_guarded: dict[str, int] = {}
    corpse_findings_out: list[str] = []

    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("settle_read_check: cannot read %s (%s) - cannot run." % (path, exc),
                  file=sys.stderr)
            return 2
        scripts += 1
        rel = os.path.relpath(path, root).replace("\\", "/")
        code = gdsource.strip_comments(raw, gdsource.BLANK)

        for fname, start_line, body, raw_body in split_functions(code, raw):
            fns_total += 1

            # An unexplained waiver, reported for its own sake rather than honoured: a
            # waiver that records no reason silences a rule and leaves nothing behind
            # saying why that was safe.
            wf = waiver_finding(raw_body, rel, start_line, fname)
            if wf:
                findings.append(wf)

            # The corpse rule runs on EVERY function, not only the ones that host a
            # scene: a kill needs no hosting to open a window, and gating it on
            # HOSTING_RE would have silently excluded any test that builds its own tree.
            c_finds, c_guards, c_read = corpse_findings(
                body, raw_body, start_line, rel, fname)
            n_removals = len(REMOVAL_RE.findall(body))
            if n_removals:
                removal_calls += n_removals
                fns_removing += 1
            if c_read:
                fns_corpse_reading += 1
            for g, n in c_guards.items():
                corpse_guarded[g] = corpse_guarded.get(g, 0) + n
            corpse_findings_out.extend(c_finds)

            host = HOSTING_RE.search(body)
            if host is None:
                continue
            fns_hosting += 1
            region = body[host.end():]
            raw_region = raw_body[host.end():]
            movers_vars = typed_locals(body, movers)
            reads = volatile_reads(region, raw_region, accumulators, movers_vars)
            if not reads:
                continue
            fns_reading += 1

            if WAIVER_RE.search(raw_body):
                waived += 1
                continue

            offset, end, kind, expr = reads[0]
            guard = guard_for(region, offset, end, kind, expr)
            if guard:
                guarded[guard] = guarded.get(guard, 0) + 1
                continue

            if BARE_AWAIT_RE.search(region[:offset]):
                bare_await_only += 1
                extra = (" It does `await` first, but only a bare one: that is a "
                         "guessed frame count, not a condition, and it is not "
                         "accepted here as a guard.")
            else:
                extra = ""

            line_no = start_line + region[:offset].count("\n") + body[:host.end()].count("\n")
            findings.append(
                "%s:%d %s() reads %s (%s) after _T.instantiate_scene with nothing "
                "waiting for it to settle. instantiate_scene pumps UI_SETTLE_FRAMES "
                "frames and returns; anything hosted that acts on entering the tree "
                "has already acted, and the value read is whatever that undeclared "
                "frame count produced.%s\n"
                "    fix: await a BOUNDED CONDITION instead of a frame count - "
                "`while <not yet true> and waited < 30: await tree.physics_frame`. "
                "The worked example is test/unit/test_board.gd:739-748. Or guard it: "
                "pin an exact value with assert_eq (test_board.gd:658), capture a "
                "baseline and assert the delta (test_combat.gd:167), or assign the "
                "member yourself first (test_selftest.gd:3200).\n"
                "    waive: add `# settle-read-check: ok - <reason>` in the body."
                % (rel, line_no, fname, expr, kind, extra))

    if not args.quiet:
        print("settle_read_check: %d test script(s), %d function(s), %d host a scene, "
              "%d of those read a settle-volatile value, %d guarded, %d waived, "
              "%d finding(s)"
              % (scripts, fns_total, fns_hosting, fns_reading,
                 sum(guarded.values()), waived, len(findings)))
        print("  Vocabulary derived from %s/: %d accumulator(s) %s | %d mover class(es) %s"
              % (args.game, len(accumulators), sorted(accumulators),
                 len(movers), sorted(movers)))
        if fns_hosting == 0:
            print("  NOTE: nothing to check -- no function under %s calls "
                  "instantiate_scene/instantiate_ui at all. A zero denominator looks "
                  "exactly like a pass and is not one." % args.tests)
        elif fns_reading == 0:
            print("  NOTE: %d function(s) host a scene but NONE of them reads a group, "
                  "an accumulator or a mover's transform afterwards. Clean, but the "
                  "rule never fired -- that is a statement about the corpus, not about "
                  "the tool." % fns_hosting)
        for g in sorted(guarded):
            print("    guarded by %s: %d" % (g, guarded[g]))
        print("  corpse rule: %d removal call(s) (.kill()/.queue_free()) in %d "
              "function(s), %d of those read the tree inside the window, %d guarded, "
              "%d finding(s)"
              % (removal_calls, fns_removing, fns_corpse_reading,
                 sum(corpse_guarded.values()), len(corpse_findings_out)))
        if removal_calls == 0:
            print("    NOTE: nothing to check -- no function under %s calls .kill() or "
                  ".queue_free() on a named node at all, so no corpse window was ever "
                  "opened. A zero denominator looks exactly like a pass and is not one. "
                  "(.free() is immediate and deliberately not tracked.)" % args.tests)
        elif fns_corpse_reading == 0:
            print("    NOTE: %d function(s) open a corpse window but NONE of them reads "
                  "liveness or a census afterwards. Clean, but the rule never fired -- "
                  "that is a statement about the corpus, not about the tool."
                  % fns_removing)
        for g in sorted(corpse_guarded):
            print("      guarded by %s: %d" % (g, corpse_guarded[g]))
        for n in notes:
            print("  NOTE: %s" % n)
        if bare_await_only:
            print("  NOTE: %d finding(s) below do await before the read, but only a "
                  "bare `await`. One process_frame is a guessed frame count too; it is "
                  "counted here and never accepted as a guard." % bare_await_only)
    # Outside the --quiet guard on purpose. The blind spots are the reason a
    # weaker tool can be trusted at all, so they print on EVERY run - a quiet
    # clean result that never says what it could not see is the failure mode this
    # line exists to prevent.
    if True:
        print("  NOT COVERED: this reads source, not a running tree. It cannot see a "
              "read made inside a helper it does not inline (a `_pest_at(game, ...)` "
              "that touches position is invisible), a volatile value reached through a "
              "Dictionary or an untyped var, or a group named by an expression. It "
              "judges only the FIRST volatile read after hosting, so a guarded read "
              "followed by a naked one is reported clean. Its bounded-await guard is "
              "function-scoped and structural: it accepts a `while`/`for` containing "
              "an `await` without checking that the loop condition names the value "
              "the assertion is about, so a bounded loop waiting for one thing "
              "excuses a naked read of another in the same test. It cannot tell a converging "
              "value from a diverging one beyond the three derived classes above -- "
              "notably it says nothing about Control layout, which settles on purpose. "
              "The CORPSE rule adds its own blind spots: it tracks only a removal "
              "written as `name.kill()` / `name.queue_free()` in the same function, so "
              "a node removed inside a helper (`take_damage` reaching "
              "`Plant.play_exit_and_free`, `game._check_wave_cleared` reading the group) "
              "opens a window it cannot see -- which is why the two best-written "
              "examples of the guard it wants, test_placement.gd:216 and :240, are not "
              "even in its denominator. It judges TEXTUAL order within the function, so "
              "a loop whose next iteration re-reads a group above a removal below it "
              "(test_placement.gd:4726-4729) reads as clean; it does not follow a "
              "variable that is reassigned between the removal and the read; and it "
              "cannot tell a census the test MEANT to include the corpse in from one "
              "that did not. "
              "Nor does it compile anything -- only import_check.py and "
              "lint_project.gd do that, and neither is parallel-safe.")
    for f in findings + corpse_findings_out:
        print("  FINDING: %s" % f)
    return 1 if (findings or corpse_findings_out) else 0


if __name__ == "__main__":
    sys.exit(main())
