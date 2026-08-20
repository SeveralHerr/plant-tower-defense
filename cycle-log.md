# Cycle 170

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## Cycles 107, 108 and 109 are MISSING from this file, and that is the first thing to fix

This file said `# Cycle 106` when cycle 110 opened it. A commit titled "Close cycle 107"
exists and did not touch this file; `.claude/bead-audit-cycle109.md` exists; `kanban.md:14`
says "audited and pruned at cycle 108". In between, the work started calling itself
"round 11" through "round 15" in `log-devtools.md` and step 6's "bump the cycle number"
stopped being run.

Nothing caught it because every other pre-flight item is a list that fills up unread and
this one is a file that quietly stops being written — the same shape as the `AGENTS.md`
mirror, which has been silently emptied twice. So the cycle skill's step 0 now derives the
number instead of reading it:

```
git log --oneline | grep -oE "Close cycle [0-9]+" | awk '{print $3}' | sort -n | tail -1
```

The counter is corrected above. Reconstructing what 107–109 actually taught is real prose
work and is filed as `plant-tower-defense-p9qo` rather than faked here.

## What cycle 170 taught

**Three beads were blocked on a bead that had already been half-finished, and its own notes
said which half.** `-s1o8.1` shipped `Board.set_road` in cycle 141, went `in_progress`, and
carried an accurate `DONE:` / `STILL OPEN:` list in its NOTES from then on. Nothing surfaced
it: `bd ready` excludes an in-progress item and `bd blocked` prints the dependency rather
than its state. **Someone had already done the expensive half**, which makes it the cheapest
work in the queue rather than the stalest. Step 5 added the pre-flight line, and it found two
more the same hour — including the title-screen board picker.

**The suite builds a `Board` forty-six times and sets a road on none of them.** Counted, not
estimated. `set_road` has existed for thirty cycles. So the whole suite is evidence about one
specific snake, and every number in it inherits that silently — which is cycle 53's inventory
again at the scale of the suite rather than three constants. The fix is not a sweep: most of
those 46 rightly want the shipped board, and the work is sorting them into *pinning* and
*asserting a property* and saying which.

**A helper that falls back to a default is worse than one that refuses.** `_over_promise_run`
now takes a road, and a refused one returns `road_refusal` and no measurements at all. Had it
defaulted, a caller passing a road it believed legal would have measured the shipped board and
reported it as the corpus — and that failure produces a *plausible* number, on the one axis
where plausible is indistinguishable from right. The test proves the parameter by **use**, not
by existence: same seed, same garden, different road-cell count.

**`name_check` printed `errors: 0` over a hard parse error again**, this time a parameter named
`road` in a function with two `for road:` loops. Recorded as a sighting rather than a gap: the
tool's own `NOT COVERED:` line says it resolves names and does not compile, the import gate
caught it one command later, and filing it would be filing the tool's own text back at it.

**This cycle ships nothing a player would see, and that is now two in a row.** It was the right
call — it closed the item blocking three beads on the replayability path, including the board
picker, and the neighbourhood rule ruled out the player-facing bead in the queue, which is in
`hud.gd` for a third consecutive cycle. **Cycle 171 takes a player-facing item whatever else is
ready.**

## What cycle 169 taught

**The rule cycle 168 added caught something on its first outing.** "If the bead names a
category, enumerate the category from the code" — the bead asked for every card in
`Hud.HINT_CARDS` and listed six. There are seven. `seen_dead_ground_tip` arrived between
the bead being filed and being worked, which is why the verdict table is swept against
`HINT_CARDS` rather than typed beside it, and why that sweep is not a formality.

**Two words in the notebook turned out to be load-bearing, and neither was found by reading
the prose.** `seen_road_tip` says everything *walking* a Bramble stops to chew through it —
`Bramble.stops()` is `return not pest_is_winged`, so the sentence is true only because of
that word. `seen_dead_ground_tip` says its bars are *slanted*, which is the channel that
separates them from the bar square to the lane. Both surfaced only when someone tried to
write the assertion. Proofreading would have passed both.

**"Opinion" is a real verdict, and it points at a feature rather than closing a question.**
"Climbing one plant beats adding another" cannot be asserted — pinning a balance judgement
as a mechanical fact makes playtesting unable to change it. But the player is being told
that and cannot check it either: the panel shows what a plant IS, never what the next rung
would make it, and the cost arrives in a separate sentence. The right resolution is not an
assertion; it is showing the delta. Filed.

**A verdict that names another test is only as good as the name.** The gate asserts the
named test still exists in the suite source, so renaming it fails rather than quietly
orphaning the card. The unchecked form of this is everywhere else in the repo — comments
naming tests, comments citing `file:line` — and `citation_check` says in its own output
that it covers `kanban.md` and beads and not GDScript comments.

Step 5 sharpened pre-flight rather than adding to it: **"absent" is matched on what a skill
DOES, against the descriptions, not on the name the log invented.** Cycle 168 logged
`audit-a-category` as missing. `derive-the-list` is that skill.

## What cycle 168 taught

**The audit found nothing where it was told to look and three defects one step to the
side.** `-n4cx` asked whether every tip names a verb the player can perform. The tips are
fine — five name a verb, two are facts on purpose and now say so in the suite. The
messages that fail that test are the **refusals**, which the bead never mentioned and which
are the single place naming a verb matters most: the player has just been stopped and is
looking for what to do instead.

**Godot's `String.capitalize()` title-cases every word, and both display sites used it.**
The player has been reading "Pests Walk There." and "Something Is Already Growing There."
for as long as refusals have existed. Nothing in this repo could have caught it: the row's
budget checks WIDTH, the corpus check checks COMPLETENESS, `name_check` resolves names,
lint compiles — and not one of them reads a capital letter. It took calling the function on
the running game and printing what came back. The whole-repo sweep afterwards found the
only other `.capitalize()` in `game/` builds a node name, which is what the function is
for.

**Rewording one string falsified a comment in the same edit that read it and believed it.**
`commit_move` held a second copy of the `"pests walk there"` literal under a comment saying
it was "the same refusal text `place_plant` gives". It was. Nothing enforced it. Both sites
now share `REFUSAL_ON_GRASS`, because a comment asserting two things are identical is a
test written in the wrong language.

**A waiver written for one gate was silently exempting the string from a different one.**
`message_corpus_check` waives the refusal call site because refusals are assembled at
runtime — correct, and its own NOT COVERED line says so. But the width budget sweeps
`message_corpus()`, and a waived line is not in the corpus, so refusals were the one class
of player-visible message nothing had ever priced. Now fed by `Game.refusal_corpus()`; a
refusal lengthened past the row fails at 987px of 876, naming the string.

Step 5 took the rule this keeps producing: **if the bead names a category, enumerate the
category from the code.** Five cycles running, the derived list has been bigger than the
bead's. `why.md` §2 carries the evidence.

## What cycle 167 taught

**Deleting four draw calls left all 1003 tests green.** The risk ring, the dead bar, the
redundant bars and the reach ring — plus, separately, short-circuiting
`SelectionMarker._draw` and `SoleCoverMarks._draw` entirely. Between them that is eight
rows of the contrast table and the dead-zone bar three cycles of work went into. The same
mutation on `Board.mark_dead_ground` fails **four** tests.

**So the split is structural, and the project already knew.** A cue pushed onto a NODE is
asserted; a cue painted in `_draw()` is not — and `board.gd:914` states exactly that as its
own reason for choosing `Line2D`, having been bitten once by "a mark 72 px out of place
that every test passed". The rule was written down, paid for, and applied in one file out
of five. That is cycle 166's pattern again at a larger size: a solved problem beside
unsolved instances of itself.

Step 5: **"is this covered?" has one honest answer — delete it and run the suite.** No
amount of reading the tests produces this; they all look like they cover something, and
they do, just not the thing. It is one edit and one run per candidate, and it is the only
measurement of coverage that cannot be argued with.

**Three escaping failures in one cycle, and the third was inside the sentence describing
the first two.** A heredoc ate a backslash and put a literal newline in a GDScript string —
compiled, ran, silently returned `""`. An equality test against a tab-return line never
matched because these files are CRLF. And a backticked keyword in a `bd close` argument was
run as command substitution and left a hole in the field. **Two of the three are rules this
project has already written down.** A rule broken by the session that just read it is not
short of prose, which is what `-po2c` asks about.

## What cycle 166 taught

**The fix was written in the file, four lines below the defect.** `PIP_RIM_COLOR`'s own
header says a bare yellow dot "dissolves into both a grass tile and the cob's own sprite,
and the rim is what keeps it legible" — and the spread arc is the SAME yellow as those
pips, at a lower alpha, with no rim. Three cycles of contrast arithmetic arrived at a
diagnosis and a cure that were sitting beside the defect the whole time. Step 5 made it a
rule: **look at the nearest thing that does the same job and see what treatment it
carries**, before designing one.

**A colour assertion and a call-site assertion are different claims.** Deleting the rim
draw left all 1002 tests green — the contrast table asserts `PIP_RIM_COLOR` clears the
floor, which says nothing about anything drawing with it. The mutation is what found that,
not the game. Now covered by reading the source with comments blanked, since the paragraph
above the call names `draw_arc` while explaining why there are two of them.

**And the live pass was the weakest of the three instruments, which the log says out
loud.** A 34 px arc with a 1.2 px rim did not resolve in any capture, and `sample-pixels`
cannot separate the arc's rim from the pips' identical ink at the same radius — it answers
"is this ink in this rect", not "is this ink at this draw". That is
`plant-tower-defense-0cl8`'s question and now its second sighting. The visual claim rests
on the file's own precedent, and the ledger records that rather than a look I did not get.

## What cycle 165 taught

**Two numbers were real and neither described anything.** Pricing the dimmed marks gave
two failures under the floor: a dimmed WARNING colour at 0.075 on dirt, and a dimmed
sole-cover ring at 0.103 on grass. Both arithmetic correct. Both **unreachable** — the
first is refused at both its call sites in as many words ("ARMED OUTRANKS HELD", because a
plant one click from destruction must not be dimmed for being the plant being compared
against), and the second prices a ring that marks ROAD cells only against grass. What
caught them was reading the call site and the class header, not computing harder.

Step 5 made it a rule: **a computed FAILURE is a claim, and its reachability is part of
it.** A number out of a table looks like evidence in a way an argument does not, which is
exactly why it needs the same check. It is the mirror of cycle 156's rule about a reasoned
EXCLUSION, and together they bracket one mistake — believing something about a case nobody
looked at, once by arguing it away and once by computing it.

**The one real find was a CONVENTION rather than a colour.** `held_ink` halves the alpha,
separation scales by exactly alpha, so every held-over mark loses half its contrast and
nobody had priced it. The reachable states clear, but the held selection marker on grass is
**0.124 against a floor of 0.12** — the tightest pair in a table that now has 22 rows.

**That is three cycles running, each finding a colour transformation nobody had priced** —
`lightened` in 163, re-alpha-ing a palette entry in 164, `held_ink` here. Filed the
generalisation: enumerate the TRANSFORMATIONS, not the colours, and write the list where
someone adding a fourth will read it.

Nothing was asked of the bridge for the third cycle running, and the log says so —
`overkill` stays an honest category only if it is recorded when the cheap instrument was
the right one, not only when a run disappoints.

## What cycle 164 taught

**A colour is not safe or unsafe; a colour AT AN ALPHA ON A GROUND is.**
`SelectionMarker.WARNING_COLOR` is `Color(GardenTheme.DANGER, 0.95)` — the same palette
colour the blocked bracket failed with last cycle — and it passes, clearing dirt at 0.151
purely because its alpha is 0.95 rather than 0.75. At the bracket's alpha it would be
0.119, under the floor. One colour, two verdicts, decided by alpha alone. That is the
whole argument for the contrast table pricing marks **as drawn**.

**Walking a derived list found the one mark nobody would have noticed.**
`CornCobbler.SPREAD_ARC_COLOR` clears neither ground — 0.064 on grass, 0.113 on dirt —
and is drawn from the muzzle out to `FAN_LENGTH`, so it lies across the lane. Nothing
prompted the look; it fell out of pricing all 25 world-space colours in one command. Step
5 made that the rule: **when a checker hands you a denominator, walk the whole list once**,
because the alternative is discovering its members one incident at a time.

**The triage is the deliverable, and most of it is out-of-scope with reasons.** Fourteen
colours are drawn on a SPRITE rather than on ground, and `reads_on_ground`'s own header
says it cannot see a sprite underneath. Four are WASHES rather than marks — the weather
tints at 0.20 and 0.18, the sundew patch at 0.10, the bomb shadow at 0.22 — and a wash is
legible as a change to the whole field rather than as a shape against ground, so a mark's
floor is the wrong question for it. Saying which and why is what stops the next sweep
re-deriving it.

`gate_aim_check` reads 8 of 35, up from 3. A coverage ratio is worth printing precisely
because the work moves it, unlike a pass.

## What cycle 163 taught

**Both playfield grounds sit in the middle of the luminance range, so dimming has a
direction and this project had been dimming the wrong way.** The convention is to lighten
a palette colour to make a hover read as a suggestion — and grass is 0.643, dirt 0.534, so
lightening walks a mark *toward* them. `BLOCKED_COLOR` ended at **0.004** separation from
the road it was drawn on: in greyscale, a blocked bracket on a road cell was gone. And
un-lightening is not enough — raw `DANGER` is 0.375 and still fails dirt at 0.119.

**The resolution generalises: carry the quiet in ALPHA and leave luminance to do the
reading.** Alpha has not moved at 0.75, which is what the test asserts and what keeps a
hover quieter than the selection beside it. Quiet is not the same as unreadable.

**The asymmetry was closed at the gate, not only in the colour, and that is the durable
half.** `OK_COLOR` cleared both grounds and `BLOCKED_COLOR` cleared neither — for as long
as neither was in the alpha-aware sweep. The colour fix would have held until the next
palette edit; the four new gating rows hold indefinitely. Reverting now fires two guards.

Step 5 spent its change on how the cycle was run: **split what the arithmetic can decide
from what only the picture can, and say which is which.** The value came from a table
before anything launched; the launch answered exactly one question the table could not —
does a deep red still read as a refusal rather than as shadow. Cycle 153 got this backwards
and had a screenshot refute a number it had already believed.

## What cycle 162 taught

**There was no warning to capture.** Two cycles had treated Godot's silence on unknown
methods as an oversight to switch off. Three probes: a `Dictionary` receiver hard-errors
(exit 1, no settings); a `Node2D` receiver does not (exit 0, silent); and
`unsafe_method_access` is the OPPOSITE case, firing on a **Variant**-typed receiver — it
warns when the type is unknown and says nothing when the type is known and the method
absent. **The silence is by design**, because any Object may gain a method at runtime
through a script. Cycle 160's null result is now explained rather than filed.

**Knowing what the silence was protecting is what produced a checker that works.** The
first draft, written without it, resolved **0 calls of 2214** — honest, printed its own
zero, worthless. The second, checking engine-typed receivers too, produced **29 findings
that were all `var _dev: Node` holding a scripted autoload** — precisely the case the
language was preserving. The third, before an index-omissions list, produced **4 that
were all `free`**, a real `Object` method the API index does not carry while `queue_free`
is. Each wrong draft named a rule the right one needed, and all three are in the
docstring rather than only the final logic.

Step 5 made that the rule: **when a language or a tool declines to check something, find
out what it is preserving before building the check.** A gate built without that question
either false-positives on the protected case or checks nothing — both happened here, in
that order.

The result checks 284 calls of 2048 and prints both numbers, and planting cycle 159's
`game.run_over()` back produces exactly one finding with its file, line, receiver and
class. `check_all` is 23.

Worth recording as an asset rather than a gap: `name_check.py`'s cached engine API index
turned out to be directly reusable by a project checker, and nothing had drawn on it
before.

## What cycle 161 taught

**One copy of a number gated and its twin silent is worse than gating neither.**
`PlantCatalog`'s nettle blurb says "wave 8" and has been pinned against
`WaveDirector.MUTATION_START_WAVE` for cycles, with a comment explaining that a const
String cannot interpolate one. The notebook's note for the same plant said the same
number and was pinned by nothing. Move the constant and the shop line fails, somebody
fixes it, **and the notebook page is then the only version left telling the player the
old number — with the failing copy gone and nothing pointing at it.** A pinning test
creates a false sense that a number is handled; step 5 made the rule that writing one
means grepping for the value and counting what else says it.

**The label sweep finished at six of six screens, and its two best outputs are clean
results.** The Keys screen is a model — every row a verb phrase naming an action, so no
noun/value confusion is available to it. The notebook's cue-legend page is the other:
"6 of the board's 11 marks" is two derived counts, the constant is gated by a test that
parses the markdown, and the block above it records that a comment quoting a number is
the copy that rots. Both were written down as models rather than passed over.

**And the method met its limit.** The Designer's Notebook legitimises developer
vocabulary — filenames, pixel counts, "never on paper" — every one of which would be a
finding on the pause card. **A method that depends on reading as a player needs to know
which screens speak in a different register**, and a screenshot cannot tell you. Filed;
the useful output is the list of such screens, which is currently one.

Also seen and deliberately not fixed: the shelf shows "Nothing left on the ground" as
earned, because cycle 159's first `end_run` call unlocked it off a synthetic run before
`--snapshot-userstate` was in use — the verb behaving exactly as its own docstring now
warns, one cycle too late. An attempt to clear the flag was refused by the sandbox, and
that is the right default: it is the developer's save, the flag is cosmetic, and a wrong
clear is worse than a wrong set.

This was the player-facing cycle the two-in-a-row rule forced, and it is worth noting
what that produced: not a feature, but a lie the game was one constant away from telling.

## What cycle 160 taught

