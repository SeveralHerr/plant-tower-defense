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

0. **Pre-flight. Read these four things and report them in one line, as four named
   values.** Four values, four names — `beads=N ready`, `skills=N (none named twice)`,
   `kanban=<the section you looked at>`, `mirror=0`. Named, because cycles 72-75 each
   reported a mirror exit code, a ready count and a skills listing and **silently dropped
   the `kanban.md` one**, which is the item with no exit code and therefore the only one a
   habit of running commands cannot cover. A line with three values in it looks exactly
   like a line with four. This
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
     **When it fires, run `python tools/mirror_check.py --fix`** — it generates
     `AGENTS.md`'s copy from `CLAUDE.md`'s and re-checks from disk. Identical by
     construction beats identical by care, and care is what has now failed three times;
     the third was the cycle that hand-edited both copies of a rule about being careful.

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
   - **If the last two cycles worked the same file or subsystem, take something else.**
     Step 6 already forces one FILED item to come from outside the neighbourhood; nothing
     forced the WORK to vary, and it does not on its own. Cycles 60 and 61 both worked the
     HUD message row; 62 and 63 both worked one Python checker. Each was the honest next
     thing, because finishing a piece of work is what exposes the next piece of it — the
     same structural pull step 6 was written for, one step earlier. The queue is 80+ items
     deep and most of it is nowhere near whatever just shipped.
   - **Write code with the Edit/Write tools, never through a shell heredoc.** A heredoc
     silently eats one level of backslash escaping and, worse, has now stripped the
     leading `#` from GDScript comment blocks four separate times. Cycle 54's instance
     produced a `test_placement.gd` that would not compile, and the suite reported
     `Total: 490 | Passed: 490 | Failed: 0 | ALL TESTS PASSED` — sixty-seven tests
     silently absent, reported as a clean run. Only the denominator (490 against 557)
     and exit `2` caught it. Four occurrences and an "environment note" in the log each
     time is not a countermeasure; using the right tool is.
   - **If the cycle launched the game at all, run `findings` before quitting it.** It is
     the harness's headline check — every zero-config check at once against the live tree
     — and it was last run in cycle 48. Twelve cycles of runtime work went past on
     hand-picked `get-state` reads, each answering the question I already had in mind,
     which is exactly the coverage a checklist of known failure modes exists to replace.
     Cycle 60 ran it and learned the UI baseline no longer exists, so every `ui_layout`
     finding has been gating as NEW for an unknown number of cycles. Read the NEW/PRE
     split and the `By check:` denominator — and **run it UNPAUSED**. `pause` freezes
     containers mid-layout as readily as it freezes a tween mid-fade: cycle 60 got four
     `ui_transparent` findings from a panel caught mid-entrance, cycle 65 got a
     `container_layout_drift` on a label whose HBox had not finished laying out, and both
     went to zero the moment the tree stepped again.
     **When a `ui_layout` finding does appear, settle and re-run BEFORE believing it — and
     before dismissing it.** Cycle 79 got one `container_layout_drift` immediately after a
     message-row text change on an unpaused tree, which is a state the warning above does
     not cover. Relaunch, `wait-frames 90`, re-run; then re-trigger the state, settle
     again, re-run. Zero twice is a transient; the same finding twice is real and the
     record is at `user://findings_last.json`. This matters more here than in most
     projects because the UI baseline is **empty** (`-v9px`), so every `ui_layout` finding
     gates as NEW and there is nothing to compare it against — the re-run IS the baseline.
   - **Read `git diff --stat` before every commit and check the shape is the one you
     meant.** Not the diff — the shape: how many files, how many lines each way. It costs
     one command and it is the ONLY gate a docs-only change has, since `/verify` triages
     those to "nothing to verify" and no checker reads prose. Cycle 64 cut three sections
     out of `kanban.md` with a `text.index()` on a section heading that turns out to
     appear twice; the intended cut was 85 lines and the diff said **1937**. Nothing else
     in the loop would have caught it, and a markdown file is exactly where nobody looks
     twice.
   - **The ledger row lands BEFORE the commit, never after.** `reach` is the diff
     intersected against what the running game loaded, and after a commit the diff is
     empty — so a row recorded afterwards reads `reached 0/0 changed file(s)`, which is
     indistinguishable from a run that never started. Cycle 48 did exactly this and
     produced a `warranted` row carrying no evidence for the verdict. If you ran the
     gates by hand instead of through `/verify`, you owe the row by hand too, and it is
     due while the work is still uncommitted.
     **A diff confined to a screen the entry hook does not open reaches NOTHING, and the
     run will look clean while doing it.** Cycle 82 changed four files across the options
     screen, the notebook and the run-summary card, launched, got `0 finding(s) across 5 of
     5 checks`, and recorded `reached 0/4 changed file(s)` — the session sat on the board
     and never navigated. Nothing in `/verify` navigates. `entry_points` has exactly one
     entry (`campaign`), so every other screen is reached only by driving to it: press the
     button, or add the screen as a named entry point and `fire-entry-point` it. **Decide
     which before launching**, because a clean pass on an unreached diff is a statement
     about the game rather than about the change, and it is indistinguishable from a real
     one until you read the ledger row.
     **And the reach snapshot is due before `quit`, not before the commit.** `reach` is
     computed from a `scene-tree` capture of a game that is still running, so the row's
     evidence has an earlier deadline than the row — and `quit` is the natural last verb of
     a runtime pass, which destroys the only thing that can prove the run loaded the diff.
     Cycle 69 quit, then had to relaunch and re-drive the entire scenario to record a row it
     had already earned. Make `python tools/devtools.py scene-tree > .devtools/tree.json`
     the last thing you do before `quit`, every time, even when you do not yet know the
     verdict.
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
     **A follow-on `:NN` binds to the last full path before it, left to right, and never
     across an entry boundary.** Entries here write `` (`game/sfx.gd:86`, `:91`, `:106`) ``
     — 44 such references in `kanban.md`, a shorthand the file invented and nothing knew
     about until `tools/citation_check.py` learned it in cycle 77. Binding them found a
     reference written as a bare `:331` in a sentence whose nearest preceding citation was
     `game/chomp_flower.gd`, a file with 183 lines; the intended target was named earlier in
     the same sentence, which is why no reader caught it. If the path you mean is not the
     last one you wrote, **write it out in full** — the shorthand is for a run of lines in
     one file and nothing else.
   - **Search for the BEHAVIOUR, not for one implementation of it.** This is the absence
     half of the rule above and it fails differently: cycle 70 wrote "no plant has idle
     motion, verified unbuilt" after enumerating every `create_tween()` call on every
     plant and finding all eight event-driven. The enumeration was complete, correct, and
     about the wrong set — `Plant._wobble` has swayed every plant since the first playable
     build and `Pest._gait` animates every pest, and both are `_process`-driven sinusoids
     that no census of tweens can see. **An enumeration over the wrong set is worse than
     an example, because it looks exhaustive**, and this one survived a cycle, became a
     bead, and was claimed before anyone opened the file. So grep for the PROPERTY the
     feature would move (`rotation`, `scale`, `sin(`) rather than for the one API you
     imagine it using, and when you write the claim down, say which mechanism you searched
     for — that sentence is what lets the next reader notice the set was wrong.
   - **An entry claiming a PATTERN needs the enumeration, not an example.** "All the X do
     Y", "these are consistent", "nothing does Z" — one citation cannot support any of
     them, and a citation that happens to be true makes the whole claim read as checked.
     Cycle 67 wrote that four drawn cues shared a grammar (dashed = a remark, solid = a
     range, filled = a gain, doubled = armed). Cycle 68 derived it from all 55 `draw_`
     calls and found "solid = a range" violated twice, once by a cue written two cycles
     earlier. `derive-the-list` says this about lists in code; it is the same rule for a
     claim in prose, and the grep that would settle it belongs in the entry.
   - **An entry that COMPARES two things needs a citation for both halves.** One
     `file:line` makes the whole entry read as sourced, including the half taken from
     memory. Cycle 65 wrote "death has a sound, a corpse and a linger; escape has none of
     the three", citing `DEATH_LINGER` for the death half. The escape half was false in
     every particular — `Sfx.PEST_ESCAPED` plays, `_note_lane_loss` tints the exit cell,
     and `_punch_readout(_lives_label)` fires on the changed count — and cycle 66 claimed
     the bead before finding out. **The asymmetry you are pointing at is the claim; the
     side you say is empty is the half that needs opening.**
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
   - **Reconcile the old gaps.** `python tools/gap_ledger.py --open` says which are
     actually open; it derives each status from its LAST mention, because the format
     records status per entry and a gap fixed in cycle 12 still carries its cycle-4
     `open` line. Do NOT rewrite old entries — append the new status and let the tool
     resolve it. Two traps, both paid for: `grep -c "status: open"` counts LINES and
     said 61 when the answer was 44; and an id **cited** in the installed harness is
     not thereby fixed — 43 of this project's ids appear in 0.38.0 but 29 of those are
     only in the harness's copy of this log, and G-044 is cited in code while still
     failing. Anything now actionable in-project goes into step 6's refill.
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
     **If a source points at a bead that is already open, add a note to THAT bead — do
     not file a duplicate in order to close it.** Cycles 53, 54, 55 and 56 each filed one
     item whose own description said "duplicate of the open X, filed only to record the
     second identification", then closed it in the same breath. The evidence is worth
     recording and the bead is not: `bd update X --notes` puts it where the person
     working X will read it, and leaves the ready count honest. A second identification
     is also a reason to raise the priority, which a closed duplicate cannot do.

     **Write the description to a file and pass `bd create --body-file PATH`. Never
     `-d "..."`.** A description passed as a shell argument goes through the shell, where
     backticks are command substitution: the word vanishes and the only tell is an
     unrelated `command not found` on stderr, easy to miss beside beads' own export
     chatter. It has happened in cycles 76, 78 and 83 — each time *after* a standing note
     told me not to use backticks, which is what makes this a tooling rule rather than
     another note. **A word that is also a valid command (`date`, `test`, `find`) is
     substituted silently, with its output landing in the description.** A file written
     with an editor tool never touches a shell, so quoting, escaping and `file:line`
     citations all survive — which matters because the rule below requires those citations.
     `--stdin` and `--design-file` are the same mechanism for the other fields.
     **Name which source each came from, in the issue.** This step used to say "out of
     kanban.md's backlog", and that single filename is what made every other source
     invisible for 33 cycles. Never end a cycle with nothing ready.
   - **Step 3's citation rules apply to a bead description too.** They were written for
     `kanban.md` and a bead is where the claims actually get acted on: a factual sentence
     in a description is read by whoever claims it, usually cycles later, and is trusted
     because it looks like a finding rather than a memory. Three cycles running, an
     absence claim written into a bead was wrong — "no plant has idle motion" (cycle 70,
     the wrong enumeration), "`step-time --then-pause` has never been used in 71 cycles"
     (cycle 71, contradicted by `log-devtools.md:3378`), and both were written in the same
     breath as filing the item. So: cite the `file:line`, enumerate the pattern, and
     search for the behaviour rather than for one implementation of it — in the issue, not
     only in the backlog. A description that says "verified unbuilt" and does not say
     **how** is a memory wearing a finding's clothes.
   - **An acceptance criterion must be something the closing commit can produce, or you
     have written two beads and filed one.** `-6cqi` asked that two plants at different
     levels be distinguishable on the board "and a screenshot proves it". The code half
     shipped in the cycle that filed it. The evidence half needed a running game and a
     rendered frame, which no commit produces, so the bead sat ready for **twelve cycles**
     looking like unbuilt work while the feature was already in the game. When the
     criterion names evidence — a screenshot, a measurement, a session driven by hand —
     either split it out as its own item or say in the bead that the code is expected to
     land first and this is the audit. Both are honest; a single bead that is silently
     half-done is not, and it is indistinguishable in `bd ready` from work nobody started.
   - **At least one item must come from OUTSIDE the neighbourhood of this cycle's
     work.** Cycles 30-34 shipped one player-facing change and eleven correctness or
     tooling ones, and the cause is structural rather than a matter of taste: the
     queue is refilled from what the last cycle's work exposed, and step 3's
     cite-a-`file:line` rule — which is right, and has caught three bad entries —
     makes citing *easiest for the file you already have open*. So the loop keeps
     finding real work three feet from where it just stood. Take one item from an
     older `kanban.md` section, or from the design brief, and run
     `kanban-staleness-audit` over that section first, since those are the parts the
     file itself calls half stale.
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

