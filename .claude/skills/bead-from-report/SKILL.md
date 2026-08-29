---
name: bead-from-report
description: Turn a one-line complaint, request or handwritten note into a bd bead the implementer can act on — locate and cite the code, check whether the reported thing exists at all, name the tests and budgets a fix will break, and write acceptance against this project's real gates. Use whenever the user, a designer note, or a playtest hands over work out of band ("the UI doesn't scale", "rain froze", "add a faster button", "it's hard to tell which packet goes with which plant"), and whenever you are about to write a bead description at all.
---

# Filing a bead from a report

A one-line report is a symptom. A bead is a claim about the repo, read by whoever claims
it — usually cycles later — and trusted **because it looks like a finding rather than a
memory**. The distance between the two is this procedure.

Related: `.claude/cycle/references/why.md` §3 holds the citation rules for any factual sentence about the
code. This skill is the intake shape that surrounds them.

## The four steps, in order

### 1. Locate the implicated code and cite `file:line`

The report says "the UI doesn't scale". The bead says `hud.gd:1346` reads
`ProjectSettings` instead of the live viewport. That sentence is the difference between an
implementer starting work and an implementer starting a search.

Cite what the game does **now**, not what is wrong with it. A "WHAT THE GAME DOES NOW
(verified <date>)" block is the shape this project's best beads use, and it is the part
that decays — so date it, and say how you checked.

### 2. Check whether the reported thing exists at all

**This is the step that gets skipped and the one that pays.** "The click and drag is
awkward" turned out to describe an interaction the codebase does not implement. That gap
was the single most valuable line in the bead, and nothing but asking directly would have
found it.

Three outcomes, all worth writing down:

- **It exists and behaves as reported** → the bead is a fix.
- **It exists and behaves differently** → the bead is now about the difference, which is
  usually a smaller and better-specified job than the one reported.
- **It does not exist** → the bead is a feature request wearing a bug report's clothes,
  and saying so out loud stops someone hunting for a regression that never happened.

The mirror of this: **check whether it is already DONE.** This project has claimed four
beads whose factual premise was already satisfied — one of them shipped by the very cycle
that filed it, twenty lines below the line the claim was read from.

**Search for the BEHAVIOUR, not for one implementation of it.** A census of `create_tween()`
calls once "proved" no plant animates while idle; both idle animations were `_process`
sinusoids. If you can only name one way the thing could be built, you are enumerating your
own assumption.

### 3. Name the tests and budgets a fix will break

The implementer should not discover `test_the_stats_row_budget_fits_the_bar` by failing it.

Before writing the bead, ask: what does this repo already assert about the thing being
changed? A width budget, a golden array, a corpus count, a "decide about this here" gate, a
tripwire test that exists precisely to notice this kind of edit. Name them, with paths.

Doing it in the bead rather than in the implementation is not bookkeeping — it frequently
**changes the ask**. A constraint found now is a design input; found later it is a
surprise, and the work has already been shaped around not knowing.

### 4. Write acceptance against this project's real gates

Generic prose acceptance ("the feature works well") cannot be met or refused. Name the
mechanism:

- a headless assertion in `test_dir`, and *which* seam it can reach
- a specific checker under `tools/`, named
- a hand pass on the running game, if it genuinely needs one — nothing scripts that any more
- a screenshot or a measurement — **and see the trap below**

> **An acceptance criterion must be something the closing commit can produce, or you have
> written two beads and filed one.** A bead asking for a code change *and* "a screenshot
> proves it" sat ready for twelve cycles looking like unbuilt work, because the code half
> had shipped the same day and the evidence half needed a running game. When the criterion
> names evidence, either split it out or say in the bead that the code is expected to land
> first and this is the audit.

## Writing it down

**Never put prose in a `bd` field as a shell argument.** Backticks are command
substitution: a backticked word vanishes, and one that is *also a command* (`date`, `test`,
`find`, `pwd`) is substituted silently with its OUTPUT landing in the field. Write the
description to a file with an editor tool and pass `--body-file`; `--stdin` and
`--design-file` are the same mechanism for the other fields. `tools/bead_prose_check.py`
scans for the damage after the fact, but the file is what prevents it.

Keep the reporter's own words somewhere in the bead. "rain froze" is two words and it
described the defect better than the paragraph that followed it.

## When the report is four things at once

The loop's refill step assumes work is generated by reflecting on the cycle just finished.
An out-of-band report is a different shape and arrives as a batch.

Split by **what would be verified**, not by sentence. Two complaints that would be proved
by the same test are one bead; one complaint that needs a code change *and* a measurement
is two. Then file them all before working any of them — the second bead routinely changes
the first, and a batch worked in arrival order loses that.

## The bar

Read the finished description back and ask: **would this sentence still be trusted if the
reader could not check it?** Because they will not check it. If a claim in it says
"verified unbuilt" without saying how, it is a memory wearing a finding's clothes — and
three cycles running, an absence claim written into a bead here was wrong.
