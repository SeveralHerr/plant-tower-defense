---
name: confirm-the-premise
description: Check a bead's factual claims before working it, by classifying WHAT KIND of claim each one is — a count, a shape, an absence, a comparison, an ask — because each kind has a different confirming move and a different way of being wrong. Use at the `confirm` step of verify-bd-item, before claiming any bd issue, and whenever a description states something about the repo as though it were a finding. Also use when a bead's cited lines all check out and the work still feels larger or smaller than the bead says.
---

# Confirming a premise

**Partner skill, and read the division of labour first.** `.claude/skills/verify-bd-item/`
owns the ORDER (`confirm → claim → implement`) and three moves that belong to it and are
not repeated here: open the code the bead says is missing, run
`bd search "<phrase>"` to find out whether the absence is an oversight or a recorded
**decision**, and confirm the HELPER you are about to write already does not exist. Do
those. This skill is the half that was still being re-derived afterwards: **what to
actually do**, which depends on what kind of claim you are looking at.

The failure this addresses is not "nobody checked". It is **checking the wrong thing and
coming away satisfied** — every cited line resolving, every quoted snippet still present,
and the bead still wrong in a way that changes the work.

## Classify every factual sentence, then use its move

A bead description mixes these freely. Go sentence by sentence; the type is usually obvious
once you are looking for it.

| Kind | Looks like | The move | How it goes wrong |
|---|---|---|---|
| **Count** | "the five plants", "three surveys", "two callers" | **Re-derive the number.** `grep -c`, or list them. Never read the number. | The repo grew. A count is a timestamp wearing a fact's clothes. |
| **Shape** | "all three are in the house-checker shape", "these are consistent" | **Check each member, not the set.** One `grep -c` per file. | Written from one member and generalised. |
| **Absence** | "nothing does X", "no plant has Y" | Grep for the **property the feature would move**, not the API you imagine. Say in your notes which mechanism you searched. | An enumeration over the wrong set — which reads as exhaustive. |
| **Comparison** | "death has a sound, escape has none" | Open **both** halves. The side called empty is the one to open. | One citation makes the whole sentence read as sourced. |
| **Behaviour** | "it takes 30s", "this is slow", "these are interchangeable" | **Run it.** | Cannot be confirmed by reading at all. |
| **The ask** | the title, and the acceptance | Ask "is this already satisfied?", separately from "are the cited lines still true?" | Every citation checks out and the work is already done. |

## The two that this project keeps paying for

### 1. The ask can be satisfied while every citation still resolves

These are independent questions and the second one is the cheap, seductive one.

Cycle 110 opened `-ibvb`, "Two new plants filling roles the five in the catalogue do not".
Its cited lines were real. Its enumeration of four hand-lists was correct and useful. But
`PlantCatalog` held **eight** plants, three of the five named roles were covered, and the
ask — *two more plants* — had been over-satisfied while the bead sat `in_progress`.
Confirming the citations would have produced a confident "premise holds" and a wasted
cycle. **Read the title as a question and answer it on its own.**

### 2. A claim about behaviour cannot be confirmed by reading, and reading it changes the design

Cycle 111's `-98h3` said `.claude/surveys/` held three scripts "written in the house-checker
shape — exit 0/1/2, a printed denominator, a NOT COVERED line", and offered two designs,
asking that one runtime be measured first. Checking each member instead of the set:

```
$ for f in .claude/surveys/*.py; do echo "$f: $(grep -c 'NOT COVERED' "$f")"; done
flourish_peak.py: 1      heredoc_survey.py: 0      heredoc_survey_controls.py: 0
```

One of three. Then running them:

```
heredoc_survey.py           exit 0   29.72s   sweeps the whole git history
heredoc_survey_controls.py  exit 0    0.06s   the fixture proving the sweep can fail
flourish_peak.py            exit 2    2.25s   needs a RUNNING GAME on the bus
```

Three different kinds, not three instances of one — and those numbers are what chose the
design. **A bead that names a set as though its members were interchangeable is making an
unstated uniformity claim**, and it is the one that never gets written down explicitly, so
it never gets checked.

## Then say what you found, in the close

A premise that held is worth one line. A premise that did not is worth a paragraph, because
the next reader of that bead — or of the one filed to replace it — is inheriting your
correction and not your conclusion. Both of the cases above are recorded in their beads'
close reasons, and both closes say *how* the check was done rather than that it was.

**If the premise is wrong, stop and decide before writing code.** Four outcomes, all fine:

- **Already satisfied** → close it with the evidence, and file what genuinely remains as a
  new bead with its own acceptance. Do not silently narrow the bead to whatever is left;
  `bd ready` cannot see that.
- **Wrong but the work is still wanted** → correct the description first (`bd update
  --body-file`), then claim. The wrong sentence is what the next reader will trust.
- **Right, but the design it implies is wrong** → this is `-98h3`. Say so in the close, with
  the measurement that changed it.
- **Right** → one line saying what you re-derived, and get on with it.

## What this cannot do

It confirms the claims a bead **wrote down**. A bead's most expensive errors are usually
the sentence it did not write — `-3mhn` listed four hand-lists a new plant must be fed and
there were nine, and no amount of confirming the four would have found the other five. For
that, the gates are the answer, not the reading: this project's suite rejected that plant
five times, each for a different missing list. **Confirming the premise tells you whether
to start; it never tells you the work is small.**
