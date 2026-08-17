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

**Or advisory: exit `0` always, and report.** Choose this when what you are reporting
**cannot be actioned by the reader**. `gap_ledger.py` is the worked example: it reports
superseded `open` lines in `log-devtools.md`, there are thirteen, and the correct
response to every one is to leave it alone — rewriting an old entry would falsify what
was true the day it was written. Its first draft called those findings and exited 1,
which is a permanently-red gate, and a permanently-red gate is worse than no gate: it
teaches people to skip the check, and then it is not there for the finding that *does*
matter. The harness's own `validate-ui` grew a baseline for exactly this reason, and
`coverage_check.py` is advisory by design. The test is not "is this important?" — it is
**"if I show this to someone, is there something they can do?"** If not, it is a `NOTE:`
and the tool exits 0.

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

**When you need both the code AND the string contents, blank for the code and slice the
RAW text at the same offsets.** Blanking preserves offsets precisely so this is possible,
and the moment a checker cares about what a literal *says* — not just that one is there —
it needs both views of the same span. `message_corpus_check` got this wrong in both
directions on its first run, and neither was visible from reading it:

- it read the corpus's own literals from the blanked source, and reported `1 literal(s)`
  for a corpus holding five — every one hollowed to `""` and collapsed by the set — then
  flagged all five as missing from themselves;
- it computed a call's argument span from raw text, where a comma inside a string is still
  a comma. `"...on the grass, then grow the first wave."` was cut at `grass,` into an
  unterminated literal that matched nothing.

The rule that avoids both: **spans come from the blanked text, contents come from the raw
text, and nothing ever scans raw source for structure.**

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

## Run it once in the mode you do not intend to use

Before the fixture, and it costs one command. A checker has a quiet mode that gets wired
into the loop and a verbose mode that prints what it looked at — and the verbose one is
where the output nobody reads lives, which makes it where the bugs live too.

`citation_check.py` was run three times in `--quiet` and shipped. Its first plain run died
with a `UnicodeEncodeError` on an em-dash in a source line it was printing: **a checker
taken out by its own output**, on a cp1252 console, in the mode a human would actually use
when investigating something. The same plain run is what surfaced a citation that resolved
cleanly and no longer supported its claim — the one class the tool's own `NOT COVERED` line
says it cannot detect, sitting visible in output nobody had looked at.

So: run it verbose, on the real corpus, once. Read some of what it prints.

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

### The procedure legitimately ends in NOT building one, and that is a success

Read the denominator before you write the scan. Cycle 89 hit a textbook candidate: `.has()`
called on a const `Array[Dictionary]` with a String argument — false for every id in the game, so
the assertion **passes over nothing**, and it is invisible to `name_check` (every name resolves)
and to lint (it is type-valid for a `Variant`). Exactly the shape this skill exists for.

Then the grep found **zero** other instances in `game/` or `test/unit/`, and the correct idiom was
already the codebase's majority. So the rules above are what said don't build it: a zero
denominator has to announce its own emptiness, and a checker nobody has watched fire is prose.

**The deliverable in that case is the written reasoning, not the tool.** Put the enumeration and
the count in `kanban.md` so the idea is not re-proposed from scratch, and say that the entry is
the *first sighting* — a second instance meets the bar, and the record is what lets someone
recognise it as a second.

### If acting on one number could bury another, print both at the point of invitation

The denominator rule keeps a clean result from hiding an empty input. There is a second
version of it for any checker that invites an **action**, and it is easier to get wrong
because the tool is being helpful.

`suite_reach_check` printed this:

```
Baseline: 51 pre-existing, 1 NEW, 1 since fixed.
PROGRESS: 1 baselined symbol(s) are now named by a test (set_uproot_armed).
          Re-run --baseline-write to lock the improvement in.
```

`--baseline-write` rewrites the **whole** file. So acting on the PROGRESS line alone —
which is exactly what it invites — banks the `1 NEW` regression as accepted debt in the
same stroke, silently and permanently. It was safe only because both numbers appear
together and the reader can see the trap.

