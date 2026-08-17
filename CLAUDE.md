# workflow
**This is a loop. It does not end. Keep going until the user stops you.**

Do these steps in order, over and over:

**`bd` IS THE WORK QUEUE. `cycle-log.md` IS THE NARRATIVE.** They are not two lists of
the same thing. Every item lives in `bd` and nowhere else — status, priority, blocked
state, dependencies and close reasons are real fields there and were being copied by
hand into a markdown checklist that could drift from them. `cycle-log.md` holds only
what `bd` structurally cannot: the cycle counter, the pattern the last cycle taught,
what is waiting on the user, and how to restart. It is what a human reads without
running a command. **Never write a work checklist into it.**

0. **Pre-flight. Read these four things and report them in one line.** This
   step exists because they were write-only: the reflection steps below are
   end-of-cycle WRITES and nothing was ever a start-of-cycle READ, so they filled up
   and never came back. Measured at the end of the first 33 cycles: `.claude/skills/`
   did not exist at all, despite the standing instruction to create skills there, and
   `kanban-staleness-audit` had been named as missing three separate times without once
   being built.
   - **Open beads.** `bd ready` and `bd list --status=open`. Anything unblocked belongs
     in this cycle. If everything open is blocked, say so explicitly — that is a real
     result and it is when to mine `kanban.md` harder, not when to invent work.
   - **Skills to create.** The skill ideas in `C:\Users\gotmi\documents\github\log.md`
     against what exists in `.claude/skills/`. **Two independent identifications of the
     same missing skill means build it** — do not identify it a third time.
   - **`kanban.md`.** The recent cycle sections, and the idea backlog you are about to
     mine. The historical sections are unpruned and roughly half stale; the file says so
     at its own top. Use the `kanban-staleness-audit` skill before promoting anything
     out of them — a wrong `STALE` deletes an idea nobody will have again. (This bullet
     used to name a `STILL REAL` section; the file has no such heading and never did,
     so the instruction pointed at nothing for 33 cycles.)
   - **The mirror.** `python tools/mirror_check.py` — exit 0 identical, 1 drifted,
     `--show-diff` for what moved. This is here because the block has now been silently
     deleted from `AGENTS.md` **twice**, most recently by the very commit that wrote the
     note warning about it, which left the note dangling above nothing. Every other
     pre-flight item is a list that fills up unread; this one is a file that quietly
     empties, and nothing else in the loop ever opens `AGENTS.md`. It was a hand-run
     `diff` for one cycle and is a tool now — which immediately caught a one-sided edit
     nobody planted, the commit that registered the tool itself.
     **When it fires, run `python tools/mirror_check.py --fix`** — it generates
     `AGENTS.md`'s copy from `CLAUDE.md`'s and re-checks from disk. Identical by
     construction beats identical by care, and care is what has now failed three times;
     the third was the cycle that hand-edited both copies of a rule about being careful.

   The harness is deliberately NOT checked here — it is checked in step 4, after it has
   actually been used. Pre-flight REPORTS AND FILES, it does not block.

1. **Read `cycle-log.md` for context, then `bd ready` for the work.** The log gives you
   the cycle number and what the last cycle learned — read it first, especially after a
   compaction. The beads ARE the queue; there is nothing to transcribe. This step used
   to say "read `todo.md`, file every item as a bd issue", which wrote every item twice
   and ticked it twice. (Do NOT use TodoWrite for any of this.)
2. **Do the items one at a time.** For each one: claim the bd issue, write the code,
   run `/verify`, then commit. One commit per item. Never batch several items into one
   commit at the end.
   - **If the last two cycles worked the same file or subsystem, take something else.**
     Step 6 already forces one FILED item to come from outside the neighbourhood; nothing
     forced the WORK to vary, and it does not on its own. Cycles 60 and 61 both worked the
     HUD message row; 62 and 63 both worked one Python checker. Each was the honest next
     thing, because finishing a piece of work is what exposes the next piece of it — the
     same structural pull step 6 was written for, one step earlier. The queue is 80+ items
     deep and most of it is nowhere near whatever just shipped.
   - **Write code with the Edit/Write tools, never through a shell heredoc.** A heredoc
     silently eats one level of backslash escaping and, worse, has now stripped the
     leading `#` from GDScript comment blocks four separate times. Cycle 54's instance
     produced a `test_placement.gd` that would not compile, and the suite reported
     `Total: 490 | Passed: 490 | Failed: 0 | ALL TESTS PASSED` — sixty-seven tests
     silently absent, reported as a clean run. Only the denominator (490 against 557)
     and exit `2` caught it. Four occurrences and an "environment note" in the log each
     time is not a countermeasure; using the right tool is.
   - **If the cycle launched the game at all, run `findings` before quitting it.** It is
     the harness's headline check — every zero-config check at once against the live tree
     — and it was last run in cycle 48. Twelve cycles of runtime work went past on
     hand-picked `get-state` reads, each answering the question I already had in mind,
     which is exactly the coverage a checklist of known failure modes exists to replace.
     Cycle 60 ran it and learned the UI baseline no longer exists, so every `ui_layout`
     finding has been gating as NEW for an unknown number of cycles. Read the NEW/PRE
     split and the `By check:` denominator, and remember a frozen tree makes tweens look
     like defects: this cycle's four findings were a panel caught mid-fade by `pause`.
   - **The ledger row lands BEFORE the commit, never after.** `reach` is the diff
     intersected against what the running game loaded, and after a commit the diff is
     empty — so a row recorded afterwards reads `reached 0/0 changed file(s)`, which is
     indistinguishable from a run that never started. Cycle 48 did exactly this and
     produced a `warranted` row carrying no evidence for the verdict. If you ran the
     gates by hand instead of through `/verify`, you owe the row by hand too, and it is
     due while the work is still uncommitted.