**Then USE it in the same cycle, on real code, before the cycle ends.** A skill built and
never applied fails the same way a skill identified and never built does — it becomes
prose nobody has tested. Cycle 51 built `scope-vs-claim` and immediately turned it on the
budget system: inside twenty minutes it found a budget still missing five of eight
producers a full cycle after being "fixed", a table asserted in one direction only, a
second hand-list nobody knew was a second list, and a stale sentence in `cycle-log.md`
itself. None of that would have surfaced from writing the skill well. **The first
application is what tells you whether the skill is a recipe or an essay** — and the first
target should be code you did not write it about.

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
python tools/message_corpus_check.py # a show_message() call site, or a producer's bool
                                     #   variant, the row's budget never measures
python tools/mirror_check.py         # CLAUDE.md and AGENTS.md's Workflow blocks have drifted
                                     #   (--fix generates the mirror; it WRITES AGENTS.md,
                                     #    so it is the one entry here not safe to fan out)
python tools/citation_check.py       # a `file:line` citation in kanban.md (or any .md you
                                     #   name) that no longer resolves. READ THE OUTPUT:
                                     #   it proves a line EXISTS, never that it supports
                                     #   the claim — and it prints how many entries carry
                                     #   no citation at all, which is 249 of 323 in
                                     #   kanban.md and the real limit on every check here
python tools/run_json_check.py       # a key in .devtools/run.json that verify_ledger reads
                                     #   nowhere, so the ledger row silently loses it.
                                     #   RUN IT BEFORE `verify_ledger record`, not after —
                                     #   the row is append-only and a dropped key is
                                     #   indistinguishable from a run that never had one
python tools/gap_ledger.py           # which [G-NNN] gaps are actually open (advisory)
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
