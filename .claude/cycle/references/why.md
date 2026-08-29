# Why each step says what it says

`SKILL.md` is the loop. This file is the long form of every step in it: the rule, and the
cycle that paid for it. Open the step you are on when the one-line version is not enough —
in particular before writing a bead description (step 5), and any time you are about to
change the loop itself (step 4), because most of these rules were added by a cycle that
had just broken them.

The steps below are numbered to match `SKILL.md` — search for `0. **`, `2. **` and so on.
`0.` pre-flight · `1.` read the queue · `2.` do the items · `3.` check the citations ·
`4.` reflect on the workflow · `5.` refill the queue · `6.` go again. After step 6:
creating skills, and where edits to `CLAUDE.md` may go. The sections numbered 5, 6 and 7
in an older revision were renumbered when the godot-selftest harness was removed on
2026-08-29, taking its `/verify` step and its own reflection step with it.

## Before step 0: the two standing biases

**The player-facing bias** was asked for directly in cycle 84. The tooling, the audits and
the checkers are how this project stays honest, and they had taken most of the ten cycles
before it: 72, 75, 77, 82 and 83 shipped nothing a player could see, and 76 shipped no code
at all. A checker or an audit is still the right call when it is the right call — it is a
bias, not a ban. A cycle that ships nothing player-facing owes one sentence in its close
saying why, the same way step 5 owes one when the workflow does not change, and two such
cycles in a row means step 2 takes a player-facing item next whatever else is ready.

**"Simple" is a constraint on the loop file itself.** It reached 826 lines by growing a
little almost every cycle, each addition individually justified, which is how a file that
nothing reviews gets to a size nobody reads. That is why the loop and its evidence were
split: `SKILL.md` is what you follow, this file is what you consult. Step 5 may spend its
one change on DELETING a rule that has stopped earning its place, and should prefer that to
adding a twelfth — and an addition belongs here, not there, unless it changes what you
actually do.

**`bd` is the queue, and there is no second list.** Status, priority, blocked state,
dependencies and close reasons are real fields there, and they were being copied by hand
into a markdown checklist that could drift from them. `cycle-log.md` used to hold what
`bd` structurally cannot — the cycle counter, the pattern the last cycle taught, what is
waiting on the user — and it was deleted with the harness on 2026-08-29; the counter is
derived from git (step 0), and what a cycle taught goes in its close reason.

0. **Pre-flight. Read these three things and report them in one line, as three named
   values.** Three values, three names — `beads=N ready`, `skills=N (none named twice)`,
   `mirror=0`. Named, because cycles 72-75 each reported a mirror exit code, a ready count
   and a skills listing and **silently dropped the fourth**, which was the item with no
   exit code and therefore the only one a habit of running commands cannot cover. A line
   with two values in it looks exactly like a line with three. This
   step exists because they were write-only: the reflection steps below are
   end-of-cycle WRITES and nothing was ever a start-of-cycle READ, so they filled up
   and never came back. Measured at the end of the first 33 cycles: `.claude/skills/`
   did not exist at all, despite the standing instruction to create skills there, and
   `kanban-staleness-audit` had been named as missing three separate times without once
   being built.
   - **Open beads.** `bd ready` and `bd list --status=open`. Anything unblocked belongs
     in this cycle. If everything open is blocked, say so explicitly — that is a real
     result and it is when to mine the design brief harder, not when to invent work.
   - **Skills to create.** The skill ideas in `C:\Users\gotmi\documents\github\log.md`
     against what exists in `.claude/skills/`. **Two independent identifications of the
     same missing skill means build it** — do not identify it a third time.
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

   - **The cycle counter, DERIVED and not read.**
     `git log --oneline | grep -oE "Close cycle [0-9]+" | awk '{print $3}' | sort -n | tail -1`.
     **The MAX, not a count** — the first draft of this bullet said `grep -c` and got 72,
     because the early cycles' commits are worded differently and a count is not an index.
     Caught within a minute by running it, which is the argument for a derived check being
     a command you actually run rather than a number you write down.
     A hand-written counter drifted by three at cycle 110 while the work called itself
     "round 11".."round 15" somewhere else, which is why the number is derived from the
     commits that closed the cycles rather than kept in a file that quietly stops being
     updated. Derive it; do not read a number and believe it.

   Pre-flight REPORTS AND FILES, it does not block.

