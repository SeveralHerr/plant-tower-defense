---
name: generate-a-bool-classifier
description: Derive a small static if-chain (a Colour, a tint, a label — some GDScript "given these booleans, return this constant" function) and its test block from one spec, via tools/gen_bool_classifier.py, instead of hand-writing the branches and the assertions separately. Use whenever you are about to write a static func whose body is an if-chain over a handful of bool params returning a named constant (plant_button_tint, threat_color, health_color are the existing shape) — especially when adding a colourblind-safe twin doubles the branch count. Also use when a classifier's branches and its test have drifted (a case added to one, forgotten in the other).
---

# Generate a bool classifier, don't hand-pair it with its test

This codebase has several static functions of the exact same shape: a handful of `bool`
params in, an early-exit if-chain, a named `Color` (or similar) constant out —
`Hud.plant_button_tint`, `Hud.threat_color`, `Hud.health_color`, and (added
plant-tower-defense-q7z6) `Hud.plant_button_tint_on` / `Hud.seeds_flash_tint_on`. Every
one of them is paired with a hand-written test asserting each branch — and every one of
those pairs can drift: a branch added to the function and forgotten in the test, or the
reverse, with nothing catching it because the two are typed in two different places by
two different edits.

`tools/gen_bool_classifier.py` derives both from one JSON spec instead.

## When to reach for it

- You're about to add a new classifier of this shape (bool params -> named constant).
- You're about to add a param to an existing one (e.g. a `safe: bool` for a
  colourblind-safe twin) — this is the case that most often causes drift, because it
  doubles every existing branch and it is easy to update the function but forget one of
  the now-doubled test cases.
- A classifier's test and its function have already drifted and you're fixing it.

Not a fit for a classifier keyed on anything other than bools (an enum, a String, a
number range) — the witness-search in `_witness_for` only enumerates `{False, True}`
per free param.

## How

1. Write a spec: `{"function": NAME, "class": OWNER, "params": [[name, "bool"], ...],
   "cases": [{"when": {...}, "value": "CONST", "desc": "..."}]}`, cases in the order the
   real if-chain should try them, last case's `when` empty (the default).
2. `python tools/gen_bool_classifier.py SPEC.json` prints both the function and the test
   block — read them before committing to the spec.
3. Wrap the target region in each file with `# GEN:<function>:BEGIN` / `# GEN:<function>:END`
   markers (function body in the `.gd` file it lives in; assertions inside the test
   function body — everything else in that test, like an inequality check between two
   constants, stays outside the markers, hand-written).
4. `python tools/gen_bool_classifier.py SPEC.json --write-func PATH --write-test PATH`
   splices the generated blocks into place. Re-run it any time the spec changes.
5. `--check-func`/`--check-test` instead of `--write-*` compares without writing and
   exits 1 on drift — useful in a review pass, not yet wired into `tools/check_all.py`
   (it isn't shaped like that contract's checkers: it's spec-scoped, not a project-wide
   scan with no arguments — see that tool's own header before trying to fold this in).

See `tools/specs/plant_button_tint.json` and `tools/specs/seeds_flash_tint.json` for two
worked examples, and their markers in `game/hud.gd` / `test/unit/test_selftest.gd`.
