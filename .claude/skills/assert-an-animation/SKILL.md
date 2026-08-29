---
name: assert-an-animation
description: Author a Godot animation so the headless suite can hold a real claim about it, and know which one claim is left for the running game. Use when adding or changing any Tween, fade, pop, punch, roll, shake or entrance; when a test "covers" an animation by pumping it and reading what moved; when an animation is correct on screen and wrong in a test (or the reverse); and when a live read of a moving property is about to become a defect report.
---

# A tween must never be the thing that arrives

`GardenTheme.animations_enabled()` is false in every headless test, by construction, and
headless pumps no frames anyway. So a tween that is *responsible for reaching* the correct
state leaves the correct state unreachable — in the whole suite, and on any machine where
animation is off. The animation's job is to overwrite a state that is already correct with
an intermediate one, and put it back.

This project has learned that four times and written it down nowhere, so here it is. The
rungs below are ordered by cost: take the highest one that fits.

## 1. Derive the value from a clock you already own — no Tween at all

The banner fade does this and argues for itself in its own header
(`game/hud.gd:3895`): a Tween would need the usual gate and would own the hide in its
finished callback, "which puts the banner's visibility inside something headless never
runs". Instead `_fade_banner` (`game/hud.gd:3902`) decrements `_banner_left` and computes
alpha from it, so the banner is in a correct state on every frame *including the ones that
never happen*.

The test then calls `_fade_banner(dt)` with the deltas it chooses
(`test/unit/test_selftest.gd:4410`). No gate, no callback, no frames, no seam to extract —
the whole animation is assertable. **If the value is a function of elapsed time, this rung
is free and every rung below it is a worse version of it.**

## 2. Set the final state first, then arm the tween

When a Tween is genuinely wanted, the order is load-bearing and reads as arbitrary. The
title screen sets the settled score line at `game/title_screen.gd:505` and only then calls
`_arm_record_ratchet(score)` at `:515`. Headless, the tween never runs and the label already
holds the right text.

Three things make it a pattern rather than one trick, and the HUD's seeds roll
(`game/hud.gd:2855`) reached all three independently a few cycles later:

- **One renderer for the moving line and the settled line.** `high_score_text_at`
  (`game/title_screen.gd:560`) is called from inside the tween method and from the builder,
  so the two cannot disagree about spacing or which modes get named.
  `Hud.seeds_roll_value` (`game/hud.gd:2836`) is the same idea as a pure static.
- **A restoring callback**, `game/title_screen.gd:618`. Not paranoia about float error —
  an *interrupted* tween never runs its last step at all, so a player pressing a key
  mid-roll would be left looking at whatever number the count had got to.
- **Kill the live tween before starting another.** `_punch_readout` does it at
  `game/hud.gd:2804`; `_arm_seeds_roll` does it at `game/hud.gd:2861` and its comment says
  why the kill goes *before* the is-it-worth-showing test — a small change arriving mid-roll
  must stop the roll, not let it keep counting toward a stale total.

What the suite can then assert is the renderer: endpoints, monotonicity, step count
(`test/unit/test_selftest.gd:15420`, whose own header says a test that drove `refresh()` and
watched the Label "would assert nothing at all while looking like coverage").

## 3. If the tween displaces, the displacement is the assertable number

An entrance that offsets a Control and eases it back leaves the offset readable for exactly
as long as no frame is pumped — which headless is. `test/unit/test_combat.gd:2421` calls
`_play_entrance()` directly and reads `position.y` on the next line, and that difference
tells a win entrance from a loss entrance. `PauseScreen._play_entrance` has the same shape
(`game/pause_screen.gd:644`).

This is weaker than rung 2: it proves the gesture was *armed* with the right magnitude, not
that anything landed.

## 4. What is left, and it is one thing

**Duration.** Nothing headless renders a frame, so a wrong duration is invisible to every
gate in this project. `test/unit/test_placement.gd:5145` sweeps every plant tween's duration
argument and can only assert that it is a *named* constant rather than a literal — its own
failure message says the value is "invisible everywhere except a pair of eyes on the running
game".

