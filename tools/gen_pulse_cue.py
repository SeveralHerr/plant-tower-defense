#!/usr/bin/env python3
r"""gen_pulse_cue.py - deterministic GDScript for this codebase's "edge-detected
pulse cue" pattern, so the next one is generated rather than hand-copied.

WHY THIS EXISTS.

game/hud.gd has grown this exact shape twice: _set_prep_bar_urgent (the prep
strip's final-seconds urgency pulse, plant-tower-defense-w86n-adjacent) and
_set_next_wave_pulse_active (the next-wave button's pressable pulse,
plant-tower-defense-jlsc). Both are four pieces of boilerplate -- two consts
(seconds/dim), two vars (a Tween + an edge-detect bool), one setter that
kills the old tween, resets to WHITE, and gates on GardenTheme.animations_
enabled() before starting a new looped Tween -- differing only in the const
values, the var/const names, and which Control gets tweened. jlsc's version
was authored by reading w86n's and retyping it with new names, which is
exactly the failure mode a generator removes: a stray rename (the dim const
used in the wrong tween_property call, the reset line pointed at the wrong
node) is a silent bug a human proofreading their own copy is bad at catching
and a generator cannot make, because there is only one template to get right.

This does not touch any file. It PRINTS three blocks -- CONST, VAR, FUNC --
each meant to be pasted at its own location in the target script, because
where each block belongs (beside which other consts, which other pulse var,
after which sibling setter) is a judgment call about the surrounding file
that this tool has no way to make safely. Compare citation_rebind.py, which
DOES write kanban.md directly -- the difference is that citation_rebind
computes a single unambiguous target line from an already-decided move,
where here the three insertion points are a per-file layout decision.

USAGE.

    python tools/gen_pulse_cue.py NAME TARGET [--seconds S] [--dim D] [--why TEXT]
    python tools/gen_pulse_cue.py --self-test

NAME is the identifier stem, e.g. "next_wave_pulse" for a button that should
end up with _set_next_wave_pulse_active(). TARGET is the GDScript expression
for the Control being pulsed, e.g. "_next_wave_button". --seconds and --dim
default to jlsc's own values (0.5s half-cycle, 0.8 dim) since a slow, gentle
"click me" reads differently from the prep strip's 0.24s/0.45 alarm and a
caller should choose deliberately, not inherit the wrong one by omission.
--why is one sentence folded into the generated doc comment explaining what
this specific cue means to the player; the tool has no way to invent that.

BLIND SPOTS: this is a text generator, not a checker -- it is intentionally
classified as a non-checker in check_all.py (see that file's NOT_A_CHECKER
entry for this file) the same way citation_rebind.py is, and deliberately
carries none of the checker contract's own marker line so it is never
mistaken for one. It does not validate that NAME or TARGET are real
identifiers in any script, does not insert anything, and does not know
whether a pulse cue is the right answer for a given piece of UI -- only that
if one is wanted, this is its shape.
"""

from __future__ import annotations

import argparse
import sys

TEMPLATE_CONST = '''## Half a pulse cycle for {target}'s {name_human} cue.
## {why}
const {upper}_SECONDS: float = {seconds}
const {upper}_DIM: float = {dim}'''

TEMPLATE_VAR = '''var _{name}: Tween = null
## Edge-detected: refresh() may run every frame this cue is armed, and
## re-tweening to the same target on every one of those frames would never
## let a cycle advance past its first step.
var _{name}_active: bool = false'''

TEMPLATE_FUNC = '''## Starts or stops {target}'s {name_human}, edge-detected -- see
## _{name}_active's own comment for why that guard is load-bearing here.
func _set_{name}_active(active: bool) -> void:
	if active == _{name}_active:
		return
	_{name}_active = active
	if _{name} != null and _{name}.is_valid():
		_{name}.kill()
	# Reset first, gate second: leaving the armed condition (or a headless run
	# that never had a Tween) must not freeze {target} dim.
	{target}.modulate = Color.WHITE
	if not active or not GardenTheme.animations_enabled():
		return
	_{name} = create_tween().set_loops()
	_{name}.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_{name}.tween_property({target}, "modulate", Color(1, 1, 1, {upper}_DIM), {upper}_SECONDS)
	_{name}.tween_property({target}, "modulate", Color.WHITE, {upper}_SECONDS)'''


