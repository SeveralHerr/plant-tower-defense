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
