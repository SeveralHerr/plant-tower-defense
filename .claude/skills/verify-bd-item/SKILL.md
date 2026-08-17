---
name: verify-bd-item
description: Take one bd issue from claim to commit — implement, run the gates, drive it at runtime, record the verify ledger row, log the harness verdict, commit, close. Use whenever you are working a bd issue in this project's loop, and especially when you are running the gates by hand instead of through /verify, because that is when the ordering constraints below are unenforced and get dropped.
---

# One bd item, claim to close

This sequence runs several times per cycle and every step is a place to silently drop
something. It was named as a missing skill twice before it was written, and in the
interval **cycle 48 dropped a step**: the ledger row was recorded after the commit, so
`reach` came back `0/0` and a `warranted` row carried no evidence for its own verdict.
`verify_ledger.py stats` currently reads `runs: 61 (partial 3 | pass 52 | unknown 6)` —
those six unknowns are this failure, already in the record.

`/verify` enforces the order when you run it. This skill is what you follow when you
don't.

## The order, and why it is an order

```
claim  →  implement  →  headless gates  →  runtime  →  LEDGER ROW  →  commit  →  log  →  close
                                                        ▲
                                    everything left of the commit must happen left of it
```

**Three things are order-dependent and only one of them announces itself:**

1. **The ledger row lands before the commit.** `reach` is the diff intersected against
   what the running game loaded. After a commit there is no diff, so the row is `0/0` by
   construction and reads exactly like a run where the game never came up. `verify_ledger`
   will even gloss it as *"a real zero: every changed file is excused from the
   denominator"* — the benign reading of an ambiguity it cannot resolve (gh#44).
2. **The scene-tree snapshot is taken before `quit`.** It cannot be reconstructed once the
   game exits, and without it the row has no reach at all.
3. **A suite count is taken on BOTH sides** of a rename, a refactor, or a dependency
   change. `554/554` after means nothing without `554/554` before — a pure rename is
   proved by the count matching, not by the tests passing. This one never announces
   itself, because the "after" number looks complete on its own.

## The sequence

### 1. Claim

```bash
bd show <id>            # read the acceptance criteria before writing code, not after
bd update <id> --claim
```

If the issue turns out to be already-done or wrong, close it with a reason rather than
building to a stale description. That has happened here — a bead was claimed and worked
before the code got read, and the feature already shipped in full.

### 2. Implement, then take the *before* count if this is a refactor

```bash
python tools/run_tests.py --godot "$GB"    # only if renaming/refactoring — this is the baseline
```

### 3. Headless gates

Resolve the binary once; the shell does not persist between calls:

```bash
GB=$(python -c "import json;print(json.load(open('addons/godot_selftest/devtools_config.json')).get('godot_bin',''))")
python tools/name_check.py                                          # names; parallel-safe; NOT a compile
python tools/import_check.py                                        # class cache + parse errors
"$GB" --headless --path . --script res://tools/lint_project.gd > lint.log 2>&1; echo "exit=$?"
python tools/run_tests.py --godot "$GB" > tests.log 2>&1;           echo "exit=$?"
grep -E "Suite:|Assertions:|Total:" tests.log
```

**Read the denominators, not the exit code.** `Total: 0 | ALL TESTS PASSED` is the worst
failure mode here. `Suite: N test script(s)` and `Assertions: M executed` are what say the
run had anything in it. Exit `2` means you verified nothing — it is not a pass.

If a new `class_name`, `.tscn` or `.tres` was added, `import_check.py` must run before
lint or you get a cascade of `Could not find type "X"` in files you never touched.

### 4. Runtime

```bash
python tools/devtools.py launch --snapshot-userstate 'highscore.save'   # restores the real save on quit
sleep 6
# ... drive the change; see read-a-moving-value before concluding from any live read ...
python tools/devtools.py scene-tree        > .devtools/tree-phase4.json
python tools/devtools.py --json scripts-seen > .devtools/scripts-seen.json
python tools/devtools.py quit
```

`--snapshot-userstate` is not optional when anything you touch can persist: `--isolated`
does **not** isolate `user://`, and a save left changed shows up as failing headless tests
several cycles later. `quit` reports what the run changed; confirm it says no file changed,
or that it restored what did.

### 5. The ledger row — **before the commit**

```bash
python tools/verify_ledger.py reach --scene-tree .devtools/tree-phase4.json \
    --scripts-seen .devtools/scripts-seen.json | grep '^worktree'
```

Write `run.json` with the fields that carry evidence, then:

```bash
python tools/verify_ledger.py record --scene-tree .devtools/tree-phase4.json \
    --scripts-seen .devtools/scripts-seen.json --run run.json
```

Two things it will tell you, both worth acting on rather than ignoring:

- `warranted with no Phase 4 checks recorded — the claim that earned it is not in the row`
  means the verdict is asserted and unevidenced. Put the runtime checks in the row.
- `reached 0/0 changed file(s)` after a clean tree means you are too late. **Do not fix
  this by rewriting the row.** A ledger whose embarrassing rows get corrected is not a
  record; note it and fix the order next time.

`found: []` is the honest value when the run caught nothing, and `found` counts a bug you
fixed mid-run — every other field describes how the run *ended*, so a defect surfaced at
minute four and repaired by minute six vanishes otherwise.

### 6. Commit — one item, one commit

Never batch. The commit message should say what the runtime run established that the diff
could not; if the answer is "nothing", the verdict is `overkill` and that is a real
answer, not an admission.

### 7. Log the harness verdict

Find the next free id first — ids are stable and never reused:

```bash
grep -o '\[G-[0-9]*\]' log-devtools.md | sort -u | tail -3
python tools/devtools.py harness-version --client     # for the `harness:` field
```

Append the entry, then confirm it parses and the ledger agrees:

```bash
python tools/check_devtools_log.py; echo "exit=$?"
python tools/gap_ledger.py --open | tail -3
```

**Hitting a known gap again bumps its `seen:` count** — do not file a second entry. And
before filing upstream, re-check the finding against the version in the plugin cache, not
the one the project runs: cycle 48's second gap was narrowed by that check and would
otherwise have been a false alarm.

### 8. Close

```bash
bd close <id> --reason="<what shipped, and the commit sha>"
```

The reason is read later by someone deciding whether a related bead is still real. "Done"
is not a reason.

## What this skill does not cover

It does not decide **whether** the runtime pass was worth running — that is Phase 0.5
triage in `/verify`, and a docs-only diff should not reach step 4 at all. Nor does it
judge the change; it moves one item through the machine without dropping a step. The
judgement lives in the `Value:` verdict you write in step 7, and `overkill` is the entry
that goes unwritten.
