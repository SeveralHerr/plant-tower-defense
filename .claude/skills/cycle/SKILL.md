---
name: cycle
description: Run one cycle of this project's development loop — pre-flight (beads, skills, kanban, mirror), take the ready bd items one at a time (confirm → claim → implement → /verify → commit), add to kanban.md, reflect on the harness and on the workflow, refill the queue, update cycle-log.md, then start the next cycle. Use when asked to work the queue, run the loop, do a cycle, or keep going; it does not end until the user stops it.
---

# workflow
**This is a loop. It does not end. Keep going until the user stops you.**

Workflow intent: Keep the workflow simple and meaningful. Reflect on the game, tools, workflow, skills, and find meaningful ways to evolve them all.

**Within that, bias step 2 toward what a PLAYER would notice** (asked for directly, cycle
84). The tooling, the audits and the checkers are how this project stays honest and
they have taken most of the last ten cycles: 72, 75, 77, 82 and 83 shipped nothing a player
could see, and 76 shipped no code at all. A checker or an audit is still the right call when
it is the right call — this is a bias, not a ban. But **a cycle that ships nothing
player-facing owes one sentence in its close saying why**, the same way step 5 owes one when
the workflow does not change, and two such cycles in a row means step 2 takes a
player-facing item next whatever else is ready.

**"Simple" is a constraint on this file too.** It is 354 lines and has grown almost every
cycle. Step 5 may now spend its one change on DELETING a rule that has stopped earning its
place, and should prefer that to adding a twelfth.


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
     out of them — a wrong `STALE` deletes an idea nobody will have again.
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
     **Since the loop moved into this skill, the mirrored block is the nine-line POINTER
     to it** in `CLAUDE.md` and `AGENTS.md`, not the loop itself — the check now guards
     that a reader of either file is still told where the loop lives, which is the same
     silent-deletion failure at a smaller size. The loop text has one copy: this file.

   - **The cycle counter, DERIVED and not read.** `cycle-log.md`'s top line against
     `git log --oneline | grep -oE "Close cycle [0-9]+" | awk '{print $3}' | sort -n | tail -1`.
     **The MAX, not a count** — the first draft of this bullet said `grep -c` and got 72,
     because the early cycles' commits are worded differently and a count is not an index.
     Caught within a minute by running it, which is the argument for a derived check being
     a command you actually run rather than a number you write down.
     The two disagreed at cycle 110 by three:
     the file said `# Cycle 106` while `.claude/bead-audit-cycle109.md` existed and
     `kanban.md:14` cited cycle 108. Cause: the work started calling itself "round 11".."round
     15" in `log-devtools.md` and step 6's "bump the cycle number" was never run again.
     This is the same silent-drift shape as the mirror — a file that quietly stops being
     updated rather than a list that fills up unread — and it belongs beside the mirror for
     that reason. Derive it; do not read the number and believe it. **If they disagree, the
     first thing this cycle writes is the missing sections**, because the counter is what
     every other retrospective in the loop is indexed by.

   The harness is deliberately NOT checked here — it is checked in step 4, after it has
   actually been used. Pre-flight REPORTS AND FILES, it does not block.

1. **Read `cycle-log.md` for context, then `bd ready` for the work.** The log gives you
   the cycle number and what the last cycle learned — read it first, especially after a
   compaction. The beads ARE the queue; there is nothing to transcribe. This step used
   to say "read `todo.md`, file every item as a bd issue", which wrote every item twice
   and ticked it twice. (Do NOT use TodoWrite for any of this.)
