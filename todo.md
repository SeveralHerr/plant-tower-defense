# todo

**Cycle 27 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 26 shipped all five items across three parallel worktree agents: `14w` (a
> Sunflower payout now rings and flies a glyph like a swept husk), `aho` (the wave
> button and the plant bar answer a press), `9zn` (the seven — now eight — keyboard
> verbs moved onto a real `InputMap`, plus a Keys screen on the title that rebinds
> and persists them), `4qi` (seven milestones, evaluated at `_end_run` and shown on
> a ribbon beside the results card), and `xu0` (a colourblind-safe blue/orange ramp
> for the health and threat bars).
>
> **The merge was the interesting part.** Two agents independently minted a
> `SAVE_VERSION = 3` meaning different things by line 4 — one the key bindings, one
> the milestones — and one went on to a 4. Both spotted it and flagged it rather
> than guessing, which is the only reason it was a merge decision instead of a
> corrupted save. Reconciled to a single **v5**: header, campaign, endless,
> milestones, options, then the binding count and rows last (a variable-length block
> in the middle moves every field under it). v3/v4 are refused on sight and
> quarantined rather than disambiguated. The colourblind toggle was also folded into
> the InputMap as a real rebindable action instead of the raw scancode check it
> arrived as. Two defects surfaced doing that, neither from either branch: the
> eighth verb overflowed the Keys screen (rows footing exactly where the footer
> starts), and a v4 refusal test kept passing for the wrong reason once v4 became
> refused wholesale. 475/475 tests, live save round-trip confirmed on disk.
>
> Three new ideas went into `kanban.md`'s cycle 26 block, all grown from what this
> cycle just built; this cycle's items are those three plus the follow-up bug an
> agent filed against its own work.

## Items

- [ ] **ac0 — The Keys screen is unreachable from inside a run.** `KeysButton` lives
  on the title screen only; `pause_screen.gd` never mentions `KeyBindingScreen`. The
  player who most wants to move a key is the one who just pressed the wrong one
  mid-run. Note `PauseScreen.card_rect()` derives its height from its contents and
  the card already has five buttons — decide what gives rather than adding a sixth
  blindly.

- [ ] **qar — An earned milestone is announced once and then has nowhere to live.**
  `RunSummary.new_milestones()` shows only what the run *just* earned; a milestone
  from three runs ago is persisted in `RunConfig.earned_milestones` and never
  visible again. `has_milestone()` is public and called by nothing outside the
  save's own tests.

- [ ] **lgv — Every persisted option is reachable by one keystroke and no menu.**
  The Keys screen can rebind `garden_colorblind` / `garden_mute_sfx` /
  `garden_mute_music` but cannot *set* what they toggle — so the configuration
  screen is the one place you cannot see whether the colourblind bars are on.

- [ ] **b6v — The in-world plant health bar is a third red-lerp bar the colourblind
  option does not reach.** `Plant.HEALTH_BAR_HURT` is `GardenTheme.DANGER` and
  `xu0` only routed the two `hud.gd` sites through the switch. Filed by the agent
  that shipped `xu0`, against its own work.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