3. **Before reflecting, always add to `kanban.md`** — cool new features or concrete
   improvements (UX, game juice, animations, enhancements, or full features). This used
   to read "the last item is always...", which described a checklist that no longer
   exists now that `bd` is the queue; it is a step of its own, not an item in a list.
   - **Every entry must name a `file:line` for the claim it makes about the code as it
     is now.** An entry says two things — "here is an idea" and "the game does not do
     this yet" — and only the first is free. Cycle 30 wrote five entries from inside
     `run_config.gd` without opening a screen: one proposed a feature that already
     ships in full (the milestone shelf, with a documented reason for the exact
     placement it suggested), one rested on a claim about `fresh_record` that is false,
     one over-claimed its scope. That is three of five, and the shelf one became a bead
     that was claimed and worked before the code got read. **An entry written from the
     neighbourhood of the file you happen to be in is a guess about the rest of the
     codebase.** Use `kanban-staleness-audit`'s bar: before writing that something is
     missing, open the code that would contain it.
4. **Reflect on the HARNESS, now that you have used it.** This comes after the work
   and not before, because "did the harness earn its keep" is a question about a run
   that has happened. Judge it on THIS cycle's usage:
   - **Was it worth it?** `warranted` / `overkill` / `insufficient` / `inconclusive`,
     with the reason. Write the `log-devtools.md` entry the harness section below
     requires. `overkill` is a useful answer and the one that goes unwritten.
   - **What was missing?** File it as a new `[G-NNN]`. If it is concrete enough to name
     what should change — a diff, a missing section, a script that should exist — and
     it ships from a repo I own, **also file it upstream** with the
     `skill-feedback-issue` skill, which files a report rather than a patch. Anything
     below that bar goes only in the log and is allowed to rot there.
   - **Reconcile the old gaps.** `python tools/gap_ledger.py --open` says which are
     actually open; it derives each status from its LAST mention, because the format
     records status per entry and a gap fixed in cycle 12 still carries its cycle-4
     `open` line. Do NOT rewrite old entries — append the new status and let the tool
     resolve it. Two traps, both paid for: `grep -c "status: open"` counts LINES and
     said 61 when the answer was 44; and an id **cited** in the installed harness is
     not thereby fixed — 43 of this project's ids appear in 0.38.0 but 29 of those are
     only in the harness's copy of this log, and G-044 is cited in code while still
     failing. Anything now actionable in-project goes into step 6's refill.
5. **Reflect on THIS WORKFLOW and tweak it for the next run.** The steps above are not
   fixed; they are the thing most likely to be quietly wrong, because nothing else
   reviews them. Ask what actually happened this cycle: did a step get skipped, did one
   produce nothing, did the real work happen somewhere these steps do not describe?
   - **Change at most one thing per cycle, and write down why in the commit message.**
     A workflow that rewrites itself freely drifts; one that changes deliberately and
     records the reason can be read back.
   - **Only edit this file OUTSIDE the `BEGIN`/`END godot-selftest-harness` markers.**
     Everything between them is regenerated by `/scaffold-godot-harness` and an edit
     there is silently lost on the next refresh.
   - **If nothing needs changing, say so explicitly.** "The steps held this cycle" is
     a real answer; silence is indistinguishable from not having looked.