**The cheap fix does not work, and knowing that is the deliverable.** Godot's own
`gdscript/warnings/unsafe_method_access` in `project.godot` changes nothing, because
`lint_project.gd`'s compile check is `load()`-based: it asks whether the script loaded and
whether it can instantiate, and a script carrying `x.no_such_method()` does both. The
analyzer emits the warning; nothing catches it. **So the fix is not a flag, it is a change
to how lint compiles** — capture the OUTPUT rather than inspect the RESULT, which is what
`import_check.py` already does one file over. The `--check-only` workaround is unavailable
too, for the autoload reason `CLAUDE.md` documents and this project hit for the first time.

**Where a negative result lives decides whether it is worth anything.** This one went into
`check_all.py`'s own `NOT COVERED` — the sentence printed directly under the "22 of 22
clean" that invites the wrong conclusion. Not the closed bead, because nobody re-reads a
closed bead before trying something; not only the log, because it is chronological and
nobody greps a log for "did we already try this". Step 5 made that the rule: **ask where
the next person will be standing when they have the idea, and put it there.**

**And the shape of the blind spot is now written down where it is read.** Every gate this
project owns asks about NAMES — does this identifier exist, is it mentioned, is it named
by a test. Not one asks whether a CALL is well-formed. That is not an accident and it is
defensible; what was not defensible was `name_check`'s own `NOT COVERED` naming type
inference and pointing at lint as the backstop, when lint does not catch it either. Filed
upstream as **gh#64** — the second issue this session against that repo, weighed against
the one-per-session rule rather than ignoring it.

## What cycle 159 taught

**A call to a method that does not exist passes every gate this project has.** I wrote
`game.run_over()` in a new verb, ran `name_check`, got `errors: 0`, found it by reading,
and asked why it had not fired. Three mutations later: bogus method on a project type,
bogus method on a `Node`-typed receiver with the engine index live, bogus method inside
`game/` to rule out a scan root — `name_check` clean, `import_check` clean, `lint` 0
errors and 0 warnings. The line fails at runtime and nowhere else, which for a devtools
verb means the first time anyone calls it. **`CLAUDE.md` describes `name_check` as
resolving "engine classes and their MEMBERS", so a careful reader is told the wrong thing
twice.** Filed P1.

**The finding came from not shrugging off a surprise.** Step 5 spent its change there:
most rules in this loop are about not believing a PASS; this one is about a pass you did
not expect. The surprise is the whole signal, because it means your model of what the
gates cover is wrong — which is worth more than the bug that revealed it, and is never
cheaper to chase than at the moment you notice.

**And five surfaces stopped being unreachable.** `cmd end_run` puts either card on screen
in one command, and both were read for the first time. It refuses an unreachable state
rather than producing one — no victory except at the last wave, no defeat with beds left
— which is the harness's own rule for a setter verb enforced instead of documented. It
also writes the real save and cannot not: `_end_run` files the score and the milestone
flags, because that is what ending a run MEANS. Measured, warned about in every reply,
and `--snapshot-userstate` put it back.

Cycle 158's blind rename turns out to have been right. That is not the point — the point
is that it is now an observation.

**An existing test caught the new verb before I could forget it**, failing with
"commands.gd registers 'end_run' and this test does not classify it" and naming both
options and where to write the reason. A gate that knows about a file the suite cannot
otherwise drive.

## What cycle 158 taught

**Every width budget on the pause card was clear the whole time.** Its first button says
"Back to the garden" and RESUMES; its last said "Back to the gate" and ABANDONS the run —
three shared opening words, one differing noun, and a second run-ender ("Start over")
sitting between them so the two "Back to the" phrases bracket a destructive option. And
"the gate" was vocabulary this game used on two buttons and nowhere else, so it named the
destination only to someone who had already pressed it once. No measurement could have
found that; the instrument is a rendered screen and a person.

**Two screens came back clean and that is a result.** The Keys screen is a **model** and
nothing had said so: every row is a verb phrase naming an action, so no noun/value
confusion is available to it. That is the property the pause card lacked, and it
generalises — **a label naming a VERB cannot be read as a readout; a label naming a NOUN
or a VALUE can.** Three instances now: this card, cycle 157's difficulty button, and the
Keys screen as the positive case.

**A suspicion that was not a defect is also written down.** Esc sits on two Keys rows, and
the data distinguishes them by a `scope` field the screen never renders — which read like
a table dropping the column that resolves a conflict. Read as a player instead of as a
table, the two labels are plainly different situations that cannot both apply. Recorded so
it is not re-suspected; the bead's own line about not reporting "I would have worded it
differently" is what stopped it becoming a change.

**And the cycle broke its own method.** It renamed the matching button on the RUN SUMMARY —
a screen it never rendered, because no entry point can produce a finished run — inside a
bead whose entire claim is "I looked". Step 5 wrote that down: **a method is a promise
about the evidence, and mixing in a different kind of evidence spends the promise.** Either
reach the surface or leave it and file it. Filed, along with the route that would fix it:
five surfaces here need a run to have HAPPENED, not a scene to be loaded.

Left at four of six screens, open, with what is left and why on the bead — which is last
cycle's partial-close rule getting its first use.

## What cycle 157 taught

**Every width number passed and the picture still said no.** The difficulty button sits
in a 142 px cell; `"Standard"` draws 80 and `"Difficulty"` draws 79, so the width test
passes for either. Rendered, `"Standard"` sitting in a column with Notebook, Keys and
Options reads as a **fourth destination that announces nothing**. The numbers answered
"does it fit" and the question was "does it say what it is". **A width budget is a
necessary condition and never a sufficient one** — and this project has a lot of
carefully-measured labels that nobody has looked at rendered.

**The shape, though, was measured before it was built, and that was right.** A third
PRIMARY row drops `menu_capacity()` from 8 to 5 — below the six the menu now holds — so a
full-width difficulty row was never available. The arithmetic decided primary-versus-
secondary correctly and could not have decided the wording. Both halves of the decision
needed their own kind of evidence.

**And the first line every player reads had been wrong by fourteen.** `"Start · 8 waves"`
was a literal while `WaveDirector.WAVES` grew to 22. Nothing could catch it: a sentence
about a table, in another file, and no gate here reads prose. Derived now, and pinned
against `WAVES.size()` rather than against 22 — hard-coding the right number reproduces
the defect one file over.

**`bd` refused the close and was right.** The bead covers a board picker as well, and is
blocked by the bead that would produce a second board to pick. `--force` would have closed
the board half by assertion, in the field the next reader trusts most. Step 5 wrote that
down: **a bead is not a unit of work, it is a unit of claim, and half a claim closed is
worse than an open one.** Note the half, say what still blocks it, leave it in the queue.

Three stale layout expectations were updated with their reasoning rather than their
numbers — the focus ring wraps to the last ROW, the shipped shape is two pairs, and the
recorded spare capacity went 3 to 2, which is the direction that assertion exists to
notice.

## What cycle 156 taught

**The sweep found no defects, and that is the result.** Cycle 155 shipped difficulty
profiles and asked for a sweep of every site computing against a constant those profiles
now vary — before a title-screen picker makes them reachable by a player. The answer is
that the running code reads run STATE rather than the constants: the prep bar divides
`prep_left` by `prep_total` and both are per-run; `milestones.gd` compares `lives_lost`
to zero, which no profile can move. Three arithmetic readers across `game/`, all correct.

**What it found instead was prose, and one line of it was an invariant.** Three headers
priced themselves against "PREP_SECONDS is 18". Two are READINGS — Bramble's "11.4s holds
one pest for most of a prep gap" simply means something different on a nine-second gap,
and saying so is the whole fix. Dandelion's is an INVARIANT: "always at a full head when a
wave arrives" is either true or the plant is a different plant, and it survived three new
profiles **by luck**, at 4.9 s against harsh's 9 s, with nothing between the claim and the
table. **A reading becomes different when its premise moves; an invariant becomes false.**
Only the second kind can be gated, and now is — priced against the minimum of the table
rather than against `harsh` by name, so a fourth shorter profile fails the test instead of
quietly falsifying the header.

**And the wrong-set shape was caught mid-flight for the first time.** The sweep's first
derivation blanked string bodies and reported three readers — while the run state it was
chasing crosses to the HUD as Dictionary KEYS, which the blanking had hollowed out. Three
is worse than zero: **a plausible small number invites belief where an empty one invites a
second look.** What caught it was asking whether the number was plausible for the question
rather than whether the command had worked. Fifth sighting; first one that cost nothing.

Step 5 wrote that down as the other half of last cycle's sizing rule: a count that decides
scope needs a sample opened, and a derivation returning almost nothing over a codebase
this size is more likely a broken scan than a clean result.

The harness was not used at all this cycle and should not have been — `log-devtools.md`
records it as **overkill avoided** rather than leaving the absence unexplained. A sweep
whose subject is "which expressions exist" is a source question.

## What cycle 155 taught

**A defect can be correct when written and wrong when the premise moves under it.**
`lives_lost` was `LIVES - lives` and the post-mortem's denominator was `Game.LIVES` —
both fine for a hundred and fifty cycles, because every run started with ten. The instant
a second difficulty profile existed they were wrong: on gentle a player losing four of
fifteen would have been told four of ten; on harsh a full wipe would have read "5 of 10",
a loss they never took, on a card that exists to be read once. No gate could have caught
it and none was at fault. The generalisation is the sweep now filed: **every site that
computes a proportion against a constant a profile varies.**

**Difficulty profiles shipped, and standard is DERIVED rather than restated.** Its three
values read `LIVES`, `PREP_SECONDS` and `SeedBank.STARTING_SEEDS`, so the forty-odd
references to those keep meaning what they meant and there is no second ten to drift. The
profile is applied ahead of every node `_ready()` builds, and that ordering is the only
part of this a running game had to answer: a headless assertion reads the settled state
and would pass either way. Live, a harsh run's top bar reads "Seeds 15 / Garden 5" on the
first frame, with no correction visible.

**And the sizing that deferred it was itself an enumeration over the wrong set.** Cycle
154 measured this at "78 references to three consts" and declined to start it. The 78 were
grep hits, overwhelmingly comments and tests; the runtime sites are about eight. That is
the fourth instance of the shape, with a consequence the other three did not have — a
wrong-set count does not only send you at the wrong thing, **it defers the right thing**,
and a deferral leaves no evidence to be caught by. Step 5 spent its change there: a size
is a claim too, and a `grep -c` is not one.

**Two other things worth carrying forward, neither of them changed this cycle.** Drift hit
**94**, by a wide margin the highest of the series (13, 21, 71, 11, 0, 14, 26, 13, 73, 14,
22, 94), because ~90 lines went in at line 51 of `game.gd` — the most-cited file, at the
worst possible place in it. And I filed a duplicate bead for the **second cycle running**,
both times after writing "NOT A DUPLICATE — check first" into the body instead of running
`bd show`. Hedging in the text is not checking. If it happens a third time it should stop
being a note and become the step-5 change.

## What cycle 154 taught

**Two cycles of this project believed a number nobody had measured.** The notes said a
headless run measures the message row under a 64x64 window, so its width was unanswerable
without launching the game — and cycle 151 launched the game to price one tip because of
it. A two-line temporary assertion says **876.0**, exactly what `node-bounds` reports
live. The `get_window().size` caveat is real and does not touch a Control laid out under
a properly-sized root, which is what `instantiate_scene` gives.

**And the bead built on that belief was false in its main claim.** `-9ji4` said the
message row's 13 non-catalogue lines were counted by one test and measured by neither.
`Game._budget_hud_message_row` had been sweeping the whole corpus all along, and adding
both mute lines at their current keybinds on top. Lengthening one bar tip past the row
turned three tests red through it.

**That is the third enumeration in this project that was complete over the wrong set.**
Cycle 70 enumerated `create_tween()` calls and missed `_wobble`; cycle 153's first draft
enumerated `draw_*` calls and missed every mark handed to `Board`; cycle 154 enumerated
tests naming the corpus and missed the budget system. The shape is identical every time:
the enumeration was over HOW rather than over WHAT, and the set was chosen from the
mechanism already in mind — which is why each felt exhaustive. `kanban-idea-pass` rule 2
already forbids this and was read in two of the three cycles that broke it. The tell it
lacks: **if you can name the API you searched for, you have probably searched for an
implementation.**

**A hand-maintained table cannot be checked into correctness; it has to be made
derivable.** The cue-legend ledger drifted twice in the same direction — and cycle 151
read the block while shipping the second hint that falsified it. Correcting it a third
time would have bought one cycle. What made it checkable was `Hud.HINT_CARDS` gaining a
`grammar_row` key: a link from a hint to the row it teaches that **did not exist anywhere
in the codebase**. For every remaining table here the question is not "is it right" but
"what link is missing that would let something else say so".

Step 5 sharpened the restore rule: **restore from the copy you made, never with
`git checkout --`.** The rule was written about `.bak` files; this cycle reached for the
blunter instrument, and `checkout` put the mutated span back while silently reverting an
unrelated correction made to the same file earlier in the cycle. `checkout` restores the
FILE, and the file is not what you mutated.

**Nothing player-visible shipped, and that is worth stating rather than glossing.** Both
items were checks: a de-duplicated width sweep and a new gating checker (`check_all` 21 →
22). The cycle also surfaced no new player-facing item, so the refill rule added last
cycle got its first honest test — the intent is a queue that holds player-facing work, not
a quota that forces inventing some. `-s1o8.3` was opened, measured at 78 references across
three consts, and deliberately not started as a second item. Cycle 155 takes it first.

## What cycle 153 taught

**A coverage ratio is a thing you can watch, and this project had none for its own
gates.** `coverage_check.py` answers which defect CLASSES get asked about, and it would
have reported the colour-legibility class covered — correctly — for every cycle the
dead-ground bar spent below the floor. `tools/gate_aim_check.py` asks the sibling
question per gate: of the sites this gate could speak about, how many actually ask it.
The answer for the `reads_on` family was **2 of 35**, and it moved to 3 within the same
cycle. A gate's coverage is the set of call sites somebody remembered to write, and until
that set has a denominator it cannot be read.

**Its first draft said 0 of 24 and was measuring its own regex.** Both halves were over
the wrong set: the numerator was call-scoped, and tests bind a colour to a local before
passing it, so the symbol is never inside the parentheses; the denominator was built from
`draw_*` call sites, which omits every mark handed to `Board` to draw — that is, exactly
the marks the gate exists for. A checker that reports zero is not thereby thorough.

**And the arithmetic was clean and wrong.** The darkened `RISK_COLOR` was priced against
grass alone, on the reasoning that hovering only reaches buildable ground — true of the
CELL, false of the RING. `RISK_RADIUS` is 30 against a 64 px cell, so a ring anchored one
cell from the lane spills onto it, and the screenshot taken to *confirm* the colour showed
the lower arc lying across dirt. **A cue whose geometry leaves the cell it is anchored to
does not inherit that cell's ground.** No number in the working said so; the picture did.

The thing left filed rather than fixed is the sharper one: `BLOCKED_COLOR` sits at 0.004
separation against dirt — the road's own luminance — so in greyscale a blocked bracket on
a road cell is simply gone, while `OK_COLOR` reads on both grounds. The cue saying YES
reads and the cue saying NO does not. The cause is a convention, not a typo: both are
palette entries LIGHTENED to read as suggestions, and lightening walks a mark *toward*
both grounds because both sit in the middle of the range.

Step 5 sharpened step 2 rather than adding to it: **a reasoned exclusion is a claim, and
gets the same check as a citation.** The citation rules cover what you assert and say
nothing about what you write down that you have deliberately left out — and an exclusion
arrives wearing the costume of rigour, with a precedent cited and a convention named. This
cycle wrote one into a constant's header and had it refuted by a screenshot minutes later.

## What cycle 152 taught

**A gate can exist, be correct, be installed, and never have been aimed at the thing it
was written for.** `GardenTheme.reads_on_ground` exists because a mark once vanished into
this lawn. Two cues are the same grammar row; the deferred bar has had a test naming it
since it shipped, and the dead-ground bar had none — and sat at 0.086 separation against a
floor of 0.12, at FULL opacity, on the only ground it is ever drawn on. Last cycle's
screenshot suggested "faint". The measurement said "below the project's own floor before
alpha is even considered", with a header directly above the constant claiming the bar
survives colour being thrown away.

**Separation scales by exactly alpha, and that turns a palette question into an arithmetic
one.** Grass sits at luminance 0.643 of a possible 1.0, so clearing the floor at a third of
an alpha from the pale side needs a luminance above 1.0. Pale on this lawn is not a value
chosen slightly wrong — it is a direction with no room in it. `reads_on_at` and
`composite_over` are the missing half of a gate that said in its own header that it could
not see opacity, and the new sweep found a second failing mark on its first run.

**The reconciler was wrong in the direction that invites action.** `harness-version
--client`'s first number credited 17 gaps as fixed upstream and did an hour of work in a
second. Its second number said 12 open gaps here are already fixed in what we run — and was
wrong all twelve times, eleven because it resolves `status: open` per LINE in an
append-only log, and one because it read a workaround citation as a fix credit. Acting on
it would have flipped eleven correct lines and closed a live gap. Filed as gh#63.

**And the pass caught itself once.** G-069's first draft said the cause was a bug in this
project and filed a bead for it. Then `devtools_ext/commands.gd` turned out to say, already
and at length, that G-069 is wrong at both ends. The bead was never created. Opening the
file before writing the claim is the only thing that stopped it — the same rule
`kanban-idea-pass` states for kanban entries, which apparently applies to gap
reconciliation too.

Step 5 DELETED a rule rather than adding one. "The assignment must be a command prefix, not
a statement" named its failure mode exactly, including the silent-fallback half — and this
cycle broke it again anyway, with the warning sitting right there. A rule that precise,
re-broken by the session that had just read it, is not a wording problem. It now says: do
not pass a path through the environment into a heredoc at all; `cd` there first. Removing
the variable removes the class.

