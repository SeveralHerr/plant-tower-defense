---
name: kanban-idea-pass
description: Write a new kanban.md entry or bd bead description whose factual claims about the code will survive being read by whoever acts on them. Use at workflow step 3 (adding to kanban.md) and step 6 (filing beads) — anywhere you are writing down a claim about what the game does or does not do yet.
---

# Writing down an idea so the next reader can trust it

An entry says two things: **"here is an idea"** and **"the game does not do this yet"**. Only
the first is free. The second is a factual claim about the repo, it is read cycles later by
someone who will act on it, and it is trusted *because it looks like a finding rather than a
memory*.

Six failures in this project's history came from getting the second half wrong, and every one
of them cost a claimed bead or a shipped correction. They are listed here as rules because
each was expensive and none of them is obvious in advance.

## The bar

**Before writing that something is missing, open the code that would contain it.** Not the
tests, not another doc, not your recollection of last cycle. The code.

Cycle 30 wrote five entries from inside `run_config.gd` without opening a screen. One proposed
a feature that already shipped in full — with a documented reason for the exact placement it
suggested. One rested on a false claim about `fresh_record`. One over-claimed its scope. Three
of five, and the first became a bead that was claimed and worked before anyone read the code.
**An entry written from the neighbourhood of the file you happen to have open is a guess about
the rest of the codebase.**

## Five rules, each paid for

### 1. Cite a `file:line` for every claim about code as it is now

And write the follow-on shorthand correctly: **a bare `:NN` binds to the last full path
before it, left to right, and never across an entry boundary.** `kanban.md` writes
`` (`game/sfx.gd:86`, `:91`, `:106`) `` — 44 such references, a shorthand the file invented,
which nothing knew about until `tools/citation_check.py` learned it. Binding them found a
bare `:331` whose nearest preceding citation was a 183-line file; the intended target was
named earlier in the same sentence, which is why no reader caught it. **If the path you mean
is not the last one you wrote, write it out in full.**

### 2. Search for the BEHAVIOUR, not for one implementation of it

This is the absence half, and it fails differently: cycle 70 wrote "no plant has idle motion,
verified unbuilt" after enumerating every `create_tween()` call on every plant and finding all
eight event-driven. The enumeration was complete, correct, and **about the wrong set** —
`Plant._wobble` has swayed every plant since the first playable build, and both it and
`Pest._gait` are `_process`-driven sinusoids no census of tweens can see.

**An enumeration over the wrong set is worse than an example, because it looks exhaustive.**
That one survived a cycle, became a bead, and was claimed before anyone opened the file.

So grep for the **property the feature would move** (`rotation`, `scale`, `sin(`) rather than
for the one API you imagine it using — and **say in the entry which mechanism you searched
for.** That sentence is what lets the next reader notice the set was wrong.

### 3. A claim about a PATTERN needs the enumeration, not an example

"All the X do Y", "these are consistent", "nothing does Z" — one citation cannot support any
of them, and a citation that happens to be true makes the whole claim read as checked.

Cycle 67 wrote that four drawn cues shared a grammar (dashed = a remark, solid = a range,
filled = a gain, doubled = armed). Cycle 68 derived it from all 55 `draw_` calls and found
"solid = a range" violated twice — once by a cue written two cycles earlier. Put the grep that
would settle it **in the entry**.

### 4. An entry that COMPARES two things needs a citation for BOTH halves

One `file:line` makes the whole entry read as sourced, including the half taken from memory.

Cycle 65 wrote "death has a sound, a corpse and a linger; escape has none of the three",
citing `DEATH_LINGER` for the death half. The escape half was false in every particular —
`Sfx.PEST_ESCAPED` plays, `_note_lane_loss` tints the exit cell, `_punch_readout` fires — and
cycle 66 claimed the bead before finding out. **The asymmetry you are pointing at is the
claim; the side you say is empty is the half that needs opening.**

### 5. Open the data structure, not just the file that names it

The newest rule and the one that generalises furthest. Cycle 89 wrote a derived check
asserting `Milestones.TABLE.has(id)` for every hint id. `TABLE` is an `Array[Dictionary]`
keyed by `"id"`, so comparing a String against Dictionaries is false for every id in the game
— **the assertion passed, over nothing.** It was caught by an unrelated crash two lines later,
not by the check being wrong.

A claim of the form "X is not in Y" needs Y's *shape* read, not just its name resolved. This
applies identically to prose: "the notebook does not mention husks" is worth nothing if the
notebook turns out to be a design-history artefact where mentioning husks was never the
question — which is what cycle 88 found after grepping for the word and before reading
`PAGES`.

## Applying it

Per entry, before writing:

1. Name the surface the feature would live on. If you cannot, the entry is a wish, not an
   idea — which is fine, but say so in it.
2. Open that surface. Cite it.
3. If the claim is an absence, name the **mechanism you searched for** and grep for the
   property, not the API.
4. If the claim is a pattern or a comparison, do the enumeration or cite both halves. In the
   entry.
5. If the claim is about membership in a collection, read the collection's shape.
6. Run `python tools/citation_check.py` after. **Read its output, not its exit code** — it
   proves a line exists, never that the line supports the claim, and it prints how many
   entries carry no citation at all (260 of 360 in `kanban.md`, which is the real limit on
   every check here).
7. **Then `sed -n 'NNNp' <file>` every citation you just wrote.** One command each, and it
   catches the single most likely error: landing on the doc comment above the thing you meant.
   The checker cannot see it — a comment line is a line — and it says so in its own
   `NOT COVERED` text, naming two cycles that did exactly this. Cycle 89 wrote
   `game/run_config.gd:135` for a constant that is at `:137`, in the same hour it wrote this
   skill, and found it only by running the `sed`. A citation two lines off is worse than none:
   it sends the reader to prose that sounds like agreement.

## Where this does not apply

**Taste.** "The husk cue would look better as pips than as a brighter ring" is an opinion, it
needs no citation, and demanding one produces entries that argue their own case instead of
describing one. Cite the facts; assert the preferences plainly and let them be argued with.

And **the idea itself is never wrong.** These rules police the sentence that says the game
does not do it yet. A perfectly-cited entry can still describe something nobody should build,
and that is a different conversation — see `kanban-staleness-audit`'s closing note, which
makes the same split for entries that already exist.
