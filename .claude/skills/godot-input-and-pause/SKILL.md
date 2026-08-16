---
name: godot-input-and-pause
description: Godot 4 input propagation and pause semantics for overlays — which node wins a keystroke, why a guard that reads is_input_handled() cannot work in a headless test, and when a signal connection must be deferred. Use when adding or testing any screen that opens over another (pause menus, notebooks, confirm dialogs, inventories).
---

# Input propagation and pause, for overlays

Every rule here was learned by something breaking. Each one costs a redesign if you
meet it mid-task instead of before starting.

## The four facts

### 1. `Viewport.is_input_handled()` is sticky outside `push_input`

The viewport's handled flag is reset **only inside `push_input`**. A headless test that
calls `some_node._input(event)` directly never goes through `push_input`, so the first
`set_input_as_handled()` anywhere in the run latches the flag on for the rest of it.

Consequence: a guard written as

```gdscript
func _input(event: InputEvent) -> void:
    if get_viewport().is_input_handled():
        return  # WRONG under test
```

works in the running game and **silently disables itself** in every subsequent test in
the same run. The test still passes, because the guard's job is to do nothing.

Guard on your own state instead — `if _overlay_open(): return`. State is readable,
assertable, and does not depend on how the event arrived.

### 2. `_input` walks children before parents

An overlay that is a *child* of the screen it covers receives the event first, and its
`set_input_as_handled()` stops the parent from seeing it. So Escape closing the overlay
rather than the screen underneath is often already correct — **by tree order**.

Do not rely on that alone. It is a fact about where the node currently sits, expressed
nowhere in either script, and it inverts the day someone reparents the overlay to a
higher `CanvasLayer` (a normal thing to do for z-order). Write the explicit guard as
well, and let tree order be the redundant half.

The guard also has to cover keys the overlay does **not** handle. Tree order protects
only what the child consumes: a pause menu bound to `P` will happily unpause the run
underneath an open notebook that never looks at `P`.

### 3. A signal emitted from inside `_input` reaches a direct handler mid-event

```gdscript
# In the overlay:
func _input(event):
    if <escape>:
        back_requested.emit()      # handler runs HERE, synchronously
        set_input_as_handled()
```

If the parent connects `back_requested` directly to a handler that frees or nulls the
overlay, the overlay is gone **while its own `_input` is still on the stack** — and the
parent's guard from fact 2, which asks "is the overlay open?", now answers *no* for the
remainder of that same keystroke. The event falls through to the screen underneath.

Fix: `CONNECT_DEFERRED`.

```gdscript
_overlay.back_requested.connect(_close_overlay, CONNECT_DEFERRED)
```

The overlay stays open for the whole of that event's propagation and closes at end of
frame. **Comment this at both ends** — it reads like an arbitrary flag and is the line
holding the interaction together.

### 4. `PROCESS_MODE_INHERIT` on a pause overlay is a trap that resolves correctly today

An overlay added under a card that is itself `PROCESS_MODE_ALWAYS` inherits `ALWAYS` and
works. Reparent it — to a `CanvasLayer`, to the scene root, anywhere — and it silently
becomes FROZEN while `get_tree().paused` is true: buttons dead, no input, no error.

Set it outright on the overlay:

```gdscript
_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
```

Its children may stay `INHERIT` and pick it up. The point is that a test can now assert
a **stated property** (`process_mode == PROCESS_MODE_ALWAYS`) instead of inferring an
inherited fact from where the node happens to sit.

## Testing overlays headlessly

- **Open through the button, not the method.** `NotebookButton.pressed.emit()` fails if
  nothing is wired to the button; `_open_notebook()` passes just as happily on a
  disconnected button — which is usually the exact bug being fixed.
- **Assert `can_process()` while the tree really is paused**, on the overlay *and* on
  its interactive children. `process_mode` alone does not prove the children resolved.
- **Drive the escape path through both `_input` handlers back to back**, with nothing
  pumped between them. That is the ordering the guard exists for, and pumping a frame
  hides fact 3 completely.
- **End with the underlying screen still working.** A guard can pass by breaking the
  thing it guards — check that Resume still resumes after the overlay has closed.
- Buttons underneath an overlay need `FOCUS_NONE` + `MOUSE_FILTER_IGNORE`, not
  `disabled`: focus is a separate channel from the mouse, and a focused button glows
  through a translucent backdrop. Using `disabled` also breaks any existing test
  asserting `not button.disabled`.

## Vacuous-pass guards

A runtime error inside a test method aborts only that method and returns `""` — which
for a `-> String` test is indistinguishable from a pass. So:

- `assert_true(node != null)` before every dereference of a `get_node_or_null` result.
- `assert_gt(SOME_TABLE.size(), 0)` before any loop over a table, or a suite that
  iterates an empty array reports a confident green.
