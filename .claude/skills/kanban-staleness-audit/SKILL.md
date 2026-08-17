---
name: kanban-staleness-audit
description: Audit a written backlog against the code that has moved under it — which idea-backlog entries are already shipped, already impossible, or quietly rewritten, and which are still real. Use when kanban.md (or any long idea list) is being mined for work, when an entry describes behaviour that does not match the game you just ran, when a section has not been read in many cycles, before promoting anything from a backlog into an issue, and whenever asking "is this file still true?". Also use when handing this sweep to subagents, which need the accuracy bars below or they will confirm the mistakes they were asked to find.
---

# Auditing a backlog nobody has re-read

`kanban.md` in this project is 1700+ lines and says at its own top that roughly half is
stale. That is the normal end state of any file that is appended to every cycle and read
selectively: the entries do not rot evenly, and the ones that rot are indistinguishable
by eye from the ones that did not. This is the procedure for turning a range of it back
into something trustworthy — run three times here by hand, twice by subagents, and it is
written down because both subagent runs got exactly one verdict wrong in the same
instructive way.

## What you are actually deciding

Per entry, one of four verdicts. **Each requires evidence of a specific kind** — the
verdict is not the finding, the evidence is:

| Verdict | Means | Evidence required |
|---|---|---|
| `SHIPPED` | the described behaviour exists now | the file:line that implements it, plus the test or gate that holds it there (or `no test` said explicitly) |
| `STALE` | it describes a game that no longer exists | the file:line showing what is there INSTEAD, and what changed it |
| `DRIFTED` | still a good idea, but the entry's description is wrong now | both: the entry's claim, and the current reality it disagrees with |
| `STILL REAL` | not built, still wanted, description holds | the absence, shown — a grep or a named surface where it would be and is not |

An entry you cannot resolve is `UNRESOLVED` with the reason. That is a legitimate output.
Guessing to fill the table is the failure this procedure exists to prevent.

## The two accuracy bars

**A wrong `STALE` is the costly error.** `STILL REAL` on something already shipped costs
one wasted lookup next cycle. `STALE` on something still wanted deletes an idea nobody
will have again — the entry is the only record it was ever wanted. So: **before calling
anything stale, open the implementing code.** Not the tests, not another doc, not the
commit log. The code.

**An entry that quotes a NUMBER must have the number re-derived from source — and you
must check what the number COUNTS, not just that it reproduces.** This is the half that
gets skipped, and it is how both subagent audits went wrong here: an entry read "138
files credited by `reach_aliases`", the agent recomputed 138, and marked the entry
accurate. The arithmetic was right and the noun was wrong — 138 was a cumulative sum
across five files, not a count of files. **A figure that reproduces exactly is the most
convincing kind of wrong.** Ask what one unit of the number is before you agree with it.

## Two more traps, both paid for

**An entry points at where the problem WAS, not where the fix landed.** "Starting a wave
has no click of its own" cited the button that emits the signal. The button is unchanged
to this day; the sound was added to the *handler* on the other side of the signal.
Checking only the cited line produces a confident, wrong `STILL REAL` — and it feels
especially rigorous, because you went exactly where the entry told you. **Resolve the
behaviour, not the citation.** Follow the signal, the caller, the subclass.

**Section headings are not unique, so cut by line number.** This file has two independent
numbering runs: `### New this cycle (25 of 30)` appears twice, with different subtitles.
`uniq -d` on the headings therefore reports nothing, and a `text.index("### …")` matched
the earlier one and deleted 1937 lines instead of 85. It was caught by `git diff --stat`
before the commit, which is the whole reason step 5 below separates the finding pass from
the rewrite. Slice by index with an assert on each boundary line.

## Procedure

1. **Take a range in, never "the file".** Line numbers or a named section, 20–40 entries.
   A whole-file sweep produces a verdict table nobody checks and the cost of a wrong
   `STALE` is paid silently. If you name a section, **verify the name is unique first** —
   see the trap above.
2. **Read the range's own header first.** Sections here are dated and titled by cycle
   ("New this cycle (12 of 30)"); an entry's neighbours tell you what was true when it
   was written, which is what you are comparing against.
3. **Resolve each entry against the code, one at a time**, filling the evidence column
   before the verdict column. Writing the verdict first is how a plausible entry becomes
   a confirmed one.
4. **Re-derive every number**, per the bar above.
5. **Report the table plus a one-line-per-entry rationale.** Do not edit `kanban.md` in
   the same pass — separate the finding from the rewrite, or a wrong verdict is applied
   before anyone reads it.

   **The one sanctioned way to compress the two passes** is to make the second pass
   mechanical instead of dropping it. Rewrite in place, then run a script that opens every
   `file:line` the rewritten range cites and prints the line it lands on:

   ```python
   import re
   sec = open('kanban.md', encoding='utf-8').read().split(START)[1].split(END)[0]
   for f, a, b in sorted(set(re.findall(r'`([a-z_]+/[a-z_]+\.gd):(\d+)(?:-(\d+))?', sec))):
       lines = open(f, encoding='utf-8').read().splitlines()
       lo, hi = int(a), int(b or a)
       print("%s:%s %s" % (f, lo, " | ".join(l.strip()[:60] for l in lines[lo-1:hi])))
   ```

   This is strictly better than a second reading by the same eyes, and it has caught two
   bad citations that a re-read did not — both times because the *edit itself* moved the
   lines it cited. What it does not check is whether the cited line SUPPORTS the claim, so
   read the printed output rather than the exit code. Cycles 68 and 76 both wrote a
   citation that resolved to a doc-comment line one above the constant it meant; only
   printing the line showed it.
6. **Then act**: `SHIPPED` entries move to the Done section with their file:line;
   `STALE` ones are deleted with the reason in the commit message; `DRIFTED` ones are
   rewritten to what is actually true; `STILL REAL` ones are the only ones eligible to
   become `bd` issues.

## Handing it to subagents

Parallel-safe, if and only if the tool list is explicit. Give each agent a disjoint line
range and this allowlist:

```
Read, Grep, Glob, and these gates (each opens no project and writes nothing to .godot/):
  python tools/name_check.py
  python tools/world_control_check.py
  python tools/meta_key_check.py
  python tools/svg_style_check.py
  python tools/group_leak_check.py
  python tools/suite_reach_check.py
  python tools/settle_read_check.py
  python tools/save_persist_check.py
```

**Not** `lint_project.gd`, `import_check.py`, `run_tests.py` or anything that launches
the game: they open the project and write `.godot/`, so two agents running them at once
corrupt each other's run. An agent that needs a live game is an agent whose range should
have been audited by you.

Put both accuracy bars in the prompt verbatim. Both subagent runs that skipped the number
rule got a verdict wrong; both runs were otherwise accurate, so the bars are the whole
delta between a useful audit and a confident one.

## What this cannot tell you

Whether the idea is still *wanted*. An entry can be perfectly accurate, unbuilt, and
something nobody would choose to build today — this procedure will mark it `STILL REAL`
and it is right to. Desirability is the user's call and belongs in a different pass;
mixing them means arguing about taste while holding a verdict table about facts.
