# Agent Instructions

# workflow
**This is a loop. It does not end. Keep going until the user stops you.**

Do these steps in order, over and over:

**`bd` IS THE WORK QUEUE. `cycle-log.md` IS THE NARRATIVE.** They are not two lists of
the same thing. Every item lives in `bd` and nowhere else — status, priority, blocked
state, dependencies and close reasons are real fields there and were being copied by
hand into a markdown checklist that could drift from them. `cycle-log.md` holds only
what `bd` structurally cannot: the cycle counter, the pattern the last cycle taught,
what is waiting on the user, and how to restart. It is what a human reads without
running a command. **Never write a work checklist into it.**

0. **Pre-flight. Read these four things and report them in one line.** This
   step exists because they were write-only: the reflection steps below are
   end-of-cycle WRITES and nothing was ever a start-of-cycle READ, so they filled up
   and never came back. Measured at the end of the first 33 cycles: `.claude/skills/`
   did not exist at all, despite the standing instruction to create skills there, and
   `kanban-staleness-audit` had been named as missing three separate times without once
   being built.
   - **Open beads.** `bd ready` and `bd list --status=open`. Anything unblocked belongs
     in this cycle. If everything open is blocked, say so explicitly — that is a real
     result and it is when to mine `kanban.md` harder, not when to invent work.
   - **Skills to create.** The skill ideas in `C:\Users\gotmi\documents\github\log.md`
     against what exists in `.claude/skills/`. **Two independent identifications of the
     same missing skill means build it** — do not identify it a third time.
   - **`kanban.md`.** The recent cycle sections, and the idea backlog you are about to
     mine. The historical sections are unpruned and roughly half stale; the file says so
     at its own top. Use the `kanban-staleness-audit` skill before promoting anything
     out of them — a wrong `STALE` deletes an idea nobody will have again. (This bullet
     used to name a `STILL REAL` section; the file has no such heading and never did,
     so the instruction pointed at nothing for 33 cycles.)
   - **The mirror.** `python tools/mirror_check.py` — exit 0 identical, 1 drifted,
     `--show-diff` for what moved. This is here because the block has now been silently
     deleted from `AGENTS.md` **twice**, most recently by the very commit that wrote the
     note warning about it, which left the note dangling above nothing. Every other
     pre-flight item is a list that fills up unread; this one is a file that quietly
     empties, and nothing else in the loop ever opens `AGENTS.md`. It was a hand-run
     `diff` for one cycle and is a tool now — which immediately caught a one-sided edit
     nobody planted, the commit that registered the tool itself.
     **When it fires, generate the other copy from `CLAUDE.md` rather than retyping it:
     identical by construction beats identical by care, and care is what has failed
     twice.**

   The harness is deliberately NOT checked here — it is checked in step 4, after it has
   actually been used. Pre-flight REPORTS AND FILES, it does not block.

1. **Read `cycle-log.md` for context, then `bd ready` for the work.** The log gives you
   the cycle number and what the last cycle learned — read it first, especially after a
   compaction. The beads ARE the queue; there is nothing to transcribe. This step used
   to say "read `todo.md`, file every item as a bd issue", which wrote every item twice
   and ticked it twice. (Do NOT use TodoWrite for any of this.)
2. **Do the items one at a time.** For each one: claim the bd issue, write the code,
   run `/verify`, then commit. One commit per item. Never batch several items into one
   commit at the end.
3. **Before reflecting, always add to `kanban.md`** — cool new features or concrete
   improvements (UX, game juice, animations, enhancements, or full features). This used
   to read "the last item is always...", which described a checklist that no longer
   exists now that `bd` is the queue; it is a step of its own, not an item in a list.
   - **Every entry must name a `file:line` for the claim it makes about the code as it
     is now.** An entry says two things — "here is an idea" and "the game does not do
     this yet" — and only the first is free. Cycle 30 wrote five entries from inside
     `run_config.gd` without opening a screen: one proposed a feature that already
     ships in full (the milestone shelf, with a documented reason for the exact
     placement it suggested), one rested on a claim about `fresh_record` that is false,
     one over-claimed its scope. That is three of five, and the shelf one became a bead
     that was claimed and worked before the code got read. **An entry written from the
     neighbourhood of the file you happen to be in is a guess about the rest of the
     codebase.** Use `kanban-staleness-audit`'s bar: before writing that something is
     missing, open the code that would contain it.
4. **Reflect on the HARNESS, now that you have used it.** This comes after the work
   and not before, because "did the harness earn its keep" is a question about a run
   that has happened. Judge it on THIS cycle's usage:
   - **Was it worth it?** `warranted` / `overkill` / `insufficient` / `inconclusive`,
     with the reason. Write the `log-devtools.md` entry the harness section below
     requires. `overkill` is a useful answer and the one that goes unwritten.
   - **What was missing?** File it as a new `[G-NNN]`. If it is concrete enough to name
     what should change — a diff, a missing section, a script that should exist — and
     it ships from a repo I own, **also file it upstream** with the
     `skill-feedback-issue` skill, which files a report rather than a patch. Anything
     below that bar goes only in the log and is allowed to rot there.
   - **Reconcile the old gaps.** Flip any `[G-NNN]` the harness has since fixed to
     `status: fixed | shipped in X.Y.Z` before filing a new one. 33 cycles left 56 of
     60 saying `open`, three of which had already shipped — at which point the field
     means nothing. Anything now actionable in-project goes into step 6's refill.
