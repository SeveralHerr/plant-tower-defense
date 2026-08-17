---
name: extract-a-testable-seam
description: Make a behaviour assertable when it lives past a gate the test suite never opens — a headless check, a feature flag, a platform branch. Use when a mutation survives a test that "covers" the code, when you find yourself asserting a table instead of the thing that reads it, or when a test pumps a function 120 times and asserts what moved. Also use before writing a test for anything behind `*_enabled()`, `is_headless()`, or a similar runtime capability check.
---

# The gate is closed for the whole suite, so the test is asserting nothing

A capability gate — `GardenTheme.animations_enabled()`, `Sfx.should_play()`,
`DisplayServer.get_name() != "headless"` — is **false for every test in the suite**, by
construction. Everything past it is unreachable code as far as a headless runner is
concerned. A test that calls the gated function and then asserts what changed is asserting
the early return.

The failure is invisible in the usual way: the test passes, the coverage looks right, and
the assertion reads as though it is about the behaviour.

## The tell

**A mutation survives that points the behaviour at the wrong target entirely.** Not a subtle
one — an obviously fatal one. Twice in this repo, three cycles apart:

| Cycle | Gated code | Mutation that survived |
|---|---|---|
| 71 | `Plant._wobble` past `animations_enabled()` | idle scale aimed at `_sprite.scale`, the exact property five event tweens own |
| 74 | `Sfx.play` past `should_play()` | the `pitch_scale` line deleted outright |

Both tests looked reasonable. Cycle 71's pumped `_wobble` 120 times and read what moved;
cycle 74's asserted that the `PITCH` table had no duplicate values. Neither could fail.

If you are about to write "pump it and see", or "assert the table", stop and read on.

## The move

**Extract the part that composes the answer into a function that takes its target as an
argument.** The gate stays exactly where it is; what moves is the arithmetic and the writes.

```gdscript
# Before — unassertable headless
static func play(event: StringName) -> bool:
    if not should_play(event, _muted, is_headless()):
        return false
    ...
    voice.volume_db = float(VOLUME_DB.get(event, 0.0))
    voice.pitch_scale = float(PITCH.get(event, 1.0))

# After — the gate is untouched, the composition is callable
static func tune_voice(voice: AudioStreamPlayer, event: StringName) -> void:
    voice.volume_db = float(VOLUME_DB.get(event, 0.0))
    voice.pitch_scale = float(PITCH.get(event, 1.0))
```

The test now builds a bare `AudioStreamPlayer` — no pool, no audio server, no gate — calls
`tune_voice` twice, and asserts one event lands lower than another. The deletion mutation
goes red.

Two shapes, pick by what the gated code does:

- **It computes** → a pure static returning the value (`Plant.breathe_scale(clock) ->
  Vector2`). Assert the shape, the extremes, the sign.
- **It writes onto something** → a function taking that something as its first parameter
  (`Sfx.tune_voice(voice, event)`). Assert the composed result on a throwaway instance.

## What the extraction does NOT buy you

**That the caller still calls it.** After extracting, deleting the call from the gated
function is a mutation that survives again — one level up. Reduce that risk rather than
pretending it is gone:

- make the seam the **only** place the write happens, so the call site is one line a reader
  can see, and say so in its doc comment;
- write **every** property in it unconditionally, defaults included — with pooled or reused
  objects a value left behind by the previous user follows the next one around, and that is
  a real bug the seam can be tested for;
- if the caller genuinely matters, that is what a live session is for. `Sfx.play` was
  exercised in a running game precisely because nothing headless can.

Say which of these you did. "The seam is tested and the call site is one visible line" is an
honest claim; "this is covered" is not.

## The related trap: asserting the table instead of its reader

Cycle 74's first check derived every `(file, volume)` pair from two const Dictionaries and
asserted uniqueness. Good check, real finding — five collisions where a hand-read had found
two. But a table's uniqueness is worth nothing if nothing reads the table, and the mutation
that proved it took one line. **A data check and a seam check are two different claims and
you usually need both**: one says the values are right, the other says they arrive.

## Cost

An extracted seam is a public function that exists partly for tests. That is a real cost —
`lint_project.gd`'s orphan pass will list it if the only other caller is a test, and it
widens the class's surface.

**This section used to say: pay it only when a mutation has actually survived, never
pre-emptively. That is no longer the default and the correction is the important part.**
It was written when this repo had two seams, both retrofitted. There are now seven —
`CornCobbler.spread_arc_span`, `Hud.uproot_shows_tip`, `Sfx.tune_voice`,
`Sfx.kill_event_for`, `ChompFlower.idle_only_because_of_flight`,
`NotebookScreen.pane_label_for`, `CueLegend.row_center_y` — and the last three were taken
**up front**, in the cycle that wrote the code, without waiting for a survival. Two of them
paid inside the hour: `pane_label_for` replaced an `if/elif/else` whose `else` MEANT one
particular kind, so adding a fourth kind would have silently given it the third's heading
and left the third correct — a failure surfacing on a page nobody was editing. The identical
defect was then found sitting in the *test* for the same code, which is the strongest
evidence available that waiting for the mutation is waiting too long.

**So the default is now the question, asked before the code is written: does the decision
have a NAME?** If you can say what it decides in a short phrase — "whether the tip is
shown", "which kill sound", "what this page's heading is" — extract it. If you cannot, do
not: the cost above is real and an unnamed seam is a decorative one.

A survival is still perfectly good evidence, and three of the seven were earned that way.
It is just no longer the only admissible kind.

Related: [[house-static-checker]] for the mutation discipline that surfaces this, and
[[derive-the-list]] for the data-check half.
