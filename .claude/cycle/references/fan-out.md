# Fanning out a cycle: writing the lanes

Read this before spawning two or more agents on bd items, together with
`.claude/skills/merge-the-fanout/SKILL.md` — that one covers the integration, and its cost
section is what decides whether to fan out at all.

**A worktree per lane is the default — `isolation: "worktree"` on the Agent call.** The
checkers are parallel-SAFE, not parallel-ISOLATED: they open no project and take no lock,
but they READ THE WORKING TREE, and in one shared checkout that tree contains every
sibling's half-finished edit. Five lanes ran with worktrees and not one reported a
sibling's file. Same for the game — one bus per checkout, and `launch --isolated` isolates
the bus, never `user://`.

The prompt-writing IS the skill. Cycle 100 wrote three lane prompts from scratch and they
were 90% identical; cycle 102 wrote five and they were 90% identical to those. What varies
between lanes is four things — the bead, the owned files, the tests, the acceptance — and
everything else is boilerplate that is expensive to omit and free to include.

## -1. Check whether a peer session already claimed the bead you're about to claim

`bd ready` and `git worktree list` don't warn you that another live Claude session is
working this same repo right now. Measured directly: a fan-out found `git worktree list`
showing four `locked` worktrees (`git worktree list --porcelain` names the locking pid) on
branches `lane/<bead-id>` for beads that were *already* `in_progress` in `bd list
--status=in_progress` — a peer interactive session (visible via `ListAgents`, a `busy`
peer with the same project name in its title) had fanned out on them minutes earlier.
Before claiming anything:

```bash
bd list --status=in_progress          # someone (you, in a stale session, or a peer) already claimed these
git worktree list --porcelain | grep -B2 locked   # locked = an agent is actively in it right now
```

A `locked` worktree with a recent commit on `lane/<bead-id>` and a matching `in_progress`
bead means SKIP that bead for this fan-out — pick a different one. Don't re-claim it, don't
spawn a duplicate lane on it, and don't assume the lock is stale just because your own
session didn't create it (`ListAgents` showing a `busy` peer session is the confirming
signal, not proof by itself — a peer whose title doesn't match this project could still
hold a lock here if repos are shared across worktree trees). This is a different question
from §0's drift check: §0 asks whether your OWN lane's worktree base is stale; this asks
whether the bead itself is spoken for by someone else entirely.

## 0. Check the worktree base before you trust a single lane report

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

## 1. Partition by FILE, not by topic

Two beads are one lane if they touch one file. That is the whole rule, and it is cheap to
get wrong because beads are written by topic. **Give each agent disjoint files and say so
in its prompt.** Two agents editing `hud.gd` is a merge conflict the loop has no step for;
two agents editing `mint.gd` and `wave_director.gd` is free.

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
writes every line after the lanes land. Cycle 100 held `test_sprite_style.gd` back that way:
two lanes each added a sprite and each needed a row, which is the one collision that was
guaranteed rather than possible. Tell each lane the file is held and to report the exact
line it needs. This is **not** the same as "they are one item": the work is independent and
only the bookkeeping overlaps.

## 2. The blocks every lane prompt needs

Copy these. Omitting one costs more than including it.

**Identity and isolation.** "You are LANE X of a parallel fan-out. You are in your OWN git
worktree, isolated from the other N lanes." A lane that does not know it is one of several
will helpfully fix things outside its remit.

**Confirm before implementing.** "The bead is a claim about the repo made at some past
moment. Open the cited lines and verify they say what the bead says. If the claim is
already satisfied or wrong, STOP and report that instead of writing code." Four beads in
this project have been claimed whose factual premise was already false.

