---
name: house-static-checker
description: How to write a stdlib-only static checker for this repo — the exit-code contract, the printed denominator, the mandatory NOT COVERED line, and the synthetic fixture that proves the checker can actually fail. Use when adding a tool under tools/ that scans source for a defect class the engine gates cannot see, or when reviewing one.
---

# Writing a house static checker

This repo has four: `world_control_check.py`, `meta_key_check.py`, `group_leak_check.py`,
`svg_style_check.py`. Each exists because some defect class is invisible to every engine
gate, and each was written by re-deriving these conventions from scratch. This is the
convention.

## Why these exist at all

The engine gates cannot be run in parallel. `lint_project.gd`, `import_check.py` and
`run_tests.gd` all open the project and write `.godot/`, so a fan-out agent gets
`name_check.py` and nothing else — and `name_check` resolves identifiers, which means
whole classes of defect are structurally invisible to it:

- a property that resolves fine but was never assigned (`mouse_filter`)
- a string used as a cross-script contract (`set_meta` keys)
- a correct call with a wrong provenance (`get_nodes_in_group(...)[0]`)

Each new checker should be able to say, in its own docstring, **which existing gate would
have caught this and why it doesn't**. If you cannot write that paragraph, the check
probably belongs in the test suite instead.

## Hard requirements

**Parallel-safe.** Open no project, write nothing to `.godot/`, take no lock. Stdlib only.
That is the entire reason these are Python and not another `.gd` under `tools/`.

**Exit codes.** `0` clean, `1` findings, `2` could not run. A `2` means nothing was
verified — never let a missing input, an unreadable file or a missing `project.godot`
fall through as a pass.

**Print a denominator, always.** The single most dangerous output a checker can produce is
a clean result over an empty input set:

```
world_control_check: 13 world-space script(s), 3 of them build Controls, 0 finding(s)
group_leak_check: 7 test script(s), 12 function(s) read a tree-global group,
                  2 of those select a single node, 0 waived, 0 finding(s)
```

A zero denominator must say so **in words**, because `0 findings` over nothing looks
identical to `0 findings` over everything:

```
NOTE: nothing to check -- no world-space script builds a Control. That is a clean
      result only if you expected none.
```

**A `NOT COVERED:` line on every run**, clean or not. Say what the tool structurally
cannot see. This is copied from `name_check.py`, and it is the single thing that makes a
weaker tool trustworthy — the harness's own `import_check.py` lacks it, reports
`Import OK` over a hard parse error, and cost a real debugging detour as a result.

State plainly that it does not compile:

```
NOT COVERED: this reads source, not a running tree. It cannot see <the specific
             blind spots>. Nor does it compile anything -- only import_check.py and
             lint_project.gd do that, and neither is parallel-safe.
```

## Writing the scan

**Strip comments and string bodies before matching.** A rule satisfied by prose is not a
rule. This repo has already been bitten the other way round: a test scanned source for a
token and matched the comment explaining why the token was absent.

**Scope by function, not by file.** A correct pattern in one function must not excuse a
wrong one in another. `group_leak_check` gets this right; a file-wide match would have
made one good test silence a whole suite.

**Accept only guards that actually guard.** `group_leak_check` deliberately refuses
`assert_gt(size, 0)` as provenance — it was true every single time the bug it hunts fired.
Ask what the failing case would have printed, and reject any guard that would have passed.

**Offer a waiver, and make it explain itself:** `# group-leak-check: ok - <reason>`.
Check the waiver *after* stripping comments strips it — that is a real bug that shipped in
a first draft here.

**Every finding carries the fix.** Not just the defect:

```
FINDING: <file>:<line> <function> <what is wrong and why it matters>
  fix: <the concrete change, naming a working example in this repo>
  waive: add `# <tool>: ok - <reason>` in the body.
```

## The fixture is not optional

**Write a synthetic file containing both the bad patterns and the good ones, run the
checker on it, and confirm it fires on exactly the bad ones.** Then delete it.

This is the step that gets skipped, and it is the step that pays. Writing the fixture for
`group_leak_check` caught two real bugs *in the checker*: the waiver was being stripped
before it was checked, and one waiver anywhere silenced a whole file. Writing it for
`world_control_check` corrected a mutation experiment I had designed wrongly — I removed a
sweep helper and got no finding, which looked like a broken checker and was actually
correct behaviour, because the file set the property per node.

A checker that has never been observed to fail is not a checker. The same rule as a test:
**green on first run means nothing until you have watched it go red for the right reason.**

### Then mutate the checker, not just the input

The fixture proves the checker fires on a bad file. It does **not** prove the checker is
looking at what you think. For that, break each stage of the tool in turn and confirm the
fixture goes red:

- turn comment-stripping off → the comment-matching findings should appear
- count string bodies as real code → the string-literal findings should appear
- disable whatever name resolution you added → those symbols should go unresolved

Restore, and the fixture must return to zero. This is a distinct discipline from writing
the fixture and it is the one that catches a checker which is quietly matching the wrong
thing. It found an escape-blind source blanker here — `"...entry[\"key\"]"` was read as
live code because the blanker did not handle `\"` — which no amount of good-and-bad
example files would have surfaced, because both files were being scanned wrongly in the
same way.

### Beware a positive control that cannot fail

A vacuity guard like "the corpus still contains every known class" sounds like it proves
the scan works. It does not: a deliberately broken blanker left ~70% of characters intact,
and no threshold separates 74.7% from 70.3%. Guards of that shape pass against the exact
breakage they exist to catch.

Replace them with a **direct unit test of the transform** on a handful of controlled
inputs, where the expected output is written out by hand. Nine lines of known-in,
known-out beats any statistic over the real corpus.

## Registering it

Add it to the parallel-safe list in **both** `CLAUDE.md` and `AGENTS.md` — they are
independent files and a sync that knows only one has already silently deleted a section
here. Do not edit the harness's managed block; `/scaffold-godot-harness` regenerates it.

Do not mint a `.uid` sidecar for a `.py` file. Those are for `.gd` scripts, and lint
reports `UIDs: OK` either way, so a stray one is invisible until someone wonders what it
is.
