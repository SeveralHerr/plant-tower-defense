# Which HUD surfaces deserve corpus-style checking — plant-tower-defense-yoc2

`yoc2` asked for a written verdict per surface, and warned against defaulting either way.
Cycle 45 set the precedent by declining to build a checker *after measuring* that its
precision would be low (9 candidates, 1 real) and recording the measurement. This does the
same, and the measuring turned up a rule that answers the next surface too.

## The rule, which is the actual deliverable

**What a surface does when text overflows decides whether it needs a content corpus.**

| Overflow behaviour | Where the overflow goes | What catches it | Needs a corpus? |
|---|---|---|---|
| **Wraps** (`autowrap_mode`) | into HEIGHT | any clearance or stack-height gate, for free | only if no height gate exists |
| **Grows / pushes siblings** | into LAYOUT | a layout budget on the container | rarely |
| **Clips** (`clip_text` + `OVERRUN_TRIM_ELLIPSIS`) | **nowhere — it becomes an ellipsis** | **nothing** | **yes. this is the case.** |

A clipping label's height and its container's layout are *unchanged* by a string that no
longer fits. There is no second-order effect for an existing gate to notice. That is the
whole argument, and it is why "has not broken yet" means different things on different
surfaces: a wrapping surface that has not broken has been *tested by every layout gate
that ever ran*, and a clipping one has not been looked at.

### The corollary, and it is the sharp end

**`clip_text` is exactly what makes `Label.get_minimum_size()` report ~1 px** — it returns
the clip stub, not the text. So the obvious width assertion,
`assert_gte(label.size.x, label.get_minimum_size().x)`, **passes unconditionally on
precisely the labels that need checking**. The surfaces that most need a corpus are the
ones where a careless gate looks like it is already there.

The project already knows this and has applied the fix once, on the notebook's hints page
(`test_placement.gd:7193`, which uses `_T.text_width` and says why in a comment). It has
not been applied to the run summary.

## The verdict, per surface

### Message row — ALREADY COVERED, and it is the control case
Three checkers, because it broke three times. Nothing to decide. It is worth naming here
only as the reason the question exists: it is the surface where "has not broken yet" was
tested to destruction and found false.

### Stats row — COVERED. Do not build.
Two budgets, and between them both failure modes are held:
- `hud_readouts` walks `Hud.WORST_CASE_TEXT` and measures each declared worst case in the
  real theme font against its label's slot. **That IS the corpus pattern**, already applied.
- `hud_stats_row` prices the layout — child count, separations, the wave button — so a new
  child is noticed even if it is undeclared.

**Measured coverage: 4 labels in the live row (`SeedsLabel`, `WaveLabel`, `LivesLabel`,
`CompostLabel`), 4 keys in `WORST_CASE_TEXT`. Complete today.**

One real gap, and it is small enough not to justify a checker on its own: **every assertion
iterates `WORST_CASE_TEXT`, never the row**, so a readout added *without* a declared worst
case is not reported as uncovered. The reverse direction is handled — `_budget_hud_readouts`
appends `"%s: declared a worst case but is not in the row"`. What keeps the residual risk
low is that the layout budget notices the new child. Worth one assertion the next time
anyone is in that file; not worth a bead of its own.

### Selection panel — WAS the open question. Now measured, and it had already broken.
Closed this cycle by `r722`, and the result is the strongest evidence in this document.
The panel had "comments and one hand measurement" — the same standing as the run summary —
and when actually priced it came out at **0 px of vertical room**, with two detail lines
already past the 232 px box (`Regrowing — 3/3 fluff, armed in 4.9s.` at 266 px; the Chomp's
chew at 252 px).

So for one of the three surfaces the question is answered empirically: **"has not broken
yet" was nobody looking.** It was already over, and it stayed quiet because the panel
*wraps* — the overflow went into height, where nothing was measuring.

### Run summary — BUILD IT. This is the one.
`run_summary.gd` sets `clip_text = true` and `OVERRUN_TRIM_ELLIPSIS` on its title, its note
and its value labels (lines 974-975, 986-987, 1127-1128). Applying the rule above:

1. A too-long value **clips to an ellipsis**. It does not wrap.
2. Because it does not wrap, `label.size.y` does not change.
3. The only gate on this surface is `BUTTON_CLEARANCE`, which compares
   `label.position.y + label.size.y` against the replay button. **It reads a height that a
   content regression cannot move**, so it is structurally incapable of firing on one.
4. **Zero width assertions exist on the run summary's `Value_*` labels** — confirmed by
   grep across all three suite files.

That is `yoc2`'s own build condition met exactly: *"Only build where the answer is 'nothing
would notice'."* Nothing would notice.

**This verdict is the justification `wf4i` ("Give the run summary the corpus pattern") should
cite.** Two notes for whoever takes it:
- Use `_T.text_width(label)`, never `get_minimum_size()`, for the reason in the corollary
  above. The hints-page test is the worked example.
- One label already autowraps (`run_summary.gd:1082`). Under the rule, that one is the
  clearance gate's business and does not need corpus entry — check whether including it
  makes the corpus report a worst case that cannot occur, which is `rd9s`'s subject.

## What this says about the other twelve beads in this group

The `ox1p` grouping found "width budgets & the corpus pattern" is 15 of 90 open beads — the
largest group by half again, and five of them are beads *about* the technique rather than
applications of it. The rule above is a stopping condition for the applications: **a surface
earns a corpus when it clips, and does not when it wraps or pushes.** That is checkable in
one grep (`clip_text` in the surface's file) rather than by judgement, and it means the
remaining application beads can be triaged rather than each one re-arguing from scratch.