## What cycle 151 taught

**Refusing a bead properly produced the cycle's best work.** `-xfbo` asked for a second
legend page and its central claim was false: the two board-drawn `Line2D` cues are not
missing from the grammar, they ARE grammar row 6, which cycle 148 had already priced and
declined for a reason that was never about room. Reading that verdict to the end turned up
its own closing sentence -- "the hints page or a mark-side tooltip ... Filed as that, not
as a legend row" -- and then that cycle 144 built exactly that for ONE of row 6's two bars
and nobody noticed there were two. The dead-ground bar had been drawn on the grass for
dozens of cycles with nothing in the game naming it. That is what shipped.

**A one-shot's gate can be a MOMENT rather than a THRESHOLD.** Every hint before this one
waited for the board to cross a line -- two guns, a bank balance, a first selection. The
dead-ground bars are on the board from the opening frame, because with nothing hovered
they answer about the garden's unlocks, so no quantity of them is informative. The gate is
the hover: the frame the cue acquires a subject. When a cue is ambient, ask what makes it
ABOUT something rather than how much of it there is.

**Cycle 148's alarm fired exactly as written.** It said a seventh hint needs one row in
`PAGES` and that a test fails until it is there. Adding the id turned three tests red at
once, naming the count and the missing row, and a fourth caught the corpus count. A
prediction made in a comment, paid off two cycles later, with no one having to remember it.

**And the verification found what the verification could not do.** The message row is
swept for completeness by one test and for width by another, and the two cover different
sets -- eight functions read `message_corpus()` and not one measures a width. The new tip
had to be measured live because `clip_text` plus `text_overrun_behavior 3` make the
headless question unanswerable. Filed, along with the sharper worry: nobody knows what
`label.size.x` is under `instantiate_scene`, and the existing budget test rests on it.

Step 5 spent its change on step 6: **at least one filed item must be something a player
would notice.** Step 2's player-facing bias is a bias over whatever the queue holds, and
after fifty cycles of refilling from reflection the queue is 85 deep and nearly all
audits, checkers and "decide whether". A steer at selection time with no steer at filing
time is a thermostat wired to nothing.

Two rules were re-broken in the cycle that read them: a bare `:NN` citation bound to the
wrong file four times (`citation_check` caught all four), and `phase4` was written where
`verify_ledger` wanted `checks` -- a gap the log had already filed as G-058 and described
down to the exact suggested error string.

## What cycle 150 taught

**A hang is worse than a failure, and four tests could hang.** Each terminated on a
condition the CODE UNDER TEST owns — `while corn.upgrade():`, `while not
cob.is_max_level():` and two more. Mutating `level += 1` out of `Plant.upgrade()` made all
four spin forever, and the runner was SIGTERMed with no output — twice, before I stopped
reading it as slowness. **A failure names its assertion; a hang names nothing**, and inside
a mutation sweep it is indistinguishable from a mutation that never applied. The suite
already had the `guard < N` convention, and two of the four kept a counter without putting
it in the condition — a loop that is already counting has admitted it can run long.

**Everything past an `animations_enabled()` gate is invisible to the entire suite, now
measured rather than suspected.** Replacing `gait_swing(...)` with `0.0` inside `_gait`
survives with zero failures; so does killing `gait_stretch`. The pure functions are all well
tested and nothing can assert `_gait` calls them. `Plant._wobble` is identical. That covers
every animation cue shipped in cycles 139–149, and the only reason `flash_hit`'s recoil is
assertable is that cycle 139 put the arming ABOVE the gate for an unrelated reason.

**Four of five suspected gaps were not gaps, and the control is what made that readable.**
The ladders are killed twice over, the message row by eighteen tests. Three suspicions
retired, one confirmed and quantified — and the road-walker control dying with 37 failures,
naming cycle 142's own paired test, is how a `SURVIVED` elsewhere earns belief.

**Two self-inflicted process failures, both repeated within the cycle.** A batched sweep was
killed mid-mutation twice, each time leaving a game file modified — a state that reads
exactly like a finding. And I wrote `SCRATCH=...` as a statement rather than a command
prefix twice, so `os.environ` never saw it. Both now in `why.md`: one mutation per foreground
call with the restore verified, and the assignment must be a prefix.

## What cycle 149 taught

**A mutation found a hole in tests I had written minutes earlier, and the tell was
visible in hindsight: neither assertion named the function under test.** I wrote a CONSTANT
test (is the glance scale sane) and a CALL-SITE test (which callers pass the flag), then
pinned `_flinch_force = 1.0` — restoring the exact defect the cycle existed to fix — and
both passed. A table is not the thing that reads the table; a list of callers is not the
thing that dispatches on it. One behaviour test closed it, and it was readable headlessly
only because cycle 139 armed the recoil BEFORE the animations gate for an unrelated reason.
**What you put above a gate is what a future test can reach.**

**A cue built from two channels can contradict itself, and nothing looks for that.** A
plate-blocked hit flashed at 0.45 against 1.9 — a 4.2× split deliberately meaning "that did
nothing" — while the recoil said "that hit hard" in the same frame. Both halves were written
on purpose, two cycles apart, each correct alone. This project's standing rule is that
colour is never the only signal; **the corollary nobody wrote down is that the second signal
must AGREE with the first**, and adding a channel to satisfy the first rule is exactly how
you get an instance of the second. Filed as a sweep.

**Enumerate what each caller DID, not what its name implies.** `grep take_damage
game/chomp_flower.gd` is empty — the Chomp holds a pest, chews it cosmetically, and kills it
on its own clock. Every reasonable question ("does the Chomp hurt pests?") answers yes from
the player's side and no from the code's, so a predicate written as "did this cue follow
damage" gets the Chomp exactly backwards. That enumeration turned a one-line tweak into the
finding.

**The decision the bead asked for was the smaller half.** It asked whether a sundew-stuck
pest should recoil as hard as a shot one — a judgement. Beside it sat a contradiction, which
is not a judgement and was not optional. Third time in seven cycles that a bead's framing
was the thing to check first.

## What cycle 148 taught

**"Full" and "complete" look identical from outside and mean opposite things.** The cue
legend is at 294 of 300px and three separate beads treated that as the wall blocking the
next cue. It is also out of things it *should* say: the audit block above it dispositions
every untaught grammar row by name, and the strongest case is refused because a legend row
teaches it WORST — four instances, four meanings, one channel — not for want of room. **Ask
what is queued behind a limit before treating it as a constraint.** A full container with an
empty queue is not a bottleneck, and this project spent three cycles' worth of bead text on
one.

**Two of the three "budgets" were not budgets.** `hint_pages_needed()` computes pages from
the list, so the notebook hints page is a pager — a seventh hint costs one row in `PAGES`
with a test that fails until it is there. The bead counted a speed bump with a working alarm
as a wall. Only the hint list is a real ceiling, and cycle 145 already showed even that
binds on DELIVERY rather than slots.

**A decision bead's deliverable is WHERE the decision is written.** This one went into
`cue_legend.gd`'s audit block, not just the close reason, because that block is what the
next person pricing a teaching surface opens — and its own worked example is the
lane-pressure hatch, which went untaught because "the decision had already been made by the
layout, before anyone asked". A close reason nobody greps would have repeated that exactly.

**Second hand-maintained teaching table to drift in four cycles.** The ledger listed row 4
as untaught two cycles after the sixth hint taught it; cycle 145's was a notebook card
teaching a rule the game had dropped. Both ends of the ledger are enumerable, unlike the
cards, so it is the easier one to check — filed.

**The cheapest teaching has no ceiling and the game was already using it.** Three cues
shipped in cycles 141, 143 and 147 and none spent a word, because motion is iconic where a
mark is arbitrary. Now written down as the first thing to try, ahead of any budget.

## What cycle 147 taught

**A cue can be aimed at the wrong moment and the arithmetic says so before any playtest
does.** The wilt's band is exactly `EAT_DPS` worth of health, so during an uninterrupted
chew it shows for ONE SECOND and then the plant is gone. Where it actually lives is
recovery: a plant whose attacker dies mid-meal sits in the band for ~12 seconds while
regrowth climbs out. **A cue tied to a health band has two durations — crossing under attack
and occupancy during recovery — and they differ here by twelve times.** Nothing in this repo
computes either, for any banded cue. Filed as a measurement.

**A DC offset is the free channel on a crowded property.** Rotation already carried two
sinusoids on deliberately separate clocks, and a third wave would phase-lock with one of
them eventually. A held lean has no frequency to lock with, composes additively, and leaves
both existing channels at full amplitude. Generalised and filed: ask for the constant term
before reaching for another wave.

