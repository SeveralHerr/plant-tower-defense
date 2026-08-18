#!/usr/bin/env python3
"""Walk a flourish tween and assert it reaches the extreme it is written to reach.

plant-tower-defense-ejfa. Needs a RUNNING game:

    python tools/devtools.py launch
    python .claude/surveys/flourish_peak.py

Exit 0 every flourish reached its peak / 1 one did not / 2 could not run.

WHY THIS IS NOT A UNIT TEST. `animations_enabled()` is false headless, so a tween
never runs there: the whole subject of this check exists only in a live game. That
is the split CLAUDE.md draws — anything needing a tween to land stays a bridge check.

WHY IT SCANS INSTEAD OF SAMPLING AT A FIXED STEP. Measured over four independent
walks: the peak VALUE is reached exactly (0.880 against a written 0.88, to within
3e-6, every time), but WHICH step lands on it moves with the requested step size —
step 3 at `--seconds 0.01`, step 5 at `--seconds 0.001` — because `step_time`
advances the process clock by an amount that is neither the requested seconds nor a
whole physics frame. So a check that reads one fixed step index is measuring the
harness's stepping behaviour, not the tween. This walks past the peak and takes the
extreme.

WHY 0.01 AND NOT 0.03, which is the finding this survey exists to settle. Cycle 72
walked the recoil at `--seconds 0.03` and read 0.900 against a written 0.88, and
could not tell a sampling artefact from a real discrepancy. It was the artefact:
`TWITCH_OUT_SECONDS` is 0.05, a 0.03 request advances roughly two frames, and the
samples straddle the peak without landing on it. At 0.01 the walk lands on 0.880
exactly. The step size is therefore chosen from the tween's own duration rather
than guessed — anything comfortably below `TWITCH_OUT_SECONDS` works.
"""
import json
import subprocess
import sys

DEV = [sys.executable, "tools/devtools.py"]
STEP_SECONDS = 0.01
STEPS = 10

# (label, class_name, method, property, axis, written extreme, direction)
FLOURISHES = [
    ("cob recoil", "CornCobbler", "_recoil", "_sprite.scale", "x", 0.88, "min"),
    ("cob recoil", "CornCobbler", "_recoil", "_sprite.scale", "y", 1.14, "max"),
]
TOLERANCE = 0.01


def dev(*args):
    out = subprocess.run(DEV + list(args), capture_output=True, text=True,
                         errors="replace")
    return out.stdout + out.stderr


def node_of(class_name):
    text = dev("find-nodes", "--class", class_name)
    for line in text.splitlines():
        if "/root/" in line:
            return line.split()[0]
    return ""


def scale_axis(node, prop, axis):
    text = dev("get-state", "--node", node, "--property", prop)
    for line in text.splitlines():
        if prop in line and "{" in line:
            body = line[line.index("{"):]
            try:
                return float(json.loads(body)[axis])
            except Exception:
                return None
    return None


def main():
    if "DevTools is running" not in dev("ping"):
        print("could not run: no game on the bus. `python tools/devtools.py launch` first.",
              file=sys.stderr)
        return 2

    dev("pause")
    failures = 0
    checked = 0
    for label, cls, method, prop, axis, written, direction in FLOURISHES:
        node = node_of(cls)
        if not node:
            print("could not run: no %s in the tree -- place one first." % cls,
                  file=sys.stderr)
            return 2
        dev("run-method", "--node", node, "--method", method)
        seen = []
        for _ in range(STEPS):
            dev("step-time", "--seconds", str(STEP_SECONDS), "--then-pause")
            value = scale_axis(node, prop, axis)
            if value is not None:
                seen.append(value)
        if not seen:
            print("could not run: %s read no %s.%s" % (label, prop, axis), file=sys.stderr)
            return 2
        checked += 1
        reached = min(seen) if direction == "min" else max(seen)
        ok = abs(reached - written) <= TOLERANCE
        failures += 0 if ok else 1
        print("%-4s %-12s %s.%s  reached %.4f against a written %.2f  (%d samples)"
              % ("ok" if ok else "FAIL", label, prop, axis, reached, written, len(seen)))
        if not ok:
            print("      samples: %s" % ", ".join("%.4f" % v for v in seen))

    print("")
    print("flourish_peak: %d flourish axis/axes walked, %d reached their written "
          "extreme, %d did not" % (checked, checked - failures, failures))
    print("  NOT COVERED: this walks the tween a plant creates and reads the property it "
          "moves. It says nothing about whether that property is what the player sees "
          "(a Control's `scale` is hidden by its container -- read `data.transform` "
          "there), nothing about the tween's SHAPE between samples, and nothing about "
          "the three flourishes not listed above. It cannot distinguish a tween that "
          "reached the extreme from one that overshot and came back between two steps.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