6. **Refill the queue, then update the log.**
   - **File 3-8 concrete, not-yet-filed items as bd issues** — drawn **from step 0's
     sources plus what steps 4 and 5 just produced**: open beads, skills to create,
     `kanban.md`, a broken mirror, harness gaps, and any workflow change worth its own
     item.
     **If a source points at a bead that is already open, add a note to THAT bead — do
     not file a duplicate in order to close it.** Cycles 53, 54, 55 and 56 each filed one
     item whose own description said "duplicate of the open X, filed only to record the
     second identification", then closed it in the same breath. The evidence is worth
     recording and the bead is not: `bd update X --notes` puts it where the person
     working X will read it, and leaves the ready count honest. A second identification
     is also a reason to raise the priority, which a closed duplicate cannot do.

     **Name which source each came from, in the issue.** This step used to say "out of
     kanban.md's backlog", and that single filename is what made every other source
     invisible for 33 cycles. Never end a cycle with nothing ready.
   - **At least one item must come from OUTSIDE the neighbourhood of this cycle's
     work.** Cycles 30-34 shipped one player-facing change and eleven correctness or
     tooling ones, and the cause is structural rather than a matter of taste: the
     queue is refilled from what the last cycle's work exposed, and step 3's
     cite-a-`file:line` rule — which is right, and has caught three bad entries —
     makes citing *easiest for the file you already have open*. So the loop keeps
     finding real work three feet from where it just stood. Take one item from an
     older `kanban.md` section, or from the design brief, and run
     `kanban-staleness-audit` over that section first, since those are the parts the
     file itself calls half stale.
   - **Then rewrite `cycle-log.md`**: bump the cycle number, write what THIS cycle
     taught in a sentence or two, and refresh what is waiting on the user and why.
     Keep it short and keep it prose — the moment it grows a checklist it has started
     duplicating `bd` again.
7. **Go straight back to step 1 and start the next cycle. Do not stop. Do not ask
   whether to continue. Do not say "next session" — you are the next session.**

The only reasons to stop are: the user tells you to, or you are genuinely blocked and
need an answer only they can give.

Keep a line at the top of `cycle-log.md` saying which cycle you are on (`Cycle 7`) and
bump it each time you refill, so the count survives a context compaction.

Whenever a good skill that would've been useful has been identified, please create it
locally in this repository, in `.claude/skills/<name>/SKILL.md`. **Identifying it twice
without building it is the failure mode** — the first 33 cycles named
`kanban-staleness-audit` three separate times and created nothing, because "identify a
missing skill" was an end-of-cycle note and never a start-of-cycle job. Step 0 reads
that directory; a skill named twice and absent from it is work, not an observation.

**Then USE it in the same cycle, on real code, before the cycle ends.** A skill built and
never applied fails the same way a skill identified and never built does — it becomes
prose nobody has tested. Cycle 51 built `scope-vs-claim` and immediately turned it on the
budget system: inside twenty minutes it found a budget still missing five of eight
producers a full cycle after being "fixed", a table asserted in one direction only, a
second hand-list nobody knew was a second list, and a stale sentence in `cycle-log.md`
itself. None of that would have surfaced from writing the skill well. **The first
application is what tells you whether the skill is a recipe or an essay** — and the first
target should be code you did not write it about.

**Where edits to this file may go.** Everything between the `BEGIN`/`END
godot-selftest-harness` markers is regenerated by `/scaffold-godot-harness`, so an edit
there is silently lost on the next refresh. That is why step 4's gap-reconciliation
rule lives up here in the project's own section rather than beside the `[G-NNN]` format
it belongs with, and it is the same trap as editing anything under `tools/` or
`addons/` — check `.harness_manifest.json` first.

**Parallel-safe gates.** The harness section below says `name_check.py` is the only gate
safe to run in parallel. That is true of the *harness's* gates; this project ships three
more stdlib-only checkers that open no project and write nothing to `.godot/`, so a
fan-out agent can run them all:

```bash
python tools/name_check.py           # names (harness)
python tools/world_control_check.py  # a Control over the playfield eats clicks
python tools/meta_key_check.py       # set_meta/get_meta keys resolve at both ends
python tools/svg_style_check.py      # sprite style contract
python tools/group_leak_check.py     # a test that selects a node it did not create
python tools/suite_reach_check.py    # the public surface no test names
python tools/settle_read_check.py    # a test reading a value the settle frames were still moving
python tools/save_persist_check.py   # a test script that can reach RunConfig._save() unredirected
python tools/message_corpus_check.py # a show_message() call site, or a producer's bool
                                     #   variant, the row's budget never measures
python tools/mirror_check.py         # CLAUDE.md and AGENTS.md's Workflow blocks have drifted
                                     #   (--fix generates the mirror; it WRITES AGENTS.md,
                                     #    so it is the one entry here not safe to fan out)
python tools/gap_ledger.py           # which [G-NNN] gaps are actually open (advisory)
```

Each prints its own `NOT COVERED:` line. None of them compiles — only `import_check.py`
and `lint_project.gd` do, and neither is parallel-safe.

Whenever a good skill that would've been useful has been identified, please create it
locally in this repository.

> This Workflow block is mirrored verbatim in `AGENTS.md`. The two files are
> independent (not symlinked), and a sync that only knows about one of them silently
> deleted this section once already — keep both copies in step.

# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

_Add your project-specific conventions here_

<!-- BEGIN godot-selftest-harness -->
## Self-Test Harness (godot-selftest-harness)