**An equivalent mutation needs a PAIR to tell it from a weak test.** Replacing
`wilt_threshold()`'s derivation with the literal `0.35` survived — because `EAT_DPS /
MAX_HEALTH` *is* 0.35 today. The pair that kills it: retune `EAT_DPS` to 20 with the
derivation (passes, both sides move) and with the literal (fails, `Expected 0.500000 but
got 0.350000`). **Any derived constant whose derivation currently lands on a round number
has this property**, and this repo has several — a single mutation against any of them looks
like a coverage gap and is nothing of the kind.

**Two values that relate to each other must be read on a PAUSED tree.** Third instance in
seven cycles, third distinct shape: the value and its predicate (141), the value and its
gate (143), the value and its input (147 — `health` and `rotation` read a second apart while
regrowth ran, putting the lean 0.007 rad outside its predicted range). Each had a plausible
wrong conclusion sitting right there. Written into `read-a-moving-value`, which covered
reading one value across time and not two against each other.

**A test-file constant is not shared.** `GAME_SCENE` lives in `test_selftest.gd`; using it
from `test_combat.gd` was a parse error, so `run_tests.py` exited **2** and nothing in that
file ran. Exit 2 is "you verified nothing", and the absence of `[FAIL]` lines would have
read as success.

## What cycle 146 taught

**A correction can be made, believed, and not hold — and that is worse than an
uncorrected mistake, because it leaves no trace.** An id invented in cycle 142 was
corrected in cycle 142 and was still live in cycle 146: the fix replaced one occurrence of
two and nobody counted. `tools/bead_ref_check.py` found it on its first run. The general
form is filed: this repo corrects prose by string replacement constantly — 116 relocated
citations, reworded tips, renamed producers — and every one is only as complete as a count
nobody printed.

**The checker caught me three times while I was writing about it.** Once in the bead that
asked for it, in a sentence claiming the invented id appeared there "nowhere, deliberately";
once more in the same description; and again in the `kanban.md` entry reporting that. So
`kanban-idea-pass` rule 1 is now generalised past citations: **writing about ANY token a
checker matches creates one**, and the way out is to name the symbol rather than the token,
or waive it on the same line. Deleting the report is wrong — the report is usually the most
useful sentence on the page.

**A surviving mutation was a finding about the code, for the second time in this repo.** I
had written a `ref == own` guard so a bead naming itself would not be flagged. Mutating it
away changed nothing: a bead's own id is in the export *by definition*, so the guard could
never fire where the membership test did not. One bead does cite itself and was correctly
silent either way. Deleted, with the invariant recorded where the guard had been. The
reflex on a survivor is to strengthen the test; the first question should be whether the
mutated code can change any behaviour at all.

**An exit `2` in a mutation sweep proves nothing, and looks exactly like a kill.** My first
attempt replaced the id set with an EMPTY one and tripped the tool's own could-not-run
guard. A sweep reading truthiness would have logged it as RED. Re-run with a single junk id:
`5 → 163 findings`, which is the result that actually demonstrates the id set decides.

**The drift series is complete and the theory holds.** 13, 21, 71, 11, **0** across cycles
142–146. This cycle added a new file and edited no existing code, and drifted nothing at
all. Position predicts it completely; size predicts nothing. That makes the step-3 threshold
a lottery on where a cycle happened to edit, which is the strongest argument yet for
scheduling the relocator rather than waiting for it.

## What cycle 145 taught

**A permanent player-facing reference taught a rule the game had stopped following, for two
cycles, and the only thing that noticed was a test about internal consistency.** The
notebook card for the move tip said "Confirming still only uproots" — false since cycle 143.
`test_the_hint_cards_agree_with_the_tips_the_message_row_posts` caught it, and caught it for
the wrong reason: it checks a card against its TIP, and the tip only moved because this
cycle reworded it. **Nothing checks a hint card against the game.** Six cards, six factual
claims about mechanics, read as copy rather than as assertions — filed.

**A tip can be true and useless.** "Hover to compare a new spot" described what the GAME
does, not what the player can do, so the one sentence a player ever got about moving never
mentioned that moving was possible. The test worth applying to every tip: does it name a
VERB the player can perform? `defer_tip` passes; `sole_cover_tip` states a fact and may be
right to. Filed as a judgement pass, not a rewrite.

**The message row is full in a DIRECTION, not just full.** The forfeit clause and the move
tip are mutually exclusive and the forfeit always wins — so an upgraded plant never sees the
move tip, and an upgraded plant is exactly the one worth moving. **A mutually-exclusive pair
with a fixed winner is a routing decision wearing a budget's clothes**: the losing clause is
withheld from precisely the population that triggered the other one. That, not "the row is
full", is why this belonged in the panel.

**Checking the tier beat assuming it.** Last cycle's lesson — a behaviour keyed to a field
the tests write directly has a second question, does anything drive it in the real game —
applied directly: the test calls `_refresh()` by hand, so the question was whether arming
does. It does, at `game/game.gd:1998`. The launch was refused on evidence rather than on
mood, and the two findings came out of the headless suite anyway.

**`run_tests.py` over `run_tests.gd`, third time this session.** I guessed a `height` key on
`selection_panel_budget` that does not exist; the test aborted mid-method and reported
`[PASS]`, and only the error count failed the run.

**The drift number confirmed cycle 144's theory rather than just extending it.** A
comparable amount of work — a new producer, a rewritten card, a reworded tip, two new tests,
five assertions across three files — produced ELEVEN drifted citations against cycle 144's
seventy-one, because the edits landed low in their files and mostly appended. Same size,
one seventh the drift, position the only difference. 116 on `-5w4v` now.

## What cycle 144 taught

**Finishing the thing you just shipped is worth more than starting the next thing.** Cycle
143 ended with two P1s against its own mechanic. Taking one of them first closed a defect a
player would actually hit — arm an uproot, spend four seconds choosing, click, and silently
buy a second plant — and the fix turned out to be small once the diagnosis was right. The
queue is 80 deep; none of it was more valuable than the hole in what had just landed.

**Pausing a deadline while the player is visibly deciding is honest, and the drawn
countdown stopping with it is the honest part.** The uproot clock now holds while a legal
destination is under the pointer and resumes when it leaves — held at exactly 4.0 across
five live reads, then 3.4, 3.1, 2.8. The confirm keeps its four seconds for anyone not
actively choosing, so the destructive half is untouched. Filed the question of whether the
husk rot timer deserves the same, deliberately as a taste call rather than as a fix.

**A behaviour keyed to a field the tests write directly has a second question, and only the
running game answers it.** The unit test sets `_hover_cell` by hand; the game sets it from
`_update_cursor(motion.position)`. "Does the behaviour work" and "does anything set that
field" are different claims, and a green suite is silent about the second. This is the
generalisable shape, not a fact about hovering.

**The row says `partial` and that is the ledger working.** I marked the event-delivery
check `blocked` — the bridge cannot drive an absolute mouse position, so nothing reading
`InputEventMouseMotion.position` is reachable — and `record` downgraded the verdict on its
own. A check that could not run is not a check that passed. Filed as `[G-141]` and as a
bead.

**Citation drift is a function of WHERE a cycle edits, not how much.** Cycle 143 appended
to the end of `test_selftest.gd` and moved 21 citations; cycle 144 made two MID-FILE edits
in the same file and moved 71. Nothing about a diff's size predicts which you did, so the
step-3 threshold fires on edit position — a property nobody chooses deliberately. 105
across three cycles now.

**Step 5: when to launch, not whether.** Twice this session runtime setup cost state — the
game played itself to a loss while I finished tests, and before that a 4-second window
decayed across four bridge round-trips and was misread as a defect. `why.md` now says to
launch at the moment the question is ready and to set the scenario up in as few round trips
as possible, because reading a predicate and then acting on it is two different games.

## What cycle 143 taught

**A bead can name the right symptom and the wrong axis, and answering it faithfully ships
nothing.** `-h5w6` framed moving a plant as a PRICE question — free, full, or
refund-minus-cost as "the middle" — and refund-minus-cost is four seeds on a healthy Corn
Cobbler, which is the free option with extra arithmetic. The barrier was never seeds:
`commit_uproot` frees the plant, so a move destroyed the level, and `uproot_refund` scales
the base cost. The cost of moving scaled with exactly how much the player cared about the
plant. **A bead that offers three options has already chosen the axis, and the axis is the
thing to check first** — the giveaway here was arithmetic the bead never did.

**A clock grew a second job without anyone deciding it should.**
`UPROOT_CONFIRM_SECONDS` is 4.0, tuned when arming meant "are you sure" — a destructive
confirm, which wants to be short. This cycle made the same window the gesture for choosing
a destination, which wants to be long, while the move tip literally asks the player to
hover and compare. Lose it and the move click silently buys a second plant at full price.
The code is right and every guard behaved as designed; the interaction is not. **When a
feature reuses an existing gesture because "every piece already exists", check what the
pieces were SIZED for.**

**The launch found it by being SLOW, which is the one thing a test never is.** Four bridge
round-trips ate the window while I read output. No headless test would ever lose it,
because a test's clock only moves when it says so. Worth keeping as a deliberate technique:
a paused tree proves the feature works, an unpaused unhurried one proves the WINDOW does.
And this is the second cycle running where the finding came from the PREDICATE decaying
rather than the value — cycle 141 read a Chomp's pivot while `is_busy` flipped underneath.

**Mutation is what proved the test pins the right thing.** Reimplementing `commit_move` as
uproot-and-rebuy-at-a-discount — the feature the bead actually asked for — fails the
identity assertion on the instance id. A test checking only the price would have passed it,
and would have been the wrong test written confidently.

**Step 5: I over-applied cycle 141's own escape hatch.** Having a sanctioned heredoc
pattern for running Python made a heredoc feel like the tool for delivering a 180-line test
file; bash rejected the whole command. `why.md` now says the hatch legitimises the
interpreter, never the payload — `Write` the file, then `cat >>` it, which is what the rule
said in the first place.

**Three invented bead ids in two cycles.** I wrote `-9dq7`, then `-3b0j`, then `-yfzs`,
each caught only by looking one up for an unrelated reason. `-xnmz` (nothing checks that a
bead id in prose names a real bead) went to P1 on the strength of it. Cross-references are
how this project chains evidence, and an invented link reads exactly like a real one.

## What cycle 142 taught

**Making a constant into a parameter converts every assumption the constant was quietly
satisfying into a validation you now owe — and those assumptions are invisible precisely
because nothing ever violated them.** `Board._build_path` walks each segment with
`while at != to` stepping `signi` per axis, so a diagonal segment never arrives: an
infinite loop inside `_ready()`, no error, nothing on screen. That was not a defect while
the corners were a const nobody could change; it became one the moment `set_road` existed.
Two more the const also happened to satisfy: in-bounds corners, and no zero-length segment.
The hazard was fenced by immutability, which is the kind of fence that vanishes silently.

**A derived test needs an INDEPENDENT derivation, not the same computation twice.** The
corpus test computes expected cells from the corners by arithmetic while the actual comes
from the walker, and expected length from the cell count while the actual comes from
measuring route points. Two routes to one number — which is why mutating `steps + 1` to
`steps` fails it. A test that recomputed the answer the way the code does would have passed
that mutation and looked identical. This is the whole difficulty in the four
shape-dependent tests still left: "which cells are dead ground for reach R" is the search
the game already runs, so each needs a second algorithm or a property a bad road violates.

**A warning message written ABOUT a constant had drifted from the constant's own
argument, and the warning is what the next reader believes.** The bead asked for
`SIMULTANEOUS_PEST_CEILING` to become road-derived, quoting a test's failure message that
says 40 is "reasoned from 32 cells / 2112 px as 3.5 pests per cell of road". The constant's
own header says something else: the road states the PROBLEM (115 pests alive at once) and
the wave table sets the number by construction. A test asserting `ceiling == cells * k`
would have invented a derivation the code does not have. Failure messages are read at
exactly the moment nobody is checking them against the thing they describe.

**Both rules added in the last two cycles fired and held.** The drift threshold from cycle
140 hit 16 drifted, so four were fixed (the working bead's own) and thirteen filed, and the
cycle stayed about the road. The env-var heredoc pattern from cycle 141 was used throughout
and nothing was eaten. Step 5 changed nothing this cycle, deliberately.

**One near-miss worth a checker: I invented a bead id in a bead description** and caught it
only by going to look it up for an unrelated reason. `citation_check` reads `file:line`;
`bead_prose_check` catches what the shell ate; neither asks whether a
`plant-tower-defense-XXXX` in prose names a real issue. Cross-references between beads are
how this project chains its evidence, so an invented link is worse than a wrong file
citation — it sends the reader to a `bd show` miss they will blame on their own typo.

## What cycle 141 taught

**Measure the QUIET side of a "clearly bigger than" claim, not the loud one — and this is
now twice.** Cycle 139 asserted the pest recoil beats `GAIT_SWING` and then measured 24
unhit pests peaking at `GAIT_SWING` to seven decimals. Cycle 141 asserted the Chomp's champ
beats `BREATHE_AMOUNT` and then measured 14 idle Chomps spanning exactly `1 ± 0.022`. In
both cases a constant-vs-constant test passes identically in a world where the quiet motion
never approaches its own amplitude — and in that world the promised separation is fiction,
because the eye calibrates against what the quiet thing actually does. The live check worth
running is on the thing you are claiming to exceed.

**A predicate can be moving too, and pausing only the value is not enough.** The first
pivot samples read ±7% while `find-nodes` had just said `is_busy false` — which reads
exactly like "the idle breathe is three times its own constant", and was nearly filed as
one. The Chomp had grabbed a pest between the state read and the scale read.
`read-a-moving-value` asks what was moving when you read it; this was the shape where the
VALUE and the PREDICATE were both moving, and the fix was reading both in one poll.

**Two of this cycle's failures were caught by gates rather than by care, and both are
rules this project had already written down.** `_T.assert_lt` does not exist, and the test
reported `[PASS]` while aborting mid-method — the coerced-empty-return case `run_tests.py`
exists to wrap, catching it on the error count while the suite line said pass. And an
UNQUOTED heredoc ate four backticked identifiers out of a test comment, leaving "the match
in  is what decides". The loop permits `<<'EOF'` and forbids `<<EOF`; I used the unquoted
form to interpolate one shell variable.

**Step 5's change is the escape hatch that rule was missing.** "Use `<<'EOF'`" is unusable
the moment the block needs one shell variable, so the reach is for the unquoted form and
every backtick inside becomes command substitution. `why.md` §2 now says to keep the
heredoc quoted and pass the variable through the ENVIRONMENT, with the pattern. An absolute
rule with no path for its own commonest exception is a rule that gets broken quietly — which
is what the paragraph above it already said about a different absolute.

**The cycle-140 threshold got its first test and held.** `--against` reported ten drifted;
ten is not more than ten, so they were fixed inline and cost minutes rather than a third of
the cycle. But the unit is wrong: `citation_check` counts distinct TARGETS and prints
"drifted", so fixing one reveals the next citing location and the pass looked finished
twice before it was — three rounds this cycle. Filed.

## What cycle 140 taught

**The decision the bead asked for had already been made, in a code comment nobody would
find, and it was wrong.** `game/cue_legend.gd` had refused the sole-cover rings a legend
row with a good argument — the page teaches the dashed ring, and the road rings are the
same node's positive case, so the concept is on the page. A player looked at the board and
asked what the marks meant. The note is amended rather than deleted because HOW it failed
generalises: the revisit condition it set itself was "if row 4 gains an instance that is
not SoleCoverMarks", a fact about the drawing code, while the condition that actually fired
was a fact about a person. **A teaching decision cannot set its own trigger in the code it
is about.** That is cycle 138's lesson one node over — a comment addressed to a role nobody
holds — pointing this time at an event nobody was watching for.

**A third budget existed and only one of the three was written down anywhere findable.**
The legend page's 300px is this project's most-cited number. The notebook's HINTS page has
the same matte and a completely separate capacity model, and nothing outside
`notebook_screen.gd` mentions it; the sixth hint's card overflowed it by 35px and a test
caught it. The message row's width is a third. All three are now at their limit at once for
the first time, so the next cue this game draws cannot be taught by adding a row, a hint or
a card — filed as a decision bead, deliberately before the cue arrives rather than during
the cycle that ships one, which is how the lane-pressure hatch ended up untaught.

**Nine more citations were already dead, and two of them were stale COUNTS.** Same class as
cycle 139's eleven, same discovery mechanism — an unrelated edit moved them and the landing
got read. Two could never be caught by any line-number check: an entry said `show_message()`
"has eight call sites" when the checker prints twenty on every run, and another said the
waivers "live in five scattered comments" when there are six. Both now derive their number
from the tool that counts it.

**Step 5's change, and it is about scheduling rather than about tooling.** Two cycles
running, the citation pass took roughly a third of the cycle, and its size is set by how
many lines the cycle's feature happened to insert into a busy file — nothing to do with
what the cycle is for. Step 3 now says that past ten drifted, the relocation is a work item:
fix what your own entries cite, file the rest, say how many you left.

**And the rule added last cycle caught the hand that wrote it.** Quoting the broken range as
an example inside the entry reporting it made it a live citation and failed the checker on
the spot. `kanban-idea-pass` rule 1 is right; it is also easy to break while writing about
the thing it forbids.

## What cycle 139 taught

**Eleven citations were dead by eight hundred lines, and the only thing that could ever
have revealed them was an unrelated edit.** Adding 30 lines to `game/pest.gd` for a pest
recoil drifted eleven `kanban.md` citations; reading where they landed showed every one had
already been wrong long before this cycle, pointing into a shape that file had years ago.
Three claimed `Pest._gait`, three `_update_facing`, and two landed on **blank lines**, which
match anything and would have survived an offset restore looking perfect. Nothing was
careless: `citation_check` plain mode proves a line EXISTS and says so itself, and
`--snapshot`/`--against` records the wrong text as its own baseline, so a citation already
wrong at snapshot time compares clean forever. Cycle 138 found four of these; this cycle
found eleven more, in the same file, by the same accident. The class is not rare and the
detection is structurally blind to it — `plant-tower-defense-nalv` asks for the `--symbol`
mode that would fire without needing anything to move, and is cross-noted onto `-2174`,
because a relocator built without it makes already-wrong citations HARDER to find.

**Two self-inflicted citation traps, both of which look like careful work.** Writing a
correction note that named the two wrong line numbers re-created them as live citations —
there is no quoting form, the checker sees text — and a bare `:NN` in `kanban.md` binds to
the last full path before it, so listing eleven dead `pest.gd` numbers inside the entry
reporting them would have re-filed all eleven. Both caught only by re-running `--against`
and watching the count go UP. Written into `kanban-idea-pass` rule 1.

**The run that measured the recoil found something a test over the constants cannot.** The
headless suite asserts `FLINCH_RADIANS > GAIT_SWING * 2.0`; the running game showed 24
samples of unhit pests peaking at `_sway=0.129999750999911` — `GAIT_SWING` to seven decimals,
so the walk genuinely attains its own analytic maximum while the shot pest reached 0.366.
The two populations do not overlap at all. A constant-vs-constant test cannot tell that world
from one where the gait never approaches its ceiling and the "2x separation" is fiction.

**The loop, `fan-out-a-cycle` and `loop-forever` are one skill now.** 830 lines across three
files became a 144-line `SKILL.md` plus `references/{why,gates,fan-out}.md`. `loop-forever`
was superseded rather than merged: its frontmatter was malformed, so the skill listing showed
the literal string `name: loop-forever` as its description, and its body told the agent to
keep a TodoWrite list and treat `kanban.md` as the queue — both replaced by `bd` many cycles
ago. That is step 5's one change, and it spends it on deleting.

## What cycle 138 taught

**A player asked what the marks on their board meant, and the repo had already written the
answer down and filed it under someone else's name.** `game/cue_legend.gd:61-74` records,
in full, that `OVERLAY_GRAMMAR.md`'s "derived from the draw calls" recipe is structurally
blind to `Board.mark_dead_ground` and `Board.mark_deferred_road` — they paint Line2D
children and call no `draw_*` at all — and it ends "reported to whoever owns
OVERLAY_GRAMMAR.md rather than fixed here". Nobody owns OVERLAY_GRAMMAR.md. The report sat
there through several cycles until a user looking at a screenshot rediscovered it from the
outside. **A comment addressed to a role nobody holds is not a report, it is a note to
self**, and the fix is a `bd` item, which is now `plant-tower-defense-ktti`.

**Reading the draw calls was the wrong way to identify a drawn mark, twice over.** The
32×5 dark bar was theorised as `WeatherOverlay.DROUGHT_MARK` (a horizontal line — but 7px
and unaligned to the grid) and then as a pest health bar (a 32×5 ColorRect at (−16,−34) —
the right shape, but no pest within four cells). What settled it was
`screenshot --hide <plant>/SoleCoverMarks --region 385,140,80,190`: the rings vanished and
the bars stayed, so they were two cues rather than one glyph. Five hide-and-compare rounds,
filed as [G-138] upstream and as `plant-tower-defense-0cl8` here.

**The failure a comment describes is still a failure you will commit.** `Hud.row_is_quiet`
exists solely because a level-triggered hint stacks copies into a busy row, and its header
says so at length. The fifth hint went in without the guard anyway and shipped 11 refused
messages into a realistic run before the suite caught it — by a symptom test three files
from the cause, whose message correctly says "a caller stacking copies into a full queue"
and does not name the caller. Documentation is not a gate; `plant-tower-defense-j724` is.

**A citation relocation that satisfies `--against` is not a citation that is right, and
this cycle can put four numbers on it.** One `const` near the top of `game.gd` drifted 63
kanban citations. Offsets from git's hunk map, applied over each entry's span and iterated
to a fixpoint, fixed 59 of them. The four that survived every automated pass had snapshot
text of: a blank line, two bare comments, and a `spend_hint` one line below the
`show_message` the entry was actually describing — **all four were already wrong before
this cycle touched anything**, and a faithful offset would have carried each forward with
the check green. Measured onto `plant-tower-defense-2174`, whose subject is a relocator
that refuses rather than one that renumbers.

## What cycle 137 taught

**A feature can be invisible for its whole life because the CAUSE is in a different file
from the SYMPTOM.** `Hud.show_weather` writes the banner; ten lines later, in the same
function and the same call stack, `Game._on_wave_started` writes it again with the wave
headline. `show_weather` is called from nowhere else. So the weather banner has never
once been visible to a player, and no gate could see it: a test calls `show_weather` and
watches the Label change, correctly. `show_weather`'s own header even said "this one is
the overwritten half" — the code knew, and the reason lived in another file's statement
order. Found by a lane that opened `game.gd` instead of trusting its own bead's header.

**All four lanes reported their bead UNDERSTATED or partly refuted — five cycles running
now.** "~100 bindable keys" was 193. "Three writers" was four public plus two internal,
and the fourth was a *clearing* writer, the class an arbitration exists to handle.
"A fixed 140px column, neither derived" had been derived for cycles. "The same eight
keys" was six on one screen and nine on the other. Zero beads were flatly wrong. Ask "is
it at least this bad", because an understated premise reads as confirmation.

**Two lanes independently reported `derive-the-list` insufficient, for two DIFFERENT
reasons**, which is worth more than either alone. One hit a derivation whose predicate is
a judgement ("the keys the engine names badly") and has to be a stated proxy; the other
hit the record-it-or-derive-it fork, where both options are principled and the deciding
test is whether a static context can even ask. Filed rather than built — one
identification each.

**Following a rule exactly can produce the wrong number, and the rule was mine.** The
loop said make `scene-tree` the last thing before `quit`. Cycle 137 did, having spent ten
verbs inside the Keys screen first — and `reach` reported `key_binding_screen.gd` NOT
reached, correctly, because reach reads a SNAPSHOT and not a history. The deadline is not
"before quit", it is "while the diff's node is still in the tree", and there is one per
screen. Two captures moved the row from 3/7 to 4/7 over an identical session. The bullet
is amended; that was this cycle's one workflow change.

**An advisory check chained with `&&` before an irreversible write is not a guard.**
`run_json_check` printed two findings — `lint` absent, `tests` absent — exited 0 because
it is advisory by design, and `verify_ledger record` proceeded and wrote `null` for both
on a run where lint was clean and the suite was 959/959. The ledger is append-only, so
the row stands wrong. Being advisory is right for a standing check and wrong for the last
thing before an append.

**Git already knows the citation map; four cycles of hand-relocation did not use it.**
`git diff -U0` gives every hunk's exact old→new correspondence, so a surviving line has
one true new number and a line INSIDE an edited hunk has none and must be REFUSED —
which is the feature, because that is exactly the citation whose *claim* may be stale.
Moved 64, refused 0. A per-file offset would have been wrong by construction and would
have satisfied `--against` anyway, since the check compares text and a blank line matches
anywhere.

**A lane that dies mid-flight leaves a worktree indistinguishable from one that
finished.** All four died to an expired login a minute in, each leaving a registered
worktree on its `lane/<id>` branch with a clean `git status`. `git log main..lane/<id>`
being empty is the tell; `git status` is not. Also found an empty worktree directory from
three days earlier that `git worktree prune` reported nothing about — and learned that
`git -C` on a non-worktree directory silently answers for the parent repo.

## What cycle 136 taught

**A relocation pass has to be able to REFUSE.** A five-lane merge drifted 105 citations, and
`hud.gd`'s real offsets spanned 0 to +127 — so the single per-file offset that worked in
cycle 131 is wrong here by construction. Piecewise interpolation between bracketing anchors
handled 25 and refused 8 where the anchors disagreed, which is precisely the signal that a
citation sits inside an edited region. Reading those 8 found three describing problems that
had since been SOLVED. Patching a line number into prose whose claim is stale produces
something that looks checked.

**A budget can be wrong in the SAFE direction and survive on the strength of the comment
beside it.** The packet rack was priced 2pt too wide, so nothing overflowed and nothing
complained; it simply reported less headroom than it had, while its comment argued the
reasoning correctly and concluded it wrongly. The instrument that caught it asks each budget
what size its own WIDGET resolves, rather than what size the budget thinks.

**A fixture asserting only the exit code passes four of this cycle's mutations.** A checker
rule that had never been exercised, an un-anchored waiver, a stripped comment pass, and a
severity branch all removed a real finding while the gate stayed green. Assert the finding
count and the named case.

**Deriving the list beat reading the bead for the fourth cycle running** — four of five lanes
reported UNDERSTATED premises, and one refuted its own bead outright with two of the game's
own strings.

## What cycle 135 taught

**Measure a proposed rule against the incidents it was filed for, BEFORE building it.** A
lane was asked to build "no bead without a citation" and instead checked it against all five
documented false-premise beads in this project's record. It would have caught zero, the
correlation runs backwards — the four most heavily cited beads are the four whose premises
turned out false — and it would have stood red on 21% of the queue. The lane wrote no code.
That is the best outcome a lane produced this cycle.

**A test that derives its expectation from a constant cannot protect prose that quotes a
number.** `CAMPAIGN_HEALTH_STEP` went 0.04 → 0.03 a cycle ago and the six figures its comment
argues were never re-derived. Both tests over that ramp compute their expectation from the
constant, so they pass identically at either value: correct about the shape, blind to every
magnitude. Derived-not-typed is house style here, and this is what it costs.

**A list written from a bead is a stale number with extra steps.** My `BUDGET_FLOOR_ACCEPTED`
came from the bead's "three rows"; the running game says four, and my draft named one that is
not at floor while missing two that are. Every headless test passed, because they assert the
warning against whatever the list says. Read the live value before writing the constant, not
after.

**"Is it at least this bad" is a different question from "is this true", and nothing checks
it.** Four beads across cycles 134 and 135 were UNDERSTATED — five call sites that were 21, a
class dismissed as less exposed that was the real exposure, a producer count stale by 85
commits, a fallback already 80% shipped — against zero that were flatly wrong.
Confirm-the-premise catches the second kind and reads an understated premise as confirmation.

## What cycle 134 taught

**A stale lane's gates all pass, because a stale tree is internally consistent.**
`isolation: "worktree"` branches from `origin/main`, which this project keeps deliberately
behind — 81 commits, on the fan-out that found it. Every one of four lanes started there, and
the danger is not the merge conflict: it is a lane reporting "the bead's premise is false"
with every checker green, because on its tree the premise really was false. One command
before spawning: `git rev-list --count origin/main..HEAD`.

**"Premise wrong" and "premise understated" need checking for separately.** Two beads this
cycle understated their own scope — five call sites that were 21, and a "less exposed" class
that was the real exposure. An understated premise reads as CONFIRMATION when you check it,
which is why confirm-before-claim caught the wrong ones and not these. Ask "is it at least
this bad", not "is this true".

**A waiver subtracts from the denominator without moving the gate.** Un-anchoring one made a
real finding vanish while the exit code stayed 1. A suppression marker therefore needs a
fixture MORE than the rule it suppresses does, and three checkers here had none.

**Measure a detector against the damage, not against a case you chose.** Deriving the corpus
— every prose comment line with its `#` deleted — showed 6.3% recall where a hand-picked
fixture would have shown a working detector.

