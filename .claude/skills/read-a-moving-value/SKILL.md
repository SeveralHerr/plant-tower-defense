---
name: read-a-moving-value
description: Read a property that a timer, tween or state machine is actively changing, without drawing a false conclusion from it. Use before filing a defect from a live `get-state` or a screenshot; when a value reads empty, zero, faded or stale and you are about to call it a bug; when a UI element shows something other than what the code says it should; and whenever you are about to write "X does not work" on the evidence of one read.
---

# A single read of a moving value is not a measurement

Three times in one session I nearly filed a defect against working code, each time on
the strength of one live read:

| Read | Looked like | Actually was |
|---|---|---|
| A banner at `modulate.a` ≈ 0.2 | the banner never shows | mid-fade, on a tween that had 0.3s left |
| An uproot confirm that refused | the 4-second window is broken | the window had lapsed; `_uproot_left` said so |
| `MessageLabel.text` empty, ×3 | the prep note never reaches the row | a transient message outranked it; `_message_left` was 0.43 |

Every one of them was *correct behaviour caught mid-transition*. And every one cost real
time, because the natural response to a surprising read is to go looking for the bug it
implies, not to ask whether the read was valid.

**The read itself cannot tell you which it was.** That is the whole problem. `text: ""`
is a complete, well-formed, honest answer, and it is identical whether the row is
genuinely blank or something else is holding it for another 400 milliseconds.

## The procedure

1. **Freeze before you read.** `python tools/devtools.py pause`. The bus answers while
   paused, which is documented as a pause-menu feature and is far more useful as a
   read-determinism tool. For a step-and-read pair use `step-time --then-pause`, which
   freezes the tree the moment the step lands so the pair carries no ambient drift.

   ### Walking a sub-second Tween, which polling cannot do at all

   A Tween shorter than a bus round-trip is not "hard to catch" — it is **uncatchable by
   polling**, and the failure is silent. `CornCobbler._recoil` is 0.05 s out and 0.10 s
   back. Four consecutive `get-state` reads immediately after firing it:

   ```
   _sprite.scale: {"x": 1.0, "y": 1.0}      <- landed
   _sprite.scale: {"x": 1.0, "y": 1.0}      <- landed
   _sprite.scale: {"x": 1.0, "y": 1.0}      <- landed
   _sprite.scale: {"x": 1.0, "y": 1.0}      <- landed
   ```

   Four well-formed reads, all of them `Vector2.ONE`, which is **exactly what a tween that
   never ran looks like**. (One cycle earlier the same approach happened to catch the tween
   on its third poll, which is worse: a technique that works one time in four teaches you it
   works.)

   The recipe, and the non-obvious part is the *first* line:

   ```bash
   python tools/devtools.py pause                     # BEFORE starting it
   python tools/devtools.py run-method --node "$N" --method _recoil
   for i in 1 2 3 4; do
     python tools/devtools.py step-time --seconds 0.03 --then-pause
     python tools/devtools.py get-state --node "$N" --property "_sprite.scale"
   done
   ```

   ```
   {"x": 0.920, "y": 1.093}    {"x": 0.9167, "y": 1.0972}   <- two independent runs,
   {"x": 0.900, "y": 1.117}    {"x": 0.900,  "y": 1.117}       side by side; samples 2-4
   {"x": 0.940, "y": 1.070}    {"x": 0.940,  "y": 1.070}       agree to six decimals
   {"x": 0.980, "y": 1.023}    {"x": 0.980,  "y": 1.023}
   ```

   **Pause first, then create the tween.** `--then-pause` lifts a pre-existing pause for the
   duration of its own step and re-freezes after, so a tween created while the tree is frozen
   is walked only by the steps you ask for. Skip the initial `pause` and the tween advances in
   wall-clock time between every command, which is the polling case above.

   It works on Tweens specifically because `step_time` waits on **both** clocks — the physics
   one for physics-driven state and the process one so idle tweens advance too
   (`addons/godot_selftest/dev_tools.gd`, the `while true` loop in `_cmd_step_time`). That is
   worth knowing because the obvious alternative, `set-game-speed`, does not have the same
   guarantee — and takes its scale **positionally**, not as `--scale`.
2. **Read the variable that holds the truth, not the one that shows it.** The rendered
   value is downstream of a decision; the decision is in a variable. `text` is painted
   from `_idle_message` *and* `_message_text` *and* a precedence rule between them. Read
   all the inputs, not the output — an output disagreeing with an input is a real
   finding, and an output you cannot explain from its inputs is not yet anything.