This project ships a **self-test harness**. Two things it does that a test suite you
write cannot: it knows a checklist of ways Godot games break and applies it with no
assertions from you, and it reports on *your* checks — which classes of defect this
project never asks about. Under that sits a bridge for driving the running game, and
a `/verify` gate. It is game-agnostic; project specifics come from the config below.

### START HERE: the findings report

```bash
python tools/devtools.py findings          # needs a running game; add --no-scenes to skip the slow scene pass
python tools/coverage_check.py             # static, no game, no engine, safe in parallel
```

`findings` runs every zero-config check at once against the live tree — offscreen and
zero-size Controls, unreachable/blocked interactive Controls, signals a script declares
and nothing connects, orphan growth and FPS against config thresholds, and scene
validation across `scan_root` — and returns one flat findings list. Each check calls
the same implementation the standalone verb does, so `findings` can never disagree
with `validate-ui` / `reachable-ui` / `performance` / `validate-all` about a scene.

**Read the denominator it prints** — `N finding(s) across K of M checks` — and read the
skipped checks: a consolidated report is the easiest place for a check to vanish from,
so one that could not run is named with a reason instead of disappearing into a clean
result. A check that ran and found nothing is a `0` in the `By check:` line, not an
absent one. UI findings are split NEW vs PRE against `user://ui_findings_baseline.json`
and only NEW ones gate. Exit `0` clean, `1` gating findings, `2` could not run — which
includes a reply missing a key, reported as unreadable rather than as a result.

`coverage_check.py` answers the other question — not *did the checks pass* but *which
questions do the checks ask at all*. A suite asserting 70 things that never once reads
a Control's screen rect prints exactly what a thorough one prints. It names the defect
classes nothing in this project exercises (`ui_layout`, `ui_reachable`,
`signal_unconnected`, `orphan_growth`, `input_path`, `scene_validation`,
`shader_compile`, `name_resolution`) and, for every class it calls covered, prints the
**file:line and token** that convinced it — read that, don't trust the verdict.
`COVERED (gate)` means an installed tool covers it; `COVERED (session)` means a past run
asked once, which is an observation, not a standing check. Advisory: exit 0 always,
`--strict` exits 1 on any unchecked class. **Coverage here is a floor, never a pass** —
a covered class means the question is asked, not that the answer was right.

When one of these fires, use the bridge below to reproduce and fix the specific case.

### Where the checks you write live

**`res://test/unit/test_selftest.gd` — add to it, don't start a new file beside it.**

When you verify a change, put the resulting checks there. `/verify` re-runs everything
in `test_dir` on every subsequent change, so a check written there is inherited by the
next session; the same check written into a scratch script or the transcript is worth
one run. Every test run prints `Suite: N test script(s) in <dir>` next to
`Assertions: M executed` — that pair is how much checking previous sessions left you.

Split by **what the check needs**: anything requiring a live playing game (real input
over time, physics, a tween landing, a scene mid-transition) stays a `/verify` Phase 4
bridge check. Everything else — pure logic, resources, data tables, and any layout
`_T.instantiate_ui` can resolve — belongs in `test_dir`.

**Writing them.** Alongside `_T.assert_*`, use
`await _T.instantiate_ui(scene, Vector2i(w, h))` / `_T.free_ui(node)` for anything
`Control`-shaped: headless pumps no frames, so without it `size` stays `(0, 0)` and
`@onready` vars never initialize. Test methods may `await`. **Always read stderr** — a
runtime error inside a test aborts only that method and returns `""` for a `-> String`
test, which is identical to a pass. `[ERR]` lines are the only signal.

**Testing "does this text fit its box"?** `Label.get_minimum_size()` returns ~1px on
any Label with `clip_text` or a non-default `text_overrun_behavior` — it reports the
clip stub, not the text, so the obvious width assertion passes unconditionally on
exactly the labels that need it checked. Use `_T.text_width(label) -> float` instead;
it measures through the label's own resolved theme font.

### DEVELOPMENT RULE (REQUIRED)
After **any** gameplay, script, or scene change, run **`/verify`** before considering
the work complete — don't wait for a commit request. Headless gates need no running
game; run them anytime:

```bash
python tools/name_check.py                                       # names only — no engine at all
godot --headless --path . --script res://tools/lint_project.gd   # UID + scene + dup-id + shader lint
python tools/run_tests.py                                        # unit tests (test_dir) — NOT the bare .gd
godot --path . --script res://tools/capture.gd -- --scene res://ui/hud.tscn --out shot.png
```