**And I corrected my own P1.** Cycle 133 blamed `--snapshot-userstate` for stopping saves on
a paired measurement. Reversing the run ORDER disproved it; the real cause was an unknown
milestone id poisoning `earned_milestones`. A paired measurement is not a controlled one
until you have swapped the order.

## What cycle 133 taught

**A safety mechanism whose success message does not depend on anything having happened is
not evidence.** `launch --snapshot-userstate` prints `userstate: restored 1 file(s)` every
time, and I read it twice in cycle 131 as confirmation the flag was working. That much still
stands. **The rest of this paragraph was wrong and cycle 134 corrected it**: I measured
`_save()` FALSE under the flag and TRUE without, and concluded the flag stopped the game
saving. Reversing the run ORDER gives TRUE under the flag. The real trigger was an unknown
milestone id poisoning `earned_milestones`, and the flag copies files into `.devtools/`
without holding anything open. **A paired measurement is not a controlled one until you have
swapped the order** — that is cycle 134's lesson and it belongs here, next to the mistake.

**A `-> bool` on a save function is worth more than it looks.** `_save -> FALSE` is a
complete diagnosis in one command. That return was added in an earlier cycle for exactly this
reason and it paid here; a project whose save returns `void` meets this bug as "the feature I
verified does not work for the one person who would notice".

**A bead can be right that something is broken and wrong about what.** `-zzx3` said the flag
failed to RESTORE, so a write survived. The write never happened. Closed rather than edited —
leaving it open sends the next reader hunting a restore bug that is not there.

**An eagerly-built failure message fires whether the assertion passes or not.** One `%r`
emitted 12 engine errors per suite run, in exactly the section where a real aborted-test
error would appear. The message argument is evaluated before the call; a bad specifier there
costs every run, not only failing ones.

**Back up by hand before an experiment that can write real user data.** The bead being
investigated was itself the warning, and it was right about that part.

## What cycle 132 taught

**"Some citations are imprecise" was always true and never actionable; 58 is.** The value of
`--weak` is the denominator, not the list. 58 of 937 resolved citations land somewhere no
text comparison can check, and four sampled from `kanban.md` were all wrong — one by 1900
lines. Fourteen of fourteen across four cycles, so read the 6% as a floor on the
wrong-citation count.

**A checker whose failure mode is printing ZERO needs a fixture that fails both ways.** A
weakness rule calling nothing weak prints `0 of 937` and reads exactly like a clean corpus —
the same shape as `--beads` two cycles earlier, which read one citation in six and printed a
clean sweep. Case 7 asserts blank and `##` ARE weak and that a distinctive line is NOT.

**When one member of a coordinate list is wrong by 1900 lines, re-derive the list.** Fixing
the one you sampled and leaving seven unread produces something that LOOKS checked, which is
worse than something obviously stale.

**The heredoc rule was broken again, in the cycle about silently-wrong pointers.** Python
turned it into an immediate `SyntaxError`; the GDScript case the rule was written for
compiles and passes the suite. Fifth occurrence. The skill already says a log entry is not a
countermeasure and using the right tool is.

## What cycle 131 taught

**A green suite proved a fix worked and the game was still broken.** Serialising the packet
flourish is correct as far as it goes, and the test asserting it passed beside 919 others,
`lint 0/0`, a clean import and all nineteen parallel-safe checkers. Re-running the bead's own
live recipe produced the identical `refused 1` and `refused_log` from two cycles earlier. The
test fired both purchases in the SAME FRAME — the one case the wrong fix did cover. This is
the entry to point at when `overkill` starts looking like the usual verdict: seventeen lines
of GDScript, every static gate green, game broken.

**When a defect is about two things overlapping, the test's timing IS the test.** "Both at
once" is the easiest case to construct and is often the only one that does not reproduce. A
flourish lasts a quarter of a second; real purchases arrive half a second apart, so they
never overlap and the guard never engaged. Ask what interval the real producer works at
before picking one.

**A field set "immediately before" a call stops being safe the moment that call can wait.**
`_opening_tier` was assigned just before `buy_packet()` and read inside the flourish — fine
while one flourish could exist, wrong once a purchase can queue. Every "set just before"
field in this codebase is a latent version of this, and the trigger is always making
something asynchronous that used to be immediate.

**Yesterday's debug verb is today's production reader.** `message_seconds_left()` and
`message_priority()` were added last cycle so `cmd messages` could report the row. The fix
uses them instead of recomputing `5.0 - MESSAGE_MIN_READABLE` in a fourth place. And
`cmd messages` itself is why the bug was diagnosable at all: `refused 1` plus the dropped
line's text, in one call.

## What cycle 130 taught

**A warning written inside a bead does not survive contact with the next bead.** `-pa4g`
said "two of my last four absence claims about this codebase were wrong, both because the
enumeration was over the wrong set". I read it, ran the audit it asked for, and filed an
absence claim enumerated over one file — `game/notebook_screen.gd` never says "drought", so
the player is never told — while the HUD says it three times. The fix is placement: the
lesson now lives in `notebook_screen.gd` beside `KIND_LEGEND`, immediately after the
paragraph arguing FOR adding a page, where somebody about to add one is already reading.

**The preventive rule has to be a command, not a judgement.** Not "check whether the game
explains this" but "grep the HUD for the mechanic's own vocabulary". `drought` appears in
`game/hud.gd` four times, and one grep in cycle 127 would have stopped the bead being filed.

**Read back citations in CODE COMMENTS too, not just in kanban.md.** The comment recording
this decision quoted the banner as "pests pay 25%" — twice, invented rather than read.
`WEATHER_DROUGHT_SEED_BONUS` is 1.5, so it says 150%. The citation beside it resolved
perfectly; the prose was wrong. That is exactly the case `citation_check`'s NOT COVERED line
describes and cannot catch.

**A decision recorded in a comment is as perishable as a count.** Two cycles ago this same
file said "the five here" beside six rows. So the decision not to add a weather page is
asserted rather than merely written: the banner must carry both halves, the prep note must
name the weather before seeds are spent, rain must be announced, clear must stay silent. If
somebody deletes the banner, the gate reopens the decision instead of a reader noticing.

**Rule overridden, deliberately, and named here.** `-47v7` is a fully diagnosed P2
player-facing bug and was the obvious next item — but cycles 128 and 129 both worked the
message row, and taking it would have made three straight. It is filed with a complete
diagnosis and a reproduce recipe, so nothing is lost by it waiting.

## What cycle 129 taught

**A bead that names the evidence which would justify it beats a bead that argues for
itself.** `-a9pi` refused to answer its own question and set a condition instead: build the
verb only if the re-measurement of cycle 93's answer reads the counters repeatedly across
scenarios. Cycle 128 then read all four eight times across five scenarios, for reasons that
had nothing to do with wanting a verb. A tiebreaker met by a measurement taken for another
purpose is the only kind that cannot be rationalised afterwards. Write more beads this way.

**A counter and a log answer different questions, and the gap was a whole severity rating.**
`messages_refused` is the same number whether the player lost a cosmetic flicker step or the
line naming the plant they just paid for. One `append` turned that into `refused_log ["The
packet held a Chomp Flower!"]` — a reveal, the serious reading. When a counter exists to
describe something the player did NOT see, the thing they did not see is the datum and the
count is only a summary of it.

**Keep a short tail of anything transient you count.** The refused log read correctly after
the row had cleared entirely — `row_text ""`, `0 pending`. A transient only readable during
the frame it occurs in is a transient nobody diagnoses; this is why `findings_last.json`
exists, and the same argument applies to every counter in the project.

**The house gates caught the new verb before I did.** The positional-verb classifier and
`suite_reach_check` both fired on the first suite run after registration, and neither is a
test written for this work. The second produced the better assertion: that
`message_queue_snapshot()` returns a copy, so a verb whose only job is to look cannot be
used to edit what it is looking at.

## What cycle 128 taught

**A control that produces ZERO is what converts a reading into a cause.** `messages_refused`
= 12 beside four packet purchases is a correlation, and this cycle's bead existed precisely
because cycle 93 had accepted one of those. Three deliberately boring runs — a purchase on a
quiet row, a purchase over a held ambient line, twelve pest kills with no purchase — all
returned zero, and a fourth reproduced the refusals with **no purchase at all**. That last
one moved the claim from "packets refuse messages" to "an IMPORTANT line held longer than the
next IMPORTANT post's patience refuses messages", which is a fact about `Hud` rather than
about packets. Budget for the controls; they are most of the work and all of the confidence.

**A comment that is accurate about the single case reads as coverage of the general one.**
The packet flourish's comment says each flicker replaces the last rather than queuing, and
that is TRUE — the preempt control confirms it — for one flourish. Two overlapping is the
only case that drops lines and nothing anywhere describes it. Both cycle 93's close and this
bead's own prime suspect were reasoned from that comment, and both were wrong.

**Do not correct a durable note you have not diagnosed.** `cycle-log.md` says a touch
press/release at a plant's `global_position` selects it; four attempts left `selected_placed`
empty. Three explanations are live and none was checked, so the note stands and the bead
names the check. Replacing one unverified sentence with another is not a correction.

**Half an acceptance is reported as half.** The uproot producer could not be driven at all —
nothing on the bridge selects a placed plant — so the close says the `MESSAGE_DEADLINE` half
is unmeasured rather than quietly scoping it out.

## What cycle 127 taught

**A surface can show a right number and a wrong number at the same time, and that is what
keeps the wrong one alive.** The notebook's legend page has always derived its source line
from `CueLegend.row_count()`. Its note, one field over in the same dictionary, said "the five
here" beside a six-row table. Anything that compared the two would have caught it instantly;
nothing was comparing, and the correct number sitting next to the incorrect one made the page
look checked. When auditing a screen, the numbers that agree with each other are worth less
attention than the two that come from different places.

**The audit found the opposite of what it went looking for.** `-pa4g` expected stale
mechanics after several cycles of new ones. Every structural count on the notebook derives
from its table and says so in a comment; all three findings were in hand-written English.
That is a better result than a list of drifted pages, and it is only visible because the
audit enumerated what it checked rather than reporting what it found.

**When a fix replaces a literal with a derivation, assert the DERIVATION.** Two of the three
new assertions pass if somebody deletes the placeholder and hard-codes "six" — the original
defect with a newer number. Only the third, which requires the `PAGES` entry to still contain
`%s`, can tell the difference. Every value-assertion is also satisfied by a fresh literal.

**The workflow did not change this cycle, and that is the entry.** Step 2's confirm-before-
claim caught `-pa4g`'s stale motivation (it claimed the notebook was untouched in seven
cycles; five commits say otherwise). Step 3's citation read-back caught my own
`notebook_screen.gd:611` going stale inside the same cycle that wrote it — my edits moved it
to `:618`. Both rules did exactly what they were added for, on the first cycle after the one
that widened them. Adding an eleventh rule on top of two that just worked would be the wrong
lesson to draw.

## What cycle 126 taught

**A clean run over an input set you never measured is the same lie as a clean run over an
empty one.** `citation_check --beads` shipped its first working version reporting
`468 bead(s) ... 0 finding(s)` while extracting ten citations from 468 beads. `bd` stores
`description` and `close_reason` as plain text -- nothing renders them, so nothing rewards
backticks -- and the regex demanded them: 95 backticked against 495 unbackticked, so the
mode read one citation in six. Every number printed was true. The only thing wrong was that
ten-from-468 is implausible, and noticing that is a thing a reader has to do. The fixture
notices instead now.

**Re-run a new checker over the artefact the cycle itself just produced.** The first bead
this feature ever closed waived itself: the close reason explains the waiver marker, and the
marker was a bare substring. 468 beads became 467, three citations left the denominator, exit
code stayed 0. Nothing in the loop would have caught it -- it was found by running the tool
once more, over its own close, for no reason other than curiosity. That is now the cheapest
known way to test a prose checker: point it at the prose the cycle wrote about it.

**An opt-in mode on a derived checker pool never runs.** `check_all.py` derives its members
by reading source for a contract marker, which is the right design, and called
`run_one(name, [])` -- so a flag was the one thing it could not derive. `--beads` would have
shipped inert with the pool still printing `citation_check.py clean` meaning kanban.md only.

## What cycle 125 taught

**Rung names are priced, and nothing said so.** `Hud.selection_corpus` crosses every plant
name with every upgrade-rung name, so the longest PAIR sets the height of the whole
selection stack. A top rung called "deep thicket" — 30 characters against the previous worst
of 25 — pushed `hud_selection_panel` **25 px through its floor** before a pixel was drawn.
Renamed "bulwark": 25 characters, exactly the existing worst case, and it climbs where "deep
thicket" did not. **Three name tables in this project are budgeted and only one now says so.**

**The ladder buys resistance, not health, and the test has to assert the reason.** "Each
rung holds longer" is equally true of the bigger-pool version the bead argued against, so
the test compares what a second of Aloe healing is WORTH at the bottom rung against the top.
Mutation-tested by flattening the resistances — which is exactly what a pool ladder looks
like from here.

**I introduced SIGNATURE B and the survey built last cycle for it reported 0 hits.** Its
`PROSE` regex needs a capitalised first word and no code tokens; my broken line started
lowercase and contained `selection_level_names()`. **Lint** caught it. A detector's name is
not its coverage, and this codebase's comments cite function names constantly — so the
excluded set is large and is exactly the prose most likely to lose its marker in a bulk edit.
Filed as `-n228` with "build the control case first", because that survey's first version
reported 554 false positives.

**Fourth script-edit damage this session, all mine.** Three were caught by lint, one by the
runner's stderr. The rule is right and I keep reaching for the forbidden tool when an `Edit`
match looks awkward.

## What cycle 124 taught

**I broke the file that detects the break, with the break, for the third time in its
history.** Writing `heredoc_survey`'s own `NOT_COVERED` constant through a shell heredoc
turned every escaped newline into a real one inside a string literal — twice in one patch,
unterminated strings at exactly the lines the patch touched. Its header already records two
such incidents from when it was first written. Fixed by joining a list of plain lines, which
has no escape to eat.

**Third occurrence of the no-scripts-write-source rule this session, and all three were
mine.** The rule is right. I keep reaching for the forbidden tool when an `Edit` match looks
awkward, and the correct move is `Read` the bytes and `Edit` again.

**The exit code has to depend on which question was asked.** A hit in HISTORY already
happened and was already fixed — gating on those is permanently red, which
`house-static-checker` calls worse than no gate. Only `--worktree` gates. That is also why
this stayed OUT of `check_all`'s pool despite being perfectly parallel-safe: the pool runs
each file one way and has nowhere to say "with a flag".

**A fixture that is not tracked is invisible to any check that asks git what to scan.** The
positive control needed `git add -N` first. That is the **third vacuous fixture this
session**, each for a different reason — an absolute Windows path the regex could not match
(116), the wrong colour read (121), untracked (124) — and **all three announced themselves in
a denominator I nearly did not read.** Run the setup, read the number, then trust the
assertion.

**The rule now has a check a fan-out lane can run.** `lint_project.gd` was the only thing
that could see this class and it is not parallel-safe, so a lane got `name_check` and nothing
else. `--worktree` is stdlib and takes a second.

## What cycle 123 taught

**The shop and the panel disagreed about the same plant, one click apart.** The Sundew's
blurb said *"crawls at half speed"*; `SLOW_FACTOR` is **0.55**, and the selection panel
prints the real number — *"Slowing N pest(s) to 55% speed."* Both on screen. Both
individually defensible. Together a contradiction a player can see without leaving the
screen.

**Check prose against the READOUT, not only against the constant.** "Half" is a fair
description of 0.55 and "55%" is exact; each is true of the constant and the pair is wrong.
That is the general finding, and it applies to three more pairs nobody has compared.

