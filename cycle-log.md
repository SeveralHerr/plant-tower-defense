# Cycle 64

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 64 taught

**Three backlog sections, eight entries, and not one still wanted.** Six had shipped, two
were stale. The oldest sections of `kanban.md` had sat unread for sixty-four cycles and
described a game that no longer exists — overlays that now share a base class, mutes that
now persist, a Sunflower payout that now has a sound.

**A number that reproduces exactly is the most convincing kind of wrong.** The title-screen
entry quoted `BUTTON_TOP` 208, heights 44/40 and `BUTTON_GAP` 8. All four still reproduce.
Its conclusion — "no sixth row at any price, decide between a scrolling list and a More
door" — is false, and `game/title_screen.gd:45-62` not only disproves it but records that
*both* of those shapes were considered and rejected, with reasons.

**And an entry points at where the problem was, not where the fix landed.** "Starting a
wave has no click" cited the button. The button is unchanged to this day; the sound went
into the handler on the other side of the signal. Checking only the cited line would have
produced a confident, wrong "still real" — and it would have felt rigorous, because I went
exactly where the entry said.

**The near-miss is the cycle's real lesson.** My first cut used `text.index()` on a section
heading. `### New this cycle (25 of 30)` appears **twice** — two independent numbering runs
with different subtitles, so `uniq -d` on the headings finds nothing — and 1937 lines went
instead of 85. `git diff --stat` before the commit is what caught it. That is now a step:
a docs-only change has no other gate, since `/verify` triages it to "nothing to verify" and
no checker reads prose.

## Where things stand

Eighty-four beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). `kanban.md` 2620 → 2584 lines. Suite untouched this cycle at 562/562; mirror
identical. Eleven skills. Upstream gh#44 and gh#46 open.

Cycle 63's new rule worked on its first outing: this cycle's work was a markdown audit, a
long way from the HUD and from `tools/` where the previous four cycles lived.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview shows a player exactly what
repositioning would do, and the game then charges full price to act on it.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Six standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, remembering it is a
tool and a hazard in one command. And **cut `kanban.md` by line number, never by heading** —
the section headings are not unique and `uniq -d` will not tell you.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (`-a6bq` to re-read them all);
`list-commands --offline` answers "does this verb exist" with no game running. Bump the
number at the top of this file every time you refill.
