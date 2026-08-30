# workflow

The development loop — pre-flight, `bd ready`, do the items, run the gates, reflect on
the workflow, refill the queue, repeat — lives in `.claude/cycle/` and runs as `/cycle`.
It is a loop that does not end until the user stops it. `SKILL.md` there is the loop
itself; `references/why.md` is the evidence behind each step, `references/gates.md` the
checkers, `references/fan-out.md` the parallel form. Every rule about how a cycle is
worked lives in that directory and nowhere else: edit it there, not here. This block is
only the pointer, and it is mirrored verbatim in `AGENTS.md`
(`python tools/mirror_check.py` checks, `--fix` regenerates the mirror) so a reader of
either file finds the loop.

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

There is no build step and no package manager. Everything runs through the Godot binary
named by `godot_bin` in `tools/gates_config.json` — **read it from there**; a bare `godot`
is not on PATH on the machine this project is developed on, and the Gates section below
spells its examples `godot` for portability rather than because that works here.

```bash
GODOT=$(python -c "import json;print(json.load(open('tools/gates_config.json'))['godot_bin'])")

python tools/check_all.py --quiet                                  # every parallel-safe checker, ~20s
python tools/run_tests.py --godot "$GODOT"                         # the unit suite, ~3 min
"$GODOT" --headless --path . --script res://tools/lint_project.gd  # UID + scene + dup-id + shader lint
python tools/import_check.py --godot "$GODOT"                      # after adding a class_name/.tscn/.tres
"$GODOT" --headless --path . --script res://tools/render_svg.gd    # art_src/*.svg -> assets/sprites/*.png
```

`run_tests.py` takes about three minutes on the full suite, which is longer than a default
command timeout — pass a longer one, or narrow with `-- --file <name>.gd` / `-- --filter
<substring>` while iterating. See the Gates section below for why it is `run_tests.py`
and never the bare `run_tests.gd`.

## Architecture Overview

A single-scene 2D tower defense. `game/game.tscn` hosts `Game`, which owns a `Board`
(14x9 grid of 64px cells, grass with a dirt road cut through it), a `SeedBank`, a
`WaveDirector` and a `Hud` on its own `CanvasLayer`. Plants are `Node2D`s parented to
`Entities`, one script per kind extending `Plant`; pests are one `Pest` script with a
`SPECIES` table and trait flags rather than a subclass each. Data that is not behaviour —
the plant catalogue, the wave table, milestones, skins, mutations — lives in
`class_name X extends RefCounted` static tables so it is assertable with no scene tree.

Art is authored as SVG in `art_src/` and rasterised to `assets/sprites/` by
`tools/render_svg.gd`; the SVGs never ship. `art_src/STYLE.md` is the contract, enforced
by `test/unit/test_sprite_style.gd` (rendered pixels) and `tools/svg_style_check.py`
(source, parallel-safe).

## Conventions & Patterns

**Comments carry the WHY.** Production files are heavily commented with the reasoning and
the refused alternative, not with what the line does. A constant that was tuned says what
it was tuned against; a shape that was chosen says what shape was rejected and why.

**A cue is a named sibling node, not a branch in somebody's `_draw`.** Seven of the nine
plant scripts override `_draw`, so anything painted in the base class appears on two kinds
and silently not on the rest. `SelectionMarker` and `SportMark` are the pattern. Name the
node — the tests address by path, and `@Node2D@131` is a path nothing can be written
against.

**Geometry and animation go in a pure `static func`.** Headless executes no `_draw` and
pumps no frames, so a shape assembled inside `_draw` is a shape no test can reach. See
`.claude/skills/assert-an-animation`.

**Derive a list rather than typing one.** `.claude/skills/derive-the-list`. If you are
about to hand-write a table of ids, paths, colours or cases, check whether the source of
truth can produce it.

**After any balance edit** (wave tables, `Game.DIFFICULTIES`, plant prices/reach), run the
playtest sweep — `test/unit/test_playtest_sweep.gd`, part of the standing unit suite.
See `docs/playtest-sweep.md` for what it checks and how to run its full (slow, gated)
matrix on demand.

## Gates

No engine-driven self-test harness: the gates are this repo's own, and every one of them
is either a static checker under `tools/` or a script the engine runs headless.

```bash
GODOT=$(python -c "import json;print(json.load(open('tools/gates_config.json'))['godot_bin'])")

python tools/check_all.py --quiet                                  # every parallel-safe checker, ~20s
python tools/run_tests.py --godot "$GODOT"                         # the unit suite, ~3 min
"$GODOT" --headless --path . --script res://tools/lint_project.gd  # UID + scene + dup-id + shader lint
python tools/import_check.py --godot "$GODOT"                      # after adding a class_name/.tscn/.tres
```