1. **`bd ready` for the work.** The beads ARE the queue; there is nothing to transcribe.
   This step used to say "read `todo.md`, file every item as a bd issue", which wrote
   every item twice and ticked it twice, and then "read `cycle-log.md` first", which was
   a narrative file the close reasons now carry. (Do NOT use TodoWrite for any of this.)
2. **Do the items one at a time.** For each one: **confirm the bead's claims, then**
   claim the bd issue, write the code, run the gates, then commit. One commit per item.
   Never batch several items into one commit at the end.
   - **`confirm` is a step and it comes before `claim`.** This step said "claim the bd
     issue, write the code" for 88 cycles, which is the wrong order and contradicts
     `.claude/skills/confirm-the-premise/SKILL.md` — the skill written for exactly this
     step, whose first instruction is to open the code the bead says is missing.
     Follow the skill; this
     bullet exists so a reader working from the loop rather than from the skill does not
     get the order backwards. Cycles 70, 84, 86 and 88 each claimed a bead whose factual
     claim was wrong or already satisfied, and cycle 88's (`-beq1`, "nothing says a pest
     carries two traits") was shipped **by the cycle that filed it** — `markers_for`
     returns one mark per flag twenty lines below the `_tint` call the claim was read
     from, and the test the acceptance asked for was written the same day.
     A bead is a claim about the repo made at some past cycle, and the repo has moved.
     **A SIZE IS A CLAIM TOO, and a `grep -c` is not one.** Cycle 154 measured a feature at
     "78 references to three consts", concluded it was a whole cycle's work, and declined
     to start it. Cycle 155 did it as one item: the 78 were grep hits, overwhelmingly
     comments and tests, and the runtime sites were about eight. Counting mentions and
     calling them uses is the same wrong-set failure the project has recorded three times
     already, with a consequence the others did not have — **it does not send you at the
     wrong thing, it defers the right thing**, and a deferral leaves no evidence behind to
     be caught by. So when a count decides scope, open a sample of what it counted before
     believing it.
     **And the same suspicion runs the other way: a derivation that returns almost NOTHING
     over a codebase this size is more likely a broken scan than a clean result.** Cycle
     156 swept for arithmetic on three constants, blanked string bodies while scanning, and
     found three readers — while the run state it was chasing crosses to the HUD as
     Dictionary KEYS, which the blanking had hollowed out. Three is worse than zero here: a
     plausible small number invites belief where an empty one invites a second look. That
     is the denominator rule `house-static-checker` states for checkers, and it applies
     just as hard to a grep you ran once in a terminal. It was caught mid-flight for the
     first time, by asking whether the number was plausible for the question rather than
     whether the command had worked.
   - **A BEAD THAT COVERS TWO THINGS CAN SHIP ONE OF THEM. Note the half, leave it open,
     and never `--force` the close.** Cycle 157 built the difficulty picker and `bd`
     refused the close: the bead covers a board picker too, and it is blocked by the bead
     that would produce a second board to pick. The refusal was right, and `--force` would
     have closed the board half by assertion — the close reason would have described work
     that does not exist, in the field the next reader trusts most. So: put what shipped on
     the bead as a note, say what is left and what still blocks it, and let the queue keep
     showing it. A bead is not a unit of work, it is a unit of CLAIM, and half a claim
     closed is worse than an open one.
   - **IF THE METHOD IS "LOOK AT IT", DO NOT CHANGE WHAT YOU DID NOT LOOK AT.** Cycle 158
     was sweeping screens by rendering them and reading them as a player. It found a
     badly-paired button on the pause card, fixed it — and then renamed the matching
     button on the RUN SUMMARY, a screen it never rendered, because the rename seemed to
     follow. It probably does. But a sweep whose whole claim is "I looked" cannot make a
     change on reasoning without quietly changing what the claim means, and the close then
     has to say which parts were seen and which were inferred. Either reach the surface or
     leave it and file it. The general form: **a method is a promise about the evidence,
     and mixing in a different kind of evidence spends the promise.**
   - **A GATE LETTING SOMETHING THROUGH THAT YOU EXPECTED IT TO CATCH IS ITSELF A
     FINDING, and the moment you notice is the cheapest it will ever be to chase.** Cycle
     159 wrote `game.run_over()` — a method `Game` does not have — ran `name_check`, got
     `errors: 0`, found the mistake by reading, fixed it, and could have moved on. Asking
     "why did that not fire?" instead cost three mutations and turned up a whole class of
     defect invisible to `name_check`, `import_check` AND `lint` alike: a call to a method
     that does not exist, on a statically typed receiver, fails at runtime and nowhere
     else. Filed P1.
     Most of the rules here are about not believing a PASS. This one is about not
     shrugging off a pass you were surprised by — and the surprise is the whole signal,
     because it means your model of what the gates cover is wrong, which is worth more
     than the bug that revealed it.
   - **A NEGATIVE RESULT GOES NEXT TO THE THING THAT WILL TEMPT THE NEXT PERSON, not
     next to the attempt.** Cycle 160 measured that Godot's own unsafe-method warnings do
     not close a gate blind spot, because lint's compile check is `load()`-based. Written
     into the closed bead, that is invisible — nobody re-reads a closed bead before trying
     something. Written only into a dated log, it is chronological, and nobody greps
     a log for "did we already try this". It went into `check_all.py`'s own `NOT COVERED`
     instead, which is the sentence printed directly under the clean count that invites
     the wrong conclusion. **Ask where the next person will be standing when they have the
     idea, and put it there.**
   - **WHEN A CONSTANT IS PINNED BY A TEST, CHECK WHETHER THE PINNED COPY IS THE ONLY
     COPY.** Cycle 161 found `wave 8` in two player-facing strings: one gated against
     `WaveDirector.MUTATION_START_WAVE` for cycles, one gated by nothing. That is worse
     than gating neither — move the constant and the checked copy fails, somebody fixes
     it, and the silent copy is then the only version left saying the old number, with
     the failing one gone and nothing pointing at it. **A pinning test creates a false
     sense that the number is handled**, so the moment you write one, grep for the value
     and count what else says it.
   - **WHEN A LANGUAGE OR A TOOL DECLINES TO CHECK SOMETHING, FIND OUT WHAT IT IS
     PRESERVING BEFORE BUILDING THE CHECK.** Cycle 162 set out to make lint capture a
     Godot warning and discovered there was none to capture: the analyzer stays silent on
     an unknown method for any Object-derived receiver BY DESIGN, because a method may
     arrive with a script at runtime. Two cycles had treated that silence as an oversight.
     Knowing the reason is what produced a checker that works — it says which SLICE it is
     safe on (receivers typed as one of this project's own classes) and prints the size of
     what it skipped, 284 calls of 2048. **A gate built without that question either
     false-positives on the case the silence was protecting — 29 of them, on the first
     draft — or checks nothing and says so.** Both happened here, in that order.
   - **SPLIT WHAT THE ARITHMETIC CAN DECIDE FROM WHAT ONLY THE PICTURE CAN, AND SAY WHICH
     IS WHICH IN THE CLOSE.** Cycle 163 computed the new colour before launching anything
     — raw `DANGER` fails one ground at 0.119, `darkened(0.15)` clears both at 0.242 and
     0.161 — so the VALUE was settled from a table. The launch answered exactly one
     question the table could not: does a deep red still read as a REFUSAL rather than as
     shadow. Cycle 157 had the same shape and cycle 153 got it wrong in the other
     direction, priced a ring against one ground and had the screenshot refute it.
     **A run that cannot name the question it is for is the run that ends up `overkill`
     in the ledger.** Deciding the split in advance is also what keeps the live pass short:
     one question, one capture.
   - **WHEN A CHECKER HANDS YOU A DENOMINATOR, WALK THE WHOLE LIST ONCE.** Cycle 164
     priced all 25 world-space colours against both grounds in a single scan and found a
     mark that clears NEITHER — the corn's spread arc, lying across the lane at 0.064
     separation — which nothing had prompted anyone to look at. The cheap move is the
     sweep, not the wait: a list that a tool already derives costs one command to walk,
     and the alternative is discovering its members one incident at a time. `gate_aim_check`
     went 3 of 35 to 8 of 35 as a result, which is the whole reason a coverage ratio is
     worth printing — it is a number the work MOVES, unlike a pass/fail.
   - **A COMPUTED FAILURE IS A CLAIM, AND ITS REACHABILITY IS PART OF IT.** Cycle 165
     priced a set of dimmed marks and got two numbers under the floor. Both were correct
     arithmetic and neither described anything: one combination is refused at both its
     call sites in as many words, and the other prices a road-only mark against grass. A
     number that comes out of a table looks like evidence in a way an argument does not,
     which is exactly why it needs the same check — **before a failing number becomes a
     finding, go and read whether the state it describes can happen.** This is the mirror
     of cycle 156's rule that a reasoned EXCLUSION is a claim; together they bracket one
     mistake, which is believing something about a case nobody looked at. The check is
     cheap and the alternative is a bead a later cycle has to disprove.
   - **WHEN THE PROJECT ALREADY SOLVED THIS PROBLEM SOMEWHERE, THE FIX IS THERE, NOT IN
     YOUR HEAD.** Cycle 166 spent three cycles of contrast arithmetic arriving at a fix
     that was documented four lines below the defect: `PIP_RIM_COLOR`'s header says a bare
     yellow dot dissolves into a grass tile and the rim is what keeps it legible, and the
     arc was the same yellow with no rim. **Before designing a fix, look at the nearest
     thing that does the same job and see what treatment it carries** — a rim, a doubled
     width, a second channel, a derived count. In a codebase that writes its reasoning
     down, the answer is usually one constant away and comes with the argument attached,
     which is worth more than an equally good fix you invented.
   - **"IS THIS COVERED?" HAS ONE HONEST ANSWER: DELETE IT AND RUN THE SUITE.** Cycle 167
     asked whether 24 rows of a contrast table were backed by anything, and found that
     deleting four draw calls left all 1003 tests green — plus two whole `_draw()` bodies
     on top. No amount of reading the tests would have produced that; they all look like
     they cover something, and they do, just not the thing. It is one edit and one run per
     candidate, it batches by file because several cues share a draw site, and it is the
     only measurement of coverage that cannot be argued with. **Reach for it whenever you
     are about to claim a thing is tested** — especially when the tests in question assert
     CONSTANTS, which is where the gap always is.
   - **RUN INDEPENDENT ITEMS IN PARALLEL (asked for directly, cycle 99).** The loop did one
     item at a time for 99 cycles and the queue is 100 deep; most of it does not touch what
     the rest of it touches. Spawn agents for items whose files do not overlap, and say in
     the close which ran together and why they were safe.
     **How to write the lane prompts, what each lane may run, the worktree traps and the
     report format the merge needs are all in `references/fan-out.md`** — the former
     `fan-out-a-cycle` skill, merged in. Read it BEFORE spawning, together with
     `.claude/skills/merge-the-fanout/SKILL.md`, whose cost section is what decides whether
     to fan out at all.
     The three things step 2 itself owes you, because they change what you claim here:
     **the safety rule is one command** — a lane runs `python tools/check_all.py --quiet`
     and nothing else, so it never runs `lint_project.gd`, `import_check.py` or
     `run_tests.py`, all of which open the project and write `.godot/`, and two of them at
     once corrupt each other's run; **a lane therefore compiles nothing** — a fresh worktree
     has no `.godot/`, so even `name_check.py --require-compile` fabricates errors there,
     and five lanes once reported green having never parsed a line (`-l638`); and **the
     engine gates, the runtime pass and every lane's wiring are the PARENT's**, run once,
     after the lanes land, at a cost that scales with the number of lanes.
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
     **THE ONE NARROWING, earned in cycle 138 and stated because the absolute form is now
     a rule this loop breaks rather than follows.** A **quoted** heredoc — `<<'EOF'`, with
     the delimiter in quotes — performs no expansion and no backslash processing at all,
     so it cannot eat a `#`, a `\n` or a `%`. Every instance this rule has ever paid for
     was an UNQUOTED `<<EOF` or a Python script writing source; none was `<<'EOF'`. Cycle
     138 appended 110 lines of GDScript through `<<'GDEOF'` while a session-level
     instruction said to prefer Bash for file edits, and the bytes landed exact —
     confirmed by `cat -A` on the section header and by `heredoc_survey.py --worktree`
     at exit 0. So: `<<'EOF'` is permitted for an APPEND to the end of a file, and
     **must be followed by `heredoc_survey.py --worktree` before the commit**. Everything
     else in this bullet stands unchanged: unquoted heredocs, in-place splices, and any
     script that writes source are still forbidden, and `Edit`/`Write` remain the default
     for anything that is not a clean append. The reason to narrow rather than restate:
     an absolute rule that conflicts with a live instruction gets broken silently and
     logged as an environment note, which is precisely the countermeasure this paragraph
     already says does not work.
     **AND THE RULE HAD NO ESCAPE HATCH FOR THE ONE CASE THAT MAKES PEOPLE BREAK IT,
     which is why cycle 141 broke it.** "Use `<<'EOF'`" is unusable the moment the block
     needs ONE shell variable — a scratchpad path, a bead id — so the reach is for `<<PY`
     unquoted, and then every backtick inside becomes command substitution. Cycle 141 wrote
     a test comment naming four identifiers in backticks and got
     `the match in  is what decides` in the file, plus four `command not found` lines lost
     in the noise. Same mechanism as the `bd` prose rule three steps down, arriving through
     a different door. **The fix is to keep the heredoc quoted and pass the variable through
     the ENVIRONMENT**, which no quoting touches:

     ```bash
     SCRATCH="$SCRATCH" python - <<'PY'
     import os, pathlib
     p = pathlib.Path(os.environ["SCRATCH"]) / "thing.md"
     PY
     ```

     Same for `bd`: `BID="$b" python - <<'PY'`. If you find yourself typing an unquoted
     heredoc delimiter, that is the signal — not a licence.
     **AND THAT ESCAPE HATCH IS FOR RUNNING PYTHON, NOT FOR WRITING GDSCRIPT.** Cycle 143
     over-applied it one step: having a sanctioned heredoc pattern made a heredoc feel like
     the tool for delivering a 180-line test file, and bash rejected the whole command with
     `unexpected EOF while looking for matching` — a failure that at least announced itself,
     which is the good version. The bad version is the one the rule above already documents:
     it *works* and eats something. **`Write` the file, then `cat >>` it.** Two commands,
     no shell parsing of the content at all, and it is what the rule says in the first
     place: Edit/Write for code, always. The env-var pattern legitimises the *interpreter*,
     never the payload.
     **DO NOT PASS A PATH THROUGH THE ENVIRONMENT INTO A HEREDOC. `cd` there first, or
     write the literal path in the script.** This rule used to say "the assignment must be
     a COMMAND PREFIX, not a statement" — `VAR=x python -` exports for that one command,
     `VAR=x; python -` does not — and it named the failure mode exactly, including that an
     `os.environ.get("VAR", ".")` fallback turns the `KeyError` into a script silently
     reading the wrong path. Cycle 150 broke it twice. **Cycle 152 then broke it again,
     including the fallback half, with the warning sitting right here.** A rule that
     precise, re-broken by the session that had just read it, is not a wording problem: the
     pattern is too easy to type wrong and there is nothing a heredoc needs the environment
     for. Removing the variable removes the class.

     **NEVER BATCH LONG WORK THAT MUTATES THE TREE.** Cycle 150 ran a six-mutation sweep as
     one background command and it was KILLED mid-mutation — twice — each time leaving a
     game file modified with a `.bak` beside it. That state is not merely untidy: a mutated
     working tree reads exactly like a finding, and any gate run against it reports a defect
     that does not exist. Both kills happened around five suite runs in, so the limit is
     real and not bad luck.
     So: **one mutation per FOREGROUND call, and verify the restore before the next one.**
     **And restore from the copy you made, never with `git checkout --`.** That rule was
     written about `.bak` files and cycle 154 reached for the blunter instrument out of
     habit: `git checkout -- game/cue_legend.gd` put the mutated span back AND silently
     reverted an unrelated correction made to the same file earlier in the same cycle.
     `checkout` restores the FILE, and the file is not what you mutated. Nothing caught it
     — the suite was green either way, because the thing reverted was a comment — and
     re-reading the diff is what found it. A `cp` back from the `.bak` cannot do this,
     which is the whole argument for making one.
     Check `git status` after any run that was killed or timed out, before believing
     anything it printed. And pass `-u` to a long-running Python child — a killed batch
     otherwise leaves an EMPTY log, because its stdout was still buffered, which is how the
     first kill looked like a hang with no information at all.

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
     **THE RULE ABOVE NAMES A MECHANISM; THE DEFECT IS SOMETHING ELSE, AND CYCLE 111 REACHED
     IT THROUGH THE SANCTIONED TOOL.** Wrapping a long assertion message across two lines
     inside an `Edit` put a real newline inside a GDScript string literal — the cycle-97
     shape, with no heredoc and no script anywhere near it. Every sentence above is about
     *how* the bytes are written; the thing that breaks is *a string literal containing a
     newline* and *a comment block that lost its leading `#`*, and those are reachable by
     hand. So: **when a string literal will not fit one line, close it and use `+` on the
     next** (`("...long text " + "more text") % [...]`), which is what every other multi-line
     message in this suite already does. And know what will and will not catch it —
     `name_check.py` reports it CLEAN (names resolve; its own `NOT COVERED` line says so),
     and `name_check.py` reports it CLEAN (names resolve; its own `NOT COVERED` line says
     so). Only a real compile finds it — `lint_project.gd` at exit 1 with `Parse Error` —
     and lint is not parallel-safe, which is the whole reason a fan-out lane, which gets no
     compile, is not "verified".
     **There is now a parallel-safe check for exactly this defect, and it takes a second:**

     ```bash
     python .claude/surveys/heredoc_survey.py --worktree    # tracked .gd files AS ON DISK
     ```

     Exit 1 naming the file and line. It reads the working tree rather than git history, so
     unlike the bare survey it CAN see a break you have not committed — which is the only
     time it matters, since the defect is introduced while editing. Run it before committing
     any `.gd` change, and in a fan-out lane, where it is the only thing besides
     `check_all.py` that can see this class at all. The bare (history) form answers a
     different question — "how often has this happened" — and stays advisory.
   - **Read `git diff --stat` before every commit and check the shape is the one you
     meant.** Not the diff — the shape: how many files, how many lines each way. It costs
     one command and it is the ONLY gate a docs-only change has, since no checker reads
     prose. Cycle 64 cut three sections out of a markdown backlog with a `text.index()`
     on a section heading that turns out to
     appear twice; the intended cut was 85 lines and the diff said **1937**. Nothing else
     in the loop would have caught it, and a markdown file is exactly where nobody looks
     twice.
   - **A REASONED EXCLUSION IS A CLAIM, and gets the same check as a citation.** The
     citation rules cover what you assert; they say nothing about what you write down
     that you have deliberately left OUT, and an exclusion arrives wearing the costume of
     rigour — "this does not clear dirt, and that is correct rather than a compromise,
     for the same reason the sweep names one ground per row". Cycle 153 wrote that
     sentence into a constant's header, with a precedent cited and a convention named,
     and the screenshot taken minutes later showed the ring lying across dirt: the radius
     was 30 against a 64 px cell, so the cue leaves the cell whose ground it was
     inheriting. **Every number said the exclusion was safe and the picture said
     otherwise.** So: when you catch yourself justifying a case you are not covering,
     that case is the one to go and look at. It is the cheapest argument there is for
     launching the game on a visual change whose arithmetic is already clean.
3. **Check the citations.** `kanban.md` was the idea backlog this step used to write
   into, and it went with the harness on 2026-08-29; ideas are filed as beads in step 5
   now, and a bead description is where the claims get acted on.
   - **Snapshot the citations BEFORE step 2's code edits, and check them after.** The
     bead descriptions you write cite code you changed an hour ago, and your own edits move
     the lines out from under them. It has happened in cycles 112 and 115 — five citations, one
     drifting by 39 lines — and `citation_check` reported clean both times, correctly, since
     each landed somewhere real. Its own `NOT COVERED:` line used to call this "the one
     nothing can automate"; deciding whether a line SUPPORTS a claim cannot be automated,
     noticing it is not the line you cited can:

     ```bash
     python tools/citation_check.py --beads --snapshot .gates/citations.json  # before step 2
     python tools/citation_check.py --beads --against  .gates/citations.json  # after step 3
     ```

     **`--beads` is not optional here, and it is the larger half.** This loop writes its
     evidence into bead descriptions and close reasons — cycle 126 alone filed ~25 heavily
     cited ones — and `citation_check` read one markdown file and nothing else for eleven
     cycles while ~500 citations accumulated where nothing looked. It now has no default
     file at all: without `--beads` or a named file it reads nothing.

     Exit 1 lists each drifted citation with its `was:` and `now:` line. A citation written
     THIS cycle is reported as `NEW`, never as drifted — there is nothing to compare it
     against — so the read-back by hand is still yours for anything new. This closes the
     half that is mechanical, which is the half that kept failing.

     **RELOCATING A DRIFTED CITATION BY OFFSET SATISFIES `--against` WITHOUT MAKING IT
     CORRECT, and this is where the real findings are.** The check compares TEXT, so a
     citation landing on a blank line, a bare `##`, or a closing brace matches anywhere and
     a uniform `+N` restore carries it forward looking clean. Cycles 129, 130 and 131 each
     found citations that were already wrong *before* that cycle touched anything — ten in
     total, and every one was found by reading the landing rather than by any tool. One had
     114 candidate lines. Two had drifted in SUBSTANCE (a count written out in prose; a
     function that no longer exists), which no line-number check can ever see.
     So: after the offsets go in, **read what each relocated citation lands on, against the
     sentence that cites it.** If the code it described is gone rather than moved, say so in
     the entry instead of repointing it at the nearest survivor.
   - **The five citation rules**, each paid for by a cycle: cite a `file:line` for every
     claim about code as it is now; search for the BEHAVIOUR, not one implementation of it;
     enumerate a pattern rather than exampling it; cite BOTH halves of a comparison; and
     read a collection's SHAPE before claiming membership in it. They lived in a
     `kanban-idea-pass` skill that was deleted with the backlog it was written for;
     `.claude/skills/bead-from-report` carries the same discipline for a bead written from
     an out-of-band report. **Taste needs no citation** — assert a preference plainly and
     let it be argued with. The rule is about the sentence claiming the game does not do
     this yet.
4. **Reflect on THIS WORKFLOW and tweak it for the next run.** The steps above are not
   fixed; they are the thing most likely to be quietly wrong, because nothing else
   reviews them. Ask what actually happened this cycle: did a step get skipped, did one
   produce nothing, did the real work happen somewhere these steps do not describe?
   - **Change at most one thing per cycle, and write down why in the commit message.**
     A workflow that rewrites itself freely drifts; one that changes deliberately and
     records the reason can be read back.
   - **The workflow is edited HERE, in `.claude/cycle/SKILL.md`** — never in
     `CLAUDE.md`, whose `# workflow` block is only the pointer to this file (mirrored into
     `AGENTS.md` by `mirror_check.py --fix`).
   - **If nothing needs changing, say so explicitly.** "The steps held this cycle" is
     a real answer; silence is indistinguishable from not having looked.
5. **Refill the queue.**
   - **File 3-8 concrete, not-yet-filed items as bd issues** — drawn **from step 0's
     sources plus what steps 3 and 4 just produced**: open beads, skills to create, the
     design brief, a broken mirror, drifted citations, and any workflow change worth its
     own item.
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
     the markdown backlog", and that single filename is what made every other source
     invisible for 33 cycles. Never end a cycle with nothing ready.
   - **Step 3's citation rules apply to a bead description too, and a bead is where the
     claims actually get acted on.** A factual sentence in a description is read
     by whoever claims it, usually cycles later, and is trusted because it looks like a
     finding rather than a memory. Three cycles running, an absence claim written into a
     bead was wrong — "no plant has idle motion" (cycle 70, the wrong enumeration),
     "this bridge verb has never been used in 71 cycles" (cycle 71, contradicted by the
     harness log itself) — and both were written in the same breath as filing the item.
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
     finding real work three feet from where it just stood. Take one item from the design
     brief, or from a part of the game this cycle never opened.
   - **And at least one must be something a PLAYER would notice** — added in cycle 151,
     which is fifty cycles after the rule above and is the same finding arriving one
     layer down. That rule fixed *where* items come from and left *what kind* alone, so
     the queue kept growing in one direction: 85 ready items, and a read of the first
     forty found audits, checkers and "decide whether" almost throughout. Two of the
     three the cycle could find were refusals, and the one thing it shipped came from
     CLOSING a bead rather than from the queue.
     **The player-facing bias at the top of this file is a bias over whatever the queue
     holds, so it cannot correct a queue that holds nothing to bias toward.** A steer at
     selection time and no steer at filing time is a thermostat wired to nothing.
     The cheap version is enough: while filing the 3-8, ask of each one "could I show
     this to somebody playing?", and if the answer is no for all of them, go and find
     one. The design brief is full of them.
   - **What this cycle taught goes in the close reason of the bead that taught it**, in a
     sentence or two, where whoever reads that bead next will find it. There is no
     narrative file any more: `cycle-log.md` was deleted with the harness, and a lesson
     filed against the work it came from beats a lesson filed by date.
6. **Go straight back to step 1 and start the next cycle. Do not stop. Do not ask
   whether to continue. Do not say "next session" — you are the next session.**

The only reasons to stop are: the user tells you to, or you are genuinely blocked and
need an answer only they can give.

Whenever a good skill that would've been useful has been identified, please create it
locally in this repository, in `.claude/skills/<name>/SKILL.md`. **Identifying it twice
without building it is the failure mode** — the first 33 cycles named one skill three
separate times and created nothing, because "identify a missing skill" was an end-of-cycle
note and never a start-of-cycle job. Step 0 reads that directory; a skill named twice and
absent from it is work, not an observation.

**Then USE it in the same cycle, on real code, before the cycle ends.** A skill built and
never applied fails the same way a skill identified and never built does — it becomes
prose nobody has tested. Cycle 51 built `scope-vs-claim` and immediately turned it on the
budget system: inside twenty minutes it found a budget still missing five of eight
producers a full cycle after being "fixed", a table asserted in one direction only, a
second hand-list nobody knew was a second list, and a stale sentence in the loop's own
documentation. None of that would have surfaced from writing the skill well. **The first
application is what tells you whether the skill is a recipe or an essay** — and the first
target should be code you did not write it about.

**Where edits to `CLAUDE.md` may go.** Anywhere: since the godot-selftest harness was
removed on 2026-08-29 there is no machine-managed region in it, and nothing under `tools/`
is regenerated from a template either. What used to be true — that an edit inside the
`BEGIN`/`END godot-selftest-harness` markers was silently reverted by the next
`/scaffold-godot-harness` run — is why several rules about harness files were written into
this loop rather than beside the thing they described. The `# workflow` block is still only
a pointer, and the loop itself still has exactly one copy: this directory.


### §2 — enumerate the category from the code, not from the bead

The rule in `SKILL.md` is one line because the evidence is repetitive, which is itself the
argument: this has now been the deciding move in five consecutive cycles, and each time it
was rediscovered rather than followed.

Cycle 168 is the clearest case because the bead was well written. `-n4cx` said *"audit every
tip for whether it names a verb the player can perform"*, listed the tip producers, and set
an acceptance criterion that each carries a recorded verdict. Working that list took twenty
minutes and produced five passes and two deliberate facts — a clean audit, and nothing to
ship.

The tips are not the set. `Hud.show_message` is called from 23 sites, and the ones that
matter most are the **refusals** — the message shown to a player who has just been stopped
and is looking for what to do instead. None of them is a tip and the bead named none of
them. They held three defects: every refusal rendered in Title Case because
`String.capitalize()` title-cases every word; a duplicated literal under a comment asserting
it was not duplicated; and a width budget that had never priced any of them.

**The tell is the word in the bead, not a feeling about the bead.** "Every", "all", "each",
"the N X's" — any of them is a claim that the author knew the boundary of the set. Spend one
grep on the boundary before spending an hour inside it:

```bash
grep -rn "show_message(" game/*.gd | wc -l    # the real denominator, not the bead's list
```

If the derived set matches the bead's, that is a two-minute confirmation and the audit
proceeds with a denominator it can state. If it does not, the difference is usually the
work. This is the same failure `kanban-idea-pass` §2 names from the other side — *an
enumeration over the wrong set is worse than an example, because it looks exhaustive* — and
a bead's list is someone else's enumeration, inherited without its caveats.

