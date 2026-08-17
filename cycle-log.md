# Cycle 76

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 76 taught

**The least accurate part of `kanban.md` is the part written in the user's own words.** All
four bullets of "Requested directly by James" have now been audited and **three of the four
were substantially wrong** — two of them describing as unbuilt a feature that ships in every
clause. The epic packet tier exists, the dandelion wears four authored fluff frames indexed
straight off its ammunition count, the seed arcs on a real parabola and detonates in a
radius, and `_update_facing` maps all four cardinals.

The cause is structural rather than careless, and it is worth generalising: **these are the
only entries nobody re-reads while working.** Every other section gets revisited when its
neighbourhood is touched; a list of asks written once, by hand, about a game that then
changed underneath it has no such traffic.

**And the rule that says open the code first had its best cycle.** Four candidate entries
died before they were written — "endless never tells the player what got harder" (there is a
`_what_got_harder` feeding the wave-start message), "the boss has no mechanic", "the
dandelion is unbuilt", "facing is broken". Four saved in one cycle is more than that rule
has caught in any previous one.

What is genuinely unbuilt turned out to be one narrow thing: the boss has a mechanic and no
**body** — it is the same `Pest` object, said outright at `game/game.gd:767`. Filed as
`-lk0n`.

## Where things stand

A hundred and three beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked
on gh#43). Suite 573/573, 12551 assertions as of cycle 74; this cycle changed no game code.
Thirteen skills. Upstream gh#44 and gh#49 open, gh#50 open with two data points.

No workflow change — the steps held. The lesson was a technique and went into
`kanban-staleness-audit`, which now sanctions compressing its two passes **only** by making
the second one mechanical: a script that opens every cited `file:line` and prints the line
it lands on. That script has been retyped seven times across seven cycles, so `-a4hk` files
it as a tool, to be run over the whole file rather than the section being edited.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-knpc` blocks `-1490` and `-lp97` (four surfaces are capacity-bound
and only the title screen computes its ceiling). `-a4hk` and `-iezf` are the two "I have
retyped this every cycle" items and are the cheapest real wins on the board.

**Nine standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading.** **Never put backticks in a `bd` description passed through bash** —
ignored again this cycle and it silently ate two words; the only tell is an unrelated
`command not found` on stderr. And **`set-game-speed` takes its scale positionally**.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Live plant ids are catalogue ids —
`corn_cobbler`, not `corn` — and a plant is selected by a real click, which
`cmd touch_press`/`touch_release` at its `global_position` will deliver. To walk a
sub-second tween: `pause` **before** creating it, then `step-time --seconds 0.03
--then-pause`. Bump the number at the top of this file every time you refill.