2. **Do the items one at a time.** For each one: **confirm the bead's claims, then**
   claim the bd issue, write the code, run `/verify`, then commit. One commit per item.
   Never batch several items into one commit at the end.
   - **`confirm` is a step and it comes before `claim`.** This step said "claim the bd
     issue, write the code" for 88 cycles, which is the wrong order and contradicts
     `.claude/skills/verify-bd-item/SKILL.md` — the skill written for exactly this
     sequence, whose diagram reads `confirm → claim → implement` and whose first
     instruction is to open the code the bead says is missing. Follow the skill; this
     bullet exists so a reader working from the loop rather than from the skill does not
     get the order backwards. Cycles 70, 84, 86 and 88 each claimed a bead whose factual
     claim was wrong or already satisfied, and cycle 88's (`-beq1`, "nothing says a pest
     carries two traits") was shipped **by the cycle that filed it** — `markers_for`
     returns one mark per flag twenty lines below the `_tint` call the claim was read
     from, and the test the acceptance asked for was written the same day.
     A bead is a claim about the repo made at some past cycle, and the repo has moved.
   - **RUN INDEPENDENT ITEMS IN PARALLEL (asked for directly, cycle 99).** The loop has done
     one item at a time for 99 cycles and the queue is 100 deep; most of it does not touch
     what the rest of it touches. Spawn agents for items whose files do not overlap, and say
     in the close which ran together and why they were safe.
     **The safety rule is one command, not a count.** A lane runs
     `python tools/check_all.py --quiet` and nothing else; it derives the parallel-safe set
     for itself. This used to name "`name_check.py` and the eleven project checkers", which
     was a hand-maintained number in a file about not hand-maintaining numbers — it was
     already fifteen when `check_all.py` replaced it, and it would have gone on drifting.
     `lint_project.gd`, `import_check.py` and `run_tests.py` all open the project and write
     `.godot/`, and **two of them at once corrupt each other's run**. So a fan-out agent
     writes code and runs that one command; the engine gates and the runtime pass are the
     parent's, run once, after the agents land. Same for the game: one bus per checkout
     (`launch --isolated` isolates the bus, never `user://`).
     **Write the lane prompts with `.claude/skills/fan-out-a-cycle/SKILL.md`** — it holds
     the ownership block, the traps every lane needs told, and the report format the merge
     needs, all of which were re-derived from scratch in cycles 100, 101 and 102.
     **Give each agent disjoint files and say so in its prompt.** Two agents editing
     `hud.gd` is a merge conflict the loop has no step for; two agents editing `mint.gd` and
     `wave_director.gd` is free. If two items want the same file, they are one item.
     **When several lanes each need one line in the SAME registry file, the PARENT owns that
     file** and adds every line after they land. Cycle 100 held `test_sprite_style.gd` back
     that way — two lanes each added a sprite and each needed an `EXPECTED_SIZE` row, which
     is the one collision that was guaranteed rather than possible. Tell each agent the file
     is held and to report what its row should say. This is not the same as "they are one
     item": the items were genuinely independent and only their bookkeeping overlapped.
     **Budget for the merge, because that is where the failures are.** Cycle 100's three
     lanes each ran all eleven parallel-safe checkers clean, and the merge failed FIVE times
     — a golden array and a hardcoded wave pair broken by another lane's growth, a
     "decide about this here" gate tripped by a new plant, a test that funded a purchase but
     never unlocked it, a doc string 119 characters over budget. **None was a mistake by the
     agent that caused it**; each was a fact about a file it was correctly forbidden to open.
     The parent pass is where parallel work integrates, its cost scales with the number of
     lanes rather than the size of any one, and it is not optional.
     **A worktree per lane is the default now — `isolation: "worktree"` on the Agent call.**
     The checkers are parallel-SAFE, not parallel-ISOLATED: they open no project and take no
     lock, but they READ THE WORKING TREE, and in one shared checkout that tree contains
     every sibling's half-finished edit. Cycle 101's Nettle lane got `suite_reach_check
     exit=1` with 12 NEW findings, all in three files it had never opened. It caught that
     itself — but only because it thought to check, and the same accident in reverse hands a
     lane a clean exit it did not earn. A worktree removes the class: five lanes ran with it
     and not one reported a sibling's file. Keep saying "a finding in a file you do not own
     is not your finding" in the prompt anyway; it costs a line and it is still true of
     anything shared.
     **A worktree also ADDS a hazard, in the checkers themselves.** A lane's own path
     contains `.claude/worktrees/`, so any tool excluding nested checkouts by testing an
     ABSOLUTE path (`"worktrees" in path.parts`) excludes the entire repo when run from
     inside a lane. `citation_check.py` did exactly that after cycle 102 "fixed" it: the
     parent read `298 resolved`, a lane read `260` and 38 bogus advisories — the same
     asymmetry as the original bug, pointing the other way, and invisible to whichever
     side you were not standing on. Exclusions must be computed RELATIVE to the tool's own
     root; `tools/repo_walk.py` is the one place that rule now lives, and the rooted
     checkers import it rather than each carrying a copy.
     **What it costs, measured rather than assumed (`-l638`).** A fresh worktree has never
     been imported, so it has no `.godot/`, and **`name_check.py --require-compile` does not
     work there** — two lanes ran it independently and both got exit 1 with fabricated
     `Identifier "WaveDirector" not declared` / `Could not find base class "Plant"` errors on
     lines they had not touched. So a lane gets NO compile at all, and that is the real cost
     of the fan-out: **five lanes each reported green having never parsed a line.** Budget
     the parent pass accordingly — this cycle's merge found two tests that were green by
     construction, a top bar with no room for the button it was given, three public surfaces
     no test named, and a checker reporting nonsense (see below). None was a lane's mistake.
     **The worktrees live INSIDE the repo (`.claude/worktrees/`), which is its own trap.**
     `citation_check.py` resolves a bare filename by unique basename anywhere under the
     root, and `rglob` does not read `.gitignore` — so five lanes turned every citation in
     `kanban.md` into a six-way ambiguity. It is fixed there, but the shape generalises:
     **any checker that walks the repo tree sees N+1 copies of everything during a fan-out,
     and only the PARENT sees them.** A lane inside its own worktree reports clean. If a
     tree-walking checker starts reporting mass findings mid-cycle, look at
     `.claude/worktrees/` before believing any of it.
     **Clean the worktrees up when the lanes land** (`git worktree remove`), or the next
     cycle's tree-walkers inherit the same six-way ambiguity.
     **And the parent owes each lane's wiring, not just its merge.** Cycle 101's upgrade
     lane correctly refused to touch `hud.gd` and `game.gd` and listed seven exact edits it
     needed there. Skipping them would have shipped a plant whose upgrade ladder no player
     could reach — three files of dead code, all gates green. A lane that reports "needs
     these lines in a parent-owned file" has not finished until the parent writes them.
   - **If the last two cycles worked the same file or subsystem, take something else.**
     Step 6 already forces one FILED item to come from outside the neighbourhood; nothing
     forced the WORK to vary, and it does not on its own. Cycles 60 and 61 both worked the
     HUD message row; 62 and 63 both worked one Python checker. Each was the honest next
     thing, because finishing a piece of work is what exposes the next piece of it — the
     same structural pull step 6 was written for, one step earlier. The queue is 80+ items
     deep and most of it is nowhere near whatever just shipped.
     **The player-facing steer at the top of this file OUTRANKS this rule, and says so
     here so the override is a decision rather than a lapse.** Cycles 91 and 92 both worked
     the notebook: 91 built the cue legend, 92 made it reachable from a paused run, and the
     second was the highest-value player-facing item on the board precisely *because* the
     first had just shipped. Varying the subsystem exists to stop the queue being refilled
     only from what the last cycle exposed; it does not exist to strand a feature one step
     from being usable. When they conflict, take the player-facing item and **say in the
     close which rule you overrode** — that sentence is what makes a third cycle in the same
     subsystem visible as a pattern instead of arriving unnoticed.
   - **Write code with the Edit/Write tools, never through a shell heredoc.** A heredoc
     silently eats one level of backslash escaping and, worse, has now stripped the
     leading `#` from GDScript comment blocks four separate times. Cycle 54's instance
     produced a `test_placement.gd` that would not compile, and the suite reported
     `Total: 490 | Passed: 490 | Failed: 0 | ALL TESTS PASSED` — sixty-seven tests
     silently absent, reported as a clean run. Only the denominator (490 against 557)
     and exit `2` caught it. Four occurrences and an "environment note" in the log each
     time is not a countermeasure; using the right tool is.
     **This includes a Python script in a heredoc that writes the file** — that is the same
     shell, plus a second escaping layer, and it is the shape the rule keeps getting broken
     in because it is what you reach for **when `Edit`'s exact match fails**. Cycle 97 hit a
     tab-versus-space mismatch, fell back to a line-range splice in Python, and
     `section.find("\n## ", 1)` landed in the file as a **literal newline inside the string
     literal**. Godot accepts that: 613/613 passed, lint reported 0/0, the behaviour was
     identical. The only gate that could see it was `suite_reach_check`, which reported four
     symbols as unnamed while they were plainly there — because everything after the splice
     was inside a string as far as any parser was concerned.
     **When `Edit` will not match, the fallback is `Read` the exact bytes and `Edit` again,
     or `Write` the whole file — never a script that writes code.** And note what this cost:
     five gates agreed with me and one disagreed, and the one that disagreed was right.
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
   improvements (UX, game juice, animations, enhancements, or full features).
   - **Follow `.claude/skills/kanban-idea-pass/SKILL.md`, which is not optional reading.**
     It holds the five citation rules this step used to state inline — cite a `file:line` for
     every claim about code as it is now, search for the BEHAVIOUR not one implementation of
     it, enumerate a pattern rather than exampling it, cite BOTH halves of a comparison, and
     read a collection's SHAPE before claiming membership in it — each with the cycle that
     paid for it. They moved out because this file is 826 lines and the rules were 50 of
     them, and because **step 6 needs the same rules for a bead description** and was
     pointing back up here to get them. A skill can be cited from both places; a numbered
     step cannot.
     The one thing the skill cannot say for you: it is about the sentence claiming the game
     does not do this yet. **Taste needs no citation** — assert a preference plainly and let
     it be argued with.
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
   - **The workflow is edited HERE, in `.claude/skills/cycle/SKILL.md`** — never in
     `CLAUDE.md`, whose `# workflow` block is only the pointer to this file (mirrored into
     `AGENTS.md` by `mirror_check.py --fix`). And never between `CLAUDE.md`'s
     `BEGIN`/`END godot-selftest-harness` markers: everything there is regenerated by
     `/scaffold-godot-harness` and an edit is silently lost on the next refresh.
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

     **Never put prose in ANY `bd` field as a shell argument — not `create -d`, not
     `close --reason`, not `update --notes`. Write it to a file first.** Prose passed as a
     shell argument goes through the shell, where backticks are command substitution: the
     word vanishes and the only tell is an unrelated `command not found` on stderr, easy to
     miss beside beads' own export chatter. **A word that is also a valid command (`date`,
     `test`, `find`) is substituted silently, with its output landing in the field.**
     It has happened in cycles 76, 78, 83 and 91 — each time *after* a standing note told
     me not to use backticks, which is what makes this a tooling rule rather than another
     note. Cycle 91 is why this rule now says ANY field: it named only `create -d`, so
     `bd close --reason "...an if/elif/else whose \`else\` MEANT one kind..."` read as
     covered, and the close reason landed reading "whose  MEANT one kind" — a sentence that
     is still grammatical, which is the whole problem. The mechanism was never about
     `create`.
     `--body-file` takes the description; `--stdin` and `--design-file` are the same
     mechanism for the other fields; for anything with no file flag, write the file and
     pass `"$(cat PATH)"` — the substitution happens once, on content the shell has already
     finished with. A file written with an editor tool never touches a shell, so quoting,
     escaping and `file:line` citations all survive — which matters because the rule below
     requires those citations.
     **Name which source each came from, in the issue.** This step used to say "out of
     kanban.md's backlog", and that single filename is what made every other source
     invisible for 33 cycles. Never end a cycle with nothing ready.
   - **`kanban-idea-pass` applies to a bead description too — same skill, and a bead is
     where the claims actually get acted on.** A factual sentence in a description is read
     by whoever claims it, usually cycles later, and is trusted because it looks like a
     finding rather than a memory. Three cycles running, an absence claim written into a
     bead was wrong — "no plant has idle motion" (cycle 70, the wrong enumeration),
     "`step-time --then-pause` has never been used in 71 cycles" (cycle 71, contradicted by
     `log-devtools.md:3378`) — and both were written in the same breath as filing the item.
     Cycle 88's `-beq1` was worse: the claim was satisfied twenty lines below the line it
     was read from, and the bead was filed by the cycle that shipped the feature. A
     description that says "verified unbuilt" and does not say **how** is a memory wearing
     a finding's clothes.
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

