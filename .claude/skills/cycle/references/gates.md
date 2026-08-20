# The gates

Two runners, on two different clocks. `check_all` answers *is the tree clean now* and runs
every cycle in about four seconds; `survey_all` answers *how often has this happened* and is
run when a rule it surveys has just been broken, when a survey is added, and at least once
every few cycles. Both discover their own set, so the lists below are a description of what
they find rather than the source of truth — the per-tool commentary is what tells you how to
read each one's output.

**Parallel-safe gates. Run them with one command:**

```bash
python tools/check_all.py --quiet     # every parallel-safe checker, list DERIVED
```

**The SURVEYS are a second command on a different clock, and are NOT part of the above.**

```bash
python tools/survey_all.py --quiet    # every .claude/surveys/ script, list DERIVED
```

`check_all` answers *is the tree clean now* and runs every cycle in about four seconds.
`survey_all` answers *how often has this happened* — `heredoc_survey.py` sweeps the whole
git history and takes ~30s, and `flourish_peak.py` needs a game on the bus and reports
`COULD NOT RUN` without one. Folding them into `check_all` would put a history sweep on
every cycle and a live-game verb into the pool whose defining property is that it needs no
project; the two were separated on measured runtimes, not on taste. **Run it when a rule
it surveys has just been broken, when a survey is added, and at least once every few
cycles** — not every cycle. A could-not-run is NAMED with the survey's own reason and does
not gate; `--strict` makes it gate.

Both are runners rather than checkers, so `check_all`'s classifier skips them by name
(`RUNNERS`). Its `CLASSIFIED` line now counts runners as their own category and prints a
`SUM MISMATCH` if the categories stop adding up to the glob — which they briefly did not,
the moment that set grew from one name to two.

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