**Run `run_tests.py`, not the bare `run_tests.gd`.** A test that aborts mid-method after
already running one real assertion is reported `[PASS]` by `run_tests.gd` itself — the
aborted coroutine's return value is coerced to `""`, identical to a genuine pass, and
`[VACUOUS]` only catches zero assertions. `run_tests.py` wraps it, catches the
`SCRIPT ERROR` the return value cannot carry, and fails the run even when `run_tests.gd`
reported `ALL TESTS PASSED`. Same flags via `-- ...` passthrough.

**Read the denominators, not just the exit code.** `Total: 0 | ALL TESTS PASSED` is the
worst failure mode here. Every test run prints `Selected: N of M discovered`,
`Autoloads: N of M ready`, `Assertions: N executed` and `Suite: N test script(s)`; lint
prints `Shaders: N of M compiled OK` and `UIDs: OK`; `check_all.py` prints how many of the
discovered checkers ran. Exit codes are `0` pass / `1` findings / `2` the runner could not
run — a `2` means you verified nothing, not that the code is clean. The Windows Godot build
often prints nothing to the console, so redirect to a file and read it back.

**After adding a new `class_name` file (or a new `.tscn`/`.tres`), run
`python tools/import_check.py` once before the next lint/test pass.** The class cache is
built by import; until it is, every script referencing the new class fails to compile with
`Could not find type "X"`, and it cascades into files you did not touch. Also mint a `.uid`
for a new `.gd` — lint reports a missing sidecar.

**The same applies when somebody ELSE's work arrives — a merge, a pull, a lane you did not
write.** The cache is a property of the checkout, not of your diff, so a merge that lands a
new method on an existing class leaves it stale exactly as your own commit would. Measured
2026-08-29: a merge landed six new statics on `Pest`, and the next suite run reported
`Failed: 5` with `Invalid call. Nonexistent function 'chop_reach' in base 'GDScript'` —
against functions plainly present in `game/pest.gd`. Nothing about that reads as a cache
problem; it reads as a broken merge, and the first instinct is to go and fix code that is
already correct. **A failure naming a function you can see in the file is a stale cache
until `import_check.py` says otherwise.** Re-import, then re-run: it went to 1193/1193.

**Run `import_check.py`, not the bare `--import`, for the same reason as `run_tests.py`.**
`godot --headless --path . --import` exits `0` whether or not the scripts it just re-scanned
compile: the parse errors are printed and never returned, so "the class cache was
regenerated" and "the project still parses" are one exit code, and a broken game reports as
a clean import. It fails worst in exactly the case you ran it for — a `class_name` arriving
from a rebase or a branch switch — because the tool you ran to fix the cascade tells you it
succeeded. The wrapper runs the same import, captures both streams to `.gates/import.log`
(and creates `.gates/`, which a fresh worktree does not have), and quotes back the lines
Godot only prints on a real failure.

**`name_check.py` is the only gate safe to run in parallel** — it opens no project and
writes nothing to `.godot/`, so it works in a fresh worktree where lint reports a thousand
bogus `not declared` errors. **But a clean `name_check` is not a compile.** It resolves
names; it does not type-check. Only `import_check.py` and `lint_project.gd` see that, and
neither is parallel-safe. If `name_check` was the only gate you could run, hand the work
back saying that — not "verified".

**Where the checks you write live: `res://test/unit/`.** `tools/gates_config.json`'s
`test_dir` is what `run_tests.py` discovers; a check written anywhere else is worth one
run. Alongside `_T.assert_*`, use `await _T.instantiate_ui(scene, Vector2i(w, h))` /
`_T.free_ui(node)` for anything `Control`-shaped: headless pumps no frames, so without it
`size` stays `(0, 0)` and `@onready` vars never initialize. **Always read stderr** — a
runtime error inside a test aborts only that method and returns `""` for a `-> String`
test, which is identical to a pass. `[ERR]` lines are the only signal. For "does this text
fit its box", use `_T.text_width(label)`: `Label.get_minimum_size()` returns ~1px on any
Label with `clip_text` or a non-default `text_overrun_behavior`.

**Adding a checker under `tools/`.** `check_all.py` discovers by contract, not by filename:
a parallel-safe checker declares a `NOT COVERED:` line in its own source and honours the
exit-code contract; anything else must be listed in `NOT_A_CHECKER` or `NOT_PARALLEL_SAFE`
with a reason, or the run reports it UNCLASSIFIED and gates. See
`.claude/skills/house-static-checker`.

### Config
`tools/gates_config.json` holds `godot_bin`, `godot_version`, `test_dir`, `scan_root`,
`uid_check_ignore`, `name_check_extra_types`, `name_check_ignore`, and `fps_min` (the
game's frame budget, which `test_web_audio_output_latency_has_mobile_headroom` derives
its floor from). Gate scratch output — import and test logs, the `user://` snapshot
record — goes to `.gates/`, which is gitignored.
