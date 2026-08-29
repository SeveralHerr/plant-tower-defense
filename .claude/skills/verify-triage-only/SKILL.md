---
name: verify-triage-only
description: Decide how much runtime verification a change actually needs — the godot-selftest-harness /verify workflow's own Phase 0.5 triage, extracted so it can be answered without loading that skill's full six-phase instruction set. Use before running /verify (or godot-selftest-harness:verify) on a small or uncertain diff, or whenever you're about to reach for the full workflow and aren't sure it's warranted. For tiers that resolve to "nothing" or a headless-only/lint-only pass, this skill runs that pass itself; only a genuine "full run" verdict should escalate to godot-selftest-harness:verify.
---

# Verify triage, standalone

The full `/verify` skill is long because it documents six phases. Most diffs never need
more than one of them. This is that one phase, on its own, so answering "does this need
the whole thing" doesn't cost loading the whole thing.

## 1. Resolve Python and Godot once

```bash
PY=""; for c in python3 python py; do "$c" -c "import sys" >/dev/null 2>&1 && { PY="$c"; break; }; done
GODOT_BIN="${GODOT_BIN:-}"
[ -z "$GODOT_BIN" ] && GODOT_BIN="$("$PY" -c "import json; print(json.load(open('addons/godot_selftest/devtools_config.json')).get('godot_bin',''))" 2>/dev/null)"
```

## 2. Classify the diff

```bash
git status --porcelain --untracked-files=all
git diff HEAD --stat
```

Check the mechanical tier-(d) case up front — an empty `main_scene` is a state, not
something the diff shows:

```bash
grep -q '^run/main_scene=' project.godot || "$PY" -c "import json,sys; c=json.load(open('addons/godot_selftest/devtools_config.json')); sys.exit(0 if c.get('main_scene') else 1)" || echo "TIER (d): no main scene - runtime unreachable"
```

| Diff is… | Tier | What to run |
|---|---|---|
| (a) Nothing Godot loads: only docs/`.md` outside code, `.beads/`, `log-devtools.md`, CI/git files | **Nothing** | Stop here. Say "nothing to verify" — no ledger row, no log entry. |
| (b) Only comments/docstrings inside `.gd`/`.tscn`, or `.md` in code dirs | **Lint-only** | Step 3's name gate + import gate + lint. Skip tests and runtime. |
| (c) Only `static func`s / `const` tables an existing unit test covers — or an instance method whose changed call site is already driven by a hosted-scene test in the headless suite (name it) | **Headless-only** | Step 3 in full (adds tests). Skip runtime; name which test stood in for it. |
| (d) Project has no `run/main_scene` (project.godot) and no `main_scene` in config | **Headless-only (forced)** | Step 3 only. Report runtime as `unreached: no main_scene`, not skipped-by-choice. |
| (e) The diff is a skill doc / `REFERENCE.md` correction / gap report **written from** a live session that already ran | **Experiment** | Whatever phases that session actually needed — already done if you're seeing this after the fact. Don't re-run for the doc alone. |
| (f) Only project-owned tooling outside `res://` (a `tools/*.py` checker nothing in `res://` imports) | **Tooling-only** | That tool's own tests/self-check. No Godot phase applies. |
| Anything else — instance methods, signals, scenes, exports, node paths, config | **Full run** | Escalate: invoke `godot-selftest-harness:verify`. |

When in doubt, pick **Full run**. Tier (c) requires you to have actually checked the
covering test exists and exercises the changed function — not assumed it.

## 3. Run the cheap tiers here, without escalating

Name gate — cheap, safe in parallel, works even in a never-imported worktree:

```bash
"$PY" tools/name_check.py; echo "exit=$?"
```

Import gate (guard `project.godot` — this step can rewrite it):

```bash
cp project.godot /tmp/project.godot.bak 2>/dev/null || true
"$PY" tools/import_check.py; echo "exit=$?"
diff /tmp/project.godot.bak project.godot >/dev/null 2>&1 || echo "WARNING: --import rewrote project.godot — diff before staging"
```

Lint:

```bash
"$GODOT_BIN" --headless --path . --script res://tools/lint_project.gd > /tmp/lint.log 2>&1; echo "exit=$?"
tail -5 /tmp/lint.log
```

Tests (tier c/d only; skip for lint-only):

```bash
"$PY" tools/run_tests.py --godot "$GODOT_BIN" > /tmp/tests.log 2>&1; echo "exit=$?"
grep -a "Total:\|Suite:\|Assertions:" /tmp/tests.log
```

Exit codes throughout: `0` pass, `1` findings — stop and report, `2` the runner itself
couldn't run — you verified nothing, say that plainly, don't read it as clean.

## 4. Report, and stop

State the tier picked and why, the gate results, and — for (c)/(d) — which test stands
in for runtime. Do **not** write a `.devtools/verify-runs.jsonl` row or a `log-devtools.md`
entry for tier (a); do for the others, using the same schema `godot-selftest-harness:verify`
Phase 5/6 documents (a `verdict`, `found: []` unless the lint/test gate actually caught
something, and the tier name in `cheaper_alternative` if you skipped runtime).

**Only escalate to `godot-selftest-harness:verify` when the tier above says "Full run",
or when a (c)/(d) call's own gates find something that needs a live game to explain.**
Everything else, this is the whole answer.