> **A tool that says "you improved, re-bank" and nothing else is worse than one that says
> nothing.** Whenever an invitation to act rewrites more than the thing it names, print
> everything that rewrite would absorb, next to the invitation and not three lines above it.

Same shape as the denominator rule: a number is only safe to act on when what it omits is
visible beside it.

### The region you measure is itself a denominator

The denominator rule above is stated for *findings*. Apply it to the **input** too, or a
checker will quietly measure a stub and report clean.

`mirror_check.py` compared the text between a `# workflow` heading and an end marker, and
that marker list contained `\n---\n` — ordinary markdown. Put a horizontal rule inside the
block and it ends the block early, **in both files equally**, so two 21-character stubs
compared identical and the tool reported clean over a fraction of the text it was supposed
to be checking. It had been like that since it was written.

Every checker that scopes by a text marker — a heading, a delimiter, a `# BEGIN` comment,
a function's closing brace — has this available to it. Ask directly: *can the region I
measured be smaller than I intended, and would that read as clean?* If yes, assert the
region's size, or detect the ambiguity. `mirror_check` now does the latter: its markers
are listed most-specific first, so a generic marker winning while a specific one appears
later in the same file means the generic one matched **inside** the block.

This was found by a fixture case written to test something else entirely. That is the
argument for writing more fixture cases than you think you need.

### A mutation that changes nothing is not a survivor

Read the NUMBER, not the verdict. Cycle 78 mutated a resolver to
`matches = [] or [m for m in ROOT.rglob(cited)]` — which evaluates the right-hand side,
so the code was different and the behaviour was not. The finding count did not move by
one; it did not move at all, and that is the tell. **A real survivor changes the code and
leaves the result identical; a no-op changes neither**, and the two are indistinguishable
if you only look at pass/fail.

Before believing a survivor, ask what the mutated line now computes. If you cannot say
what changed, nothing did.

### Then mutate the checker, not just the input

The fixture proves the checker fires on a bad file. It does **not** prove the checker is
looking at what you think. For that, break each stage of the tool in turn and confirm the
fixture goes red:

- turn comment-stripping off → the comment-matching findings should appear
- count string bodies as real code → the string-literal findings should appear
- disable whatever name resolution you added → those symbols should go unresolved

Restore, and the fixture must return to zero. This is a distinct discipline from writing
the fixture and it is the one that catches a checker which is quietly matching the wrong
thing.

**Keep the mutations. Write them into the checker's own docstring.** This has now cost
four separate sessions the same twenty minutes, which is the whole argument: the fixture
is written once and deleted, but the mutations are what you re-run *after every edit to
the checker* — and a mutation that found a bug in the tool (see `mirror_check.py`, where
removing the CRLF normalisation changed nothing because `open()` was silently doing it)
proves the mutations are a standing test, not a one-time ritual. Re-deriving them from
scratch is most of the cost of writing them the first time. One block, at the bottom of
the module docstring:

```python
# fixture:   identical / block deleted from one side / one-line drift / CRLF one side
# mutations: drop the `text.replace("\r\n", "\n")`  -> the CRLF fixture must go red
#            count the template block as an entry    -> id count rises by one
```

Three lines that survive in the file are worth more than a perfect fixture that does not. It found an escape-blind source blanker here — `"...entry[\"key\"]"` was read as
live code because the blanker did not handle `\"` — which no amount of good-and-bad
example files would have surfaced, because both files were being scanned wrongly in the
same way.

### Assert a property where it can FAIL, not where it holds regardless

The commonest way a test survives a mutation while looking thorough: it checks the right
property, in a case where that property is true no matter what the code does.

A message producer took a `with_tip` flag and composed a warning plus a tip. The test
asserted the warning was present — on the call where `with_tip` was **false**. There the
warning is present however the tip is composed, so the assertion could not fail. The
mutation that made the tip *replace* the warning survived untouched, and the test's own
docstring claimed to guard exactly that.

> **For each assertion, name the mutation it is supposed to kill, then check the case
> you asserted in is one where that mutation would show.** An assertion in the safe case
> is documentation wearing a test's clothes.