**Where edits to `CLAUDE.md` may go.** Everything between its `BEGIN`/`END
godot-selftest-harness` markers is regenerated by `/scaffold-godot-harness`, so an edit
there is silently lost on the next refresh. That is why step 4's gap-reconciliation
rule lives here in the project's own loop rather than beside the `[G-NNN]` format
it belongs with, and it is the same trap as editing anything under `tools/` or
`addons/` — check `.harness_manifest.json` first. This skill file has no managed
region; all of it is the project's own and may be edited by step 5.

**Parallel-safe gates. Run them with one command:**

```bash
python tools/check_all.py --quiet     # every parallel-safe checker, list DERIVED
```

It discovers its own set — any `tools/*.py` declaring the house contract's `NOT COVERED:`
line — runs them concurrently, and prints `ran N of M discovered` plus a classification of
every `tools/*.py` into checker / not-parallel-safe / known-non-checker / **unclassified**.
That last category is the point: a new tool that is neither derived nor listed fails the
run, so a checker can no longer be written and silently never run. `import_check.py` is
excluded by name with a reason (it opens the project); a checker that could not run is
named, never dropped from the denominator.

**The list below is now a DESCRIPTION of what that command finds, not the source of truth.**
Adding a checker here does not make it run; giving it a `NOT COVERED:` line does. It is kept
because the per-tool commentary is what tells you how to read each one's output:

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
python tools/bead_prose_check.py     # prose the SHELL ate on its way into `bd` -- a word
                                     #   inside backticks is command substitution, and one
                                     #   that IS a command (`date`, `pwd`) lands its OUTPUT
                                     #   in the field silently. Gates on open issues only;
                                     #   closed ones are advisory. THE WAIVER IS THE
                                     #   CORRECTION NOTE -- an issue that records what was
                                     #   eaten stops firing, which is why the rule below is
                                     #   "add a note", never "rewrite the field"
```

Each prints its own `NOT COVERED:` line. None of them compiles — only `import_check.py`
and `lint_project.gd` do, and neither is parallel-safe.

Whenever a good skill that would've been useful has been identified, please create it
locally in this repository.

> This loop used to be the top 411 lines of `CLAUDE.md`, mirrored verbatim into
> `AGENTS.md`. It moved here so it is one file with one copy, invocable as `/cycle`.
> `CLAUDE.md` and `AGENTS.md` keep a `# workflow` block that is only the pointer to this
> file; `mirror_check.py` still guards that pointer, because the block it points from has
> been silently deleted twice before.
