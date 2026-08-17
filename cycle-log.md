# Cycle 78

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 78 taught

**An exception in a grammar is often a missing row.** `OVERLAY_GRAMMAR.md` called the
Chomp's shrinking chew ring one of two exceptions to "solid ring = a reach". Making it
sweep at a fixed radius did not add a special case — it made the Chomp the **second
instance of a row**, the first being a husk's rot timer. The exception only ever existed
because the derivation had filed `husk_layer.gd` under "sprites drawing themselves", the
one part of that census done by judgement rather than by grep. Twice now, "this thing is
unique" has meant "the census excluded its twin".

**And a change that fixes one document can break two others.** The Sunflower's header
listed "growing instead of shrinking" as one of four axes separating its gauge from the
chew ring; three axes remain, and the header now says which. Both fixes shipped in the same
commit as the code, because a doc made wrong by your own change is not someone else's job.

**The runtime check I could not run is recorded as `blocked`, not skipped.** Photographing
a partial arc mid-chew failed four different ways, and the reason is a genuine three-way
squeeze: an aphid chew is 0.45 s against a ~200 ms round trip, so polling gets one sample
by luck; `pause` makes stepping deterministic and stops the wave delivering a pest;
`set-game-speed 0.08` keeps the window open and stops the pest arriving at all. Each tool
solves the problem and breaks a precondition of the others. **`verify_ledger` downgraded
the row `pass → partial` on its own** for that one check, which is a more honest headline
than a pass with a footnote.

**Second item this cycle, because the first made a document unverifiable.**
`game/OVERLAY_GRAMMAR.md` cites its neighbours as bare filenames and `citation_check` could
see none of its fifteen citations. Relaxing that surfaced a third convention — bare names in
root-level docs meaning "the obvious file", 42 of them, all correct as a reader reads them.
The resolver now does what a reader does: beside the citing file, then the repo root, then a
unique basename. 190 visible citations became 272.

## Where things stand

A hundred and seven beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked
on gh#43). Suite **574/574**, 12576 assertions; lint 0/0; eleven checkers clean; findings
0/4. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

`house-static-checker` gained a rule earned by getting it wrong: **a mutation that changes
nothing is not a survivor.** `matches = [] or [...]` evaluates the right side, so the code
differed and the behaviour did not — and the tell was the finding count not moving *at all*
rather than moving by one.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** `-t0vy` is the smaller question that does not
need it answered first: whatever weather does, the player should be able to see it doing it.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-orcl` is the half of the citation audit no tool can do — read the
landed lines once and record the rot rate. `-knpc` blocks `-1490` and `-lp97`. `-ip4n`
blocks `-l86t`: photograph a chew mid-sweep, then ask whether 0.45 s is long enough for a
readout to say anything at all.

**Nine standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading.** **Never put backticks in a `bd` description passed through bash.** And
**`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/citation_check.py` answers "do this file's citations still land, and how much of it
cites nothing"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant
ids are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it
can be planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a
plant is selected by a real click, which `cmd touch_press`/`touch_release` at its
`global_position` will deliver. To walk a sub-second tween: `pause` **before** creating it,
then `step-time --seconds 0.03 --then-pause`. Bump the number at the top of this file every
time you refill.
