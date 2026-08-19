---
name: fan-out-a-cycle
description: Write the lane prompts for a parallel cycle — how to partition beads into lanes that cannot collide, the file-ownership block, the gate allowlist a lane may run, the project traps every lane needs told, and the report format that makes the merge possible. Use when spawning two or more agents on bd items in one cycle, when deciding whether two beads are one item, and when a lane comes back with a report you cannot merge from. The merge itself is `merge-the-fanout`; this is everything before it.
---

# Writing the lanes

## 0. CHECK THE WORKTREE BASE BEFORE YOU TRUST A SINGLE LANE REPORT

`isolation: "worktree"` branches from **`origin/main`**, not from your local `HEAD`. This
project batches pushes on purpose — every push auto-deploys — so `origin/main` is
routinely dozens of commits behind. Measured on the fan-out that produced this section:
**all four lanes were checked out at `2563734`, 71 commits behind local `main`.**

That is not a cosmetic difference. On that tree `tools/citation_check.py` was 339 lines with
no `--beads` mode at all, `game/game.gd` had no packet serialisation, and
`test/unit/test_selftest.gd` was missing ten tests. **Every absence claim a stale lane makes
is a fact about the checkout rather than about the repo** — one lane would have reported
"the bead's premise is false, the third sighting does not exist" and been wrong.

So, before spawning and again in every prompt:

```bash
git rev-parse --short origin/main; git rev-parse --short HEAD
git rev-list --count origin/main..HEAD      # 0 means the default base is fine
```

If those differ, put this in **every** lane prompt, verbatim:

> Your worktree may be checked out behind local `main`. Before anything else, run
> `git rev-list --count HEAD..main`. If it is not 0, run `git checkout -B lane/<bead-id> main`
> and re-confirm the bead's citations against that tree — line numbers and neighbouring code
> have moved. Report your base sha in your final report.

Two of four lanes caught this unprompted and rebased themselves; one had to be told
mid-flight and redid its work; the fourth was already on main by luck of timing. **Do not
rely on the lane noticing** — a lane that does not notice reports a clean, confident, wrong
answer, and its gates all pass because the stale tree is internally consistent.


The prompt-writing IS the skill. Cycle 100 wrote three lane prompts from scratch and they
were 90% identical; cycle 102 wrote five and they were 90% identical to those. What varies
between lanes is four things — the bead, the owned files, the tests, the acceptance — and
everything else is boilerplate that is expensive to omit and free to include.

**Partner skill:** `merge-the-fanout` covers integration. Read it BEFORE fanning out, not
after, because its cost section is what tells you whether to fan out at all.

## 1. Partition by FILE, not by topic

Two beads are one lane if they touch one file. That is the whole rule, and it is cheap to
get wrong because beads are written by topic.

- **Same file, different functions → still fan out, but say which functions.** Cycle 102
  put the top-bar lane and the packet lane on disjoint regions of the same 2000-line
  `hud.gd` and git merged them without a conflict. Name the exact functions each lane owns
  AND the exact functions it must not touch, with the sibling's name, so each knows a
  collision is possible.
- **Same file, same region → they are one item.** Give both beads to one lane, in order,
  one commit each.
- **Same mechanism → they are one item even in different files.** Two beads that both add
  an entry to the same registry, the same enum, or the same one-shot hint list will
  conflict in spirit even where git merges cleanly. This is the one the file rule misses.

**A shared append-only file is not a reason to split.** Every lane appends tests to the
same suite; that conflict is expected, mechanical, and yours. Tell each lane to append at
the very END under a clearly-named section comment, and tell it that siblings are doing
the same.

**Hold a registry file at the parent.** When several lanes each need one line in one file
— an `EXPECTED_SIZE` row, a corpus entry, a button in a bar — the parent owns that file and
writes every line after the lanes land. Tell each lane the file is held and to report the
exact line it needs. This is not "they are one item": the work is independent and only the
bookkeeping overlaps.

## 2. The blocks every lane prompt needs

Copy these. Omitting one costs more than including it.

**Identity and isolation.** "You are LANE X of a parallel fan-out. You are in your OWN git
worktree, isolated from the other N lanes." A lane that does not know it is one of several
will helpfully fix things outside its remit.