**Run `run_tests.py`, not the bare `run_tests.gd`.** A test that aborts mid-method
after already running one real assertion is reported `[PASS]` by `run_tests.gd` itself
— the aborted coroutine's return value is coerced to `""`, identical to a genuine pass,
and `[VACUOUS]` only catches zero assertions. `run_tests.py` wraps it, catches the
`SCRIPT ERROR` the return value can't carry, and fails the run even when `run_tests.gd`
reported `ALL TESTS PASSED` (0.27.0, gh#27). Same flags via `-- ...` passthrough.

**Lint flags** (after `--`): `--strict` (warnings fail the run), `--baseline-write PATH` /
`--baseline PATH` (split findings into `NEW` vs `PRE-EXISTING` against a saved snapshot —
the number that means "this change" rather than "all repo debt"), `--no-orphans` (skip the
advisory unreferenced-function pass, on by default since 0.21.0), `--no-shaders` (skip
compiling every `.gdshader` and embedded `Shader`).

**After adding a new `class_name` file (or a new `.tscn`/`.tres`), run
`godot --headless --path . --import` once before the next lint/test pass.** The
class cache is built by import; until it is, every script that references the new
class fails to compile with `Could not find type "X"` — and it cascades into files
you did not touch, reading like a broad regression. Lint's `stale class cache` hint
names the fix after the fact; this is the note that says to do it *before*
(`/verify` runs `import_check.py` for you; a bare lint does not). Also mint a
`.uid` for a new `.gd`: `python tools/devtools.py new-uid --write path/to/file.gd`.

**Exit codes are `0` pass / `1` findings / `2` the runner couldn't run.** A `2` means
you verified nothing — not that the code is clean. Redirect to a file and read it back;
the Windows Godot build often prints nothing to the console, so a failed run looks like
silent success.

**Read the denominators, not just the exit code.** `Total: 0 | ALL TESTS PASSED` is
this harness's worst failure mode. Every test run prints `Selected: N of M discovered`,
`Autoloads: N of M ready`, `Assertions: N executed` and `Suite: N test script(s)`; lint
prints `Shaders: N of M compiled OK` (`Shaders: none found` means there are none, not
that they passed), `UIDs: OK` (no stale `uid=` **and** no `.gd` missing its `.uid`
sidecar) and `Orphans: N of M public function(s) ... have no live reference` (advisory,
never gates — but a public method whose only caller is nothing is a feature that cannot
run; read the `WARN:` lines it prints, especially for a method you just added). A selector matching nothing, and a suite with no `test_*` methods, are both
exit `2`. A test returning pass having executed none of its own `_T.assert_*` calls
prints `[VACUOUS]` and fails — usually a loop over an empty collection, so fix the
data, not the test.

**`name_check.py` is the only gate safe to run in parallel** — it opens no project and
writes nothing to `.godot/`, so N agents can run it at once and it works in a fresh
worktree where lint reports a thousand bogus `not declared` errors and still exits `0`.
**But a clean `name_check` is not a compile.** It resolves names; it does not
type-check. `var kids := root.get_children()` on a bare `Node` is a hard parse error
that `name_check` reports clean, because every name in it resolves. Only
`import_check.py` and `lint_project.gd` see that class, and neither is parallel-safe.
If `name_check` was the only gate you could run, hand the work back saying that — not
"verified". It prints this itself as a `NOT COVERED:` line. If it prints
`engine index: NONE` the engine-name half was **skipped, not passed**; run
`python tools/name_check.py --refresh-api` once. `--require-compile FILE [FILE...]`
closes the gap for named files without losing parallelism — one `godot --check-only`
per file, verified read-only against `.godot/` — but needs the project imported once
already, or a cross-file `class_name` false-positives as unresolved.

**`capture.gd` must NOT be run headless** — note the missing `--headless` above.
Headless has no renderer, so it exits `2` naming the fix rather than writing a blank
PNG. Use `--frames N` (default 3; **two is the floor** for `Control`s). For a *live*
session mid-play use the bridge's `screenshot` verb instead.

Flags for all of these are in `REFERENCE.md`.

### The bus: driving the running game

Launch first: `python tools/devtools.py launch` (or `godot --path . --mute &` then
`sleep 5 && python tools/devtools.py ping`).

Measured across real sessions: 1192 verb calls used 25 of ~48 verbs, the top ten were
92% of all calls, and `get-state` alone was 44%. Those are below. **The rest are in
`REFERENCE.md`** — or run `list-commands`, which discovers generic and project verbs at
runtime and prints each verb's arg keys (`place_plant  args: plant, x, y` — a key not
listed is silently ignored; `--offline` parses the scripts statically with no game running).