**The sentence moved, not the constant.** 0.55 is tuned and carries its own
overlapping-patch reasoning. Changing a balance number to make a blurb true is the tail
wagging the dog — and the assertion is a RELATIONSHIP, so a future retune to an actual half
makes "half speed" permissible again rather than leaving a test that pins today's wording.

**Six of the seven unpinned blurbs were true**, which is the honest shape of the result. The
writing here is careful and the numbers behind it are right; what was missing was anything
that would notice when the code moved underneath the prose.

**One clause is true and not mechanically checkable, and saying so is better than a gap in a
table.** The Bramble's "Hurts nothing" is an absence of damage code, not a value — and
`engages` is the obvious key and the wrong one, because the Bramble engages by HOLDING.
Three separate readouts have now wanted "damages" specifically and each uses a proxy that
works today for unrelated reasons. Filed as `-i8k9`.

## What cycle 122 taught

**The emulated mouse event arrives BEFORE the touch that produced it.** Measured, not
reasoned about: `PROBE mouse press device=-1 touch_index=-1` then `PROBE screen touch
pressed index=0 device=0`. So every design that guards the mouse path with a flag set by the
touch handler is wrong — **and looks right**. The first implementation of the touch layer
planted at the press cell, which is precisely the behaviour commit-on-release exists to
remove. The discriminator is the device id (-1 emulated, 0 real), narrowed by
`is_touchscreen_available()` because -1 means *synthesised*, not *from touch*.

**When two input paths can describe one gesture, the arrival order is a measurement.** It
cost a `print()`, one bridge verb, and reading `.devtools/launch_stdout.log` — two minutes.
This project has three other places where two paths describe one action and none has been
measured.

**Emulation cannot be turned off, and that is now load-bearing.** Every Button here is a
Control answering MOUSE events, so switching emulation off to get clean touch handling would
kill the shop, the pause card and every Back button on exactly the devices touch is for —
and would pass every headless test, because tests press buttons through `pressed.emit()`
rather than through the pointer.

**The bridge and the suite covered genuinely different halves, for once.** Three cycles of
declining launches made that easy to forget. The headless test cannot reach the
emulated-mouse guard at all — `is_touchscreen_available()` is a property of the machine —
so `set-feature --touchscreen` plus `touch press/drag/release` was the only way in.

**Three of four acceptance clauses, and the fourth split out.** "Reproduced on an actual
touch device" is a criterion no commit can produce, so it is `-bfbb` with the three ways a
real device differs from the bridge written down. Leaving it inside would have made a
finished item look unstarted in `bd ready` — which `-6cqi` did for twelve cycles.

## What cycle 121 taught

**A skill's first application disproved one of its own sections, in about ten minutes.**
`palette-against-the-background` had been identified three times and never built. Section 5
told you to audit an existing sprite by reading its dominant colour's luminance gap against
the background. Run on the real set, that flagged **five sprites and every one was fine** —
Mint at dL 13, Aloe at 9, the aphid, Shield Bug and Queen at 17–18.

**The separation lives in the RIM, and nothing had written that down.** `STYLE.md` mandates
"outline = darker shade of the fill, 2px" and justifies it as matching the kit's look. Its
real function is legibility against the ground — which means **the fill is free to sit
anywhere**, and a fill-only audit condemns most of the set by design. The section now reads
the best MAJOR colour with a 5% floor, and records the 5-of-5 false-positive rate.

**The two corrections guard opposite failures.** Without the rim fix the check fires on
everything; without the 5% floor "best major colour" becomes whatever two-pixel highlight is
brightest and it passes on everything. Either alone would have been worse than useless.

**The corrected result is 0 findings over 22 sprites**, and that is a meaningful clean
result rather than a vacuous one only because the denominator is stated and the method had
just survived being wrong.

**This is precisely what the loop's "USE it in the same cycle" rule exists for.** The rule
says the first application tells you whether the skill is a recipe or an essay. One section
was an essay. Writing it well would never have shown that.

## What cycle 120 taught

**A save confirmation must not claim work was lost when it was not.** `RunConfig._save()`
has four failure paths and three of them lose the write — but the RENAME failure does not:
its own warning says *"The finished save is at %s and _load will adopt it"*, so the record
is complete, validated, on disk, and adopted next launch. It returns **true**. That was the
only real judgement in the change, and it is the failure direction a player cannot recover
from by ignoring the message.

**Silence is the confirmation; only the failure gets words.** Appending "saved" to every key
capture would put a word about disks on a screen about keys, forever, to cover a case that
essentially never happens. `persisted_note` therefore returns its caller's own sentence
UNCHANGED on success — which is also what made both branches pure and assertable with no
screen and no failing disk.

**A sentence a player will almost never see is the one most likely to ship misspelled.** The
failure branch is unreachable without a filesystem fault, so nothing in normal play or
normal testing renders it. Building it as a pure static both branches of the test read is
the cheap insurance; assembling it inline at the two call sites would have put it where
nothing could see it.

**The launch was declined for SAFETY, a first this session.** Every earlier decline was "the
test already makes this claim". Here the branch is only reachable by making a save FAIL, and
doing that live writes the developer's real `user://` — `--isolated` does not isolate it.
Worth adding to cycle 115's launch-triage question: *"what claim can the launch make"* has a
sibling, *"what would the launch have to break to make it"*.

**Filed `-05va`:** four other things still write without being able to say whether they
landed, and the honest answer for some of them is probably "say nothing, and here is why".

## What cycle 119 taught

**The shop line had already answered the question.** `-l86t` asked whether the chew ring's
0.45s flash is readable and proposed suppressing it below a threshold. `PlantCatalog`'s
Chomp entry reads *"Eats small pests instantly. Big ones take a while — and it is busy the
whole time."* A 0.45s sweep reading as instantaneous is the cue agreeing with the sentence
the player was sold. The bead called it "a design question nobody has asked"; it had been
answered, in the shop, and nothing checked the answer was still true of the numbers.

**A cue's ABSENCE is a claim, and it is the half nobody designs.** The ring means BUSY — a
Chomp mid-chew cannot grab — so no ring means FREE. Suppressing it would have made a busy
mouth read as a free one at the moment a player is scanning for one to use. The bead asked
whether the flash is readable; the sharper question was what its absence says.

**Two numbers would have gone stale, so it became a relationship.** The acceptance asked to
"record both chew durations as numbers". Recorded numbers are the shape this file has spent
cycles removing. The test derives them from `Pest.SPECIES` and pins all three clauses of the
blurb, so a retune that makes an aphid slow to eat fails rather than quietly making the shop
lie. Mutation-tested: aphid 0.45 → 1.2 fires the gap assertion.

**Writing a test paid down recorded debt, and the gate noticed.** `chew_progress` sat in
`suite_reach_baseline.json` as a symbol no test named; the suite failed telling me to
re-bank it. 43 symbol findings down to 42. A debt list that notices its own repayment is
rare.

**Seven of nine shop blurbs promise things nothing checks** — the Sundew's "half speed,
wings included", the Aloe's "too slow to save one being eaten", the Mint's "a third again as
fast". Every one is a number living elsewhere, and every one is read by a player deciding
how to spend. Filed as `-2878`.

## What cycle 118 taught

**A decision pinned only where it holds is not pinned.** The husk rot floor was defended by
two assertions — nothing rots faster than 4.5s, and everything at or above `FULL_VALUE`
shares it — and **both are satisfiable by flattening the curve entirely.** Making every husk
rot at 4.5s would "fix" the inconsistency the bead complained about and pass them. Only a
third assertion — that below the saturation point a richer husk rots STRICTLY faster —
tells "the floor is deliberate" from "the whole curve was deleted". Confirmed by mutation,
not argued. Same class as a non-empty denominator, one level up: a denominator stops a check
passing over nothing; this stops one passing over everything.

**An argument for why a constant has its VALUE is not an argument that the BEHAVIOUR is
right.** `FULL_VALUE`'s comment argues at length against widening it ("a balance change
wearing a legibility fix's clothes") and it is easy to read that as settling the matter. It
settles the knob. Whether a 60-seed husk *should* share a 9-seed husk's rot floor is a
different question, and it had never been answered. It is now, with different reasons —
4.5s is a reaction time, the richest husks come from the two bosses and therefore drop at
the busiest moment on the board, and the failure modes are asymmetric. Filed as `-8v43` for
the constants nobody has swept.

**Nothing player-facing shipped, and the sentence the loop asks for:** the item was a design
question whose honest answer turned out to be "the current behaviour is right and was
undefended". No balance moved. That is a real outcome for a bead filed "so the question is
on the record, not so it gets built" — but it means cycle 119 takes a player-facing item.

**The drift report's new "written at" line paid for itself one cycle after being added.**
Three citations drifted from a comment I inserted; the report named all three and where each
was written, and the fix was three edits with no searching. Last cycle the same report left
twenty to be grepped out of a 4000-line file.

## What cycle 117 taught

**The drift checker found 48 stale citations on its first real cycle.** Cycle 116 built it
because drift had bitten twice and been caught by hand both times. Its first genuine use
reported **48** — every one written by an earlier cycle, moved by this cycle's edits to
`game.gd`, and every one reported CLEAN by the ordinary run because each still landed
somewhere real. The manual rule ("read every citation back after the edits") was being
honoured all along — for the two or three written *that* cycle. **A discipline scoped to
what you wrote cannot maintain what everyone else wrote.** All 48 are fixed.

**A finding must name where you go to act on it, not only where the problem is.** Fixing
those 48 meant locating each in a 4000-line file, and 20 were bare `:NNNN` continuations
whose number repeats. The checker already knew the citing line and did not print it. It does
now, and that turned the last third of the job from a search into an edit.

**The notebook refused the fourth hint, exactly as its own prose predicted.** *"A FOURTH
hint does not fit."* Both ways out it named were considered: the pitch cannot drop (four rows
need 67 against a 94px row, and shrinking the note clips the UNSHOWN form, which the same
block calls the state a reader most needs), so the page splits — still finite, still loud, a
seventh hint fails the suite exactly as the fourth did.

**The suite reported 903/903 ALL TESTS PASSED through two freed-object defects.** A cast and
a `.text` read on Labels whose pane the next page rebuild had freed. Only `run_tests.py`'s
stderr check saw them. Third time this session it has earned its place over `run_tests.gd`,
and the first time the defects were mine rather than inherited.

**`queue_free()` is deferred, and that is a correctness bug in a rebuild.** The old pane was
still in the tree when the new one was added, so Godot renamed the newcomer and every
`get_node("Hints")` kept returning page one. It presented as "a hint with no row" for a row
that existed and rendered perfectly.

**Which gate caught what is the useful summary, and it was not the obvious one.** The engine
gates caught nothing. `check_all` caught a public surface no test named — the hint's own
tests, which I had forgotten while building the page split. The notebook's layout test caught
the capacity. The two defects that would actually have shipped were caught by the test
runner reading stderr, not by any assertion anyone wrote.

## What cycle 116 taught

**I shipped a feature that made my own tool's caveat false, and wrote a close claiming I had
considered it.** `citation_check.py`'s `NOT COVERED:` line said drift was "the one nothing
can automate". The commit that made drift detectable left that sentence printing under every
run of the tool that had just disproved it — and the bead's close asserted I had left it
"deliberately for the SUPPORTS half", which it is not about. **Caught only by going back to
verify a claim I had made about my own work.**

That is the third instance of one shape in five cycles — `eaten_message` (112),
`idle_detail` (115), this — and the third is what makes it a class: **a sentence naming what
something cannot do goes stale the moment somebody makes it do that.** The population is
47 such sentences across 22 of 29 files under `tools/`, all printed to the operator on every
run, none ever re-read. That is `-zfmv`.

**A `NOT COVERED:` line is a to-do list disguised as a limitation.** Reading one as such
produced this whole cycle's feature. "Cannot, by construction" and "does not, yet" are
written identically in all 47 and only one of them is work.

**Confirming the premise stopped a design mistake, not just a wasted cycle.**
`citation_check` already had `--baseline`/`--baseline-write` and I nearly reused them — but
they snapshot FINDINGS ("which broken citations are new"), where drift is about citations
that still RESOLVE. One flag meaning both would have made a clean `--baseline` run read as
evidence about drift, which it is not.

**The first fixture was vacuous and said so in its denominator.** An absolute Windows path's
drive colon is not matched by the citation regex, so it reported `0 citation(s), 0 resolved`
— and both controls would have passed over nothing. Caught by reading the denominator on the
SETUP run rather than on the assertion.

**Nothing player-facing shipped this cycle, and here is why:** the item was a tooling gate
that closes a failure the loop hit twice in five cycles, and the loop's own rule is that the
next cycle takes a player-facing item. Cycle 117 does.

## What cycle 115 taught

**The argument was already written down, three lines above the bug.** `idle_detail()` says
"Idle — waiting for a pest", and every plant without its own branch gets it — which is Mint,
Aloe and Nettle. Mint speeds its neighbours and Aloe repairs them; **neither can touch a
pest at all**, and both had been announcing that they were waiting for one. The Sundew got
its own line for exactly this reason and the comment saying why sits directly above the
fall-through: *"'Idle' was simply the wrong word for the one plant that cannot be."* Right,
and never extended when Mint and Aloe landed two cycles later.

**The shape that makes a sentence safe, counted rather than felt.** Of 33 producers in
`hud.gd`, **21 interpolate the thing they describe** and therefore cannot outlive it. Every
defect found in two cycles of looking has been in the handful that name a MECHANISM in prose
— "a hungry pest", "waiting for a pest". That is a review heuristic and not a gate:
`-u9zb`'s close records the decision that accuracy cannot be mechanised, because there is no
shared vocabulary between English and code to check.

**Fixed as a rule, not as three cases.** The new test drives off `PlantCatalog.engages()`
over the whole catalogue, so the tenth plant inherits the rule rather than the bug. That was
only available because `engages` already means exactly "can this touch a pest" — the claim
the sentence makes. Worth noticing as luck rather than design.

**I have been launching out of habit.** Four of six cycles launched, and in two the ledger's
own `cheaper_alternative` records that the launch only re-confirmed what a headless test had
already asserted — because the test hosted the real scene and read the real node. Step 2 now
says the launch decision belongs to `/verify`'s triage table, and gives the question that
settles it: **name the claim the launch will make that the suite structurally cannot.**

**Citation drift is not unautomatable, and the checker says it is.** All three new citations
drifted this cycle under my own edits, by 39, 8 and 39 lines; `citation_check` reported
351 of 351 clean, correctly, since each landed on a real line. Deciding whether a line
SUPPORTS a claim cannot be automated. Noticing that it is not the line it pointed at before
can. Filed as `-5sxj`.

## What cycle 114 taught

**A 3px jump is invisible in every still and obvious in play.** The Bramble's two new damage
frames first rendered with painted bases at 53 and 52 against the whole frame's 56 — so the
plant would have hopped upward the instant it was bitten. Caught by MEASURING the rendered
PNGs, not by looking at them, and now pinned by a test that holds the three frames against
*each other* rather than each against the family, which is the tighter claim and the one an
animation actually needs.

**A surviving mutant is not evidence of anything until you ask why it survived.** Swapping
`DAMAGE_THRESHOLDS` produced no failure — because `texture_for_health` COUNTS thresholds
rather than walking them, so the order genuinely cannot matter. An equivalent mutant, and a
small virtue of the code. The second mutation (making the ragged frame unreachable) was
caught at once. `house-static-checker` names this case and does not say how to tell; that is
now `-fwlg`.

**A test writing `health` proves the function; only the game proves it is wired.** Under a
real aphid the frame changed between health 32.53 and 25.83 — the 2/3 boundary, crossed by
damage rather than by a setter. That is the whole of what the launch bought, and it is worth
buying.

**The ninth plant broke a rule the game spent eight plants teaching, and says nothing.**
Three one-shot hints exist for rules the board does not state (a flier ignores a Chomp; a
planted plant can grow; Uproot compares before it digs). "You may build on the road" is not
a gap in what the player knows — it is the reverse of what they learned, and
`place_plant` still answers "pests walk there" for eight of the nine. Filed as `-lven`.

**The steps held, third cycle running.** Worth noting rather than repeating: the two
workflow candidates from cycles 113 and 114 both became beads (`-str8`, `-fwlg`) instead of
edits, because each is a claim to decide rather than a repair to make.

## What cycle 113 taught

**A cue can promise one plant while describing another, and nothing notices until two
plants stop being interchangeable.** The move preview draws the ring, reach and coverage
dots of the plant being UPROOTED, while its green brackets are a promise about what a click
does — and a click plants the SHOP pick. Those are different plants whenever an uproot is
armed, and before the Barrier Bramble they could not visibly disagree, because every plant
was placeable in exactly the same cells. Hover a road cell with a cob armed and a Bramble
picked: a cob's range ring inside green brackets, over ground no cob can occupy.

**The bead refused to claim it was reachable, and that was the right call.** `-l7ak` said
"NOT YET REPRODUCED ON A RUNNING GAME. That is the first job." It is reachable —
`_select()` writes `selected_placed` and never touches the shop's `selected_plant` — and
saying so *after* checking is worth more than the bead having asserted it.

**Red-then-green, for the first time in four cycles.** Cycles 110–112 each wrote a test,
watched it pass, then broke the game code to prove the test could fail. Here the
reproduction was written first, failed for the stated reason, and passed after — same
evidence, no ceremony, and the failure is recorded in the ledger row rather than
reconstructed in prose. Whether that should become the default is `-str8`; it has a real
cost, which is that cycle 113's first draft failed on its own **precondition** and a test
failing for the wrong reason looks exactly like one failing for the right one.

**The fix had to refuse rather than resolve.** Requiring BOTH — the click will plant, AND
the described plant could stand there — is the only version that does not decide `-h5w6`
("what should moving a plant cost?") by accident, in a hover handler. Same reasoning kept
the ring itself untouched: `-3jjc` is filed and explicitly blocked behind `-h5w6` rather
than tidied.

