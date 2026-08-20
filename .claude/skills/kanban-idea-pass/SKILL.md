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

**WRITING ABOUT A CITATION WRITES A CITATION.** There is no quoting form — the checker sees
text, so a line number that appears in prose *describing* a citation is indistinguishable
from one making it. Cycle 139 repointed eleven dead `game/pest.gd` citations and then wrote
a correction note saying which two numbers had been wrong; both were bare `:NN`, both bound
to `game/pest.gd`, and the note re-filed the exact citations it was reporting. Caught only
by re-running `--against` and seeing the count go UP.
So when an entry needs to say a citation was wrong: **name the symbol, never the old
number** ("it cited a line for a two-writer design that no longer exists"), and say in the
entry that you have left the numbers out deliberately — otherwise the next reader adds them
back as a kindness. The same trap fires in a bead description, a close reason, and a commit
message that a checker reads.

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

**And check that your search term is about the same thing your claim is about.** This is the
half that slipped past the rule as written. Cycle 88 claimed `NotebookScreen` was "a
design-history artefact" and therefore the wrong shape to host a rules page, on the strength
of grepping the file for `husk` and `compost` and finding nothing. The grep was correct and
the conclusion was not: it answered a question about the file's **contents**, and the claim
was about its **shape**. Thirteen lines from the top, `KIND_SHELF` is documented as "about
the player rather than about the game" — the file had stopped being a scrapbook several
cycles earlier, and the one word that would have shown it was `KIND_`.

Cycle 91 built the legend as a fourth kind in an afternoon, against a bead that said it
needed a new screen. So before you grep, say out loud what KIND of claim you are making —
*this file does not mention X* is a different search from *this file is not the sort of
thing that could hold X*, and only the first one is answered by searching for X.

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
7. **Then `sed -n 'NNNp' <file>` every citation you just wrote — after the code edits are
   FINAL, not while they are still moving.** One command each, and it catches the single
   most likely error: landing on the doc comment above the thing you meant.

   **And read what the cited line DOES, not just that it is the line you meant.** The
   sharper failure is a citation that resolves, lands exactly right, and supports the
   opposite of the sentence around it. Cycle 93 wrote "arming an uproot destroys the line
   the player is reading" and cited `game/hud.gd:1462` — which is `if priority >
   _message_priority:`, the correct line, the pre-empt branch, genuinely the one that fires.
   The two lines under it queue the displaced message rather than dropping it. I had
   reasoned from the *other* branch, eight lines away, and the citation made the claim read
   as checked. It cost cycle 94 to disprove.
   `citation_check` says in its own `NOT COVERED` output that it cannot see this — it proves
   a line exists, never that the line supports the claim. So the `sed` is a floor: read the
   three or four lines around what comes back and ask whether they say what your sentence
   says. **A correct citation under a wrong sentence is more expensive than no citation**,
   because it is the thing that stops the next reader checking.

   Do it last because your own edits shift the targets. Cycle 90 rebound the same two
   citations **three times**: written against the file, then invalidated by adding a doc
   comment above them, then invalidated again by a one-line fix to that comment. Each
   round the `sed` was run and each round it was run too early. Derive the numbers with a
   `grep -n` for the code you mean rather than typing them, and do it once, at the end:

   ```bash
   grep -n 'the exact line of code you are citing' path/to/file.gd
   ```
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