5. **Reflect on THIS WORKFLOW and tweak it for the next run.** The steps above are not
   fixed; they are the thing most likely to be quietly wrong, because nothing else
   reviews them. Ask what actually happened this cycle: did a step get skipped, did one
   produce nothing, did the real work happen somewhere these steps do not describe?
   - **Change at most one thing per cycle, and write down why in the commit message.**
     A workflow that rewrites itself freely drifts; one that changes deliberately and
     records the reason can be read back.
   - **Only edit this file OUTSIDE the `BEGIN`/`END godot-selftest-harness` markers.**
     Everything between them is regenerated by `/scaffold-godot-harness` and an edit
     there is silently lost on the next refresh.
   - **If nothing needs changing, say so explicitly.** "The steps held this cycle" is
     a real answer; silence is indistinguishable from not having looked.
6. **Refill the queue, then update the log.**
   - **File 3-8 concrete, not-yet-filed items as bd issues** — drawn **from step 0's
     sources plus what steps 4 and 5 just produced**: open beads, skills to create,
     `kanban.md`, a broken mirror, harness gaps, and any workflow change worth its own
     item.
     **Name which source each came from, in the issue.** This step used to say "out of
     kanban.md's backlog", and that single filename is what made every other source
     invisible for 33 cycles. Never end a cycle with nothing ready.
   - **Then rewrite `cycle-log.md`**: bump the cycle number, write what THIS cycle
     taught in a sentence or two, and refresh what is waiting on the user and why.
     Keep it short and keep it prose — the moment it grows a checklist it has started
     duplicating `bd` again.
7. **Go straight back to step 1 and start the next cycle. Do not stop. Do not ask
   whether to continue. Do not say "next session" — you are the next session.**

The only reasons to stop are: the user tells you to, or you are genuinely blocked and
need an answer only they can give.

Keep a line at the top of `cycle-log.md` saying which cycle you are on (`Cycle 7`) and
bump it each time you refill, so the count survives a context compaction.

Whenever a good skill that would've been useful has been identified, please create it
locally in this repository, in `.claude/skills/<name>/SKILL.md`. **Identifying it twice
without building it is the failure mode** — the first 33 cycles named
`kanban-staleness-audit` three separate times and created nothing, because "identify a
missing skill" was an end-of-cycle note and never a start-of-cycle job. Step 0 reads
that directory; a skill named twice and absent from it is work, not an observation.

**Where edits to this file may go.** Everything between the `BEGIN`/`END
godot-selftest-harness` markers is regenerated by `/scaffold-godot-harness`, so an edit
there is silently lost on the next refresh. That is why step 4's gap-reconciliation
rule lives up here in the project's own section rather than beside the `[G-NNN]` format
it belongs with, and it is the same trap as editing anything under `tools/` or
`addons/` — check `.harness_manifest.json` first.

**Parallel-safe gates.** The harness section below says `name_check.py` is the only gate
safe to run in parallel. That is true of the *harness's* gates; this project ships three
more stdlib-only checkers that open no project and write nothing to `.godot/`, so a
fan-out agent can run them all:

```bash
python tools/name_check.py           # names (harness)
python tools/world_control_check.py  # a Control over the playfield eats clicks
python tools/meta_key_check.py       # set_meta/get_meta keys resolve at both ends
python tools/svg_style_check.py      # sprite style contract
python tools/group_leak_check.py     # a test that selects a node it did not create
python tools/suite_reach_check.py    # the public surface no test names
python tools/settle_read_check.py    # a test reading a value the settle frames were still moving
python tools/save_persist_check.py   # a test script that can reach RunConfig._save() unredirected
python tools/mirror_check.py         # CLAUDE.md and AGENTS.md's Workflow blocks have drifted
```

Each prints its own `NOT COVERED:` line. None of them compiles — only `import_check.py`
and `lint_project.gd` do, and neither is parallel-safe.

Whenever a good skill that would've been useful has been identified, please create it
locally in this repository.

> This Workflow block is mirrored verbatim in `AGENTS.md`. The two files are
> independent (not symlinked), and a sync that only knows about one of them silently
> deleted this section once already — keep both copies in step.
---

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

> **Architecture in one line:** Issues live in a local Dolt database
> (`.beads/dolt/`); cross-machine sync uses `bd dolt push/pull` (a
> git-compatible protocol), stored under `refs/dolt/data` on your git
> remote — separate from `refs/heads/*` where your code lives.
> `.beads/issues.jsonl` is a passive export, not the wire protocol.
>
> See [SYNC_CONCEPTS.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md)
> for the one-screen overview and anti-patterns (don't treat JSONL as the
> source of truth; don't `bd import` during normal operation; don't
> reach for third-party Dolt hosting before trying the default).

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

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

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
