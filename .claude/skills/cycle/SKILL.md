---
name: cycle
description: This project's development loop, run end to end and repeated until the user stops you — pre-flight, then bd items one at a time (confirm → claim → implement → /verify → commit), then add to kanban.md, reflect on the harness and on the workflow, refill the queue, bump cycle-log.md, and go again. Use it whenever the user asks to run a cycle, work the queue, do the next item, keep going, work indefinitely, loop forever, or never stop — and use it for the parallel form too, when several bd items should be fanned out to agents in worktrees.
---

# The cycle

**This is a loop. It does not end. Keep going until the user stops you.**

Keep the workflow simple and meaningful. Reflect on the game, tools, workflow and skills,
and find meaningful ways to evolve them all.

**`bd` IS THE WORK QUEUE. `cycle-log.md` IS THE NARRATIVE.** Every item lives in `bd` and
nowhere else — status, priority, blockers and close reasons are real fields there.
`cycle-log.md` holds only what `bd` structurally cannot: the cycle counter, what the last
cycle taught, what is waiting on the user. Never write a work checklist into it, and never
use TodoWrite for any of this.

**Bias step 2 toward what a PLAYER would notice.** The tooling and audits are how this
project stays honest, and they have repeatedly taken whole runs of cycles. A checker is
still the right call when it is the right call — this is a bias, not a ban. But a cycle
that ships nothing player-facing owes one sentence in its close saying why, and two in a
row means the next cycle takes a player-facing item whatever else is ready.

## The three files

| File | What it is |
|---|---|
| `SKILL.md` (this one) | the loop, and only the loop |
| `references/why.md` | the long form of every step: the rule, and the cycle that paid for it |
| `references/gates.md` | the two runners, and how to read each checker's output |
| `references/fan-out.md` | writing lane prompts when a cycle runs in parallel |

Read the step's section in `why.md` when the one-line version below is not enough. Most of
those rules were written by a cycle that had just broken them, so the reasons are worth more
than the instructions.

## The steps

**0. Pre-flight — read four things and report them as four NAMED values**, because a line
with three values in it looks exactly like a line with four: `beads=N ready`,
`skills=N (none named twice)`, `kanban=<the section you looked at>`, `mirror=0`.

- `bd ready` and `bd list --status=open`. If everything open is blocked, say so.
- Skill ideas in `C:\Users\gotmi\documents\github\log.md` against `.claude/skills/`. Named
  twice and absent means build it, not identify it again.
- `kanban.md` — recent sections plus the backlog you are about to mine. Roughly half of the
  historical sections are stale; run `kanban-staleness-audit` before promoting anything.
