---
name: kanban-idea-pass
description: Mine this repo's own code for the next cycle's backlog entries and append them to kanban.md. Use for the recurring workflow item "add cool new features or concrete improvements to kanban.md", at the end of a cycle, or whenever the backlog needs restocking with ideas that are grounded in the code rather than invented. Produces entries carrying a file:line and a real constant, not wishes.
---

# Kanban idea pass

The recurring last item of every cycle in `todo.md`. Its output is the input to
the next cycle's refill, so the quality of the whole loop rests on it.

## Why this exists

Asked for "cool new features", a model reliably produces a list that could have
been written without opening the repo: particles, screen shake, more levels,
achievements. Those are not ideas, they are categories. The entries this project
actually shipped from — the husk that rots in 10s and looks identical to one that
rots in 4.5s, the 15 of 94 buildable cells that cover no road — all came from
reading a constant and noticing what it implies for a player.

**The unit of a good entry is an observation, not a suggestion.**

## Procedure

### 1. Read what just shipped
`git log -8` and the last few entries of `log-devtools.md`. The best material is
in what the previous cycle *created*: a feature that now exists makes new absences
visible. Sound shipping is what made "no plant makes a noise" findable; the
post-mortem shipping is what made "it can only count what the run lost" findable.

### 2. Read the subsystems, not the summaries
Open the actual files. Every entry must cite something you read this session. The
recurring shapes worth checking in a game like this one:

- **What does the game know that the player cannot see?** This project's single
  most productive question. Any computed value that never reaches a Control.
- **What does a value's *range* imply?** A constant that scales (a timer, a
  radius, a chance) usually has an end the player never experiences, or two ends
  that look identical.
- **What has no counter?** Grep for a funnel — a single method every instance of
  an event routes through — and check whether it increments anything.
- **What has no sound, no motion, no colour?** Grep `AudioStreamPlayer`,
  `create_tween`, `add_theme_color_override` and note which subsystems never appear.
- **What is unreachable?** A public method whose only caller is a test. Lint's
  orphan scan (`Orphans:` line) hands you these for free.
- **What is a strictly dominant strategy?** If one choice is always right, the
  decision it belongs to is decoration.
- **What do two constants imply when multiplied together?** The single most
  productive shape on one run, and the one nothing else prompts for. A spread
  angle and a hit radius give the range at which a wider shot stops connecting;
  a rot timer and a walk speed give whether a husk is reachable at all. Neither
  constant is wrong on its own, which is why reading them one at a time never
  finds it.

### 3. The diff is the authority on what is in flight — not the issue list
Run **`git status --short` and `git diff --stat` first**. Anything modified is
work a concurrent agent is doing right now, and an entry describing a problem
being fixed as you write is worse than no entry. On one run this killed two
drafted entries whose issues were closed before the pass finished.

**Re-run the diff immediately before you write**, not only at the start. A clean
`git status` goes stale in about ninety seconds here.

Then run plain **`bd list`** for the filed set. Be aware it is *not* an in-flight
signal: agents in this repo do not claim a bead before working, so a run that
reported `0 in progress` had three of its four issues under active edit. Use it to
avoid duplicating something already **filed**; use the diff to avoid duplicating
something already **being fixed**. **Say in the report which ones you avoided.**

Also read the existing backlog section; a re-worded version of an idea already
sitting there is worse than nothing, because it makes the backlog look longer
than it is.

### 4. Grep the backlog for the subsystem before reading it
Before opening a file to mine it, `grep` `kanban.md` for its name. A subsystem
already covered by an entry filed three cycles ago will produce the same
observation again, and finding that out after writing it is wasted work.

### 5. Write 6–8 entries
Append a new subsection at the **top** of the "Cool new features (idea backlog)"
section:

```markdown
### New this cycle (N of 30) — grown from the features above
```

Each entry: a **bold lead sentence naming the problem**, then 2–5 sentences of
specifics. Match the voice of the entries already there.

| Bad | Good |
|---|---|
| "Add sound effects for plants." | "**Eleven sounds shipped and not one of them is a plant doing its job.** Every entry in `Sfx.SOUNDS` is a pest, a husk, a wave or a run-ender; `_fire_at`, `_grab`, `_bite` and `_bloom` are all silent — so the half of the game the player *builds* makes no noise while the half that attacks them does." |
| "Improve the difficulty curve." | "**The escalation note is a three-second line about a permanent change, and it goes quiet exactly when the ramp stops.** `ENDLESS_HEALTH_STEP` caps at 3.0 around wave 41 and `SPEED_STEP` at 1.6 around wave 48, while `threat_level` keeps climbing — so the number keeps rising after the thing it measures has stopped." |

### 6. Verify your line numbers AFTER writing, not before
Citations drift while you draft, and in this repo they drift *because other agents
are editing the same files*. Measured on one run: `hud.gd` went 886 → 934 lines
and `plant.gd` gained 149 while the pass was being written; `announce_wave` moved
from 850 to 898 between being read and being cited.

So: cite by **symbol and line** (`hud.gd:898 announce_wave`), not line alone, and
re-open every file to confirm the anchors **after** the entries are written rather
than as you go. A wrong anchor costs the next session more than the entry is
worth, and a right-when-read anchor is still wrong when filed.

## Scope discipline

This pass touches **`kanban.md` and nothing else.** It runs alongside other work,
frequently in parallel with agents editing game code, and a stray edit to a `.gd`
file is a merge hazard for someone else's in-flight change. Do not commit; do not
launch Godot or call `tools/devtools.py` — another process usually owns the
devtools bus.

## What to report back

The entry titles, and for each the `file:line` evidence behind it. Name any filed
issue you deliberately avoided duplicating. If a "problem" turned out on reading
to be already solved, say so — that is a useful finding about the backlog, not a
failure to produce eight entries.