The tell: an assertion whose subject is not the thing the surrounding case is varying. If
the case under test toggles X, the assertions that matter are the ones X can break.

### A survivor is sometimes a finding about the CODE, not about the test

The default reading of a surviving mutation is "the test is too weak, strengthen it". There
is a second reading that is easy to miss and worth checking first: **the mutated code may
not matter.**

`_update_preview` guarded on `_uproot_armed if _uproot_left > 0.0`. Deleting the second half
killed nothing, and the test was not at fault — `_disarm_uproot()` nulls `_uproot_armed` on
*every* exit path there is, so the two conditions can never disagree. The guard was dead
code wearing a safety belt. Strengthening the test to kill that mutation would have locked
in a redundancy and called it coverage.

> **When a mutation survives, ask which is true before writing another assertion: is the
> test blind to a real behaviour, or is the mutated code unable to change any behaviour?**
> The second means delete it — and put the invariant that made it redundant into a test,
> because *that* is the thing actually holding the property up.

This repo has now hit it twice: here, and `mirror_check`'s CRLF normalisation, which was
also found by mutating and watching nothing go red. Do not delete on suspicion, though — a
guard that cannot disagree today may be what stops two things diverging tomorrow. The test
is whether an invariant elsewhere *guarantees* it.

### "Did not apply" and "survived" are opposite results

A mutation that never reached the file looks exactly like a mutation the fixture ignored,
and only one of them means "this guard is not load-bearing".

Two of four mutations here once printed `MUTATION TEXT NOT FOUND` because a shell heredoc
ate a level of backslash escaping — the needle contained `"\n"` and what reached Python
was a real newline. A sweep checking only exit codes would have recorded both as SURVIVED,
i.e. as evidence that two working guards were dead code. The opposite of the truth.

So: **assert every needle matches exactly once before running anything**, normalise line
endings first (a CRLF checkout is a second way a needle silently misses), and report three
outcomes rather than two — `RED`, `SURVIVED`, `NOT-APPLIED`. Prefer an editing tool over a
shell heredoc for any needle containing a backslash.

**And read the exit code specifically, never just its truthiness.** This applies to
mutating production code against the test suite exactly as much as to mutating a checker,
and it bit twice within one hour. A sweep that ran `python tools/run_tests.py --godot "$GB"
--filter facing` recorded all three mutations as killed; `--filter` is only accepted after
`--`, so argparse exited **2** every time and not one test ran. `if returncode:` is true
for 2, and this repo's whole exit convention is that `2` means *nothing was verified*.

Map all three explicitly, and **print the denominator beside each result**:

```
0 -> SURVIVED   (the guard is not load-bearing)
1 -> RED        (killed, for the right reason — check WHICH assertion failed)
2 -> BROKEN RUN (proves nothing; fix the invocation and rerun)
```

The tell that caught it was the **restore** run coming back non-zero when it had no
business doing so. Always run the restore and assert it is clean — an unmutated failure
means every verdict above it is void.

### Beware a positive control that cannot fail

A vacuity guard like "the corpus still contains every known class" sounds like it proves
the scan works. It does not: a deliberately broken blanker left ~70% of characters intact,
and no threshold separates 74.7% from 70.3%. Guards of that shape pass against the exact
breakage they exist to catch.

Replace them with a **direct unit test of the transform** on a handful of controlled
inputs, where the expected output is written out by hand. Nine lines of known-in,
known-out beats any statistic over the real corpus.

## Registering it

Add it to the parallel-safe list in `.claude/skills/cycle/SKILL.md` — the loop lives
there now, in one copy; `CLAUDE.md` and `AGENTS.md` carry only a pointer to it. Do not
edit the harness's managed block in `CLAUDE.md`; `/scaffold-godot-harness` regenerates it.

Do not mint a `.uid` sidecar for a `.py` file. Those are for `.gd` scripts, and lint
reports `UIDs: OK` either way, so a stray one is invisible until someone wonders what it
is.
