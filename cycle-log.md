# Cycle 75

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 75 taught

**The bead asked for a document and a document would not have worked.** `-knzv` was P1
because `verify_ledger`'s silent key-dropping had corrupted the evidence file twice; it
asked for the run.json schema "written down where /verify can see it". Reading
`verify_ledger.py` is exactly what I did, twice, and it is exactly how `tier` survived — a
key I have written into **every** run.json this session and which the tool reads nowhere.
Scanning 1400 lines for lookups that are *absent* is the task a regex is better at than a
person.

So `tools/run_json_check.py` derives the accepted key set from every `run.get("...")` in the
installed ledger, which means a harness upgrade updates the checker for free and there is no
second source of truth about a tool whose whole problem is drift. It found `tier` on its
first run. Measured while there: **26 of 86 rows carry `verdict: "unknown"`** — 30% of the
evidence file, mostly an omitted `verdict` the tool defaults quietly rather than a misnamed
key.

**And step 0 has been running at three-quarters for four cycles.** Cycles 72–75 each
reported a mirror exit code, a ready count and a skills listing, and each silently dropped
the `kanban.md` item — the one with no exit code, and therefore the only one a habit of
running commands cannot cover. Step 0 now asks for four *named* values, because a line with
three values in it looks exactly like a line with four.

## Where things stand

A hundred and five beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite 573/573, 12551 assertions; lint 0/0; **ten** checkers clean. Thirteen skills.
Upstream gh#44 and gh#49 open; gh#50 has a second data point commented on it — the triage
table has no row for project-owned tooling Godot never loads, which is the same hole as the
experiment case from a different side.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-knpc` now blocks both `-1490` and `-lp97`: four surfaces in this game
are capacity-bound, the title screen **computes** its ceiling and the other three re-derive
theirs by hand in prose, and both of those blocked items are "this surface is full" wearing
different hats. `-pa4g` (audit the notebook) is the furthest thing from the last seven
cycles.

**Nine standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Run `run_json_check.py` BEFORE `verify_ledger record`** — the ledger is append-only and a
dropped key is indistinguishable from a run that never had one. **Cut `kanban.md` by line
number, never by heading.** **Never put backticks in a `bd` description passed through
bash.** And **`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Live plant ids are catalogue ids —
`corn_cobbler`, not `corn` — and a plant is selected by a real click, which
`cmd touch_press`/`touch_release` at its `global_position` will deliver. To walk a
sub-second tween: `pause` **before** creating it, then `step-time --seconds 0.03
--then-pause`. Bump the number at the top of this file every time you refill.
