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
confirm  →  claim  →  implement  →  headless gates  →  runtime  →  LEDGER ROW  →  commit  →  log  →  close
                                                                     ▲
                                                 everything left of the commit must happen left of it
```

**`confirm` comes before `claim` and is the cheapest step here.** Open the code the bead
says is missing, before writing a line — **and search the queue for the same question**
(`bd search "<a phrase from the description>"`). The code tells you whether the feature is
absent; only the queue tells you whether that absence is an oversight or a **decision**.
Cycle 84 claimed a bead asking for a weather readout on the top bar, having checked the
code and found none, and discovered mid-cycle that the same request had been filed in
cycle 17, measured, and refused — every candidate string overflowed the slot by 5-54 px and
the numbers were in the older bead's notes. Two minutes of `bd search` would have found it,
and the refusal is what pointed at the right surface. A bead is a claim about the repo made at some past
cycle, and the repo has moved: cycle 70 claimed `-6cqi` ("two cobs at different levels are
indistinguishable on the board"), read `corn_cobbler.gd`, and found the feature had shipped
twelve cycles earlier — along with a test enumerating every level pair. The remaining work
was the bead's *evidence* half, which is a different job from the one the title describes.
A bead that turns out to be done is a good outcome and a fast one; a bead re-implemented
because nobody looked is the expensive failure, and it looks like progress the whole time.

**And confirm the HELPER you are about to write, not only the bead's claim.** Three cycles
running, the thing about to be built already partly existed. Cycle 90's `-beq1` was shipped
by the cycle that filed it. Cycle 91's `-bxhg` said the notebook was the wrong shape for a
legend; `KIND_SHELF` had made it the right shape cycles earlier. Cycle 92 wrote
`page_for_kind` and then found `shelf_page()` — the same search over the same table, by a
different name, written first and for the same stated reason.

**And if the change grows a list something RENDERS, evaluate the layout functions at the
new size before writing a line.** Cycle 98 added a sixth plant to a five-plant catalogue: it
built the class, the art, the tests and the wiring, placed it on a real board and watched it
work — and then `findings` reported the side panel 167px off the right edge, because five
plant buttons already sat at exactly the 40px touch floor and there was no room for a sixth.

`Hud.plant_bar_layout(6)` is a pure function. Calling it costs one line and would have found
the wall before any of that existed. The file even predicted it — `PLANT_BAR_BOTTOM`'s comment
ends "the next plant runs into it" — so this was not hidden, it was just never asked.

The pattern generalises past that one function: a catalogue, a menu, a legend, a key list and
a shop rack are all lists something lays out, and all of them have a pure sizing function in
this codebase precisely so the question can be asked cheaply. **Ask it at N+1 first.** The
answer is arithmetic, it is free, and it decides whether the cycle is a feature or a blocker.

None of those is findable by the bead's own words, and no gate sees any of them: two
functions with different names doing the same search resolve every name, compile clean and
pass. What finds them is one grep for the *shape* of the thing you are about to add —
`grep -n "^static func .*_page\|for i: int in PAGES.size()"` before writing another one —
and it costs a single command against a rewrite you would otherwise ship and have to
collapse later.
This is `scope-vs-claim`'s bar applied one step earlier — to the issue rather than to the
finding.

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

Two schema traps, both paid for: entries go under **`checks`** with `name`/`result` (not
`phase4`, not `check` — an unknown top-level key is dropped in silence, and the tool then
reports the evidence as missing), and `found[].phase` must be one of `import`, `lint`,
`tests`, `runtime`, `other` — anything else is recorded as null, though at least that one
says so.

### If the number does not move, you have not verified anything

The trap that got two consecutive cycles here. You widen a measurement's corpus, re-run,
and it reports the same value — because the previously-widest item is still the widest.
**That output is identical to the one a completely broken change produces.** "The new
inputs are included and are narrower" and "the new inputs are silently not included" are
the same number.

So when a change should affect a measurement and demonstrably doesn't, do not record a
pass. Mutate one of the new inputs to something absurd and confirm the measurement moves:

```
570 of 876 px, state ok      # before, and after — proves nothing on its own
1068 of 876 px, state spent  # with one corpus entry mutated huge — now it is proved
570 of 876 px, state ok      # restored
```

Then restore and re-read. The restore is not a formality: it is what separates "the
mutation moved it" from "something else moved it".

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

**Re-read the ACCEPTANCE and answer it clause by clause.** An acceptance criterion is
usually a sentence with two or three "and"s in it, and the last clause is the one that gets
dropped — it is furthest from the code and reads as bookkeeping. Cycle 91 closed `-bxhg`
having built the thing, tested it and driven it at runtime, while quietly skipping "and
`OVERLAY_GRAMMAR.md` gains a line saying which rows are taught". Nothing noticed for four
cycles; it surfaced only because cycle 95 happened to go looking for somewhere to record
exactly that.

No mechanism catches this. `bd close` does not read the acceptance, the commit does not
either, and a close reason describing what shipped is *indistinguishable* from one
describing what was asked for — which is precisely why the habit has to be quoting the
criterion rather than summarising the work.

If a clause genuinely should not be met, say so in the reason and why. "Refused the third
clause because X" is a fine close and a useful one; silently satisfying two of three is not.

**Never pass the reason as a shell literal** — `--reason "$(cat FILE)"`, per `CLAUDE.md`.
Backticks in a close reason are command substitution and the word vanishes leaving a
still-grammatical sentence, which has now happened four times in this project.

## What this skill does not cover

It does not decide **whether** the runtime pass was worth running — that is Phase 0.5
triage in `/verify`, and a docs-only diff should not reach step 4 at all. Nor does it
judge the change; it moves one item through the machine without dropping a step. The
judgement lives in the `Value:` verdict you write in step 7, and `overkill` is the entry
that goes unwritten.
