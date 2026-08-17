# Cycle 68

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 68 taught

**Deriving a grammar disagreed with the grammar I had written from memory.** Cycle 67's
kanban entry said four drawn cues shared a vocabulary: dashed = a remark, solid = a range,
filled = a gain, doubled width = armed. Three of those hold. **"Solid ring = a range" is
violated twice** — `SoleCoverMarks` draws small *solid* rings on road cells (a mark, not a
radius) and `ChompFlower` draws a solid ring whose radius *shrinks* as a chew completes. I
wrote the first of those two cycles ago.

`game/OVERLAY_GRAMMAR.md` states the grammar with both exceptions named rather than
smoothed over, because a fifth cue copying "solid ring" from the wrong one inherits the
wrong meaning. Its mechanical half is a test — six mutations, all red — and its prose half
says plainly that it will rot, with the `grep` that would falsify it written into the file.

**And the document's own pointers broke it before it was committed.** Adding a five-line
header to three cue files shifted eight of the line numbers the document cites. Re-derived,
then verified *programmatically* that all twelve citations land on a `draw_` call rather
than trusting the fix by eye.

## Where things stand

Ninety-one beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **565/565**, 12305 assertions; lint 0/0; nine checkers clean. Eleven skills.
Upstream gh#44 and gh#46 open.

The workflow gained a rule this cycle and it is the second of its family: **an entry
claiming a pattern needs the enumeration, not an example.** Cycle 66 added the same thing
for comparisons. Both came from my own entries being wrong about code I had written.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Step 2 says take work away from the last two cycles' subsystem — those
were budgets and drawn overlays.

**Six standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**. And **cut `kanban.md` by line number, never by heading**.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings and says how many are at
floor; `list-commands --offline` answers "does this verb exist" with no game running. Bump
the number at the top of this file every time you refill.
