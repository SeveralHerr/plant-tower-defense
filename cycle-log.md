# Cycle 42

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 42 taught

**A glyph is a word, and this game speaks two vocabularies.** The armed reset now marks the
rows it will take back, in two channels — a mark and a `DANGER` tint, because a tint alone
is what `colorblind_safe` exists to make unreliable, and this project already hatches its
lane overlay and notches its regrow bars for the same reason.

The first mark was `←`. It is proven in this font and reads as "going back", and
`KeyBindings.SHORT_NAMES` renders `KEY_LEFT` as **that same glyph** — so the pager's own row
is a key literally named `←`, and a moved one would have read `← ←`. The headless test
asserts `KEY_REVERT_MARK` generically and passes whatever it is; only the screenshot showed
it. It is a bullet now, which is not a keycode string in any build.

**And widening the panel exposed a defect several cycles older than this change.**
`findings` reported 12 `interactive_overlap` pairs. The overlap is a symptom: with an
overlay open, `Button_corn_cobbler` reads `focus_mode: 2, disabled: false` — **the HUD stays
focusable behind any overlay.** The backdrop blocks the mouse; focus is a separate channel,
which is precisely what `OverlayScreen`'s own header says `_set_card_active` exists for, and
nothing does it for the HUD's CanvasLayer. At the old panel width the overlap was ~6px and
went unreported. *The defect did not change — only its visibility did.* Filed as
`plant-tower-defense-csrc` and deliberately **not** baselined, so it keeps gating.

That is the argument for a zero-config sweep: I never asked `findings` about focus, or
overlays, or the HUD.

## Where things stand

Twenty-five beads ready, one of them a P2 bug (`-csrc`) that `findings` will keep reporting
until it lands — correctly. Suite 551/551 with 12096 assertions; lint 0/0; mirror identical;
gap ledger clean; the real save's md5 unchanged for the sixth consecutive session. Eight
skills, backlog empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. **`findings` is currently
non-clean on purpose** — 12 `interactive_overlap` pairs, all symptoms of `-csrc`. Fix that
bug before treating a dirty `findings` as new.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings. Bump the number at the top of
this file every time you refill.
