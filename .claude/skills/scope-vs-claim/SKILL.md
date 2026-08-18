---
name: scope-vs-claim
description: Compare what a check SAYS it covers against what it actually covers. Use when writing or reading anything that describes its own coverage — a measurement with an evidence string, a checker scoped by a marker, a hand-enumerated set of cases, a denominator that can be zero for more than one reason — and whenever a check has reported clean for a long time and you cannot say what it would have missed.
---

# The description is the half that cannot fail

A check has two halves. It **covers** a scope, in code. It **states** a scope, in prose —
an evidence string, a docstring, a test name, a `NOT COVERED:` line. A reader trusts the
prose, because reading it is cheap and reading the code is not.

Nothing compares the two. So when they drift apart, the check goes on reporting clean and
the sentence goes on being read, and there is no moment at which anything is wrong enough
to notice. **The code can fail. The sentence cannot.** That asymmetry is the whole defect
class.

It has now happened four times in this repo, in four different disguises.

## The four shapes, and the cheap test for each

### 1. A free-text corpus string

`_budget_hud_message_row` (`game/game.gd:2037`) measured the widest message the HUD's
message row could hold, and described itself as sweeping *"GardenTheme.measure() over
every plant name and corn level"*. True when written. Then the prep note started sharing
that row, and at 570px became the widest thing on it against the plant messages' 534. The
budget was wrong by 36px for seven cycles **while reporting green**, because a budget over
a subset always reports more headroom than exists.

> **Test:** read the sentence, then ask *what else falls inside the thing it names?* Here
> the sentence named the corpus ("every plant name and corn level") but the **row** was
> the scope. Anything that can appear in the row belongs in the sweep.

### 2. A region delimited by a marker

`mirror_check.py` compared the text between a `# workflow` heading and an end marker, and
that marker list contained `\n---\n` — ordinary markdown. A horizontal rule inside the
block ends the block early **in both files equally**, so two 21-character stubs compared
identical and it reported clean over a fraction of the text. Fixed by
`truncation_warning()` (`tools/mirror_check.py:119`).

> **Test:** can the region be smaller than intended, and would that read as clean? If the
> delimiter is a string that can legitimately occur *inside* the content, the answer is
> yes. Assert the region's size, or detect the ambiguity.

### 3. A hand-enumerated set of cases

`Pest._update_facing()` maps four cardinal directions. The suite asserted `+X` in the gait
test, `-X` incidentally via the corpse test, used `+Y` without checking its value, and
never mentioned `Vector2.UP` at all. Three of four covered *by accident*; the fourth by
nothing. No test was named in a way that revealed the set had four members, so nothing
showed the gap. Now `test_update_facing_maps_every_cardinal_to_the_art_up_screen_convention`
(`test/unit/test_selftest.gd:8390`) asserts the whole mapping in one place.

> **Test:** is the set enumerated **anywhere in one place**, or only implied by scattered
> coverage? Coverage spread across N tests written for other reasons is not a statement
> about the set — it cannot be read, so it cannot be read as incomplete.

### 4. A denominator that can be zero for two reasons

`suite_reach_check.autoload_names()` returned `{}` both when a project genuinely declares
no autoloads and when `[autoload]` was absent, renamed or unparseable. An empty map just
resolves fewer names, silently. It reports its count now (`tools/suite_reach_check.py:582`),
loudly when that count is zero.

> **Test:** for every zero the check can produce, name **all** the states that produce it.
> If there is more than one and they mean different things, the zero is not a result.

### 5. A test's NAME, which is the claim most people read and least people check

`test_the_road_is_still_the_road_the_constants_were_measured_against` existed to fire when
the game's road changed. Cycle 53 changed the road completely — every corner, a whole new
leg — and it passed, correctly. What it actually asserts is the road's **length and cell
count**, which were deliberately preserved; it says nothing about shape.

Both halves are right. The test is right to pass and the road is right to have changed.
The defect is that a reader trusting the name would conclude the road was untouched, and
a name is the cheapest thing to read and the most expensive thing to verify.

This one has since been fixed (plant-tower-defense-kndl): it is now
`test_the_road_still_has_the_length_and_cell_count_the_constants_were_measured_against`,
and its header names the shape-dependent tests that guard what it does not. The rename is
kept visible here rather than swapped in silently, because the old name is what the six
places that still cite it can be grepped by.

> **Test:** read the name alone, say what would have to be true for it to fail, then read
> the assertions. A name that describes a stronger claim than the body checks is the
> commonest form of this whole defect, because a test that passes is never re-read.

Rename to the property actually guarded, and say in the header which sibling tests guard
the rest. `..._the_constants_were_measured_against` should be
`..._is_still_the_length_and_cell_count_the_constants_were_measured_against`, pointing at
the shape-dependent tests by name.

## Doing the audit

Read the sentence first, then the code, in that order — the reverse re-derives the
sentence from the code and always agrees.

1. **Say the scope out loud in your own words**, from the prose alone.
2. **Ask what else falls inside it.** Not "is the code correct" — "is the *set* right".
3. **Then read the code** and list what it actually visits.
4. **Where they differ, fix whichever is wrong** — sometimes the sentence was aspirational
   and the code is right, in which case correct the sentence. A description narrowed to
   match reality is a real fix; it is what makes the next reader's trust warranted.

Fixing only the code and leaving a now-stale sentence is how shape 1 happened in the first
place.

## Where this sits next to the other two skills

- **`derive-the-list`** asks *should this set be computed rather than typed?* It is about
  the set's **source**.
- **`house-static-checker`** demands a printed denominator and a `NOT COVERED:` line. It is
  about the check's **output**.
- **This** asks whether the sentence and the code agree. It is about the **gap between
  them**, and it applies even when the list is correctly derived and the denominator is
  correctly printed — a truthful denominator over the wrong region is still the wrong
  answer, confidently stated.

## The tell

**A check that has reported clean for a long time, where you cannot say what it would have
caught.** That is not evidence of health; it is the absence of evidence either way, and it
is exactly what all four incidents above looked like from outside on the day before they
were found.
