---
name: who-wrote-this-file
description: Find out which test, or which bridge call, actually reached a function — by instrumenting the function itself with get_stack() for one run instead of reasoning about the call graph. Use when something wrote a file nothing named (a save, a config, a baseline under user://), when a suite reports a file changed but not by whom, when a test fails against state no test set, when "nothing in the diff calls this" and yet it ran, and generally whenever the question is "what got here" rather than "what does this do". Also use before theorising about test pollution or a leaked autoload.
---

# Ask the function who called it

The reasoning version of this question is expensive and usually wrong. The measured
version is six lines and one run, and it has now settled two separate incidents in this
project that a call-graph argument had already got backwards.

## The move

```gdscript
func _save() -> void:
	if save_path == SAVE_PATH:                      # the narrowest predicate that IS the bug
		print("TRACE _save on the REAL path: ", get_stack())
```

Run the thing once. Read the chains. Revert.

That is the whole procedure. What follows is only the parts that cost something when
skipped.

## Guard on the predicate, not the function

`_save()` runs hundreds of times in a suite; `_save()` **on the developer's real path**
ran three times. Instrumenting the function entry buries the answer in its own output and
tempts you to start filtering, which is how you filter out the case you were hunting.

Write the `if` as the precise statement of what is wrong — "this is the production path",
"this id is not in the expected set", "this count is above the ceiling". If you cannot
write that predicate, you do not yet know what you are looking for, and the trace will
not tell you.

## What the answer looks like

```
TRACE _save on the REAL path: [
  {"source": "res://game/run_config.gd", "function": "_save", "line": 781},
  {"source": "res://game/run_config.gd", "function": "record_score", "line": 281},
  {"source": "res://game/game.gd", "function": "bank_score", "line": 909},
  {"source": "res://test/unit/test_selftest.gd",
   "function": "test_quitting_a_run_through_pause_still_files_the_score", "line": 4573},
  {"source": "res://tools/run_tests.gd", "function": "instantiate_scene", "line": 893}]
```

The **intermediate hops are the finding**, not just the bottom frame. Both of the writers
this found reached the save through the game's own code — `Game.bank_score()` and
`Game._unhandled_input()` — so no test body mentioned the autoload at all, and the
project's hand-written guard listing `RunConfig.record_score` and six siblings had been
reporting clean over both of them since it was written. Reading the diff could not have
produced that, and neither could grepping the tests for the mutator's name.

## Reading the output

- **Read the log file, not the console.** Godot's Windows build is frequently the
  non-console one, so a run that printed your trace shows nothing in the terminal.
  `run_tests.py` captures to `.devtools/tests.log`; a bridge session to
  `.devtools/launch_stdout.log`.
- `get_stack()` returns `[]` in a release build. Debug (which every headless suite run
  and every `devtools.py launch` is) is what carries frame info — an empty array means
  the build, not the absence of a caller.
- A `print` inside a hot function slows a suite enough to matter. Another reason the
  predicate guard is not optional.

## The bridge variant

The same instrumentation answers "did my *verification session* do this". It has to be
asked, because it is not a hypothetical: driving a rebinding screen through the bridge in
cycle 31 called the game's real persist path and wrote the developer's actual
`user://highscore.save`. `--isolated` isolates the bus and **not** `user://`, so a live
session mutating production state looks exactly like a live session not doing that. The
failure surfaced twenty minutes later as five unrelated byte-exact tests failing at
startup.

So: if a suite starts failing on state no test sets, instrument, then run the *suite* —
if the trace is silent, the writer was not the suite, and the previous live session is
the next suspect. A silent trace is a result.

## For a static utility with no node

`class_name X extends RefCounted` never appears in a scene tree, so `scripts-seen` and
reach cannot see it however much of it ran. `DevTools.mark_script_reached("res://path.gd")`
called once from each real entry point closes that, and is worth adding permanently rather
than for one run.

## Then throw the instrumentation away — nothing will remind you

A stray `print(get_stack())` passes `name_check.py`, passes lint, passes the suite, and
changes no behaviour. **Every gate in this project is blind to it.** Revert it in the same
tool call that reads the answer, before you start fixing anything; the fix is usually
somewhere else entirely and it is easy to arrive at a commit with the trace still in.

## The fix is usually not at the frame you landed on

The trace names a call site, and a call site is the smallest possible place to fix
anything. Both incidents here were fixed one level up — a per-file `setup()` redirect, and
a checker that derives the reaching set instead of listing it — because the same defect
was available to every test that would ever be written in those files. Ask what class the
frame belongs to before patching the frame.
