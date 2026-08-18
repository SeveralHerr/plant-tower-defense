---
name: merge-the-fanout
description: Integrate several parallel lanes back into main after a worktree fan-out — the order the gates run in, how to resolve appended-test conflicts without silently deleting a test, why a lane's new public API is routinely unreachable until the parent wires it, and which failures are the parent's to expect rather than the lane's to have prevented. Use when merging two or more agent branches, when a lane reports "needs these lines in a file I do not own", when a merged suite fails a test that passed in every lane, and before removing any agent worktree. Also use when deciding whether to fan out at all, because the merge cost is the thing that decides it.
---

# Merging a fan-out

**The lanes are the cheap half. The merge is where the failures are, its cost scales
with the NUMBER of lanes rather than the size of any one, and it is not optional.**

Cycle 100's three lanes each ran every parallel-safe checker clean and the merge failed
five times. Cycle 102's five lanes each reported green and the merge found five more.
**Not one was a mistake by the agent that caused it.** Each was a fact about a file that
lane was correctly forbidden to open. Plan for that, or the fan-out's speed is borrowed
against a debugging session nobody scheduled.

## Before you fan out: what a lane structurally cannot do

A lane in a fresh worktree **compiles nothing**. `lint_project.gd`, `import_check.py` and
`run_tests.py` all open the project and write `.godot/`, so two at once corrupt each
other's run and lanes are forbidden all three. The obvious escape —
`name_check.py --require-compile` — **does not work in a worktree**: a fresh checkout has
no `.godot/global_script_class_cache.cfg`, so every cross-file `class_name` false-positives
as undeclared. Two lanes hit this independently and got
`does not compile: Parse Error: Identifier "WaveDirector" not declared` on a line
unchanged from main.

So: **N lanes report green having never parsed a line.** That is the deal. It is usually
still worth it — but it means the parent owes a real gate pass, and "all lanes were clean"
is not evidence of anything except that names resolve.

## The order

1. **Merge lanes one at a time**, most-independent first. Do not merge all five and then
   look. A conflict you resolve with three lanes' changes already in the tree is a conflict
   you resolve blind.
2. **After EACH merge, check the shape** — `git diff --stat`, and whether the files you
   expected are the files that moved.
3. **Run the engine gates ONCE, after every lane has landed**, not per merge:
   `import_check.py` → `lint_project.gd` → `run_tests.py`. Run `--import` first if any lane
   added a `class_name`; until the cache is rebuilt, every script referencing the new class
   fails to compile and it cascades into files nobody touched.
4. **Then `suite_reach_check` again** (see below — this one is routinely NEW after a merge
   and clean in every lane).
5. **Then the runtime pass**, and read `reach` on the ledger row: a lane's diff often sits
   on a screen the entry hook never opens.
6. **Then remove the worktrees** — after, never before, and only once each branch is proved
   merged.

## The appended-test conflict, and the way it eats a test

Every lane appends to the end of the same suite file, so every merge after the first
conflicts there. It looks trivial. It is not, in exactly one way:

**Git factors out a shared suffix.** When both sides' last function ends the same way —
and in a test suite they very often do, with `_T.free_ui(game)` / `return err` — that
suffix is hoisted BELOW the `>>>>>>>` marker and belongs to *both* sides. Resolving by
deleting the three marker lines then attaches it only to the second side's last function,
and silently truncates the first side's:

```gdscript
        err = _T.assert_eq(missing.size(), 0, "...")   # lane C's last function ENDS HERE
=======
# -- lane D's block starts here
        ...
        err = _T.assert_false(..., "...")              # lane D's last function
>>>>>>> lane/packets
    _T.free_ui(game)                                   # <-- belongs to BOTH
    return err
```

The fix is to give each side back its own ending. The tell that you got it wrong is not a
compile error — GDScript is perfectly happy with a function whose last statement is an
assignment — it is a **test that silently stops returning its own result**.

**So verify the count, every time, before committing the merge:**

```bash
grep -c '^func test_' <suite file>                      # merged
git show <base>:<suite file>   | grep -c '^func test_'  # base
git show <lane>:<suite file>   | grep -c '^func test_'  # each lane
# merged MUST equal base + sum(lane - base)
```

329 base + 3 + 4 + 4 = 340, and the merged file had exactly 340. That arithmetic is the
only thing standing between you and a quietly deleted test.

## The failure classes to expect, in the order they show up

**1. A test that was green by construction in its lane.** A lane cannot run the suite, so
a test that never actually asserted anything reports the same as one that did. Cycle 102:
two direction tests asserted "this plant has not attacked yet" with the prey already in
range — `_act()` runs on every settle frame, so the plant had eaten during
`instantiate_scene` and the precondition read a lunge vector instead of zero. **The plant
was right and the assertion was wrong.** Read the failure before assuming the lane's
feature is broken; more often the lane's *test* encodes a state the game cannot be in.

