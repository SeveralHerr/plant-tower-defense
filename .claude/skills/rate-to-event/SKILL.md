---
name: rate-to-event
description: Turn a per-frame rate into a discrete, telegraphed event without moving the balance — and find the five things that quietly depended on the rate being continuous. Use when a mechanic applies `X * delta` every physics frame and should read as a countable action instead (a bite, a drain, a heal, a charge, a tick of damage), when a cue "does not read" because it is re-armed sixty times a second, or when a design note asks for something to happen "less often".
---

`something.take_damage(RATE * delta)` in a `_physics_process` is a rate. A player cannot
count it, cannot anticipate it, and cannot point at the frame it happened on. Turning it
into an event is usually the whole of an "it should be more obvious" ask.

## Solve the cadence, do not choose it

Pick the COUNT first — how many events should it take? — and then solve the period so the
LAST event lands where the continuous version finished. Then nothing derived from the rate
has to move:

```gdscript
const EVENTS_TO_FINISH: int = 3
const STRIKE_AT: float = 0.68            # where in the cycle the event fires, 0..1

static func period() -> float:
    return (Target.MAX / RATE) / (float(EVENTS_TO_FINISH - 1) + STRIKE_AT)

static func damage() -> float:
    return Target.MAX / float(EVENTS_TO_FINISH)
```

The old constant survives as **the average rate**, which is what every derived reader
already assumes it is. State that in its header, because it is no longer the rate damage
ARRIVES at and the next reader will assume it is.

Two consts pointing at each other's class at load time is a cycle — make these `static
func`s, not `const`s, whenever the derivation crosses a class boundary.

## Count the events, do not branch on one

A frame long enough to span a period owes the target two. Make it pure and a COUNT:

```gdscript
static func strikes_between(before: float, after: float, period: float) -> int:
    if period <= 0.0 or after <= before:
        return 0
    var offset: float = STRIKE_AT * period
    return maxi(0, int(floor((after - offset) / period)) - int(floor((before - offset) / period)))
```

A rate that quietly halves itself when the machine stutters is a difficulty setting nobody
chose. Test this pure — the suite cannot produce a real 2.5 s physics frame.

## THE FIVE THINGS THAT DEPENDED ON IT BEING CONTINUOUS

Every one of these was found by hand in `plant-tower-defense-ulf1`. Grep for them before
you claim the change is done.

1. **Tests that pump N frames and assert the target lost something.** They now sit inside
   the wind-up and fail. That is the change working — rewrite them to assert the wind-up
   costs nothing AND that one whole lump lands after it. Two assertions where there was
   one.
2. **A test that resets the target's state but not the actor's new clock.** Settle frames
   advance it, so the first event fires early and a "takes exactly the time it always did"
   test measures short. Reset both.
3. **A recovery / quiet / cooldown clock the stream was pinning at zero by brute force.**
   It now RUNS in the gaps. Check the gap against the delay; the margin, not the old
   accident, is now what makes the rule true, and it needs a test.
4. **A sound repeat gate that WAS the audible rate.** With the stream gone the gate is a
   safety net for crowds instead. Its comment says otherwise; fix it.
5. **Comments elsewhere that say "every physics frame".** They are load-bearing
   explanations of why some cue looks the way it does, and they are now wrong. `grep -rn
   "every physics frame\|every frame" game/`.

## The pose, and what may not move

Put the shape in pure `static func`s returning a Dictionary — one curve, and derive the
second channel from the first so they cannot disagree about which frame the blow is on.
See `.claude/skills/assert-an-animation`.

Compose it where the existing per-frame animation is composed rather than beside it: two
sinusoids multiplied into one scale channel do not read as two states, they read as noise.
Take the walk/idle channel, leave any HIT/FLINCH channel alone — a thing that is mid-event
and gets shot still has to say so.

**Moving the picture is not moving the actor.** Write the offset to the SPRITE, never to
`position`: every proximity and targeting rule in the game reads `global_position`, and an
actor that lunges out of range of the things shooting at it is a balance change nobody
recorded. Same for facing — if the actor turns to look at its target, keep the old heading
in the field everything else reads and give the picture its own. A pest turned to face the
plant it is eating answers "coming towards you" to
`ChompFlower.is_past_enough` and is never grabbable again.