| Verb | Use |
|---|---|
| `get-state --node PATH [--property N ...]` | Read a node's properties. **Always pass `--property`** — an unfiltered `Label` is ~120 keys. Repeatable; dotted paths walk into Resources, Dictionaries and struct components (`slot_data.item.name`, `position.x`, `modulate.a`); unknown names are reported, not dropped |
| `scene-tree [--root PATH] [--depth N]` | Discover root scene name + node paths (don't assume names). Each node carries `script` and `scene_file`, so a changed file maps to the node that runs it. Ends with `N node(s)` on stderr — don't `grep -c` the JSON, each node prints several lines |
| `find-nodes [--class C\|--group G\|--method M] [--where N=V] [--property N] [--call M]` | Locate nodes by what they *are*, not where they sit. `--class` takes a script `class_name` too (subclasses included) and **fails on a name that is neither**; `--where` is repeatable and takes dotted paths; `--call METHOD` reads a zero-arg getter beside each hit, so an auto-named node is found and read in one trip. Usually the right verb for identifying one node in a large tree |
| `run-method --node PATH --method N --args "[...]"` | Call a method — preferred over `set-state` when a signal should fire. Reports `returned_null` + `declared_return`, so a `-> void` that ran is distinguishable from a call that aborted |
| `set-state --node PATH --property N --value V` | Set raw property (bypasses setters/signals) and print the read-back. A JSON array is rebuilt as the property's typed Array (`Array[StringName]` works). Dotted paths write through — note that mutates the **Resource**, so a shared material changes for every node using it. Write `--value=-200,-296` with an `=` when it starts with `-` |
| `node-bounds PATH` | Exact **screen-space** position/size — deterministic layout ground truth, ancestor `CanvasLayer` transforms applied. Prefer this over a screenshot |
| `press --node PATH` | Emit `pressed` on the nearest `BaseButton` at or under PATH — a real press with no screen coordinates to guess. A disabled button is reported, not silently "pressed" |
| `input press`/`release`/`tap` ACTION, `input state [ACTION ...]` | Simulate input actions; `state` polls what the game is actually seeing. `tap` releases on the NEXT frame and reports `pressed_during`/`pressed_after` |
| `screenshot [--region X,Y,W,H] [--hide NODE]` | Visual check only (`sleep 0.5`–`1` after a state change). Crop and hiding happen game-side, so a capture is reproducible |
| `ping` / `quit [--kill]` | Confirm the bridge is live (reports `bus_dir`, `user_dir`, and `tree is PAUSED`; **the bridge answers while paused**, so pause menus are verifiable) / shut down, **exiting 1 if the process survived** — or if any earlier launch of this project is still alive (`.devtools/launched.jsonl`); `--kill` terminates exactly those pids, never by image name. On Windows the printed fallback is `Stop-Process -Force -Id` (PowerShell) — `taskkill /F` through Git-Bash becomes `F:/` and fails |

Worth knowing exists, reach for `REFERENCE.md` when you need them — `validate-ui`,
`reachable-ui`, `performance`, `validate --scene`, `validate-all` (all folded into
`findings`, and worth calling alone only to re-check one thing after a fix);
`first-frame` (visible `CanvasLayer`s in paint order, the topmost on-screen Control,
paused state, cursor mode — "what IS the screen showing", not "is anything wrong");
`save-ui-baseline`, `ui-snapshot`, `ui-snapshot-diff` (structured UI state vs baseline);
`aabb` (3D world-space bounds, `top_y`/`bottom_y`), `node-bounds`' 3D counterpart;
`look-at --node PATH` (points the active Camera3D, or `--from-node`, at a target's
AABB centre — orientation only, never repositions);
`step-time [--then-pause]` (`--then-pause` freezes the tree the moment the step lands,
so step + read pairs carry no ambient drift), `set-game-speed` (refuses a scale below
0.01 — that is a freeze, not a speed; use `pause`/`unpause` for a real freeze),
`wait-frames` (advance time deterministically), `pause`/`unpause` (sets
`SceneTree.paused` directly, bus keeps answering — catch a sub-second effect, poll for
the moment, pause, then inspect at no rush);
`project-settings [--filter PREFIX|--name KEY]` (ProjectSettings as the RUNNING game
sees them — did the value written to `project.godot` actually land?);
`contained-in --node PATH --within PATH` (is this Control's box inside that panel's;
exit 1 with the per-side overhang — `findings` reports the same as `ui_escapes_panel`
for a sibling panel);
`raycast --from X,Y[,Z] --to X,Y[,Z]` (2D or 3D by arity; refuses a 2D ray on a
3D-only tree), `sample-pixels`, `canvas-scale`, `set-resolution`;
`fire-entry-point NAME` (fires a named `entry_points` entry on demand — switches
scene first if one is configured, then calls the node/method with its `args`);
`tilemap-cells`, `tilemap-region`; `curve` (a pure method over a range as one read);
`input clear`, `input list`, `input sequence FILE`, `key NAME`,
`mouse-move --relative DX,DY [--steps N]` (a real `InputEventMouseMotion` — the
only way to drive mouse-look; a captured cursor makes your physical mouse a second
input source between commands);
`reload res://path` (re-read an edited shader/.tres/texture into the running game —
holders see it, no relaunch);
`touch press`/`release`/`drag`/`clear`/`list` (the only way to exercise multi-touch);
`set-feature --touchscreen` (makes touch UI show itself on desktop — set it *before*
the scene loads); `clear-nodes --via-method` (free nodes through the game's own removal
path); `scripts-seen`, `new-uid`, `logs`, `harness-version [--client]` (also says when a newer
harness is already on this machine than this project runs; `--client` never opens the
bus — use it for a log entry's `harness:` field), `cmd <verb>`.

#### Gotchas
- **One command at a time, enforced.** One command file / one result file. Requests
  carry an id the game echoes, so a crossed reply errors instead of silently returning
  another request's data. A command sent mid-handler waits on disk and runs after —
  deferred, never dropped, never concurrent. So a timeout can mean *your command never
  started*; the error says which, naming the verb hogging the bus. For parallel
  instances use `launch --isolated`, which isolates the **bus only**
  (`GODOT_DEVTOOLS_BUSDIR` / `--devtools-busdir`) — `user://` (saves, screenshots, UI
  baselines, `.godot/`) stays **shared, with no way to isolate it**: Godot has no
  `--user-data-dir` flag and honours no `GODOT_USERDATA` env var (gh#28 — an earlier
  version of this line implied setting one would isolate it; it does nothing). Parallel
  `--isolated` instances can still collide on saves/screenshots/UI baselines.
- **`game not running` in ~2s** means a dead game *or* the wrong `user://` dir; the
  error can't tell them apart. Check `--userdata` before assuming a crash.
- **Assert transforms on `data.transform`, not the property dump.** Godot hides
  `position`/`scale`/`rotation` on container children, so a scale animation on a
  `VBoxContainer` child is invisible to a property read while working on screen.
- **A run that never changes is broken, not passing.** Check the `status` field.
- **`performance` FPS is a mean over a window** (`--frames N`, default 30, with min/max
  and `STILL SETTLING` when the halves disagree). Read after `wait-frames 60`+ past a
  settings change; a single frame's rate is not a measurement. Its `Total nodes …
  growth +N` is the leak signal the orphan count cannot see (in-tree accumulation);
  `--by-type` names which classes grew.
- **A headless gate never touches the bus.** `lint_project.gd` / `run_tests.gd` bring
  the autoload up passive: safe to run while another session drives this game.
- **A worktree sibling shares your bus.** Same project name → same `user://`. `ping`
  prints the answering game's `project` path and the client refuses to send to a game
  from another checkout — if you see `DIFFERENT checkout`, quit it or `launch --isolated`.

### Add project-specific debug verbs
Register domain verbs in `res://devtools_ext/commands.gd` (loaded after generic verbs,
last-writer-wins). Each handler returns exactly `{success:bool, message:String, data:Dictionary}`.

```gdscript
func register_commands(dev: Node) -> void:
    dev.register_command("spawn_enemy", func(args):
        return {"success": true, "message": "ok", "data": {}})
```

Reach them via `cmd spawn_enemy --args '{"count":3}'`. Use these for setup/trigger steps
the generic primitives can't express.

**Attach liveness to every reply.** Register one status provider and its Dictionary is
merged into *every* response as `status`. Without it, a session that has silently died
or frozen keeps answering with well-formed zeros, which looks exactly like a clean pass.

```gdscript
    dev.register_status_provider(func(_args):
        var p = dev.get_tree().get_first_node_in_group("player")
        return {"player": "absent"} if p == null else {"player": "dead" if p.is_dead else "alive"})
```

Pair it with verbs that can *undo* the dead state (a `revive_player` that clears the flag
and leaves the death state). Restoring a health value is usually not enough — the death
flag and state machine outlive it. And **a setter verb must leave the game in a state the
game itself can reach**: a `set_combo` that sets the count but not the combo window tests
nothing the moment the readout starts fading on that timer.

**A `class_name X extends RefCounted` static-utility script (no node ever carries its
script) is invisible to `scripts-seen`/`reach` no matter how much of it ran** — call
`DevTools.mark_script_reached("res://path/to/it.gd")` once from each real entry point
(static context included; DevTools is an autoload, reachable by name from anywhere).

### DEVTOOLS LOG (REQUIRED)
At the end of **every** response, append an entry to `log-devtools.md`. Two required
halves: **was using the harness worth it**, and **what was missing from it**. If nothing
was missing, write one explicit "no gaps this turn" line — that is what makes an absent
gap distinguishable from a forgotten log. The `Value:` block is required either way.

```markdown
## YYYY-MM-DD — <what this response did>

- Value: **<warranted|overkill|insufficient|inconclusive>** — <one sentence of why>
  - Expected: <what you predicted runtime would reveal, written before running it>
  - Got: <what it actually told you — quote the assertion, not "it passed">
  - Found: <what this run caught that reading the diff would not have, or "nothing">
  - Cheaper: <the cheapest thing that would have given the same confidence>

- Gap: **<what was missing>** — <the command run, the output it gave, the workaround used>
  - [G-001] status: open | seen: 1 | harness: 0.7.0
  - Improvement: <the smallest change that would have closed it>
```

`warranted` = runtime produced a claim the diff could not (name it). `overkill` =
everything passed and confirmed what was already known. `insufficient` = it ran but
never reached or asserted what mattered (**reach decides this, not your impression**);
file the gap. `inconclusive` = aborted or too small to judge.

**`overkill` is a useful entry, not an admission** — and it is the one that goes
unwritten, because a run that passed feels like a run that helped. `Cheaper:` must name
something concrete ("reading `player.gd:40-60`", "lint alone, 4s", "nothing, this needed
the running game"). **`Found:` counts a bug you fixed mid-run** — every other field
describes how the run *ended*, so a defect surfaced at minute four and repaired by minute
six vanishes otherwise. "nothing" is the honest answer for a run that confirmed what you
already knew.

The `[G-NNN]` line is required: ids are stable and never reused, `status:` is
`open`/`fixed`/`wontfix`, `harness:` comes from `python tools/devtools.py harness-version --client`.
**Hitting a known gap again bumps its `seen:` count** — don't file a second entry. Quote
real output; a gap without evidence can't be acted on. Entries here get upstreamed into
`godot-selftest-harness` itself, so a gap logged here becomes a fixed feature for every
project using it.

### The verify ledger
`/verify` Phase 5 appends one line per run to `.devtools/verify-runs.jsonl` — including
the clean ones, which is the point. The gaps log records what the harness couldn't do;
the ledger is the denominator it lacks.

The field worth reading is **reach**: the diff intersected against the `script`/
`scene_file` paths in a `scene-tree` snapshot, so it says whether a run actually loaded
the code it claimed to verify rather than asking the run to grade itself. A pass on an
unreached file is a statement about the diff, not the running game — report it that way.
Each row also carries the `value` verdict and **`found`** (`[]` when it caught nothing).
A Phase 4 check that failed and was fixed keeps `"result": "fail"` with
`"fixed_in_run": true`; rewriting it green erases the run's own evidence.
`python tools/verify_ledger.py stats` reads the history back. Commit the ledger.

### Config
`res://addons/godot_selftest/devtools_config.json` holds thresholds and hooks:
`fps_min`, `orphan_growth_max` (gate on this — `orphan_max: 0` is unreachable),
`safe_area_inset`, `mute`, `main_scene`, `entry_hook {node_path, method}` (fires
**automatically, once**, shortly after launch — advances past a menu into the playable
scene; check `ping`'s `entry_hook_status` if it does not seem to have fired: `fired` /
`not_configured` / a specific error, never silent), `entry_points` (named alternates
reached **on demand** via `fire-entry-point NAME`, not automatically), `test_dir`,
`scan_root`, `hud_layer_name`, `name_check_extra_types` (types a GDExtension registers at
runtime, which the static checker cannot see) and `name_check_ignore` (path prefixes).

### Token-aware
- Prefer `findings` over a hand-built sweep of individual verbs; prefer `node-bounds` /
  `ui-snapshot` over `screenshot`. Only open a screenshot PNG when a genuine **visual**
  regression is suspected.
- **A `GEOMETRY CAVEAT` / `[HEADLESS geometry]` tag means the number is a headless
  measurement**: the window is 64×64 there, so anything the game positions from
  `get_window().size` sits off-viewport headless and centred for a player. Confirm an
  off-screen verdict windowed before reporting it as a defect.
- **`TREE IS PAUSED`** on `ping` / `performance` means every metric describes a game
  that is not stepping — call `unpause` if you paused it, or set `entry_hook` to
  advance past whatever's pausing it automatically on launch, before believing them.
- `get-state` dumps ~120 keys for a `Label` — pass `--property NAME` (repeatable).
- `findings` / `validate-ui` keep the records of the last non-clean run at
  `user://findings_last.json` (path printed when the count is non-zero) — a transient
  is diagnosable after the frame that produced it is gone.
- A live check that touches persisted state (a key whose handler saves) writes the
  developer's real `user://` file — `--isolated` does not isolate `user://`. `quit`
  names what the run changed; `launch --isolated --snapshot-userstate` makes `quit`
  put it back. A save left changed shows up as failing headless tests later.
- `_T.assert_margin(values, threshold, margin, recorded)` gates a tuned constant on the
  corpus items sitting near it — use it instead of hand-rolling a sweep.
- `press` emits `pressed` without moving the mouse: an open tooltip stays open and can
  appear in a screenshot taken straight after. `mouse-move` first if the picture matters.
- Run `/verify` **inline**; don't wrap routine validation in subagents/workflows.
- On Windows, probe Python by running it (`python3` may be a Store alias stub that
  exists and refuses to run).

### (Re)install
Run **`/scaffold-godot-harness`** to install or refresh the harness. Re-running it also
refreshes this very section in place (it never duplicates it).
<!-- END godot-selftest-harness -->