So watch it run. `read-a-moving-value` owns how: `pause` **before** the tween is created,
then `step-time --seconds 0.03 --then-pause`. The cheaper `set-game-speed 0.05` also works
and is how the record roll was first seen moving — at 1.0 an 0.8 s roll finishes inside a
single bridge round-trip, which cost cycle 38 four attempts that saw only the final value.
Its scale is **positional**, not `--scale`.

## The counter-example is in the repo, and it has bitten twice

`Plant`'s planting pop sets `_sprite.scale = Vector2(0.4, 0.4)` at `game/plant.gd:425` and
makes the tween responsible for getting back to `Vector2.ONE` (`game/plant.gd:427`). It is
gated on `is_inside_tree()` only, not on `animations_enabled()` —
`test/unit/test_combat.gd:200` says so while explaining why a *different* test needs a real
tree. Both halves of the failure have been paid for:

- **Live**, cycle 110: `pause` froze the entrance and a 64 px plant was photographed as a
  20 px speck, which read as a broken sprite. `[G-127]`. Pause freezes a pop exactly the way
  it freezes a fade.
- **Headless**, still: the one test that reads a plant's sprite scale compares it against
  itself before and after (`test/unit/test_combat.gd:210`, `test/unit/test_combat.gd:215`)
  rather than against `Vector2.ONE`, because `Vector2.ONE` is not where it is.

Neither is a crisis. Both are the cost of an animation that owns its own destination.

## Three ways a check here passes while asserting nothing

- **Pumping the animation and reading what moved.** Everything past the gate is an early
  return, so the assertion is about the return. Cycle 71 wrote exactly that test for
  `Plant._wobble` and watched two mutations survive it — including one that pointed the idle
  breathe at `_sprite.scale`, the property five event tweens own. The fix was the pure
  `breathe_scale` (`game/plant.gd:544`). [[extract-a-testable-seam]] is the whole procedure.
- **Assertions expressed relative to the amplitude.** The same test survived
  `BREATHE_AMOUNT = 0.0`, because every claim in it was written *in terms of*
  `BREATHE_AMOUNT` and zeroing it left them all true. Pin at least one endpoint to a number.
- **Correct geometry that nothing can see.** Every rung above is about a *value*; a drawn
  animation also has a *composite*, and no property read reaches it. The Chomp's vines
  (`game/chomp_flower.gd`, cycle 175) shipped with `vine_curve` endpoints, phase boundaries
  and carry endpoints all asserted against pinned absolutes and all green — and at the first
  constants every vine, once the bug had landed, lived inside the 24 px the beetle sprite
  covers, so the whole chew showed a bug on a flower with nothing visibly holding it.
  `screenshot --region` was the only thing that could say so.

  So: **if the animation draws on a layer, one of your checks is a cropped screenshot, and
  it is not optional.** The tell that you need one is a drawn overlay whose target is
  *another sprite* — an outline, a tether, a grip, a highlight — because the thing that
  hides it is the sprite it is about, and that relationship exists in no number either
  object holds. Read [[palette-against-the-background]] for the same failure in colour.

## Two smaller things worth knowing

**A `create_tween()` census is the wrong set.** Cycle 70 closed a bead "verified unbuilt" by
enumerating call sites; `Plant._wobble` (`game/plant.gd:506`) and `Pest._gait` are
`_process`-driven sinusoids and had been animating since the first playable build. Grep for
what writes the property, not for what creates a Tween.

**A constant that describes the animation but nothing reads is decorative.**
`RATCHET_STEPS` is declared at `game/title_screen.gd:580` under a comment claiming it "is
what the roll actually shows" (`game/title_screen.gd:578`) — and it is read nowhere in the
repo. The stepping lives in `Hud.seeds_roll_value` instead, which is why the seeds roll can
assert its step count and the record roll cannot. If the shape is a claim, put it in the
renderer.

## Before writing "the animation is broken"

Three live misreads in one session (cycles 110–111), three distinct causes, none of which
produced a malformed reply: a modal covering the board, a paused tree freezing this pop at
0.4, and a hidden Label still holding its last text (`visible = false`, and "Holds 0s" read
three times running on a plant that had been eaten and freed). Ask
[[read-a-moving-value]]'s question first — *what was moving when I read it* — and add the
one this file exists for: **is what I am reading a state the tween was supposed to leave
behind, or one it was supposed to arrive at?**
