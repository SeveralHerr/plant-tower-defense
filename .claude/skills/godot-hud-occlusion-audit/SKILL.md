---
name: godot-hud-occlusion-audit
description: Find Godot HUD Controls that overlap each other on screen - a counter running under a button, a banner covering a score, two panels sharing pixels. Checks pairs of sibling Controls, which validate-ui and `findings` structurally cannot do because they only ever measure one Control against its own box. Use whenever a HUD gains a label whose text length varies at runtime (a count, a score, a timer, a name), whenever a HUD bar is laid out with manual positions rather than a Container, after adding any node to the HUD layer, and at the symptoms - "the text is cut off", "something is covering the score", "it only breaks when the number gets big", "the HUD looks fine in the editor". Also use when validate-ui reports 0 findings over a HUD that visibly looks wrong.
---

# HUD occlusion audit

## What this is for

`validate-ui` / `findings` ask *"does this Control fit in its own box?"* — one node,
measured against itself. That question is blind to the whole class of bug where two
nodes each fit perfectly and land on top of each other.

This was not hypothetical. On 2026-08-15 this project's HUD read
`Compost 0 (11 ready)` while the "Grow the next wave" button sat on top of the
`(11 ready)` half. `findings` reported **`0 finding(s) across 5 of 5 checks`** over
that exact frame, and was right to: the Label's rect is fine. It is the *button* that
is in the wrong place, and no per-node check can see a pair.

So run this **in addition to** `/verify`, not instead of it.

## Run it

Needs a running game (it drives the harness devtools bus).

```bash
python tools/devtools.py launch          # if not already up
python .claude/skills/godot-hud-occlusion-audit/hud_occlusion_check.py
```

Exit codes follow the harness contract: **`0`** clean, **`1`** findings,
**`2` could not run** — which is not a pass. A `2` means the game is not up, the HUD
layer name did not resolve, or no visible sized Controls were found.

Flags: `--layer NAME` (defaults to `hud_layer_name` from `devtools_config.json`),
`--min-fraction F` (ignore overlaps below this share of the smaller rect, default
`0.04`, which drops 1px border kisses), `--json`, `--repo PATH`.

## The one thing that will make you miss the bug

**A clean run only proves the HUD does not overlap *in the state it is in right now*.**
The failure this check exists for is almost always length-dependent: the counter reads
`Compost 0` on a fresh board and only grows into the button at `(11 ready)`. Launching,
running the checker, and getting a `0` proves nothing about the state that breaks.

Stage the extreme state first, then measure:

```bash
# whatever makes the text its longest - a full board, a 5-digit score, a long name
python tools/devtools.py cmd spawn_pest --args '{"species":"beetle"}'   # ... etc
python .claude/skills/godot-hud-occlusion-audit/hud_occlusion_check.py
```

**`set-state` on the label does not work here, and the way it fails is quiet.** Writing
`text` directly holds only until the next `Hud._refresh()`, which every seed/husk/wave
signal triggers — so the write appears to succeed, the read-back confirms it, and by the
time the checker measures, the HUD has put the real string back and you get a clean `0`.
Stage the *game state* that produces the long string, not the string.

The recipe that reproduces this project's known finding, twice in a row:

```bash
# 12 aphids killed on the spot -> "Compost  0 (11 ready)" in the top bar
python - <<'PY'
import json, subprocess
def dv(*a):
    return json.loads(subprocess.run(["python","tools/devtools.py","--json"]+list(a),
                                     capture_output=True, text=True).stdout)
for _ in range(12):
    subprocess.run(["python","tools/devtools.py","cmd","spawn_pest",
                    "--args",'{"species":"aphid"}'], capture_output=True)
for n in dv("find-nodes","--group","pests")["data"]["nodes"]:
    dv("run-method","--node",n["path"],"--method","kill","--args","[]")
PY
python .claude/skills/godot-hud-occlusion-audit/hud_occlusion_check.py --json
```

```
"a_text": "Compost  0 (11 ready)",  "b_text": "Grow the next wave",
"overlap_px": 1484.0, "fraction_of_smaller": 0.254
```

**Measure within ten seconds.** Husks rot at `CompostMeter.HUSK_LIFETIME`, the counter
shrinks back, and the finding disappears — a run made a moment too late reports a clean
`0` for a HUD that is still broken. That timing trap generalises: any HUD state driven by
a timer has a window, and the checker has no idea it missed it.

## What it reports, and what it deliberately does not

Reported: a pair of visible, non-zero-size Controls under the HUD layer whose **screen**
rects intersect by more than `--min-fraction` of the smaller, where one of them is
opaque (a Button, Panel, ColorRect, ProgressBar…) and at least one carries text. That
is the shape of "something is covering something a player needs to read or click".

Not reported, on purpose:

- **A child inside its own container.** A Label inside a PanelContainer shares pixels
  by design; the checker skips any pair where one path is an ancestor of the other.
- **Two transparent nodes overlapping.** Without an opaque node in the pair nothing is
  actually hidden.
- **Anything outside the HUD layer.** World-space nodes overlap constantly and legally.

Screen rects come from `node-bounds`, which applies ancestor `CanvasLayer` transforms.
Do not substitute a Control's own `position`/`size`: those are layer-local and will
happily agree with each other while the two nodes sit on top of each other on screen.

## After you find one

Fixing the pixel positions is the smaller half. The durable fix is usually **a layout
that cannot produce the collision**: an `HBoxContainer` with the button in its own slot,
so a longer counter pushes rather than underlaps. Then promote the check into
`test/unit/test_selftest.gd` with the *long* string staged, using `_T.instantiate_ui` —
that turns a one-off audit into something every future `/verify` re-runs for free.