**The steps held again.** No workflow change; the one candidate became a bead instead,
because "prefer red-first" is a claim that needs deciding rather than an obvious repair.

## What cycle 112 taught

**A skill named twice is work, and this one paid on its first use.**
`confirm-the-premise` had been identified twice without being built. Turned on `-cs2k` — a
bead nobody wrote it about — it moved all three of that bead's factual claims before a line
was written: the count was seven, not three; the ask was already partly satisfied by a test
nobody had connected to it; and **the implementation the bead specified would have been a
permanently-green test.** "Walk every Control under a lower CanvasLayer and assert
`focus_mode == FOCUS_NONE`" passes identically over a screen that went inert and one that
was never focusable, because a Label, a ColorRect and a Panel are `FOCUS_NONE` always.

**The fix for that came from the test the bead was proposing to replace.**
`test_the_hud_is_inert_while_an_overlay_is_open` already collects its subject while nothing
is open and asserts a non-empty denominator — its own defence against exactly this vacuity.
Reading the thing you are about to supersede is where the design was.

**A test that passes on its first run has told you nothing yet.** Forcing
`PauseScreen._set_card_active` to always `FOCUS_ALL` produced a named failure on a named
button. Both new guards this cycle were mutation-tested, and both mutations were caught.

**Nothing here can tell whether a sentence is TRUE, and one had quietly stopped being.**
`"A hungry pest ate your %s!"` was correct for every plant death until the ninth plant —
`Pest` only reaches `_adjacent_plant()` inside its `is_hungry` branch, and a wall is chewed
by every pest. Nineteen checkers, lint and 897 tests were green over it for two cycles.
Found by reading the producer while looking for something else. `message_corpus_check.py`
is the closest this project gets to checking prose and it verifies a line is *priced*,
never that it is *accurate*. That is now `-u9zb`.

**The steps held.** No workflow change this cycle — step 3's rule about re-reading every
citation *after* the code edits caught two of my own references drifting by eight lines,
which is the rule doing its job rather than needing another one.

## What cycle 111 taught

**A tool that is shaped like a gate gets treated like one, and both of the surveys were
neither.** `.claude/surveys/` held three scripts and nothing ran any of them — the exact
failure `check_all.py` exists to prevent, one directory over, and its own honest line
`CLASSIFIED 28 tools/*.py … 0 unclassified` says nothing whatever about a directory it
never looks in. They have a runner now (`tools/survey_all.py`).

**Measuring the three decided the design, and reading them would have got it wrong.** The
bead assumed they were interchangeable. They are three different kinds: a 29.7s
whole-history sweep, its 0.06s fixture, and one that needs a live game and exits 2 without
one. That is why they are a second command rather than a second discovery root — a history
sweep does not belong on a per-cycle clock, and a verb needing a live game can never join a
pool whose defining property is that it opens no project.

**Then the predicted hazard fired under a green line.** Giving `survey_all.py` the
`NOT COVERED:` line a house tool owes made `check_all` adopt it as a checker and run it. It
reported `clean` — correctly, since with no game up `survey_all`'s own gate declines to
fire — while spending ~30s inside the git-history sweep on every run of the pool whose
entire promise is that it is the fast one. 4.1s to ~34s, green throughout. And fixing it
immediately broke `check_all`'s own arithmetic: `CLASSIFIED` printed 19+1+7 = 27 of 29 and
looked exactly as authoritative as before. Both guards are mutation-tested now, because a
positive control that cannot fail is worse than none.

**The panel learned a word for tough, and runtime is what chose it.** "Health 40/40" is
true of a Barrier Bramble and misleading about it. The line now reads
"Holds 11s against one pest" — seconds rather than a multiplier, and the whole argument for
that is that it MOVES: 40.0 health → 11s, 21.86 → 6s, watched live. No static test of the
formatter could have made that claim.

**And the test that should have gated it had silently stopped covering the plant it was
for.** `test_the_selection_box_stays_inside_the_side_panel_when_damaged` says "Every plant
kind" in its own comment and `continue`d on any placement refusal — so the Bramble, refused
on grass since cycle 110, was skipped while the test went on passing. The same `continue`
swallowed `not paid for` just as silently, so it had only ever measured whatever the
starting unlocks covered. **A skip that reads as a pass, in a test that claims
exhaustiveness.** It now asserts its own denominator.

**I broke the string-literal rule with the sanctioned tool.** Wrapping a long assertion
message inside an `Edit` put a real newline inside a GDScript string literal — the cycle-97
defect with no heredoc and no script anywhere near it. The workflow's rule names the
MECHANISM (heredoc, script) and the defect is something else, reachable by hand; the rule
now says so. What reported clean over it: `name_check.py`, and `heredoc_survey.py` — the
project's own designated countermeasure, which sweeps git history and structurally cannot
see an uncommitted break. Only a real compile caught it. Filed as `-h613`.

**Three moving-value misreads in one session, three distinct causes.** A modal covering the
board (the run had ended unattended and I was measuring the summary card's paper); a paused
tree freezing an entrance tween at `scale 0.4`; and a hidden node retaining its last text
(`visible=false`, `selected_placed=null`, and I read "Holds 0s" three times running).
None produced a malformed reply. `read-a-moving-value` exists for the first; the other two
are worth adding to it.

## What cycle 110 taught

**The ninth plant, and the first thing a pest has to deal with rather than walk past.**
The Barrier Bramble stands in the road. Every plant before it acts on a pest that is
walking by, and the pest walks by regardless — `Pest`'s physics step stopped for exactly
two things, a Chomp's mouth and, for the `is_hungry` mutation only, a bed it had chosen to
eat. What the Bramble sells is time. Verified on the real route rather than asserted: an
aphid walks 70.7 → 173.4 → 250.1 and stops there for three seconds while the wall goes
40.0 → 25.8. The wall is at x=288, so it halts 37.9px out against the 38.4px `STOP_RADIUS`
the constant declares.

**A resistance rather than a bigger health pool, and the reason is the Aloe.** Both buy the
same seconds against a lone pest. They differ in what a point of HEALING is worth —
four times more here — so the Salve Aloe standing off the road is worth four times more
behind a Bramble than behind anything else, and "Aloe behind the wall" becomes a real
board. A bigger pool would have made the Aloe proportionally worse. The cheaper diff and
the better design happened to agree; the design is why.

**A file argued itself into a contradiction one plant early.** `title_screen.gd`'s `PLANT_X`
header said "a NINTH is the two-row day, and this time there is no third trick: five 96px
canvases need 480 in a 426px band." The arithmetic is right and it is about CANVASES. The
seven-slot layout below it had already established that canvases may overlap and only INK
may not — then the eight-slot rewrite dropped the scale and discarded the ink argument as
"slack rather than load-bearing". Measuring the nine sprites' real ink (mint 32 … sunflower
54) shows the five narrowest fit that band with 17.5px of clear ink per join at the current
scale. The lawn is still one row.

**The gates rejected the plant five times and each rejection was a different hand-list.**
Title lawn slots, the sprite-size table, the engaging-plants count, the reachless-plant
count, the seed-sink maker table. None of these is derivable and all five are deliberate:
each exists to force a decision rather than let a new plant inherit an answer. That is the
catalogue working, and it is why the ninth plant cost a cycle rather than an afternoon.

**A checker that names what it SKIPPED beat one that counts what it checked.**
`art_src/bramble.svg` carried a `--` inside an XML comment. Godot's rasteriser accepted it
and wrote a perfect 64×64 PNG. `svg_style_check.py` could not parse the file and said so —
`ERR bramble ? geometry not measured`, plus two named skipped checks — while its summary
line still read `Checked: 28 of 28 discovered`. A pass/fail count would have shipped a
sprite exempt from every geometry gate.

**Two confident, well-formed, wrong live readings in one session.** First I sampled pixels
for my new sprite and measured the run-summary card's cream paper, because the game had
been left running and the garden had been eaten. Then, after relaunching and pausing, I
photographed a 20px speck — `Plant`'s planting-pop tween frozen at its 0.4 start scale.
`pause` freezes an entrance exactly the way it freezes a fade. Both were measurement
errors, neither produced a malformed reply, and the fix both times was
`unpause` → `wait-frames 90` → `pause` → read. Filed as `[G-127]`: `screenshot` and
`sample-pixels` should say `TREE IS PAUSED` the way `ping` and `performance` already do.

**No fan-out, deliberately.** `fan-out-a-cycle` §5 rules out a lane for anything needing a
new asset, an import pass, or a running game, and rules out an item that is "mostly a
decision rather than mostly typing". This cycle's player-facing item needed all three of
the first and the rest of the ready queue is largely the second. Run serially at the
parent; the skill's own section is what decided it, in about a minute.

## What cycle 109 taught

**BACKFILLED IN CYCLE 135 (`-p9qo`), from the commit record rather than from memory** — and
the honest caveat first: nobody wrote these down at the time, so what follows is
reconstructed from what the repo can still prove. Where the record does not support a lesson,
this says so rather than inventing one. These three are the only gap in the file: every cycle
from 100 to 134 is otherwise present.

## What cycle 108 taught

**The Done section, pruned by `-tkdz`.** `kanban.md:14` still credits it: "Audited
and pruned at cycle 108. Every row below shipped **and** is held there by a named test — the
pair is the point." The lesson is in that sentence: a Done line with nothing asserting it is a
claim rather than a fact, and the one entry that turned out to be exactly that went back to
the backlog instead of staying. The audit also found Done had **gone stale about itself,
twice, both times against its own next entry** — a section long enough to contradict itself is
the whole argument for pruning it.

### The cycle-109 bead audit itself: all 138 open beads read and judged (`c2ea0ca`, record kept at
`.claude/bead-audit-cycle109.md`, 49KB). Verdicts: 11 stale, 66 not worth doing, 40 a player
would notice. The method is the part worth keeping — `bd list --status=open --json` for the
bodies, then **the cited file opened before the verdict was written**, under
`kanban-staleness-audit`'s bar that a wrong `STALE` deletes an idea nobody will have again.
That "open the file before judging" discipline is the direct ancestor of the confirm-before-
claim step now in the cycle skill.

**And the lesson the gap itself carries, which is why the backfill is worth more than the
three entries.** These three went unwritten because step 6 said "bump the cycle number" and
nothing derived it, so the file quietly stopped being written while every other pre-flight
item was a list that visibly filled up. Cycle 110 fixed that by DERIVING the counter from the
commit titles. **A file that quietly empties needs a different guard from a list that visibly
fills** — the same shape as the `AGENTS.md` mirror, which has been silently emptied twice and
now has a checker.

## What cycle 107 taught