3. **Read the clock alongside the value.** `_message_left`, `_uproot_left`, a
   tween's remaining time. A timer at `0.43` explains an unexpected read completely and
   costs one extra `--property`. This is the single highest-value habit here: the timer
   is usually *already* a property on the node you are reading.
4. **Then drive it to the state you meant to test**, rather than waiting for it. Drain
   the queue (`_advance_message_queue`), zero the timer, call the setter. A state you
   arrived at deliberately is reproducible; a state you caught is not.

## The rule applies to the SESSION, not just to the read

Freezing before a read is not enough if the game keeps running between reads. Launch it,
spend four minutes reading source or deciding what to check, and the thing you come back to
is not the thing you left: a wave finishes, the garden is eaten, and the board you meant to
photograph has been replaced by a summary screen. **A game left running is a moving value
the size of the whole board.**

So `pause` immediately after `launch` whenever the next thing you do is anything other than
driving the game, and `unpause` deliberately when you want time to pass. The cost is one
command; the failure mode is a screenshot of something else entirely, which is easy to
misread as the feature being broken.

## An empty result can be the CORRECT rendering of a cue that says nothing

The table above is all one shape: *the value looked wrong and was mid-transition*. There is
a second shape with an identical debugging instinct and a different cause — **the value
looked absent and was correctly absent, because the check was aimed at the one case the
feature deliberately excludes.**

A new hover cue drew nothing in its first screenshot. The cue was fine. The cell being
hovered was one the click refuses, and the draw path returns before that cue on exactly
those cells — by design, because a second mark on ground already carrying a refusal is
noise. Ten minutes went into "why is my drawing not appearing".

> **Before concluding a feature does not render: name the cases where it renders NOTHING,
> and check you are not standing in one.** Every cue with a precedence rule, a guard, or an
> "only when placeable" condition has such a case, and it is usually written down one
> function above the drawing.

That near-miss was worth having: it exposed a real inconsistency underneath, where the
predicate answered for a cell the drawing skipped. The picture and the predicate disagreed,
and only aiming at the excluded case showed it.

### The design rule that falls out of it

The two sections above are for *reading*. The same ambiguity has an authoring side, and it
is cheaper to fix there:

> **If a state has a meaningful empty answer, give that answer a mark.** "No result" and
> "no feature" must never be the same pixels.

A cue showing which map cells depend on a selected unit drew nothing when the answer was
"none" — which was a genuinely useful fact (the unit can be moved for free) rendered
identically to "nothing is selected" and to "this is broken". Fixing it cost one dashed
ring in a different position. Leaving it would have cost every future reader the same ten
minutes the debugging rule above was written about.

The tell at design time: **you are about to write `if result.is_empty(): return`** in a
draw path, a status line, or a report. Ask what the empty case means. If it means something,
say it.

## What makes this different from "flaky, retry it"

Retrying gets you a *second* undated sample. Sometimes it agrees and you conclude wrongly
with more confidence — I read that empty label three times and the third read was exactly
as uninformative as the first, because all three landed inside the same 0.43 seconds.

Repetition is not determinism. Freezing is.

## The inverse error, which is just as real

Do not read this as "the code is always right and the read is always wrong". Twice in
the same span the opposite held: a test was green for many cycles while never checking
its rule, and a doc comment cited a devtools verb that does not exist. The rule is not
*trust the code*; it is:

> **A live read and the code are two sources. When they disagree, you have learned that
> you do not yet know which is wrong — and that is a different state from either
> "working" or "broken".**

Resolve it before writing either verdict down. The freeze is how you resolve it cheaply.

## Where this shows up when nothing is animating

The same failure mode with no timer in sight:

- **Headless geometry.** A `GEOMETRY CAVEAT` / `[HEADLESS geometry]` tag means the window
  is 64×64, so anything positioned from `get_window().size` sits off-viewport. Confirm an
  off-screen verdict windowed before reporting it.
- **A paused tree.** `TREE IS PAUSED` on `ping`/`performance` means every metric describes
  a game that is not stepping. Here the freeze is the *cause* of the bad read, not the fix.
- **Settle frames.** A value read before layout settles is the same defect one layer down;
  `tools/settle_read_check.py` catches the test-suite version of it.

## The cheapest version of this whole skill

Before writing "this does not work", answer one question in one sentence:

> **What was moving when I read it?**

If you cannot name what was moving *or* say confidently that nothing was, you have not
finished reading. That sentence would have saved all three incidents in the table.
