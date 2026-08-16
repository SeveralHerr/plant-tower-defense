---
name: godot-test-isolation
description: Why a Godot test can be green for the wrong reason — tree-global groups returning a node your own settle frames created, indexed group reads that measure a stranger, and suite-order-dependent passes. Use when writing or reviewing tests that read get_nodes_in_group, when a test passes in the suite but fails alone (or vice versa), when adding tests changes an unrelated test's result, or before theorising about test pollution at all.
---

# Tests that pass for the wrong reason

The failure this is about does not look like a failure. It looks like a green suite, for
months, while an assertion measures an object the test never meant to select.

It also comes with a strong, wrong, ready-made explanation. Read the mechanism section
before adopting one.

## The mechanism

**Measure before you believe a story about this.** The obvious story — that `queue_free()`
defers and leaks nodes into the next test — was wrong in this repo, and I wrote it into a
skill, a doc comment and two commit messages before someone counted. `free_ui` calls
`free()` outright, and a group census taken after every one of 358 tests showed **no group
growing across any test boundary**. If your harness frees immediately, cross-test leakage
is not your problem and chasing it wastes the cycle.

The real mechanism is narrower and lives *inside* one test:

1. **`get_nodes_in_group()` is tree-global.** It returns every node in the group anywhere
   in the SceneTree, not the ones your test made, and not in an order you chose.
2. **Instantiating a scene pumps settle frames.** Anything that acts on entering the tree
   has already acted by the time your test body runs. So the group is *already populated*
   by your own setup before you take `[0]`.

`test_kernels_launch_from_the_cob_on_an_offset_layer` is the worked example. A
`CornCobbler` enters the tree already loaded, so hosting one beside a pest fires a volley
during the settle frames. Its `kernels[0]` was that setup kernel, never the shot under
test. Green for months, because a setup kernel looks exactly like a fired one — and red
only when unrelated tests changed what the tree happened to contain.

Both stories have the same fix, which is why the fix survived the wrong diagnosis. Only
the *reasoning* was wrong, and reasoning is what you reuse on the next bug.

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

## Where the stranger can come from

Check these in order, cheapest first:

- **your own setup, during settle frames** — the common case, and the one that looks least
  like a bug. Anything auto-acting on `_ready` has already run.
- a node parented **outside** the freed subtree (a projectile added to `get_parent()`
  rather than to the host the test frees), which survives that host's teardown
- `free()` vs `queue_free()` — one is immediate, one is not. **Check which your harness
  uses before theorising**; do not assume, and do not trust a comment saying which,
  including one you wrote.
- a node added to a group before it enters the tree (it is not in `get_nodes_in_group`
  until it does, which makes it *absent* rather than extra — the opposite surprise)
- autoloads and statics, which survive `reload_current_scene()` and every test

## Counting it

A census that walks `tree.root` and tallies `node.get_groups()` catches groups nobody
named; a census of groups you thought to list only confirms what you already suspected.
Take it with no frame pumped, which is stricter than reality rather than weaker.

## `[PASS]` with an error on stderr

`[VACUOUS]` catches a test that executed no assertions. It does **not** catch a test that
executed several, passed them, and *also* errored — because assertions did run. Two real
cases here, both of which printed green:

- an unconfigured `Kernel` has default `Rect2()` bounds, so it is outside its own bounds
  on frame one and frees itself during `instantiate_scene`'s settle frames. The test
  printed `[PASS]` on six assertions while stderr carried
  `Nonexistent function 'setup' in base 'previously freed'`.
- a test that scanned source matched the comment explaining why a token was absent.

**Read stderr on every run, including green ones.** `[ERR]` lines are the only signal that
a `-> String` test aborted partway: the method returns `""` from wherever it died, and
`""` is a pass.

```bash
godot --headless --path . --script res://tools/run_tests.gd > out.txt 2>&1
grep -aE "\[ERR\]|SCRIPT ERROR|Nonexistent|previously freed" out.txt
```

A run that is green **and** silent is the only green worth having.

## `set_physics_process(false)` before tree entry does not stick

Godot re-enables processing when the node enters the tree, so a test that disables it on a
detached node and then parents it gets a node that moves anyway. Here a kernel flew 56px
between construction and assertion (`Expected 160.0 but got 216.0`).

Add the node to the tree **first**, then disable processing, and do not `await` afterwards.
Existing tests in this repo survive the same pattern only because they happen to step
exactly one frame — which is luck, not design, and is the same class of accident as a test
that passes only in company.