**Eight beads in five lanes, and the seam between two of them.** The close
(`6acc3cf`) filed three harness gaps, and the one that bit is worth carrying: **nothing gates
a call site's arguments against the callee's default when a shared helper gains a mode
parameter** (G-125). Two lanes touched opposite ends of one helper; each was individually
correct. The other two are the same fan-out lesson this project keeps re-learning from a new
angle — a lane cannot type-check the file it wrote (G-124: "five lanes reported green this
cycle having parsed nothing"), and the `/verify` skill shipping with plugin 0.60.0 describes a
`run.json` the installed 0.38.0 ledger does not read (G-126). All three were live again in
cycles 129–134, which is the argument for writing the log entry at the time.

## What cycle 106 taught

**A screenshot from James beat every gate this project owns.** The playfield sat hard left
on a wide window with all the extra canvas in one grey gutter, while `findings`, lint, 741
tests and 16 checkers were green over it — because every one of them measures the design
size, and every test hosts the board at the origin. The cheapest detector in the toolkit is
still a person looking at the game.

**Two bugs were stacked and fixing the first exposed the second.** Before cycle 105 the side
panel sat at a hardcoded `1152 - PANEL_WIDTH` and the board at `x = 0`. Both were wrong and
they hid each other, because the panel's error happened to sit exactly where the board's
gutter would have been. Agreeing at the design size is not evidence of anything.

**Then moving the board exposed a third.** `_click_at` compared an absolute `screen_pos.x`
against a board-LOCAL width — correct for exactly as long as the board started at x=0. A
centred board silently ate every click on its rightmost 117px **while drawing them
perfectly**. No picture of that can ever be wrong; it was found by reading the guard.

**The same shape, one screen over.** `PauseScreen`'s Backdrop is `MOUSE_FILTER_STOP`
precisely so the board cannot be played through a pause — and at 1152 on a 1548 canvas it
stopped 396px short, leaving live clickable board over a held run. A correctness bug wearing
a layout bug's clothes.

**"Three copies" was eight.** The count was the finding: one name was answering two
different questions — how big is the screen I must cover, and how big is the canvas this was
composed on — and half the callers are `static` on purpose, so `ProjectSettings` was the
only implementation that could serve them. At 16:9 the two answers are identical, which is
why it drifted invisibly for so long.

**A boss that the targeting rule refuses to shoot.** Every damaging plant fires at the pest
furthest along the road; the Nurse Beetle walks behind the front and heals everything near
her. The Queen asks *where do I want it to die*; the Nurse asks *does my garden own anything
that can hit the back of a wave*. It cost 48 points of beetle and displaced nothing — the
finale is byte-for-byte the row it has been for four species running.

**Closes are honest now; clause-by-clause answers still are not.** 40 of 146 closed beads
carry the literal reason `'Closed'` — all under the old id scheme, all unauditable, since
the evidence was never written. Under the current scheme it is **97 of 97 with a real
reason**. But a real reason is necessary and not sufficient: `-1d07` has a good close that
leaves one acceptance clause unanswered and another only partly. The prototype gate flagged
122 of 146, which is a permanently-red gate and therefore no gate at all — so the answer is
`-txme`, making the close *start* from the acceptance rather than adding another instruction.

## What cycle 105 taught

**The eighth plant, and the file that had already written down how to fit it.** The Salve
Aloe is the first thing in the game that undoes damage — before it, `Plant.health` only
ever fell, and the sole exception was the rain, which is the weather's doing and arrives
every fifth wave whether you need it or not. It cannot save a plant under attack and that
ceiling is the design: 3.0 HP/s against a mouth taking a full-health plant down in 2.86s.
Verified live at 10.0 → 20.4 → 35.4 health.

**`-ibvb` names four hand-lists a new plant must join. There are five.** The fifth is
`TitleScreen.PLANT_X`, caught as `Expected 7 >= 8` — and its own header had already done the
arithmetic and named the fix in advance: *"That is the day to drop PLANT_SCALE or go to two
rows."* Dropped 1.7 → 1.5, which fits four 96px canvases per band with 42px spare and funds
the ninth plant too. A comment that predicts its own failure is worth more than a test that
reports it, because it also says what to do.

**Read the denominator, again, and this time it was mine.** My first Aloe tests used
`GAME_SCENE`, which `test_combat.gd` does not declare. The parse error took the whole script
down and the suite reported **`Total: 564` against 705** — 141 tests silently absent, exit
2. The exit code alone would have read as an ordinary failure.

**Two tests failed at the audio merge and neither was wrong** — both had had their subject
moved underneath them. A save fixture pinned to `SAVE_VERSION` rather than to the version
whose *shape* it tests goes stale on every bump, and the failure it produces points at the
parser instead of at itself. And the exactly-full tripwire counted `OPTIONS.size()` alone,
so it measured three rows on a panel that now shows five: a tripwire counting the wrong set
reads as "still full" while the surface fills up past it.

**`set_resolution` answered what no headless test in this project can.** Lane 0jye said so
plainly and handed it over as a named check rather than claiming it. Three resizes settled
it: a 1720×720 window gives a 1548-wide canvas with the side panel at x 1292 (1292 + 256 =
1548, still pinned), and 1024×768 gives 1152×792 — the width floor the whole stats-row
budget silently rests on, confirmed rather than reasoned about.

## What cycle 104 taught

**The merge found a bug in a fix I had already called done.** Cycle 102 stopped
`citation_check` walking into `.claude/worktrees/` by testing `"worktrees" in path.parts` —
an ABSOLUTE path. Run from inside a lane, whose own path *is* `.claude/worktrees/…`, that
discards the entire repo: the parent read `298 resolved`, a lane read `260` and 38 bogus
advisories. Same asymmetry as the original defect, pointing the other way, and **invisible
from whichever side you happen to be standing on**. Only running the fan-out produces both
viewpoints at once. Exclusions are now relative to the tool's own root, in `repo_walk.py`,
imported rather than copied — and the sweep that found it enumerated every tree-walking
tool instead of fixing the one that complained.

**Read the denominator, not the verdict.** `check_all` exited 0 on every run through that
entire defect. The only thing that ever moved was `19 world-space script(s)` → `38` and
`298 resolved` → `260`. Filed `-G-123`: a `--compare-to` mode would make "run it twice
under different conditions and diff the numbers" a standing check rather than something
done by hand.

**Two tests failed on a merge and both were right.** The garden remembers its speed now, so
the game has genuinely stopped starting at 1x. `GameSpeed._step` is static and
`RunConfig.game_speed_step` is autoload state loaded from the real save *before any
`setup()` runs* — process-global twice over. A `GameSpeed.reset()` at the top of a test
stopped being enough the moment `_ready()` began restoring the saved step.

**An autoload beats `setup()`, and no checker can see it.** The first suite run after the
v6→v7 save bump rewrote the developer's real `highscore.save`. Nothing was lost, and the
migration is what the game would have done anyway — but `save_persist_check` is clean by
construction there, because no *test function* is in the chain. `-58u7`.

**Beads rot, and the rot is measurable.** A derived scan found **139 open beads carrying an
absence claim**. Sixteen were resolved against the code; two had premises that were now
entirely false and closed without a line written — one would have had somebody building a
boss that already has 80 health, two sprites and 26 wave appearances. **123 were not
reached**, and saying so is the point: a sweep that does not state where it stopped reads
as complete.

## What cycle 103 taught

**The game finally says that upgrading exists.** Cycle 101 measured that upgrading decides
the run — same economy, no cheats, one policy bit; breadth-first died at wave 10, depth-first
won 22 waves losing no lives — and nothing in the game mentioned it except a refusal and a
confirmation, both reached only by someone who had already found the button. There is now a
third one-shot hint, fired the first time the player can afford the cheapest upgrade **on
their own board**: verified live at the boundary, false at 19 seeds and true at 20, which was
that cob's exact `upgrade_cost()`. And the Shield Bug, spawnable by name since cycle 100 and
met by nobody, now debuts in wave 15 — 4 of them, confirmed on a live census.

**A hint on a funnel is not a hint on an event, and the difference is invisible until you
read the return contract.** `show_message` returns false on a busy row but **queues** the
text rather than dropping it. That is right for `_on_flight_ignored`, which fires once per
winged pest. It is wrong for anything offered from `_refresh`, where the condition stays
true — every later refresh stacks another copy, so a one-shot would have shown up to
`MESSAGE_QUEUE_MAX` times. `Hud.row_is_quiet()` exists now, and the tip asks before
offering.

**A file became a writer of the developer's real save without one line of it changing.**
`save_persist_check` printed
`place_plant() -> _refresh() -> _maybe_teach_upgrading() -> spend_hint() -> _save()` and
named the two tests in `test_board.gd` that walk it — before a single test had been run.
That is the argument for a project growing its own checkers in one line.

**And the harness's own safety net did not catch.** `launch --snapshot-userstate` did not
restore, so the run left `m1:seen_upgrade_tip` in James's real save — meaning he would never
have seen the hint this cycle exists to add. Put back by hand (`m0`, scores 3454/5008
intact) and filed as `-zzx3`: the flag's failure mode is currently indistinguishable from
its success.

**Two things to know about the fan-out.** The lane's worktree branched from an *older*
commit than `main`, so it worked without cycle 102 in its tree and correctly reported that a
command its brief named did not exist — it said so rather than assuming, which is the only
reason that was caught. **Check a lane's base.** And a concurrent session is working in this
same checkout; its in-flight edits to `dev_tools.gd` and the itch workflow were swept into
this cycle's merge commit. Both are correct and wanted, but `dev_tools.gd` is
harness-managed and one `/scaffold-godot-harness` from vanishing silently — `-kdnl`.

## What cycle 102 taught

**Five lanes, in worktrees this time, and the isolation worked exactly as advertised — while
introducing a trap nobody predicted.** Rain that falls, directional bite and sting, a styled
top bar, spent packets that read spent, packets that point at their plants, and a player-facing
speed toggle, all at once. Not one lane reported a sibling's file, which is the whole reason
`-l638` existed. But agent worktrees live *inside* the repo and `rglob` does not read
`.gitignore`, so `citation_check` turned every bare citation in `kanban.md` into a six-way
ambiguity — **visible only to the parent**, because a lane inside its own worktree has no
nested copies. A finding count that depends on which process is asking is worse than no count.

**The honest price of a worktree is that a lane compiles NOTHING.** `--require-compile` is the
documented escape and it does not work there — two lanes hit it independently and got
`Identifier "WaveDirector" not declared` and `Could not find base class "Plant"` on lines
unchanged from main, because a fresh checkout has no class cache. So five lanes reported green
having never parsed a line, and the parent found: two tests that were green by construction,
a top bar with no room for the button it was handed, three public surfaces no test named, and
a checker reporting nonsense. **None was a lane's mistake.** `merge-the-fanout` is now a skill,
because that procedure had been re-derived from scratch twice in three cycles.

**A merge can delete a test with no compile error.** Git hoists a shared suffix below the
`>>>>>>>` marker when both lanes' last function ends the same way — twice here it was
`_T.free_ui(game)` / `return err` — so removing the three marker lines silently truncates one
side's final test. GDScript accepts a function whose last statement is an assignment. The only
thing that catches it is arithmetic: 329 base + 3 + 4 + 4 = 340, and the merged file had 340.

**"The plant was right and the assertion was wrong."** Two lane tests asserted "this plant has
not attacked yet" with the prey already in range. `_act()` runs on every settle frame, so the
Chomp had eaten and the Nettle had stung before the precondition was read — the failure
message even carried that exact aphid's lunge vector at full `LUNGE_DISTANCE`. There is no
"has not bitten anything" state for a flower sitting on top of its lunch.

**Let the thing that measures do the measuring.** The speed button needed 67px the top bar did
not have. Instead of arithmetic: set the constant absurdly low, run the one test that checks
it, read the number out of the failure. "Grow the next wave" needs 202px of its 216px slot;
"Next wave" needs 120. The row ended with *more* headroom than it started with — 19px to 38 —
while gaining a control.

**And `reach` disagreed with a button I had watched work.** `game_speed.gd` is a static utility
no node carries, so it is invisible to `scripts-seen` however much of it ran. Filed as
`-v3ji`: a file that CANNOT be seen and a file that WAS NOT loaded are opposite results, and
today they print identically.

## What cycle 101 taught

**The game got played, and it has exactly one difficulty event.** Two full campaigns, same
economy, no cheats, differing in a single policy bit — spend surplus on NEW plants or on the
plants already down. Breadth-first reached eleven level-1 plants and **died at wave 10**.
Depth-first **won all 22 waves without losing a life** (591 pests, 1129 spare seeds at the
end). Both had all seven plants by wave 7, so the catalogue is not the difference.

**Upgrading decides the run and nothing teaches it.** The button exists only while a placed
plant is selected, and every mention of upgrading in the game is either a reply to a player
who already found it (a refusal, a confirmation) or a notebook caption they must go and open.
Filed as `-gz53`, and it is the highest-value item on the board.

**A cliff and a plateau, both derived rather than felt.** Wave 8 was carrying a +45.9% count
step *and* the mutation multiplier's +24.0% — `MUTATION_START_WAVE` is 8 — for **+80.9%** in
one wave, where every wave from 9 to 22 steps +2.0% to +13.6%. Two independent difficulty
increases on the same wave, so there was nowhere in the campaign a player met a mutation at a
density they could read. Wave 8's counts now hold wave 7's peak spawn rate exactly: the
mutation is the only new thing there. Measured after: the breadth policy that died at wave 10
reached **wave 17**. That was the cycle's one tuning, out of a budget of three — two robot
policies are not enough evidence to spend the other two, and the rest is filed (`-iqp8`,
`-uqeo`) rather than guessed.

**Three lanes again, and this time the parent owed them wiring, not just a merge.** The
upgrade lane correctly refused to touch `hud.gd`/`game.gd` and listed seven exact edits it
needed there. Skipping them would have shipped a Chomp Flower whose ladder no player could
reach — three files of dead code with every gate green.

**A lane's checkers see the other lanes.** Parallel-*safe* is not parallel-*isolated*: they
read the working tree, and in one checkout that tree holds every sibling's half-finished
edits. One lane got 12 NEW findings in three files it had never opened. It caught that itself;
the same race in reverse hands a lane a clean exit it did not earn, silently. `-l638`.

**And runtime caught what nothing headless could.** `cmd upgrade_plant` on a Chomp answered
`success: false` with an *empty message* — indistinguishable from the game refusing — while
the upgrade had actually landed. The debug verb cast the result to `CornCobbler` and died
inside its own reply. It had been correct for every cycle in which corn was the only plant
with a ladder, and became wrong with no edit to the file.

## What cycle 100 taught

**The first parallel cycle. Three agents, three lanes, and every failure lived in a seam none
of them could see.** A campaign (16 → **22 waves**), a pest species (the **Shield Bug**, whose
plate bounces a Corn Cobbler's kernels and not a Dandelion's seed) and a plant (the **Prickly
Nettle**, which stings only mutated pests) all shipped at once. Each agent ran all eleven
parallel-safe checkers clean in its own lane. **The merge failed five times.**

A golden headcount array and a hardcoded endless wave pair, broken by another lane's growth. A
deliberate "a new plant must be decided about here" gate asserting exactly three engaging
plants. A placement test that funded a purchase but never unlocked the plant. A notebook note
119 characters over budget. **None was a mistake by the agent that caused it** — each was a
fact about a file it was correctly forbidden to open. The parent pass is where parallel work
integrates, and its cost scales with the number of lanes rather than the size of any one.

**Two bead premises were wrong again, both mine, both found by the agent opening the code.**
"Growing the campaign is an afternoon" — no: three assertions chain to cap any finale at 436.7
base health and wave 16 was already 418, so seven appended waves had **one beetle** of headroom
between them. The six went in *front* of the finale instead. And "nothing SPLITS" — the queen
has split into aphids since the boss landed.

**A magic number derived from a constant outlives the constant and reads as deliberate.** The
endless ramp test priced waves `[60, 100, …]` and said "past wave 48"; both were correct at 16
waves and silently wrong at 22. It now *finds* the first pinned wave instead.

## Carried from cycle 99

**When a container cannot hold its contents, the arithmetic has two sides and only one usually
gets examined.** The plant bar took six plants — and now seven — because a button's minimum
width fell from 195px to 8px, not because the bar changed.

## Carried from cycle 98

**Ask the layout function at N+1 before building the thing.** A sixth plant was built whole
before anyone called `plant_bar_layout(6)` — one line, pure, and it knew. Also: a branch a
file documents as broken is worse than no branch, because it reads as handled.

## Where things stand

Suite **654/654**, 13566 assertions; lint 0/0; import clean; eleven checkers clean; `findings`
**0 across 5 of 5, exit 0**. Fifteen skills. Upstream gh#44 and gh#51–57 open. Still on harness
**0.38.0** deliberately (`-ny3h`, gh#43).

**The game has 22 waves, seven plants, four pest species — and now two plants that grow.** The
Chomp Flower has a three-rung ladder (bud → toothy maw → gaping maw) behind a generic `Plant`
surface: a plant is upgradeable iff its ladder is non-empty, so the third one is a const plus
one override with no branch anywhere else. The playfield wears the notebook's own paper as a
wobbling page frame, and `GardenTheme.reads_on_ground()` is now a real gate against the failure
that let the Mint be drawn in the lawn's exact hue in cycle 98. The Nettle stings audibly.

**The loop is paused here at the user's request** ("let's wrap up this loop and be one for
awhile"), at the end of a clean cycle rather than mid-item. Nothing is half-finished: every
lane merged, every gate green, the queue refilled.

**Parallel is the default.** Step 2 carries the rule, its gate list, the shared-registry case,
the merge budget, and now two more: a lane's checker findings outside its own files are not
its findings, and the parent owes each lane the parent-owned wiring it was forbidden to write.
`-pdri` (Shield Bug into a wave) is still open — cycle 101 held `wave_director.gd` for the
tuning, so that lane waited.

## Waiting on the user

**73 commits are held locally and unpushed, and this is the item to raise first.** Every
push to `origin/main` auto-deploys to itch.io (`severalherr/pest-control:html5`) via
`.github/workflows/deploy-to-itchio.yml`, with no paths filter — so pushing is publishing,
and the loop commits once per bd item rather than once per release. The held work is a
coherent playable increment by now: difficulty profiles with a title-screen picker, the
dead-ground hint, three contrast fixes, the spread-arc rim, and cycle 168's refusals. **It
needs one word from James to go out.**


**`-ix76` — ANSWERED in cycle 118, not by James.** The question was whether a 60-seed husk
should rot faster than a 9-seed one. The answer is no: 4.5s is a reaction time, the richest
husks come from the two bosses and so drop at the busiest moment on the board, and the
failure modes are asymmetric — too slow is a mildly generous meter, too fast teaches the
player that boss kills are not worth chasing. Recorded above `MIN_HUSK_LIFETIME` and pinned
by a test. Left here rather than deleted because it sat on this list as a question for
several cycles and a reader who remembers it should find the answer where they left it.

**`-oo7e` — weather has no counter-play.**

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

**`-fohy` — what does "held" mean now?** New in cycle 110 and the one worth reading first,
because it is cheap today and expensive later. The post-mortem's "Where you held them" row
counts KILLS at a cell, and `run_summary.gd:830-837` argues at length for that word on the
grounds that "'Held' is true of a kill and false of an escape". Sound when it was written,
and the Barrier Bramble now holds pests without killing any of them — so the plant whose
whole mechanic is holding contributes exactly nothing to the row named after it. Three
options in the bead; the ambiguity gets expensive the moment a second wall-shaped plant
exists.

**A note, not a question: the harness is twenty-two releases behind.** `-ny3h` has been
BLOCKED since cycle 44 on upstream gh#43, a deterministic `0xC0000005` segfault at
`test_corn_shoots_the_pest_closest_to_escaping` on 0.42.0. It was four releases when that
was filed; the machine now carries 0.60.0 against this project's 0.38.0, and cycle 110 hit
the first concrete cost — `run.json`'s `tier` key is documented as required by the current
workflow and is silently dropped by this project's ledger (`[G-128]`). Nothing to do until
gh#43 closes; recorded so the size of the gap is visible rather than assumed stable.

## Answered by the user, and now ordinary work

Both of cycle 101's questions were put to James and answered on 2026-08-17. The answers are
recorded in the beads themselves, which is where the next cycle will read them — logged only,
nothing started.

**`-iqp8` — the campaign gets a real second act.** Retitled from "Decide: should it escalate
at all", because it is no longer a question. Waves 9-22 should climb so the plants unlocked at
wave 7 have something to be needed for. The reading this rules out is "a flawless 22/22 is the
correct ending for a tutorial campaign", which was live until now. The bead carries the
starting point: `health_scale_for` is the one-function lever, rewriting fourteen wave rows is
the expensive path, `mutation_chance_for` is the other flat axis and a different feel, and
whatever lands has to keep `threat_for` rising strictly — priced offline against `_raw_threat`
before editing, the way cycle 101's wave-8 tuning was.

**`-uqeo` — re-measure the seed surplus before designing any sink.** Not blocked on James any
more; blocked on a number. The 1129-seed figure came from a run predating the Chomp Flower's
ladder, so it had one plant to sink into and now has two — the sink roughly doubled between
the measurement and today. The bead says exactly what the re-run must produce so the two are
comparable: the per-wave banked series, the per-wave low-water mark (the early game bottomed
at 0, 1, 1, 3 and 4, which a boundary reading hides), and a depth-first policy, since that is
where the recorded series came from.

## Restarting

`bd ready` for the work, this file for the context, `/cycle` (`.claude/skills/cycle/SKILL.md`)
for the loop itself — `CLAUDE.md` and `AGENTS.md` now carry only a pointer to it. **Confirm a bead's premise before claiming it** — step 2's first move, and for
three cycles running it is where the design happened rather than a correctness check: it found
a wrong absence claim (90), a wrong claim about a file's shape (91), and a whole option the
bead had not listed (92). It now also says to grep for the HELPER you are about to write.
`-g1o4` (P1) is that sweep over the whole open queue. `-knpc` blocks `-1490` and `-lp97`;
`-ip4n` blocks `-l86t`; `-q1xs` blocks `-vvxn`. `-ei83` is unblocked and sharpened: a missed
hint is a real queryable state, but it cannot be solved by adding the id to `Milestones.TABLE`
— the shelf counts earned off TABLE, so a foreign id breaks that guard. `-9afm` is the
fragility cycle 81 worked around rather than fixed. `-qewq` is the one I most want answered:
two mutations survived their first guard in one cycle, both because the guard checked for the
presence of a good thing rather than the absence of the bad one, and the sweep decides whether
that is in the codebase or was just in me.

**Twelve standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at — and **reconcile a gap against the INSTALLED version, not the
pinned one** (`gap-reconcile`); two were already fixed. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **NEVER TYPE A NODE PATH** — get it from `find-nodes
--class X --where name=Y` or `scene-tree`. This project's HUD node is `/root/Game/HUD` while
its class is `Hud`, so the wrong guess is the natural one, and a path miss reports only the
path: fourteen identical `Node not found` replies read as fourteen empty reads (gh#53).
**`pause` right after `launch`**, but **unpause before `findings`** — except the pause card —
and **capture `scene-tree` before `quit`** or the ledger row loses its reach. **A paused tree
does not repaint**: anything drawing from `_process` holds its old frame, so a change made
while paused needs `run-method --method queue_redraw` on the drawing node (`-rvvt`).
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading**, and **take a citation's line number only after the code edits are final** —
cycle 90 rebound the same two three times because its own comments kept moving them.
**No prose in ANY `bd` field as a shell argument** — not `create -d`, not `close --reason`,
not `update --notes`. Backticks are command substitution: the word vanishes and leaves a
still-grammatical sentence, which is why four cycles have now done it (76, 78, 83, 91).
Write the file, then `--body-file` or `"$(cat PATH)"`. **Durable means TRACKED** —
`.devtools/*` is gitignored (`.gitignore:8`, one exception for `verify-runs.jsonl`), so
anything owed to a future cycle goes in a bead body or a committed file; `git check-ignore -v
PATH` answers it in one command. And **`set-game-speed` takes its scale positionally**, not as
`--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open" as a fact about the
log, not about the harness; `python tools/citation_check.py` answers "do this file's citations
still land"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant ids
are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it can be
planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a plant is
selected by a real click, which `cmd touch_press`/`touch_release` at its `global_position`
will deliver. `run_tests.py` takes its own flags **after `--`** (`-- --filter husk`), which is
how a mutation pass runs in seconds instead of a minute. To walk a sub-second tween: `pause`
**before** creating it, then `step-time --seconds 0.03 --then-pause`; to verify a fix to a
once-per-save behaviour, `launch --snapshot-userstate` **before** clearing the flag, or the
run writes the developer's real save. Bump the number at the top of this file every time you
refill.
