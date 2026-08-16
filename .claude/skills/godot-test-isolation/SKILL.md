---
name: godot-test-isolation
description: Why a Godot test can be green for the wrong reason — tree-global groups outliving the test that filled them, queue_free deferring past the end of a test, and assertions that measure a leaked node from a previous run. Use when writing or reviewing tests that read get_nodes_in_group, when a test passes in the suite but fails alone (or vice versa), or when adding tests changes an unrelated test's result.
---

# Tests that pass for the wrong reason

The failure this is about does not look like a failure. It looks like a green suite, for
months, while an assertion measures an object belonging to a test that finished long ago.

## The mechanism

Two facts combine:

1. **`get_nodes_in_group()` is tree-global.** It returns every node in the group anywhere
   in the SceneTree, not the ones your test made. Nothing scopes it to your subtree.
2. **`queue_free()` defers to the end of the frame.** A test that frees its host and
   returns has *scheduled* a free, not performed one. The next test starts with those
   nodes still in the tree and still in their groups.

So the next test's `get_nodes_in_group("pests")[0]` can hand back a pest from a game that
no longer conceptually exists — and it will usually look plausible, because it is the same
kind of object with the same defaults.

**This was found here four times.** `test_kernels_launch_from_the_cob_on_an_offset_layer`
read `kernels[0]`, measured a leaked kernel on every run, and was green for months. It
turned red only when four *unrelated* tests were appended and shifted the suite order.
Three more tests read `get_nodes_in_group("pests")[0]` straight after `spawn_pest`.

## The signature

**A test that passes in the suite and fails alone — or the reverse — is not flaky. It is
measuring something it did not create.** Treat suite-order sensitivity as a correctness
bug in the test, never as noise to rerun.

Symptoms worth recognising:

- adding an unrelated test turns a distant test red
- a test fails under `--filter` but passes in a full run
- a value is "almost right" — right type, wrong instance

## The rule: diff the group, never index it

```gdscript
# WRONG — whichever node the tree lists first, from any test
var pest: Pest = game.get_tree().get_nodes_in_group("pests")[0] as Pest

# RIGHT — provably the one this action created
var before: Dictionary = {}
for p: Node in game.get_tree().get_nodes_in_group("pests"):
    before[p.get_instance_id()] = true
game.spawn_pest(species)
for p: Node in game.get_tree().get_nodes_in_group("pests"):
    if not before.has(p.get_instance_id()) and p is Pest:
        return p as Pest
return null
```

Key it on `get_instance_id()`, not on identity or name: names collide across tests and a
freed node compares unhelpfully.

**Return `null` on not-found and make the caller fail loudly.** A helper that returns a
wrong-but-plausible node reintroduces the bug it exists to prevent; a nil deref aborts the
method and returns `""`, which for a `-> String` test is indistinguishable from a pass.

Iterating a group is safer than indexing it but not safe: a loop that asserts "every pest
is X" will happily assert it about a stranger. If the assertion is about *your* nodes,
diff first.

## Verifying the fix

Run the test **alone** as well as in the suite. That is the property being fixed, and a
full-suite pass does not demonstrate it:

```bash
godot --headless --path . --script res://tools/run_tests.gd -- --filter <name>
```

Both must pass. If only the suite does, the test still depends on its neighbours.

## Diagnosing "my change broke an unrelated test"

Establish the control **first**, before bisecting:

> Does the test fail at HEAD, alone, under the new conditions?

If yes, the change did not break it — the change exposed it. Reverting files one at a time
is the slower path to the same answer, and it misleads: reverting each of three changed
files individually can leave the failure in place, which looks like "none of them did it"
rather than "none of them could have."

## Other leak sources to check

- a node parented **outside** the freed subtree (a projectile added to `get_parent()`
  rather than to the host the test frees)
- `free()` vs `queue_free()` — one is immediate, one is not, and tests mix them
- a node added to a group before it enters the tree (it is not in `get_nodes_in_group`
  until it does, which makes it *absent* rather than leaked — the opposite surprise)
- autoloads and statics, which survive `reload_current_scene()` and every test