**No backgrounding, and the final message IS the report.** "Never spawn a background or
async task of your own and wait on it — run everything synchronously, in this same turn.
Your FINAL message must contain the full report text itself (worktree, branch, commits,
diff-stat, what you found, gate results) — never a promise to report once something
finishes." Three lanes in one session did real, correct, committed work and then ended
their turn with "I'll pause and wait for the sweep to finish" or equivalent — the
work was fine, the terminal message was not. Each cost the parent a manual recovery
(inspect the worktree's `git status` and diff, re-run the gates, commit by hand) per §3's
"a garbled report is not evidence the work is bad" note. The line above is the cheap fix,
paid once per prompt instead of once per recovery.

**File ownership as a hard boundary.** List what it OWNS, then list what it must NOT edit
by name — including `kanban.md`, `cycle-log.md`, `log-devtools.md`, `CLAUDE.md`,
`AGENTS.md`, `.beads/*` — and "do not run any `bd` command that writes; the parent owns the
tracker." Add: "You may READ anything."

**The gate allowlist, verbatim, and the prohibition.** In this project the allowlist is one
command — `python tools/check_all.py --quiet`, which derives the parallel-safe set for
itself — plus `python .claude/surveys/heredoc_survey.py --worktree` for any lane touching
`.gd`. Then say plainly: do NOT run `lint_project.gd`, `import_check.py`, `run_tests.py`,
`/verify`, or launch the game — they open the project, write `.godot/`, and would corrupt
the sibling lanes.

**"A clean `name_check` is not a compile."** Say it in every prompt and require the lane to
repeat it in its report. It resolves names; it does not type-check.
`var kids := root.get_children()` on a bare `Node` is a hard parse error it reports clean.
**And a fresh worktree has no `.godot/`, so `--require-compile` does not work either** — two
lanes ran it independently and both got exit 1 with fabricated
`Identifier "WaveDirector" not declared` / `Could not find base class "Plant"` errors on
lines they had not touched (`-l638`). The lane gets no compile at all and must say so rather
than claiming "verified".

**"A finding in a file you do not own is not your finding."** Costs a line, still true of
anything shared even under worktree isolation. Cycle 101's Nettle lane got
`suite_reach_check exit=1` with 12 NEW findings, all in three files it had never opened —
that was a shared checkout, and the worktree default removed the class, but the sentence is
what makes a lane check rather than trust a clean exit it did not earn.

**The escaping trap.** "Write code with the Edit/Write tools, NEVER through an unquoted
shell heredoc, and never via a Python script that writes source. A quoted `<<'EOF'` append
to the END of a file is permitted and must be followed by
`python .claude/surveys/heredoc_survey.py --worktree`. If `Edit`'s exact match fails, `Read`
the exact bytes and `Edit` again, or `Write` the whole file. When a string literal will not
fit one line, close it and use `+` on the next." Step 2 has the full version and the four
occurrences that paid for it.

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

## 3. The worktree hazards that are this repo's, not git's

The worktrees live INSIDE the repo (`.claude/worktrees/`), and that costs twice.

- **A lane's own path contains `worktrees`**, so any tool excluding nested checkouts by
  testing an ABSOLUTE path (`"worktrees" in path.parts`) excludes the entire repo when run
  from inside a lane. `citation_check.py` did exactly that after cycle 102 "fixed" it: the
  parent read `298 resolved`, a lane read `260` and 38 bogus advisories — the same asymmetry
  as the original bug, pointing the other way, and invisible to whichever side you were not
  standing on. Exclusions must be computed RELATIVE to the tool's own root; `tools/repo_walk.py`
  is the one place that rule now lives, and the rooted checkers import it.
- **Every tree-walking checker sees N+1 copies of everything during a fan-out, and only the
  PARENT sees them.** `citation_check.py` resolves a bare filename by unique basename
  anywhere under the root, and `rglob` does not read `.gitignore` — so five lanes turned
  every citation in `kanban.md` into a six-way ambiguity. A lane inside its own worktree
  reports clean. If a tree-walking checker starts reporting mass findings mid-cycle, look at
  `.claude/worktrees/` before believing any of it.
- **Clean the worktrees up when the lanes land** (`git worktree remove`), or the next
  cycle's tree-walkers inherit the same ambiguity.
- **On Windows, `git worktree remove --force` can fail with `Permission denied` even right
  after a lane reports done.** The directory unregisters from `git worktree list` (and its
  branch becomes deletable) but the folder itself can survive on disk, held by the agent
  process's own file handles for a beat after its "completed" notification lands. Retrying
  `--force --force` immediately doesn't fix a live handle; it's a timing issue, not a stale
  lock, so leaving the empty-but-undeleted directory for a later pass is fine — it's inert
  once `git worktree list` no longer names it. Don't loop retrying in place.

**A lane can die mid-flight, and the worktree it leaves looks like a finished one.**
Cycle 137's four lanes all terminated a minute in — `Agent terminated early due to an API
error: Login expired`. Each left a **registered worktree, checked out on its `lane/<id>`
branch, with a clean `git status`**. That is exactly what a lane that finished and committed
leaves behind, minus the commit, and `git worktree list` cannot tell them apart. So when a
lane comes back failed, or comes back at all:

```bash
git worktree list                       # branch and sha per lane
git log --oneline main..lane/<bead-id>  # EMPTY means it committed nothing
```

An empty log is the tell, not `git status`. Clean up with `git worktree remove --force`
and `git branch -D` before re-spawning, or the new lane collides with the old branch name.

**A garbled final report is not evidence the work is bad — it can mean the work is real
and just uncommitted.** One lane's whole reply was "I'll stop making tool calls now and
wait for the background task/monitor notifications to arrive" — no diff-stat, no numbers,
nothing usable. `git log main..lane/<id>` was empty (the tell above), but `git status`
inside its worktree showed real, substantial, uncommitted work: a new test file, a new
doc, a CLAUDE.md edit, all exactly matching the bead's ask. The agent had done the job and
then confused itself out of ever calling `git commit` or writing a real summary. **Read
the worktree's actual files and `git status` before deciding a lane failed** — an empty
log plus a garbled report is not the same finding as an empty log plus an empty `git
status`, and treating them the same throws away real, verified-able work. Recovering it
cost one read of the diff, one test run to confirm it still passed, and one commit — far
cheaper than re-running the lane.

Two things worth knowing while you are in there:

- **`git worktree prune` does not remove a stale worktree DIRECTORY** whose admin files are
  already gone. Cycle 137 found one from three days earlier that `prune` reported nothing
  about and `git worktree list` never showed; it was empty, so it was harmless, but a
  non-empty one is another copy of the repo for every tree-walking checker to find.
  `ls .claude/worktrees/` and compare against `git worktree list` — they should match.
- **`git -C <dir>` on a directory that is not a worktree silently resolves to the PARENT
  repo**, so a loop over `.claude/worktrees/*` reports the parent's dirty state as if it
  were a lane's. That is how the stale directory above got noticed at all, and it is a
  reading error waiting to happen in the other direction.

## 4. What the parent owes, and it is more than the merge

**Budget for the merge, because that is where the failures are.** Cycle 100's three lanes
each ran every parallel-safe checker clean, and the merge failed FIVE times — a golden array
and a hardcoded wave pair broken by another lane's growth, a "decide about this here" gate
tripped by a new plant, a test that funded a purchase but never unlocked it, a doc string
119 characters over budget. **None was a mistake by the agent that caused it**; each was a
fact about a file it was correctly forbidden to open. The parent pass is where parallel work
integrates, its cost scales with the number of lanes rather than the size of any one, and it
is not optional. Because the lanes compile nothing, expect the parent pass to find tests
green by construction, layouts with no room, and public surfaces no test names.

**Verifying in an integration worktree does not verify the PARENT'S OWN primary
checkout.** A lane's `--import` and a subsequent integration-branch `--import` each build
a `.godot/` class cache local to that directory. When the merge finally lands in the
primary checkout (the one you started the cycle in), that checkout's own `.godot/` has
never seen the new `class_name` files the lanes added — `run_tests.py` there fails wide
(measured: 550 of 1102 in one merge, exit 2) in a way that reads exactly like a real
regression the integration pass somehow missed. It is not one: `godot --headless --path .
--import` in the PRIMARY checkout, one more time, after folding the integration branch
in, and the same green result reappears. Budget this import as its own step after every
fan-out merge, not just after each worktree's — it is a directory-local cache, not a
repo-wide one, and "I already verified this" from a different checkout does not carry
over.

**Stop hunting for the Godot binary — `addons/godot_selftest/devtools_config.json`'s
`godot_bin` key already has it.** `python tools/run_tests.py` and `tools/devtools.py`
read it automatically; only a bare `godot --headless ...` invocation (an `--import` or a
direct `lint_project.gd` run outside those wrappers) needs the path spelled out, and it
should come from that same config key, not from a fresh `Get-ChildItem`/`find` sweep of
Downloads. One session re-discovered the installed binary's path by searching the
filesystem before checking the config that already named it — the config is the source
of truth precisely so nobody has to do that twice, let alone once per lane.

**Don't gate the next lane on this round's slowest sibling.** The default pattern —
spawn N lanes, wait for all N, merge, verify, THEN spawn the next N — leaves the parent
idle for however long the slowest lane in a batch takes, every round, even though the
other lanes finished long before it. Merge and close out a lane's bead the moment it
lands (already the right move per §4 below), and claim + spawn its replacement in the
SAME turn rather than waiting for the batch to complete — a continuous stream of lanes,
not a sequence of gated batches. Over a many-round fan-out this is the single largest
lever on wall-clock time, and it costs nothing: the lanes that are still running keep
running exactly as before.

**The parent owes each lane's wiring, not just its merge.** Cycle 101's upgrade lane
correctly refused to touch `hud.gd` and `game.gd` and listed seven exact edits it needed
there. Skipping them would have shipped a plant whose upgrade ladder no player could reach —
three files of dead code, all gates green. **A lane that reports "needs these lines in a
parent-owned file" has not finished until the parent writes them.**

**A file-split lane can satisfy one gate by tripping another.** A lane extracting a
cohesive chunk of a big file into its own `.gd` correctly avoided giving it `class_name`
(this repo's own rule: every named class must be named somewhere in the test suite, and a
purely-internal implementation detail has no business being a public class) — but the new
FILE was then invisible to `suite_reach_check.py`, which flagged it and its public
functions as "no test names this" even though they were reached, correctly, through the
delegating wrapper the split left behind. Run the full gate suite after ANY split, not just
the mutation-parity proof the split itself was gated on — a second gate can fail for a
reason the first one's own success actively created.

**Ask for the report you will need at merge time.** A lane's report is the only thing you
have when the merge fails. Require:

- worktree path, branch name, commit sha(s) — and tell it to commit on `lane/<bead-id>`
- its base sha, per §0 above
- `git diff --stat`
- **whether each bead's claims confirmed** — with what it actually read
- exactly which functions / line ranges it touched in any file a sibling also owns
- which gates ran, with exit codes, and the not-a-compile caveat
- **anything it needs in a file it does not own, as an exact copy-pasteable edit**
- the decisions it made that the bead left open, and why
- one sentence of harness verdict (`warranted`/`overkill`/`insufficient`/`inconclusive`)

**Tell each lane what the OTHER lanes will need from it.** The prompts are not independent
even when the files are. Cycle 102's top-bar lane was told a third lane would want a small
button in that same bar, and asked to report how much width headroom it left — so the parent
learned the row was 43px short from a lane that never saw the button. A lane that knows what
is coming reports the number that makes the merge cheap.

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

**A "check the installed harness, append one log line" bead is still worth a lane, but
expect it to look identical to its siblings.** Measured: two beads whose whole acceptance
was `.claude/skills/gap-reconcile/SKILL.md` (check `harness-version --client`, read the
installed source, append a `[G-NNN]` status line — explicitly forbidden from touching the
harness-managed tool file itself) produced two lane prompts that differed only in the gap
number and the file, and both correctly concluded "already fixed upstream, no repo code
change" independently. That's not wasted parallelism — the worktree isolation cost nothing
because neither lane touched a shared file except the expected `log-devtools.md` append —
but it's a sign this shape of bead (owns zero code files, acceptance is a log line or an
upstream filing) could just as cheaply run sequentially in the parent's own shell without
a worktree at all, if there's no other reason to keep it isolated from a code-touching
sibling lane running at the same time. Fan it out anyway when it's running alongside lanes
that DO touch code — the uniform lane treatment costs nothing there and keeps the merge
process one shape instead of two.