**Confirm before implementing.** "The bead is a claim about the repo made at some past
moment. Open the cited lines and verify they say what the bead says. If the claim is
already satisfied or wrong, STOP and report that instead of writing code." Four beads in
this project have been claimed whose factual premise was already false.

**File ownership as a hard boundary.** List what it OWNS, then list what it must NOT edit
by name — including `kanban.md`, `cycle-log.md`, `log-devtools.md`, `CLAUDE.md`,
`AGENTS.md`, `.beads/*` — and "do not run any `bd` command that writes; the parent owns the
tracker." Add: "You may READ anything."

**The gate allowlist, verbatim, and the prohibition.** Give the exact command list and then
say plainly: do NOT run `lint_project.gd`, `import_check.py`, `run_tests.py`, `/verify`, or
launch the game — they open the project, write `.godot/`, and would corrupt the sibling
lanes. In this project that list is one command now: `python tools/check_all.py --quiet`.

**"A clean `name_check` is not a compile."** Say it in every prompt and require the lane to
repeat it in its report. It resolves names; it does not type-check.
`var kids := root.get_children()` on a bare `Node` is a hard parse error it reports clean.
**And a fresh worktree has no `.godot/`, so `--require-compile` does not work either** —
the lane gets no compile at all and must say so rather than claiming "verified".

**"A finding in a file you do not own is not your finding."** Costs a line, still true of
anything shared even under worktree isolation.

**The escaping trap.** "Write code with the Edit/Write tools, NEVER through a shell
heredoc, and never via a Python script that writes source. If `Edit`'s exact match fails,
`Read` the exact bytes and `Edit` again, or `Write` the whole file." This project has been
bitten four times by a heredoc eating a leading `#`.

**The project's own skills, named for the lane's actual problem.** Do not list all of them;
point at the one or two that match. A lane testing something behind a runtime gate gets
`extract-a-testable-seam`; one adding to a HUD gets `godot-hud-occlusion-audit`; one
writing a derived list gets `derive-the-list`; one reading tree-global groups gets
`godot-test-isolation`.

**The suite's own traps**, for any lane writing tests: `_T.instantiate_ui` /
`instantiate_scene` for anything Control-shaped (headless pumps no frames, so `size` stays
`(0,0)`); `_T.text_width` rather than `get_minimum_size()` on a clipped Label; and **always
read stderr, because a runtime error inside a test aborts only that method and returns
`""`, which is identical to a pass.**

## 3. Ask for the report you will need at merge time

A lane's report is the only thing you have when the merge fails. Require:

- worktree path, branch name, commit sha(s) — and tell it to commit on `lane/<bead-id>`
- `git diff --stat`
- **whether each bead's claims confirmed** — with what it actually read
- exactly which functions / line ranges it touched in any file a sibling also owns
- which gates ran, with exit codes, and the not-a-compile caveat
- **anything it needs in a file it does not own, as an exact copy-pasteable edit**
- the decisions it made that the bead left open, and why
- one sentence of harness verdict (`warranted`/`overkill`/`insufficient`/`inconclusive`)

**That "exact edit" line is load-bearing.** A lane that reports "needs these lines in a
parent-owned file" has not finished until the parent writes them, and skipping it ships
dead code with every gate green. Cycle 101 nearly shipped an upgrade ladder no player could
reach; cycle 102's speed control was seven edits away from being a keyboard verb with no
button.

## 4. Tell each lane what the OTHER lanes will need from it

The prompts are not independent even when the files are. Cycle 102's top-bar lane was told
a third lane would want a small button in that same bar, and asked to report how much width
headroom it left — so the parent learned the row was 43px short from a lane that never saw
the button. A lane that knows what is coming reports the number that makes the merge
cheap.

## 5. Decide before you spawn: is this worth a lane?

A lane costs a full prompt, a worktree, a merge, and a parent pass — and **it compiles
nothing**. Fan out when the items are genuinely independent and each is more than a few
edits. Do NOT fan out:

- two items whose only connection is that you thought of them together (they are still one
  lane if they share a file)
- an item that is mostly a decision rather than mostly typing
- anything needing a running game, an import pass, or a new asset — a lane can do none of
  those, so it will hand the work straight back

Say in the cycle's close which lanes ran together and why they were safe — **and what the
merge cost**, because that is the number that decides whether to do it again.