**2. A budget or golden value another lane moved.** Anything that sums across files —
a width budget, a golden array, a hardcoded pair — is invisible to every lane and breaks
at the merge. If the project has a budget system, it will tell you the exact number; let
it, rather than guessing (see `buy-the-width` below).

**3. A lane's new public API that nothing calls.** This is the one people miss, because it
is clean in the lane and clean in the suite. A lane writes `plant_button_tint()` in a file
it owns; the thing that would call it lives in a parent-owned file; the lane hands back an
edit list; the parent writes the lines and stops. Now the feature works and no test names
it. `suite_reach_check` reports it as NEW **only after the merge**.

> **Do not bank those into the reach baseline.** `--baseline-write` rewrites the WHOLE
> file, so acting on a `PROGRESS:` line alone accepts every NEW regression as debt in the
> same stroke. Read both numbers. Write the tests, re-run until it reads `0 NEW`, and only
> then bank the improvement.

**4. A shared function whose DEFAULT is not what its callers were written against.** The
worst one, because both lanes are correct and every gate is green. One lane collapses N
copies of a helper into a shared implementation and gives it a mode parameter; another
lane, in parallel, writes a new caller against one of the old copies. The names match, the
import resolves, the checkers pass — and the caller silently gets a behaviour it was never
tested with.

Cycle 107: lane A folded nine source-blankers into `gdsource.strip_comments(text,
strings=KEEP)`. Lane E's new `sfx_call_check` called it bare, having been written and
mutation-tested against `message_corpus_check`'s copy, which **blanked** string bodies.
The two modes differ on 40 of 44 `game/*.gd` files. `check_all.py` reported **18 of 18
clean** with the bug live; the counts only matched because no `Sfx.play(` happened to sit
inside a string literal that day. Planting one gave 26 call sites and a false finding
against the correct 25 and 0.

The second half is subtler and is the part to remember: lane A's report *named* the
behaviour change — "differs only in whether an `&` prefix is blanked, which no caller
reads" — and it was true of every caller lane A could see. Lane E's checker did not exist
in lane A's worktree, and it reads exactly that `&`.

> **So: when any lane collapses duplicate implementations into one, the merge owes a
> per-caller check that the chosen default matches what THAT caller previously had.** Do
> not accept "no caller reads it" from a lane — it can only speak for the callers in its
> own worktree, and a sibling lane's new caller is invisible to it by construction. Grep
> the merged tree for every call site, and for each one ask which of the old copies it was
> written against. Prove it by planting the input the modes disagree on and running the
> caller both ways; the counts agreeing today is not the same as the modes agreeing.

**5. A checker that walks the repo tree.** Agent worktrees live *inside* the repo and are
gitignored, but `rglob` does not read `.gitignore`. Five lanes turn every bare-filename
citation into a six-way ambiguity — **and only the parent sees it**, because a lane inside
its own worktree has no nested copies. If a tree-walking checker starts reporting mass
findings mid-cycle, look at the worktrees before believing one of them.

## The parent owes each lane's wiring, not just its merge

A lane that reports "needs these lines in a parent-owned file" **has not finished until
the parent writes them.** Skipping that ships three files of dead code with every gate
green. Demand the edit list in the lane's prompt, exact and copy-pasteable, and treat it
as part of the merge rather than a suggestion.

And when the wiring does not fit — the row has no width, the enum has no slot — that is
the parent's problem to solve, not a reason to drop the lane's work. **Do not guess the
number. Make something measure it for you:** set the constant absurdly low, run the one
test that checks it, and read the requirement out of the failure message.

```
"Grow the next wave" plus the paper box's margins needs 202px of its 80px slot
"Grow next wave"     ... needs 168px of its 80px slot
"Next wave"          ... needs 120px of its 80px slot
```

Three probes, three exact numbers, no arithmetic in your head. Then spend the width where
it is cheapest and say in the commit which alternative you rejected and why.

## Removing the worktrees

**Prove each branch is merged before deleting anything.** `git worktree remove --force`
takes the checkout with it, and a lane branch that failed to merge is real work.

```bash
for b in lane/a lane/b lane/c; do
  git merge-base --is-ancestor "$b" main && echo "MERGED   $b" || echo "UNMERGED $b"
done
```

Then `git worktree remove` each, `git worktree prune`, and **re-run the tree-walking
checkers** to confirm the findings they reported during the fan-out were the worktrees and
not something real.

## What to write in the close

Say which lanes ran together and why they were safe — but more usefully, **say what the
merge cost**. A fan-out whose close reports only "five lanes, all green" has hidden the
one number that decides whether to do it again.