- `python tools/mirror_check.py` (`--fix` regenerates `AGENTS.md`'s copy). This guards the
  nine-line pointer to this skill, which has been silently deleted twice.
- The cycle counter, **derived not read**:
  `git log --oneline | grep -oE "Close cycle [0-9]+" | awk '{print $3}' | sort -n | tail -1`
  against `cycle-log.md`'s top line. The MAX, not a count. If they disagree, fix that first.

Pre-flight reports and files; it does not block. The harness is checked in step 4, after it
has been used. → `why.md` §0

**1. Read `cycle-log.md` for context, then `bd ready` for the work.** The log carries the
cycle number and what the last cycle learned; the beads are the queue and there is nothing
to transcribe.

**2. Do the items one at a time: confirm → claim → implement → `/verify` → commit.** One
commit per item, never batched. Follow `.claude/skills/verify-bd-item/SKILL.md`.

- **If the bead names a CATEGORY, enumerate the category from the code.** "every tip",
  "all the cues", "each of the X" — the bead's own list is a snapshot of what its author
  could see, and five cycles running the derived list has been bigger than it. Cycle 168's
  tip audit found nothing in the tips and three defects in the **refusals**, the sibling
  class the bead never mentioned. → `why.md` §2
- **`confirm` comes before `claim`.** A bead is a claim about the repo made at some past
  cycle, and the repo has moved. Four beads have been claimed whose premise was already
  false; one was shipped by the cycle that filed it.
- **Run independent items in parallel** when their files do not overlap. Lane prompts,
  gate allowlist and worktree traps: `references/fan-out.md`. Two items that want the same
  file are one item.
- **If the last two cycles worked the same file or subsystem, take something else** —
  unless the player-facing steer says otherwise, in which case say in the close which rule
  you overrode.
- **Write code with Edit/Write, not through a shell heredoc**, and keep every string
  literal on one line. A newline inside a GDScript string literal compiles, passes, and is
  invisible to every gate but a real compile. → `why.md` §2
- **Read `git diff --stat` before every commit** and check the shape is the one you meant.
  It is the only gate a docs-only change has.
- **The ledger row lands before the commit**, and its `scene-tree` capture lands **while
  the diff's node is still in the tree** — one capture per screen, not one per run.

**3. Add to `kanban.md` before reflecting** — features, UX, juice, animation, lore, or a
concrete improvement. Snapshot citations before step 2's edits and check them after:

```bash
python tools/citation_check.py --beads --snapshot .devtools/citations.json  # before step 2
python tools/citation_check.py --beads --against  .devtools/citations.json  # after step 3
```

Follow `.claude/skills/kanban-idea-pass/SKILL.md`, which holds the five citation rules and
is not optional reading. Taste needs no citation; a claim about the code does. → `why.md` §3

**If `--against` reports more than ten drifted, the relocation is a WORK ITEM, not part of
this step.** Fix what your own entries cite, file the rest as a bead, and say in the close
how many you left. Cycles 139 and 140 each absorbed it silently and each spent something
like a third of the cycle there — 11 dead citations then, 9 more now — because the count
is set by how many lines the feature happened to insert, which is nothing to do with what
the cycle is for. **Every one of those twenty was already wrong before the cycle that found
it**, so this is real work and it deserves to be scheduled rather than to arrive as a tax
on whichever feature touched a busy file.

**4. Reflect on the HARNESS, now that you have used it.** Was it worth it
(`warranted`/`overkill`/`insufficient`/`inconclusive`, with the reason) — write the
`log-devtools.md` entry. What was missing — file it as `[G-NNN]`, and upstream it with
`skill-feedback-issue` if it is concrete enough to name what should change. Reconcile the
old gaps with `python tools/gap_ledger.py --open`. → `why.md` §4

**5. Reflect on THIS WORKFLOW and tweak it.** Change at most one thing per cycle and say
why in the commit message. Prefer DELETING a rule that has stopped earning its place to
adding a twelfth. Edit it **here**, never in `CLAUDE.md` (whose `# workflow` block is only
the pointer) and never inside the harness's `BEGIN`/`END` markers. If nothing needs
changing, say so explicitly — silence is indistinguishable from not having looked.

**6. Refill the queue, then update the log.** File 3-8 concrete items as bd issues drawn
from step 0's sources plus what steps 4 and 5 produced, naming which source each came from.
At least one must come from outside this cycle's neighbourhood, **and at least one must be
something a PLAYER would notice** — step 2's bias is worthless over a queue with nothing to
bias toward, and a queue of 85 that is nearly all audits, checkers and "decide whether" is
what fifty cycles of refilling from reflection produces. → `why.md` §6

- **Never put prose in ANY `bd` field as a shell argument** — backticks are command
  substitution and a word that is also a command lands its output in the field silently.
  Write a file and use `--body-file` / `--stdin` / `"$(cat PATH)"`.
- A source pointing at an already-open bead gets a note on that bead, not a duplicate.
- An acceptance criterion must be something the closing commit can produce, or you have
  written two beads and filed one.
- Then rewrite `cycle-log.md`: bump the number, a sentence or two on what this cycle
  taught, refresh what is waiting on the user. Prose, not a checklist. → `why.md` §6

**7. Go straight back to step 1. Do not stop, do not ask whether to continue, do not say
"next session" — you are the next session.** The only reasons to stop are the user saying
so, or a genuine block only they can unblock.

## Gates

```bash
python tools/check_all.py --quiet     # every parallel-safe checker, list DERIVED (~4s, every cycle)
python tools/survey_all.py --quiet    # every .claude/surveys/ script (~30s, every few cycles)
```

Neither compiles. Only `import_check.py` and `lint_project.gd` do, and neither is
parallel-safe. → `references/gates.md`

## Skills

When a skill would have been useful, create it in `.claude/skills/<name>/SKILL.md` —
**identifying it twice without building it is the failure mode.** Then USE it in the same
cycle, on real code you did not write it about; the first application is what tells you
whether it is a recipe or an essay.

> This loop was the top 411 lines of `CLAUDE.md`, mirrored into `AGENTS.md`, until it moved
> here as one file with one copy. `mirror_check.py` still guards the pointer left behind.
> The `fan-out-a-cycle` and `loop-forever` skills were merged in on 2026-08-19: fan-out
> became `references/fan-out.md`, and `loop-forever` was superseded outright — it told the
> agent to keep a TodoWrite list and treat `kanban.md` as the queue, both of which this loop
> replaced with `bd`.
