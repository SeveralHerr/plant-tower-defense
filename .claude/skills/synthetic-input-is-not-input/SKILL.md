---
name: synthetic-input-is-not-input
description: Why a headless test that calls _unhandled_input (or _input, or a handler directly) with a hand-built InputEvent can be confidently green over a bug that reproduces every time on the running game. Use when writing or reviewing any test that constructs an InputEvent, when a gesture works headless and fails live (or the reverse), when a handler reads state that an earlier event was supposed to have updated, and before believing a green input test on a screen that has a HUD, panel, or any Control over the playfield.
---

# A synthetic InputEvent skips the part of input that fails

## The shape

A test builds the event and calls the handler:

```gdscript
game._unhandled_input(_touch_event(false, off_the_board))
```

That is not input. Real input goes through the viewport first: the GUI pass hit-tests
every `Control`, and anything with `MOUSE_FILTER_STOP` calls `set_input_as_handled()` and
the event never reaches `_unhandled_input` at all. Calling the handler directly starts
*after* that step, so **the test cannot observe any event being consumed** — it delivers
100% of what it sends, every time, by construction.

The bugs that live in the gap are the ones where a Control eats *some* of a gesture.

## What it cost here

`plant-tower-defense-vvmy`, cycle 180. "A finger that leaves the board disarms the plant."
The abort branch read `_hover_cell`, on the reasoning that the cue's own leftover state
could not disagree with the cue that wrote it. The test sent press → drag-to-far-side →
release and passed. On the running game the same gesture failed every time.

Dragging off the **right** edge crosses onto the side panel, which is an ordinary
`Control` doing exactly what it should: it consumes the remaining `InputEventScreenDrag`s.
So `_update_cursor` is never called again and `_hover_cell` keeps the last cell it heard
about. Measured on the live game right after the gesture:

```
_touch_index: -1
_hover_cell: (13, 8)        # column 13 of 14 — the last one before the edge
selected_plant: corn_cobbler # still armed
```

The synthetic drag went straight to the handler, set `_hover_cell` to `(-1, -1)`, and the
assertion passed over a state the game can never actually be in mid-gesture.

## The tell

**A handler reads a field that an EARLIER event in the same gesture was supposed to
update.** That is the whole signature. The handler is correct in isolation; what it
depends on is the *delivery* of the events before it, and delivery is the one thing a
synthetic test guarantees and reality does not.

Ask of any state a handler reads: *could the event that writes this have been eaten before
it arrived?* If a Control overlaps any part of the gesture's path, the answer is yes.

## The fix, in the code

Read the state the event **carries**, not state a previous event left behind.

```gdscript
# NO — depends on every prior drag having been delivered
if _hover_cell.x < 0:

# YES — the release position is on the event in hand
if off_board(touch.position):
```

Extract the predicate so the live path and the abort path cannot drift into two answers
(`Game.off_board`, `game/game.gd`). Same-value-two-derivations is the failure this whole
project keeps re-finding.

## The fix, in the test

**Withhold the intermediate events on purpose.** A test that sends the full clean gesture
asserts the easy case. Send press, then the release at the far position, and *no drag* —
that is exactly the swallowed-drag state, and it fails against the implementation that
shipped past the well-behaved version:

```gdscript
game._unhandled_input(_touch_event(true, on_board))
# NO drag event: reproduces a Control having eaten it
err = _T.assert_true(game._hover_cell.x >= 0,
    "the cue still points at a cell, because nothing told it otherwise")
game._unhandled_input(_touch_event(false, off_board))
err = _T.assert_eq(game.selected_plant, &"", "disarms anyway")
```

Worked example: `test_a_finger_leaving_the_board_disarms_the_pick` in
`test/unit/test_selftest.gd`.

## And confirm it on the running game

A synthetic test cannot generate this state on its own — it has to be *told* to, which
means someone has to already know. So the gesture itself still wants one live pass:

```bash
python tools/devtools.py ... set-feature --touchscreen true
python tools/devtools.py ... touch press   --index 0 --pos X,Y
python tools/devtools.py ... touch drag    --index 0 --to X2,Y2 --steps 6
python tools/devtools.py ... touch release --index 0 --pos X2,Y2
python tools/devtools.py ... get-state --node /root/Game --property <the state> --property _hover_cell
```

Read the *intermediate* field beside the outcome. `_hover_cell` reading a real cell after a
release that was supposed to be off-board is the fingerprint, and it is invisible if you
only assert the outcome.

`touch drag` reports what it **sent**, not what was **delivered** — there is no delivered
count (gap G-084). Inferring it from a stale field is the workaround.

## Related

- `godot-input-and-pause` — the production-code half: which node wins an event, and a
  world-space `Control` *wrongly* deleting playfield clicks. **This skill is the other
  case**: the Control there is behaving correctly, and the defect is that a test cannot
  see it happen.
- `extract-a-testable-seam` — for the predicate you pull out to make the branch assertable.