def render(name: str, target: str, seconds: float, dim: float, why: str) -> dict:
    if not name.replace("_", "").isalnum() or name[0].isdigit():
        raise ValueError(f"NAME must be a valid GDScript identifier stem, got {name!r}")
    if not (0.0 < dim < 1.0):
        raise ValueError(f"--dim must be between 0 and 1 (exclusive), got {dim}")
    if seconds <= 0.0:
        raise ValueError(f"--seconds must be positive, got {seconds}")
    name_human = name.replace("_", " ")
    upper = name.upper()
    fmt = dict(name=name, name_human=name_human, target=target, upper=upper,
               seconds=seconds, dim=dim, why=why)
    return {
        "CONST": TEMPLATE_CONST.format(**fmt),
        "VAR": TEMPLATE_VAR.format(**fmt),
        "FUNC": TEMPLATE_FUNC.format(**fmt),
    }


# The golden fixture: jlsc's own hand-authored hud.gd is the ground truth this
# tool must reproduce byte-for-byte for the FUNC block (the part with the most
# ways to get a rename wrong) when fed jlsc's own real parameters. CONST/VAR
# differ from the shipped code only in their doc comments, which are
# necessarily hand-authored per cue -- so those two are checked structurally
# (right names, right values) rather than byte-for-byte.
_GOLDEN_FUNC = '''## Starts or stops _next_wave_button's next wave pulse, edge-detected -- see
## _next_wave_pulse_active's own comment for why that guard is load-bearing here.
func _set_next_wave_pulse_active(active: bool) -> void:
	if active == _next_wave_pulse_active:
		return
	_next_wave_pulse_active = active
	if _next_wave_pulse != null and _next_wave_pulse.is_valid():
		_next_wave_pulse.kill()
	# Reset first, gate second: leaving the armed condition (or a headless run
	# that never had a Tween) must not freeze _next_wave_button dim.
	_next_wave_button.modulate = Color.WHITE
	if not active or not GardenTheme.animations_enabled():
		return
	_next_wave_pulse = create_tween().set_loops()
	_next_wave_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_next_wave_pulse.tween_property(_next_wave_button, "modulate", Color(1, 1, 1, NEXT_WAVE_PULSE_DIM), NEXT_WAVE_PULSE_SECONDS)
	_next_wave_pulse.tween_property(_next_wave_button, "modulate", Color.WHITE, NEXT_WAVE_PULSE_SECONDS)'''


def self_test() -> int:
    failures = []

    blocks = render("next_wave_pulse", "_next_wave_button", 0.5, 0.8, "pressable")
    if blocks["FUNC"] != _GOLDEN_FUNC:
        failures.append(
            "FUNC block for the jlsc fixture drifted from the golden text:\n"
            f"--- got ---\n{blocks['FUNC']}\n--- want ---\n{_GOLDEN_FUNC}"
        )

    if "NEXT_WAVE_PULSE_SECONDS: float = 0.5" not in blocks["CONST"]:
        failures.append("CONST block missing the expected seconds const")
    if "NEXT_WAVE_PULSE_DIM: float = 0.8" not in blocks["CONST"]:
        failures.append("CONST block missing the expected dim const")
    if "var _next_wave_pulse: Tween = null" not in blocks["VAR"]:
        failures.append("VAR block missing the Tween var")
    if "var _next_wave_pulse_active: bool = false" not in blocks["VAR"]:
        failures.append("VAR block missing the edge-detect bool")

    for bad_name, reason in [("9pulse", "leading digit"), ("pulse-cue", "hyphen")]:
        try:
            render(bad_name, "_x", 0.5, 0.8, "")
        except ValueError:
            pass
        else:
            failures.append(f"render() accepted an invalid NAME ({reason}): {bad_name!r}")

    for bad_dim in (0.0, 1.0, 1.5, -0.1):
        try:
            render("p", "_x", 0.5, bad_dim, "")
        except ValueError:
            pass
        else:
            failures.append(f"render() accepted an out-of-range --dim: {bad_dim}")

    if failures:
        print(f"SELF-TEST FAILED: {len(failures)} failure(s)")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("SELF-TEST OK: 4 fixed assertions + 6 rejection cases, all passed")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name", nargs="?", help="identifier stem, e.g. next_wave_pulse")
    ap.add_argument("target", nargs="?", help="GDScript expr for the pulsed Control")
    ap.add_argument("--seconds", type=float, default=0.5)
    ap.add_argument("--dim", type=float, default=0.8)
    ap.add_argument("--why", default="", help="one sentence for the doc comment")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)

    if args.self_test:
        return self_test()

    if not args.name or not args.target:
        ap.print_usage()
        print("error: NAME and TARGET are required unless --self-test", file=sys.stderr)
        return 2

    try:
        blocks = render(args.name, args.target, args.seconds, args.dim, args.why)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    for label in ("CONST", "VAR", "FUNC"):
        print(f"# -- {label} " + "-" * (60 - len(label)))
        print(blocks[label])
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
