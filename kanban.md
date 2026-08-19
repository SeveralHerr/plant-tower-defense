# Plant Tower Defense — Kanban

The design brief is `image1.jpg`–`image6.jpg` (hand-drawn). Canonical task state
lives in **beads** (`bd list`); this board is the readable view of it plus the
idea backlog that isn't filed yet.

> "I want it to be a tower defence game. Plants fight bugs. You get one free
> plant to start with, some aren't free. You have to buy plant seeds to get plants."

---

## Done

Audited and pruned at cycle 108 (`plant-tower-defense-tkdz`). Every row below shipped
**and** is held there by a named test — the pair is the point. A Done line with nothing
asserting it is a claim, not a fact, and the one entry that turned out to be exactly that
has gone back to the backlog instead of staying here. The prose each row used to carry is
in the commit it cites; this is the index, not the record.

| Shipped | Commit | Beads | Held by |
|---|---|---|---|
| Style contract measured out of the kit, not guessed — 64x64, up-screen facing, outline a darker shade of the fill, 32-colour palette | `fe45397` | `-udz` | `tools/svg_style_check.py` cross-reads `art_src/STYLE.md`'s palette table; `test_every_colour_is_kit_palette_or_a_blend_of_two` |
| First sprite set — SVG sources in `art_src/`, rasterised 1x and 2x by `tools/render_svg.gd` | `fe45397` | — | `test_every_svg_source_is_declared`, `test_no_rendered_png_is_an_orphan`, `test_rendered_png_matches_its_svg_source_size` |
| The contract is a gate — six ways a sprite can drift | `fe45397` | — | one test each: `test_sprites_are_square_and_kit_sized`, `test_retina_is_exactly_double`, `test_sprites_actually_drew_something`, `test_content_is_bilaterally_centred`, `test_content_stays_inside_the_canvas`, `test_every_colour_is_kit_palette_or_a_blend_of_two` |
| Kenney kit vendored — 299 PNGs, tilesheet, CC0 (`assets/kenney/License.txt:9`) | `fe45397` | — | `test_every_grass_cell_has_a_tile_the_kit_actually_ships` |
| The game is playable end to end — 14x9 board (`game/board.gd:15`), both plants, both pests, eight waves, seeds, packets, upgrades, uproot, win and lose | `fe45397` | `-iks`, `-95o`, `-cv3`, `-el9`, `-wn0`, `-1e9` | most of `test/unit/`; entry and exit pinned by `test_route_covers_every_path_cell_plus_an_entry_and_an_exit` |
| Road tiles derived from the kit, not eyeballed — `Board.GRASS_EDGE_TILE` | `fe45397` | — | `test_every_grass_cell_has_a_tile_the_kit_actually_ships`, plus the reverse check at `test/unit/test_board.gd:128` that no dead mask survives |
| Selection, the range ring it unlocked, and the Chomp's shrinking chew ring | `6016294` | `-how`, `-x7h` | `test_a_chomp_flowers_selection_marker_shows_even_though_it_owns_draw` |
| Sprite pass 2, pest mutations, packet tiers + Sunflower, compost meter, title screen + endless, Designer's Notebook | `628f799` | `-eeq`, `-5fu`, `-b5k`, `-d0w`, `-e0w`, `-1qo` | `test_a_killed_pest_shows_a_dead_sprite_and_lingers_before_freeing`, `test_an_armoured_pest_takes_twice_as_long_to_chew`, `test_a_winged_pest_flies_over_a_chomps_reach`, `test_a_hungry_pest_eventually_destroys_the_plant_it_eats`, `test_a_common_packet_never_rolls_above_its_tier_cap`, `test_a_sunflower_grows_seeds_once_its_interval_elapses`, `test_an_uncollected_husk_rots_away`, `test_each_mode_reports_its_own_best`, `test_no_two_notebook_pages_show_the_same_drawing` |
| SelectionMarker as its own node; lane pressure; husk value by mutation; endless mutates faster; second bite frame | `8e6f2e7`, `ca7b163`, `86fa345`, `6ef0972`, `88f507f` | `-42t`, `-4wv`, `-1rh`, `-1qi`, `-rrx` | `test_a_sunflowers_selection_marker_is_shared_from_the_base_plant_class`, `test_lane_pressure_is_committed_even_when_the_last_life_is_lost_mid_wave`, `test_each_mutation_has_a_husk_multiplier_above_one`, `test_endless_still_gets_harder_after_every_per_pest_scale_has_capped`, `test_the_late_bite_frame_is_showing_by_the_time_any_chew_finishes` |
| Husk size/glow by value; endless scales the pests themselves; lane pressure as a distribution; placement preview | `7450fc6`, `5e1af7a`, `3a607bf`, `83f0bc7` | `-afd`, `-nps`, `-j1h`, `-rfh` | `test_a_richer_husk_draws_bigger_than_a_poorer_one`, `test_the_biggest_husk_still_fits_inside_its_own_click_radius`, `test_a_pest_spawned_deep_in_endless_is_tougher_than_a_wave_one_pest`, `test_a_single_loss_in_a_huge_wave_is_still_visible`, `test_the_placement_preview_is_a_selection_marker` |
| HUD top bar as a container; richer husks rot faster; readable threat level; unfaded per-run lane pressure; hungry-pest warning | `780eeac`, `792cc5e`, `10176a6`, `3d61206`, `0863707` | `-kcj`, `-kh9`, `-o1p`, `-dbg`, `-8bb` | `test_no_two_top_bar_controls_share_pixels`, `test_the_stats_row_budget_fits_the_bar`, `test_size_glow_and_urgency_all_agree_about_which_husk_is_rich`, `test_the_threat_level_stays_a_small_readable_number`, `test_the_run_depth_is_weighted_by_losses_not_by_lit_cells`, `test_a_sunflower_away_from_the_road_is_not_flagged` |

Three things the audit turned up that deleting the prose quietly would have buried:

- **Done had gone stale about itself, twice, and both times against its own next entry.**
  The first-session row said "`game/game.tscn` is the main scene"; `project.godot:14` reads
  `run/main_scene="uid://ce2dtga2f08e"`, which is `game/title.tscn` — changed by an entry
  four rows further down that nobody reconciled upward. Same shape for compost: a flat 10s
  husk lifetime became a ceiling five rows later, and both numbers are live today
  (`game/compost_meter.gd:28` is `HUSK_LIFETIME` 10.0, `:62` is `MIN_HUSK_LIFETIME` 4.5). A
  Done section long enough to contradict itself is the whole argument for pruning it.
- **The eight devtools verbs were never really done.** Only one of the eight is asserted by
  anything. Returned to the backlog below rather than deleted, because "shipped" and "held
  there" are different claims and only the second one keeps.
- **Harness gaps G-012 through G-019 were duplicated here from `log-devtools.md`**, which is
  the file that actually reconciles them against a harness version. Dropped from this copy;
  nothing was lost.

## Next up

**`bd ready`.** That is the whole answer, and it is the only one that cannot go stale.

This section used to name five specific beads and said "**Cycle 3 of 30** is filed and
ready". Audited at cycle 103: all five (`-zr4`, `-5zc`, `-cw1`, `-cuk`, `-gqs`) are
CLOSED, the counter was a hundred cycles out, and it pointed at `todo.md` — a file the
loop stopped reading long ago, because keeping it wrote every item twice and ticked it
twice. It was the first thing anyone opening this file read, and every claim in it was
dead. Deleted rather than refreshed: a hand-copied queue at the top of a document is the
exact drift `bd` exists to end, so replacing the five names with five newer names would
have rebuilt the same trap.

---

## Cool new features (idea backlog)

### Returned from Done — audited cycle 108 (`plant-tower-defense-tkdz`)

- **The project's own devtools verbs are the least-tested code in the repo, and they are
  what every runtime claim is read through.** `devtools_ext/commands.gd:19-38` registers
  thirteen verbs and one status provider. Exactly three are asserted by anything:
  `board_info` (`test_board_info_prints_the_husk_click_budget_as_a_subtraction`), `budgets`
  (`test/unit/test_economy.gd:2123` and two sites in `test_placement.gd`) and
  `project_identity` (`test_project_identity_returns_the_three_key_envelope`,
  `test_project_identity_is_registered_with_a_literal_name`). The mechanism searched was
  both spellings a test could use — the registered name as a literal (`"place_plant"`) and
  the handler symbol (`_cmd_place_plant`) — across all of `test/`; `game_state`,
  `place_plant`, `spawn_pest`, `add_seeds`, `start_wave`, `buy_packet`, `upgrade_plant`,
  `compost_state` and `collect_husk` return **zero hits for either**, and nothing calls
  `_status` directly. This sat in Done for a hundred cycles reading like finished work.
  The distinction that matters: an unasserted verb does not fail loudly, it answers a
  well-formed lie, and the reply is then quoted into a verify ledger row as evidence.
  Cheap to close and the pattern already exists — `_board_info(game)` in
  `test/unit/test_placement.gd:2808-2812` instantiates the extension directly, points
  `ext._dev` at a hosted `Game`, and calls the handler as a pure function with no bus and
  no running game. Nine more of those is an afternoon.
  - The narrow version, if the full sweep is too much: assert the **envelope** for all
    thirteen in one loop — every handler returns exactly `{success, message, data}` with
    those three keys and nothing else. `test_project_identity_returns_the_three_key_envelope`
    already asserts it for one; the same three lines over a list of handlers catches the
    class of defect that makes a reply unparseable, without needing per-verb semantics.

### Added cycle 106 — out of a screenshot James sent

- **The playfield is CENTRED in a wide window, not SCALED to fill it, and that is a
  decision worth revisiting rather than a finished answer.** The board is a fixed 14×9 grid
  of 64px cells — 896×576 — so on a 1387-wide canvas it now sits centred with 117px of
  grass-coloured nothing either side (`Game._apply_board_layout`). Centring was the safe
  fix and it looks deliberate. Scaling would fill the window properly, and it is the
  bigger, riskier change: every reach is in pixels (`CornCobbler.RANGE`, `Mint.REACH`,
  `Aloe.REACH`, `StickySundew.SAP_RADIUS`), `Board.CELL` is an `int` that a dozen things
  divide by, and `world_to_cell` floors a pixel position. A scale factor touches all of it.
  Taste call: on a very wide monitor the centred board reads as a window rather than as a
  game, and that is worth paying for eventually.
- **More board is the other answer to the same problem, and it is more interesting.** A
  wider window could show MORE GARDEN rather than a bigger one — `Board.COLS`/`ROWS` are
  constants and the road is generated, so a wider board is a level-design question rather
  than a rendering one. It would also change the game, which is the point: the fixed 14×9
  is the reason a plant's reach means the same thing in every run.
- **Two bugs were stacked and fixing the first exposed the second.** Before cycle 105 the
  side panel sat at a hardcoded `1152 - PANEL_WIDTH` and the board at `x = 0`; both were
  wrong and they hid each other, because the panel's error happened to sit exactly where
  the board's gutter would have been. Worth remembering when a layout looks right at one
  size: agreeing at the design size is not evidence of anything.
- **A guard that mixes coordinate spaces is invisible until something moves.** `_click_at`
  compared an absolute `screen_pos.x` against a board-LOCAL width and was correct for
  exactly as long as the board started at x=0. Nothing in the suite could have caught it,
  because every test hosted the board at the origin — which is
  `godot-2d-placement-audit`'s central claim, arriving on this project for the second time.

### Added cycle 105 — out of the eighth plant and the live viewport

- **The roster has ONE genuinely uncovered role left that needs no pathing work: husks.**
  Cycle 104 verified three were open — blocks the road, heals, uses husks — and the Salve
  Aloe took the healing one. `husk_layer.gd` is still read only by the compost sweep, so a
  plant that auto-composts husks in its reach is a new economy role that is not the
  Sunflower's clock, and it needs no answer to "what does a pest do when its path is
  occupied". That makes it the cheap ninth plant and the road-blocker the expensive one.
- **The ninth plant is already funded and the tenth is the two-row day.** `PLANT_SCALE`
  dropped 1.7 → 1.5 to fit an eighth slot on the title lawn, which puts four 96px canvases
  in each 426px band with 42px to spare. `TitleScreen.PLANT_X`'s header carries the
  arithmetic. Worth knowing before anyone designs a tenth: five 96px canvases need 480 in a
  426px band, so there is no third trick.
- **The Aloe makes a "repair between waves" loop possible that nothing yet closes.** Damage
  is no longer permanent, but nothing tells the player a plant is damaged unless they select
  it — the health bar is per-plant and only drawn under attack. A garden-wide "3 plants
  hurt" cue, or a between-waves summary line, would turn the Aloe from a thing you own into
  a thing you place deliberately. Taste call: the prep gap is the moment, and the message
  row is already priced.
- **The whole HUD now re-lays-out on resize, and nothing else does.** `game/hud.gd` reads
  the live viewport; `game/title_screen.gd` and `game/overlay_screen.gd` each still declare
  their OWN `get_viewport_width()` reading `ProjectSettings`. Filed as `-nrup`, and the
  interesting half is that there are three copies of one method rather than two more bugs.
- **`stretch/aspect="expand"` is load-bearing and now has exactly one test holding it.**
  The stats-row width budget is only safe because `expand` gives the canvas a hard width
  floor of the design size; below it the failure is silent, because `Control.size` clamps UP
  to the container's minimum and the wave button simply lands off-screen with nothing
  reporting it. Anyone who changes that project setting should expect a red test, and should
  read why before changing it anyway.

### Added cycle 104 — out of four lanes and an absence sweep

- **Three roster roles are genuinely uncovered, and two that `-ibvb` lists are not.**
  Re-checked rather than inherited: nothing blocks or holds the road (`grep -rln
  "blocks_road\|is_wall\|impassable" game/*.gd` returns nothing), no plant heals another
  (the only `.heal(` on a plant is `game/game.gd:370`, the rain weather effect), and husks
  are still read only by the compost sweep. The bead's other two — buffs neighbours, hits
  only mutations — shipped as Mint and Nettle, whose own class headers say so. A blocker
  plant is the interesting one: placement geometry currently only decides reach and lane
  coverage, and a plant that contests a road cell would make the road itself a resource.
- **The run summary is now the place strategy gets said, and it has exactly one free
  subject.** `-bou9` put "Seeds spent — 275 on plants, 0 on upgrades" on the card by
  SWAPPING out "Threat reached" (folded onto the waves row), because `rows_capacity()`
  computes 7 and there were 7. Any future card subject is another swap. Worth deciding
  what the seven are *for* before the next one is filed, rather than discovering the
  ceiling again — the eighth row foots at 486 against buttons at 476.
- **Four `show_message` sites are edge-triggered only by an explicit latch.**
  `docs/message_trigger_audit.md` classifies all 17; the four at `game.gd:453`, `:1333`,
  `:1611` and the packet-reveal loop are edge ONLY because `_wave_live`, `_flight_noted`,
  `_uproot_left` and a bounded loop each latch them. Nothing marks them as load-bearing,
  and any refactor that moves one turns a level-triggered caller loose on the message
  queue. A comment at each, or a test naming the latch, is cheap insurance.
- **`Hud.messages_refused` and `messages_evicted` are readable and nobody reads them.**
  They exist precisely to answer "is the row dropping lines a player was owed", and the
  only measurement of them is now a headless test. A `cmd budgets`-style verb or a line on
  the run summary would make the row's real loss rate visible during an actual playtest,
  which is the only place it can be judged.

### Added cycle 103 — out of the upgrade hint

- **The hint teaches that upgrading EXISTS. It does not teach that upgrading BEATS
  breadth, which is what the A/B actually measured.** `RunConfig.HINTS`
  (`game/run_config.gd:162`) now has three entries and the third fires the first time the
  player can afford the cheapest upgrade on their own board — so they are told the button
  is there. Cycle 101's two campaigns differed on where surplus seeds WENT, not on whether
  the player knew where they could go: breadth-first died at wave 10 having never upgraded,
  depth-first won 22 waves losing no lives. A player told "you can upgrade this" may still
  spend the seeds on an eighth plant, which is exactly what the losing run did. Honest
  taste call: one sentence cannot carry a strategy, and a second hint that tries to would
  be the tutorial `-qoil` refused. The place to say it is the run summary, below.
- **The run summary never mentions upgrading, and it is the one screen that could teach the
  lesson without spending the message row.** `game/run_summary.gd` contains no reference to
  plant upgrades at all — its only two `level` matches are `threat_level` (`:258`) and a
  layout comment (`:84`). The card is already the moment a player asks "why did that go
  wrong", it has room a live HUD does not, and the run's own numbers are right there. A row
  reading how many upgrades were bought against how many plants were placed would let a
  breadth-first player see their own policy stated back to them. This is where the A/B
  belongs.
- **`Hud.row_is_quiet()` (`game/hud.gd:1881`) is now a general capability and only one
  caller uses it.** It exists because `show_message` returns false on a busy row but QUEUES
  the text, so a LEVEL-triggered caller stacks copies — true of any cue driven off
  `_refresh` rather than off an event. Worth a sweep: which other advisory lines are posted
  from a funnel rather than an edge, and are any of them quietly queueing duplicates today?
  The two counters `messages_refused` and `messages_evicted` already exist to be read with
  `get-state`, so the question is answerable without guessing.

### Added cycle 102 — out of the five-lane fan-out

- **A second Chomp jaw frame, so the bite has a shape and not just a direction.**
  `_bite()` now lunges the whole sprite 7px at the pest (`ChompFlower.LUNGE_DISTANCE`,
  `game/chomp_flower.gd`) on top of the existing squash, and it reads as an attack — but
  the *sprite* is one picture throughout. The eating textures already exist and already
  swap (`_show_eating_sprite`, and `art_src/chomp_flower_eating.svg` /
  `chomp_flower_eating_late.svg` are two of the three chomp SVGs), so the machinery for a
  frame swap is built; what is missing is an open-jaw frame at the moment of the bite
  rather than during the chew. Cost is one SVG plus one `EXPECTED_SIZE` row in
  `test/unit/test_sprite_style.gd`. Deferred out of the v104 lane deliberately: a lane in
  a worktree cannot run the import pass a new asset needs.
- **An "N left" count on a seed packet, once the rack has width for it.** A spent tier now
  reads `Common — Empty` (`Hud.packet_button_text`), which answers "can I buy this again"
  — but not "is this the last one". `SeedBank.packet_pool(tier).size()` is the number and
  it is already computed at refresh time, so this is purely a layout problem: the packet
  row is 232px, the icon and margins take ~50, and `Common Packet (20)` alone measures
  99px for eleven characters. It needs either a second line, a floating pip over the rack,
  or the shorter name the spent state already uses (`display.trim_suffix(" Packet")`).
- **The top bar's caption/value split, which is blocked rather than expensive.** 7mj3
  shipped ruled lines and paper buttons but not the smaller-muted-caption /
  larger-bright-value hierarchy, because a caption Label nested inside its value Label
  overlaps it and fails `test_no_two_top_bar_controls_share_pixels` (`_hud_rects` recurses
  through `find_children`), and it cannot be nested in a per-stat HBox either because four
  test files address `Root/TopBar/StatsRow/<Name>` directly. Interleaving captions as row
  siblings costs about 240px and the row has 38. So this is a layout change with a
  test-fixture change under it, not a styling pass — worth doing, worth filing honestly.
- **Weather that is not only rain.** Rain now falls (`_rain_phase` advances in
  `WeatherOverlay._process`, gated on `GardenTheme.animations_enabled()`); drought
  deliberately stays a still frame, and the file argues that "rain moves, drought does not"
  is itself a channel alongside hue and mark shape. That argument is sound for two
  weathers and gets thinner with a third — if a fourth weather ever lands, the motion
  channel needs a real grammar rather than one exception.
- **A speed control that survives the run.** `GameSpeed` cycles 1x/2x/½x and parks at 1x
  for the pause card (`hold()`/`release()`), and resets on `_end_run` and `_exit_tree`.
  What it does not do is remember the player's choice between runs — `RunConfig` persists
  audio mutes and key bindings already, so the mechanism is there. Taste call: someone who
  plays at 2x almost certainly wants 2x next time.

### Requested directly by James — not grown, asked for

**All four bullets audited as of cycle 76, and three of the four were substantially
wrong.** One shipped entirely (facing), one shipped in every clause (the dandelion), one
had two of three factual claims false (waves and bosses), and the fourth was corrected in
cycle 71 (animation). **This is the least accurate section in the file**, and the reason is
structural rather than careless: these are the only entries nobody re-reads while working,
because they were written once, by hand, about a game that then changed underneath them —
every other section is at least revisited when its neighbourhood is worked.
*(The cycle-76 commit message says "four of five bullets"; there are four, and all four are
done. Counted afterwards, which is the same mistake the audit was about.)*

- **Animate all the plants and enemies.** The ask: idle motion — sway, breathe,
  twitch — on every plant and pest, not just reaction poses for the moments the game
  already hooks.
  **CORRECTED (cycle 71). The description below this line used to say "every plant
  and pest currently reads as mostly static art with a handful of one-off tweens
  bolted on for specific events", and that has been false since the first playable
  build.** `Plant._wobble` (`game/plant.gd:351`) rocks every planted bed off a
  per-cell phase, and `Pest._gait` (`game/pest.gd:733`) gives every pest a walk cycle
  with a side-to-side swing, a body stretch at twice the rate, and a per-instance
  phase. Both are `_process`-driven sinusoids, which is why a census of
  `create_tween()` calls — the check that produced the wrong "verified unbuilt" —
  could not see either of them. **An enumeration over the wrong set is worse than an
  example, because it looks exhaustive.**
  What was genuinely missing was one channel: a plant rotated and nothing else, while
  a pest rotated *and* stretched, and it is the stretch that stops a walking bug
  reading as a rigid sprite being turned. Shipped in cycle 71 as
  `Plant.breathe_scale` on a `Sway` pivot — a separate node because `_sprite.scale`
  already has five event owners that all tween back to `Vector2.ONE`.
  **What is still open under this heading** is the third word of the ask, *twitch*:
  every idle motion in the game is a continuous sinusoid, so nothing is ever
  startled, surprised, or briefly out of rhythm. A Chomp with a full mouth
  (`game/chomp_flower.gd:83`) and a plant being eaten (`game/plant.gd`'s `_quiet_time`
  regrowth clock) both know something a sway does not.
- **More waves, and bosses.** The ask: real additional waves in the table, and at least
  one boss pest — bigger health pool, a distinct sprite, a mechanic that isn't just
  "armoured but more".
  **AUDITED (cycle 76): DRIFTED — two of the three factual claims are false.** The
  description used to open "the wave table currently ends at 8 fixed waves before endless
  mode takes over with escalating mutation chance on the same two pests, and there is no
  boss". `WaveDirector.WAVES` (`game/wave_director.gd:164`) holds **16** entries, not 8 —
  the file's own prose treats wave 16 as a deliberately sized landing point. And a boss
  mechanic ships: `WaveDirector.wave_carries_boss()` (`:319`) feeds the HUD's prep note,
  and the mechanic itself is documented at `game/game.gd:796` — a pest whose species names
  a split bursts into that many.
  **What holds** is the two-species part: `Pest` still declares only `APHID` and `BEETLE`
  (`game/pest.gd:16-17`).
  **What is genuinely unbuilt** is narrower than the bullet reads, and it is the half the
  ask cared about visually: the boss is the **same `Pest` object**, said outright at
  `game/game.gd:767`. So "a mechanic that isn't just armoured but more" shipped, and
  "bigger health pool, a distinct sprite" did not. That is one bead, not three.
- **An animated dandelion plant that blows its seeds as bombs**, in an "epic" seed packet
  tier above the common/rare split — the head visibly losing fluff as it fires, seeds
  arcing and detonating rather than travelling like a kernel or a bite.
  **AUDITED (cycle 76): SHIPPED, every clause.** The epic tier exists at cost 90
  (`game/seed_bank.gd:41`) and is third in `PACKET_ORDER` (`:52`). The head wears one of
  four authored frames indexed straight off `_fluff` (`game/dandelion.gd:107`, with
  `FLUFF_MAX` 3 at `:65`), so the picture cannot disagree with the ammunition. The seed
  arcs on a real parabola — `SeedBomb.ARC_HEIGHT` 44 through zero at both ends
  (`game/seed_bomb.gd:46`, `:160-162`) — and detonates in a radius rather than colliding
  (`BLAST_RADIUS` 46 at `:51`, `has_detonated()` at `:141`). Kept here rather than moved
  to Done because this section is a record of what was **asked for**, and an ask whose
  outcome is written beside it is more useful to a reader than an ask that vanished.
  No test coverage claim is made here; that was not checked.
- **Fix enemy facing direction.** Pests should visually face the way they walk; the art
  style doc calls out up-screen facing as the convention.
  **AUDITED (cycle 76): SHIPPED.** `Pest._update_facing` (`game/pest.gd:708-717`) picks the
  dominant axis and maps all four cardinals onto the up-screen convention, and `_gait`
  composes the walk cycle's sway on top of `_facing` rather than replacing it, so a bug
  leaning into a step still faces where it is going.

### New this cycle (101) — the campaign was played, and it has exactly one difficulty event

- **Nothing in the game teaches upgrading, and upgrading is the whole campaign.** Two full
  playthroughs, same seed economy, same unlocks (all seven plants by wave 7 in both), differing
  in one policy bit: spend surplus on NEW plants, or on the plants already down. Breadth-first
  reached eleven level-1 plants and was dead at wave 10. Depth-first won all 22 waves **without
  losing a single life** (591 pests, ending on 1129 spare seeds). The affordance is a button
  that only exists while a placed plant is selected (`game/hud.gd:806-811`, made visible at
  `:1234`), and nothing ever suggests selecting one. I searched for the BEHAVIOUR — "the game
  tells the player upgrading exists" — across three mechanisms rather than one: `milestones.gd`
  (no entry mentions upgrades or levels), all twenty `show_message` call sites in `game/game.gd`
  (only `:1321` "That upgrade costs N seeds", a refusal after you already tried, and `:1331`, a
  confirmation after you succeeded), and the notebook (`game/notebook_screen.gd:296-297`, one
  caption, in a screen the player must go and open). The opening tutorial line
  (`game/game.gd:273`) teaches placing and starting waves and stops there. So every mention of
  the mechanic that decides the run is either a reply to a player who already found it, or
  optional reading.

- **The back half of the campaign does not escalate.** Derived from all 22 rows through
  `WaveDirector._raw_threat` (`game/wave_director.gd:755`), not sampled: waves 9-22 step between
  **+2.0% and +13.6%** in threat, averaging about +6%, while waves 2-7 step +15% to +80%. The
  reason is structural rather than a matter of table-writing taste — `health_scale_for`
  (`:850`) returns exactly 1.0 for every campaign wave and `mutation_chance_for` (`:840`)
  returns a flat constant, both by an `over <= 0` early return, so the entire escalation
  machinery is endless-only **by construction**. Inside the campaign, difficulty IS the table,
  and the table plateaus at 26-37 pests from wave 8 to the finale.

- **The seed economy runs away once the wave-8 wall is behind you.** Measured across the winning
  run's own rows, banked seeds at each wave boundary: 51 (w12), 106 (w14), 139 (w16), 857 (w18),
  1129 (w22). It ended holding more seeds than the 41 plants on its board had cost, with nothing
  to spend them on. The first seven waves are the opposite — `low_seeds` bottomed at 0, 1, 1, 3
  and 4 on five separate waves. So the game is broke exactly while decisions matter and rich
  exactly when they do not.

- **591 kills produced 591 husks and not one was banked.** Every kill drops one
  (`game/game.gd:893`) and they live 4.5-10s on a value-scaled ramp (`HUSK_LIFETIME` and
  `MIN_HUSK_LIFETIME`, `game/compost_meter.gd:28,34`), with no auto-collect anywhere.
  **The honest caveat, and it is the whole entry:** my driver only swept between waves, so every
  husk had rotted before it looked. This measures a driver, not a player — a human clicking
  during combat would bank some unknown fraction. What it does establish is the shape: the
  compost system pays out only to a player dividing attention between the lanes and the litter,
  and nothing in the run reports what was left to rot. A human playtest is the only thing that
  can price it.

### New this cycle (100) — three lanes at once, and five failures in the seams

- **Every failure the parallel run produced lived in a seam no agent could see.** Three
  agents shipped a campaign, a pest and a plant; each ran all eleven parallel-safe checkers
  clean in its own lane; and the merge failed **five** times. The campaign's growth broke a
  golden headcount array and a hardcoded endless wave pair in another lane's file. The
  Nettle's `engages: true` tripped a deliberate "a new plant must be decided about here" gate
  asserting exactly three engaging plants. Its placement test funded a purchase but never
  unlocked the plant. Its notebook note ran 419 characters against a 300-char budget.
  **None of these is a mistake by the agent that caused it** — each is a fact about a file it
  was correctly forbidden to touch. So the parent pass is not a formality or a review step;
  it is where the parallel work actually integrates, and its cost scales with the number of
  lanes rather than with the size of any one of them. Worth knowing before adding a fourth.
- **A magic number derived from a constant outlives the constant, and reads as deliberate.**
  The endless ramp test priced waves `[60, 100, 137, 250, 499]` and its docstring said "past
  wave 48". Both were correct when `WAVES.size()` was 16 and both silently wrong at 22,
  because every endless landmark keys off `wave - WAVES.size()` — wave 60 simply stopped
  being past the speed cap. Nothing marked those numbers as derived; they looked like
  chosen sample points.
  The fix was to **find** the first wave where all three multipliers have pinned rather than
  to move the numbers, and the general form is worth the entry: **a constant computed from
  another constant should either be computed at read time or say in one clause what it was
  computed from.** `kanban-idea-pass` already requires that of prose claims; this is the same
  rule for a literal in a test.

### New this cycle (99) — three cycles divided the bar; none changed what was in it

- **The plant bar was never a layout problem.** 232px divided by two is 114, and a button
  carrying an icon plus a name measured **195**. Three separate attempts across three cycles
  tried to make two columns fit by dividing the bar differently — and `hud.gd`'s header was
  right every time that it could not be rendered. What none of them did was change what had
  to fit inside it. Taking the NAME off took the minimum from **195x31 to 8x8**, and six
  plants now sit in two columns of three with room for four more.
  The general shape is worth more than the fix: **when a container cannot hold its contents,
  the arithmetic has two sides and only one of them is usually examined.** Every note in
  `hud.gd` about this bar is about pixels available; none was about pixels required, and the
  required side was the one that moved.
- **The side effect was better than the fix.** Icons went from 32px to 69px, and the bar now
  reads as a seed-packet tray rather than a list of labelled rows — which is the design
  brief's own framing ("You have to buy plant seeds to get plants") and what this genre does
  with a growing roster. The name lives in the tooltip and on the selection panel; a locked
  plant shows **no price** rather than the word "locked", which is the same fact in one fewer
  channel and costs no width.
  Worth naming because it was not the goal: the change was made to fit a sixth plant and it
  improved the five that were already there. **A constraint that forces content out of a
  cramped surface is not obviously a loss** — the thing removed here was the least useful of
  the three (a name, beside a picture of the thing, on a button you hover).

### New this cycle (98) — the roster has a ceiling and it is a UI one

- **The catalogue is five plants because the side panel holds five buttons, and nothing said
  so until a sixth existed.** Cycle 98 built a working Mint — class, art, tests, a real board
  showing a neighbouring Corn at `fire_interval()` 0.6 against a base 0.8 — and could not
  sell it. The panel is priced exactly: `44 + 5*40 (plants) + 3*40 (packets) = 364` against
  `SelectionBox` at 392, leaving 28px for seven gaps, and five plant buttons sit at
  **exactly** `PLANT_BUTTON_MIN_HEIGHT` (40.0). Not near the floor. On it.
  `hud.gd`'s own `PLANT_BAR_BOTTOM` comment predicted this in the words "the next plant runs
  into it", and it was right. **That is the interesting part**: the constraint was written
  down, priced, and still invisible in every place a person would look for it — the catalogue
  reads like a list you can append to, `-ibvb` researched four hand-lists and missed this one,
  and the sweep test that "proves the bar fits ten plants" only ever reasoned about height,
  which its own comment says.
  So the roster's ceiling is a HUD fact, not a design one, and it belongs where roster work
  starts. `-wb3r` is the panel; `-zhq9` and `-l4ke` now block on it.
- **A branch a file documents as broken is worse than no branch, because it reads as
  handled.** `Hud.plant_bar_layout` fell back to two columns when one would not fit, and the
  function's own header says two columns "does not work" and "cannot be rendered at
  PANEL_WIDTH — the GridContainer grows instead of shrinking and pushes the side panel off the
  viewport". It returned that answer anyway. The branch was unreachable while the catalogue
  had five plants, so it sat there for cycles reading like a handled case.
  It is single-column now and reports `overflows` instead, which was always the honest answer
  — the flag existed, and what was missing was a caller that did anything with it. **The
  general shape is worth watching for: a fallback nobody can reach is a fallback nobody has
  run**, and the comment saying it is broken does not stop it being returned.

### New this cycle (97) — a checker that was right while looking wrong

- **The board's cues are palette-blind on purpose, and that is now enumerated rather than
  asserted.** `-vxq6` asked whether two cues had been checked against the colourblind ramp.
  The answer is that **no cue on the board reads `RunConfig.colorblind_safe` and none should**
  — `SelectionMarker`'s header (`game/selection_marker.gd:62`) already argued it: the flag
  "exists precisely because a hue is not a reliable carrier, so the brackets get heavier as
  well as redder". The flag changes the HUD's ramps; the board's cues were built to survive
  without it, so wiring them in would answer a question they were designed not to ask.
  What was actually wrong was the grammar document. Its "one rule with teeth" section claimed
  **all ten rows** obey the two-channel rule "by shape, position, or line weight" and
  enumerated none of them — `kanban-idea-pass` rule 3 violated by the file whose own argument
  is that patterns get derived rather than remembered. The per-row table is written now, and
  the derivation held: nine channels are shape, size, fill, count or sweep, and the tenth is
  width, which is the only one already pinned by a test.
- **A checker reported four symbols as unreached while all four were plainly named in real
  code, and the checker was right.** This looked like a `suite_reach_check` bug for several
  minutes. It was not: I had written GDScript through a shell heredoc — which `CLAUDE.md`
  step 2 forbids **in those words, for exactly this reason** — and it ate a backslash, so
  `section.find("\n## ", 1)` landed in the file as a **literal newline inside the string
  literal**. Godot accepts that, the behaviour is identical, and **613/613 passed with lint
  at 0/0**. `blank_strings` correctly treated the remaining 1018 characters of the file as
  one string body, so every symbol after the splice was genuinely invisible to it.
  Two things worth keeping. The rule I broke has a fourth instance now and the log says
  heredocs have stripped GDScript comment markers four separate times — this is the same
  mechanism reaching a different target, so the count is higher than the log records. And
  **a checker's finding that contradicts what you can plainly see is the one most worth
  believing**, because everything cheaper has already agreed with you: the suite passed, lint
  passed, the code ran. The disagreement is the information.

### New this cycle (96) — "measured in a real run" measures the game, not the player

- **A measurement driven by playing waves measures AMBIENT behaviour, and cycle 96's answer
  was zero until a player did something.** `-gtne` asked how often the row resumes a
  displaced line. Six waves, 54 kills, eight lives lost, 257 seconds with `run_seconds`
  moving as a witness: `messages_preempted` **0**. That reads as "never happens" and would
  have closed the bead — except every pre-empting call site is a **player action**. Arming an
  uproot (`game/game.gd:1393`) and opening a seed packet (`:1519`, `:1529`) are the only
  three, and six waves of driving the wave director contain neither. One `arm_uproot` over a
  live message: `messages_preempted` 1, first try.
  **This retroactively weakens cycle 93's answer to `-i366`.** That cycle measured
  `messages_refused` = 0 over the same shape of run — waves driven, no player actions — and
  concluded the row does not drop lines in ordinary play. A refusal needs a full queue, and
  the two producers most likely to fill one are exactly the two actions that run was missing.
  The counters still exist and the re-measurement is cheap; until it happens, "the row drops
  nothing" is a claim about a game nobody was playing.
  **ANSWERED IN CYCLE 128 (`-gd27`), and cycle 93's conclusion is CORRECTED: the row does
  drop lines.** Four packet purchases fired back to back during a live wave produced
  `messages_refused` = **12**, exactly three per purchase against `PACKET_OPEN_STEPS` = 3
  (`game/game.gd:1931`). Four controls separate the cause from the correlation: one purchase
  on a quiet row refuses nothing; one purchase over a deliberately-held ambient line refuses
  nothing and preempts four times; twelve pests spawned and killed with no purchase refuse
  nothing; and the mechanism reproduces with no purchase at all — one `MESSAGE_IMPORTANT`
  post held for 5s followed by five more at the same priority queues three
  (`MESSAGE_QUEUE_MAX`, `game/hud.gd:804`) and refuses two.
  **The producer is the REVEAL, not the flicker**, which inverts the bead's prime suspect.
  `_reveal_plant_unlock` holds the row at `MESSAGE_IMPORTANT` for 5.0s, so a second purchase
  inside that window is equal priority, cannot preempt, and its steps fill the queue. The
  flourish's own comment is correct about one flourish and silent about two overlapping —
  which is the only case that drops anything. Filed as `-47v7`.
  And the other half of the acceptance went unmeasured: **nothing on the bridge can select a
  placed plant**, so the `MESSAGE_DEADLINE` producer could not be driven at all (`-cfvb`).
  `cycle-log.md`'s standing note that a touch press/release at a plant's `global_position`
  selects it did not hold in this run, and why is unestablished.
  The general form is worth more than either instance: **"drive it in a real run" is not the
  same as "exercise it", and a zero is only as good as the actions the run contained.** Ask
  what triggers the thing before deciding what to drive.
- **A boundary assertion computed by subtraction does not test the boundary.** Cycle 96 wrote
  `line_was_read(4.0, 4.0 - MESSAGE_MIN_READABLE)` to assert the comparison is `>=` rather
  than `>`. `4.0 - 1.2` is `2.8`, and `4.0 - 2.8` is `1.2000000000000002` — strictly greater
  than `1.2`, so the assertion passed under **both** comparisons and said nothing about the
  boundary it named. Only a mutation flipping `>=` to `>` found it; the test was green the
  whole time.
  The fix is to write operands that subtract exactly — `line_was_read(MESSAGE_MIN_READABLE,
  0.0)` — and the rule is that **an "exactly at the threshold" case must be constructed, not
  computed.** Enumerated before generalising: the other subtraction-bearing assertions in the
  suite (`test_economy.gd:59`, `test_placement.gd:56`, `:2176`) are integer seed arithmetic,
  and `test_combat.gd:2227` / `test_selftest.gd:3481` subtract a margin as the quantity under
  test rather than to hit a boundary. So this is **one instance**, recorded rather than made
  into a checker, on the same ground cycles 89, 92 and 95 declined to build one.

### New this cycle (95) — a test edited by whoever breaks it, and one cue that needs no row

- **Three tests kept a hand-written copy of a list the game already declares; one of them
  fired this cycle for exactly that reason.** `test_every_legend_row_has_a_shape_the_legend
  _can_draw` held its own array of drawable shapes, so adding a sixth row broke a test that
  the same edit was supposed to satisfy — **a test maintained by the person who breaks it is
  not an assertion**. Replaced with a derivation from the source that checks two things which
  fail apart: the `match` arm exists, and a painter exists for it to call.
  Enumerated what remains, because two more is a pattern and zero more would have been an
  anecdote. `test/unit/test_combat.gd:637` lists the `Sfx` event ids the call sites use;
  `:5255` lists the three mutations. **They are not the same problem.** The mutations one is
  trivially derivable — `Pest.MUTATION_HUSK_MULTIPLIER` is already described elsewhere in the
  suite as "the canonical list of traits a wave can roll", so the hand-list is a second copy
  of a thing one expression away. The Sfx one is not: it lists what the *call sites* use,
  which cannot come from `Sfx.SOUNDS` because `SOUNDS` is what it is checked against. Getting
  it honestly means scanning game source for `Sfx.play(` — **which this project already does
  for messages**, in `tools/message_corpus_check.py`, and that tool exists precisely because
  the same list was being rebuilt by hand for three cycles.
  So the cheap half is a one-line change and the expensive half has a working precedent to
  copy. Worth doing in that order.
- **One of the four cues the legend still does not teach needs no row, because the game says
  it in words.** The weather's scattered marks are the row a seventh legend entry would most
  obviously want — a player sees the whole board change texture. But `Hud.show_weather`
  (`game/hud.gd:1899`) puts a banner up naming it, `Hud.weather_headline` (`:1907`) is what
  writes that sentence, and `Hud.next_wave_note` (`:1582`) names the coming weather in the
  prep note as well. Three places tell the player the word.
  So the marks are a second channel on a named state rather than the only carrier, which is
  the two-channel rule working and the opposite of the ARMED cue's situation — that one had
  *no* words anywhere, which is why it was worth the row. **A seventh row now costs a layout
  decision** (six end at 294 of the 300px matte; seven would end at 340), so the next
  candidate has to earn it, and the weather does not. That leaves the straight-line state,
  the husk pips and the marked-cell ring, and none of those has a banner.

### New this cycle (94) — a line that comes back looks like a line that happened twice

- **A resumed message is indistinguishable from a repeated event, and cycle 94 made that
  reachable on purpose.** The row now provably defers a pre-empted line and brings it back
  with the time it had left — verified live: kill a bed, arm an uproot, and 4 s later "A
  hungry pest ate your Corn Cobbler!" is on the row again. `_advance_message_queue` restores
  it by assigning `_message_text` (`game/hud.gd:1627`) and marks it in **no** way: same
  text, same styling, no "still" or "—" or fade distinguishing a resumption from a fresh
  event.
  So the player who loses a bed and immediately arms an uproot sees that exact sentence
  twice, four seconds apart, and nothing tells them one plant died rather than two. The
  saving grace is that the sentence names the plant, so "two Corn Cobblers died" is at least
  self-consistent — which makes it *plausible* rather than obviously a glitch, and that is
  the worse of the two failures.
  Cheap fixes exist and none is obviously right: prefix a resumed line, fade it in
  differently, or simply not resume a line that has already had `MESSAGE_MIN_READABLE`
  seconds on screen (the player read it; bringing back the tail teaches nothing). That last
  one is the most interesting because it *shortens* the row's work rather than adding to it.
- **"A hungry pest ate your X!" is honest today, and that is a constraint on every future
  way of losing a plant.** Enumerated rather than assumed: `Plant.destroyed` is emitted from
  exactly one place (`game/plant.gd:614`, health reaching zero inside `take_damage`), and
  `Plant.take_damage` has exactly one caller in the whole game — `game/pest.gd:714`,
  `meal.take_damage(EAT_DPS * delta)`, the eating path. Uprooting does not go near it:
  `commit_uproot` frees the plant with `play_exit_and_free()` (`game/game.gd:1460`), so
  digging up your own Corn Cobbler does not accuse a pest of eating it.
  The message is therefore accurate by a coincidence of there being one cause, and
  `Game._on_plant_destroyed` names that cause unconditionally. **Anything that ever kills a
  plant another way — a Dandelion bomb catching your own bed, a weather effect, a pest that
  crushes rather than eats — makes the sentence a lie the moment it lands**, and it will do
  so silently, because a message that reads perfectly is not something a test looks at
  twice. Worth stating now: the fix when that day comes is a cause on the signal, not a
  second `show_message` call site, and it is much cheaper to decide that before there are
  two callers than after.

### New this cycle (93) — the row loses nothing, and the one message that takes something

- **Arming an uproot destroys the line the player is reading, and that is the real cost of
  the rung system — not the queue overflow cycle 90 predicted.** Measured this cycle: the
  message row drops **zero** lines in a real run (waves 1-6 to a full loss, 54 kills, ten
  lives lost, every wave transition), and the threshold is five messages inside one 2-4 s
  window against a row that holds four. Ordinary play never gets close.
  What the rungs actually buy is pre-emption. Enumerated: exactly three of the twenty-two
  `show_message` call sites pass a priority — `game/game.gd:1393` (`MESSAGE_DEADLINE`, the
  uproot prompt) and `:1519`, `:1529` (`MESSAGE_IMPORTANT`). When one of those arrives, the
  line already on the row is pushed into the queue (`game/hud.gd:1462`), and against a full
  queue of equals it is **refused** — so an urgent message costs the sentence the player was
  mid-way through, not one they had not reached.
  The uproot case is the one worth looking at, and its `DEADLINE` is argued for in place
  (`game/game.gd:1390-1392`: the countdown is already running, so deferring eats the window
  the message describes). That reasoning is right. What nobody decided is what it should be
  allowed to erase — and "A hungry pest ate your Corn Cobbler!" is one of the nineteen at
  `MESSAGE_NORMAL` (`game/game.gd:1287`), so a player who arms an uproot in the same second
  a bed dies never learns which plant they lost. **Not a bug to fix blindly**: making the
  loss notice un-stompable would let it eat the uproot window instead, which is the trade
  cycle 79 already made once in the other direction.
  **MEASURED in cycle 94, and the headline sentence above is FALSE — corrected here rather
  than deleted, because how it was got wrong is the useful half.** The pre-empt branch does
  not erase the displaced line; it pushes it into the queue **with the time it had left**
  (`game/hud.gd:1462-1463`), and `_advance_message_queue` restores exactly that. So total
  reading time is preserved across the interruption: a notice pre-empted after 0.5 s of its
  4.0 comes back with 3.5, well over `MESSAGE_MIN_READABLE`. Driven against the real paths —
  a real plant killed, a real `arm_uproot`, then `step-time --seconds 4.05 --then-pause` —
  the row shows the loss notice again. It is destroyed only when the queue is full of equals,
  which needs four simultaneous ordinary lines and which the same cycle's six-wave run never
  reached.
  **The error was reasoning from the queue's drop rule instead of from the branch that
  actually runs.** Both are in `show_message` and only one of them fires for a higher-rung
  arrival. The entry cited `game/hud.gd:1462` for the pre-empt and then described the
  behaviour of the *other* branch — a citation that resolves, on the right line, supporting
  the opposite of the sentence around it. That is the exact failure `citation_check`'s own
  `NOT COVERED` line names and cannot detect.
- **The game counts every husk it lets rot and, until this cycle, nothing it never said.**
  `CompostMeter.total_rotted` (`game/compost_meter.gd:137`) exists specifically as the
  denominator for `total_collected` — the class header argues that a husk count alone would
  call sweeping one cheap husk and letting the richest rot a 50% run — and the post-mortem
  prints "Compost swept" off it (`game/run_summary.gd:260`). So this game already had the
  instinct to count what the player *lost*, in exactly one system.
  The message row now has the same (`Hud.messages_refused` / `messages_evicted`), and the
  general shape is worth stating because the next silent discard will not announce itself:
  **anything that can drop something on the player's behalf should count what it dropped**,
  or the question "does this ever actually happen" cannot be answered later without first
  building the instrument. That is the whole reason `-i366` sat unanswerable for three
  cycles. Where else? The honest answer is that I have not enumerated it — the candidates
  are the queue here, the compost meter (done), and whatever caps a spawn or a particle,
  and finding the rest is a grep for `return` inside a full-capacity branch that nobody has
  run yet.

### New this cycle (92) — a door that knows what you asked, and one that could know more

- **The pause card could open the notebook on the PLANT you have selected, and the two
  pieces are already built.** Cycle 92 gave `NotebookScreen` an `open_at` so the door
  chooses the page: the title screen opens the drawings, a paused run opens the cue legend.
  The next question the same mechanism answers costs almost nothing —
  `NotebookScreen.page_for_plant(id)` has existed for cycles and returns the page about a
  catalogue plant or -1, and `Game.selected_placed` is the plant the player last clicked.
  `Game.pause_run` already hands `PauseScreen.build` two arguments about the run's state.
  So a player who selects a Chomp, wonders what it does, and pauses could land on the Chomp
  Flower's page rather than on the legend.
  **The objection is real and should decide the design rather than be discovered after**: a
  selection persists from an earlier click. Somebody who selected a plant two waves ago and
  paused because a *pest* did something unexplained would be sent to the wrong page — and
  worse, to a page that looks like an answer. Options: only prefer the plant page when the
  selection is recent, or only when the plant was selected since the last wave started, or
  accept the miss because Prev is one press from the plant page to the legend either way.
  That last one is probably right and is worth checking rather than assuming: the legend
  and the plant pages are not adjacent in `PAGES`.
- **Two cycles running, an enumeration has said "do not build the checker" — and that is
  the enumeration working, not a failure to act.** Cycle 89 found a silent-green
  `.has()` type mismatch, grepped for more, found zero, and recorded the reasoning instead
  of writing a tool. Cycle 92 found `shelf_page()` and a newly-written `page_for_kind()`
  were the same search over `PAGES` by different names, fixed it by delegation, then
  checked whether the pattern recurs: `NotebookScreen` has three finders over that table
  (`page_for_kind` at `game/notebook_screen.gd:232`, `shelf_page` at `:688`,
  `page_for_plant` at `:753`) and the other two search **different fields**, so they are the
  same shape and not duplicates.
  What caught the duplicate was grepping for existing accessors *before* writing a new one —
  a habit, not a gate, and no checker in this repo could have seen it: two functions with
  different names doing the same search resolve every name, compile, and pass. Worth
  stating plainly because the reflex when a defect class has no gate is to build one, and
  the honest denominator has now said no twice.

### New this cycle (91) — the legend exists and is nine clicks away

- **The page that teaches the board is the last page of the notebook.** `CueLegend` ships
  as `KIND_LEGEND`, the tenth of ten `NotebookScreen.PAGES` entries, and the screen opens
  on page 0 (`game/notebook_screen.gd:420`, `go_to(0)` at the end of the build). So the
  route is: title screen → Notebook → **nine presses of Next**. The title's own header
  calls the notebook "a click further away" deliberately
  (`game/title_screen.gd:56-60`) — that reasoning was about a designer's scrapbook, and it
  now also gates the one page that explains what the marks on the board mean.
  Three shapes the fix could take, and they are not equivalent: reorder `PAGES` so the
  legend is first (cheapest, but it makes the scrapbook open on a rules page and the five
  pencil drawings are the notebook's reason for existing); add a direct route from the
  pause screen, which is where a confused player already is; or have the notebook open on
  the legend the FIRST time and on page 0 thereafter — which is a hint-shaped behaviour and
  `RunConfig.spend_hint` now exists for exactly that kind of one-shot.
  Measure before choosing: nobody has watched a player try to find this.
- **The five shapes the legend does NOT teach include the one guarding the only
  irreversible action.** The grammar has ten rows and the page shows five; the five left
  out are the straight-line state (`OVERLAY_GRAMMAR.md:28`), the weather's scattered marks
  (`:30`), the doubled line width (`:31`) and the husk's pip count (`:32`).
  **Doubled line width means ARMED — "a destructive action is one click away"** — and it
  is drawn by `SelectionMarker.WARNING_LINE_WIDTH` and `SoleCoverMarks.WARNING_RING_WIDTH`
  on the uproot, which is the one act in the game that cannot be undone and which cycle 79
  spent a whole cycle wording the warning for. That omission was a deliberate scoping call
  (the five taught are the first two waves, and a player cannot uproot before they have
  planted) but it is the wrong one to leave standing: the cue with the highest cost of
  being misread is the one not explained. A sixth row is not free —
  `test_the_legend_fits_the_page_it_is_drawn_on` puts the current five at the edge of the
  300px matte — so this is `ROW_PITCH` coming down, or a second legend page, and the test
  will say which.
  **SHIPPED in cycle 95, and the constraint above was wrong in the direction that makes work
  cheaper.** "At the edge of the matte" was an impression, not a measurement: derived from
  `CueLegend`'s own constants, five rows end at **248 of 300** and a sixth at **294**. It fit
  at the existing pitch with six pixels to spare and cost nothing but the row. **A seventh
  does not fit** (340), so the constraint is real — it was just one row further out than the
  entry claimed, and claiming it early nearly bought a page nobody needed.
  The four still untaught are the straight-line state, the weather marks, the husk pips and
  the small-solid-ring marked cell. Teaching a fifth is now genuinely a layout decision
  rather than an append, which is what this entry thought it already was.

### New this cycle (90) — 19 messages on one rung, and a class with one member

- **Nineteen of the game's twenty-two message-row calls sit on the SAME rung, and a tie
  drops the NEWER line.** Enumerated by balancing parentheses across every
  `show_message(` in `game/*.gd`, not by grepping one line each — these calls wrap, and a
  single-line grep reports all 22 as defaulted, which is how this nearly went in wrong.
  The real split is 19 at the default `MESSAGE_NORMAL`, two `MESSAGE_IMPORTANT`
  (`game/game.gd:1519`, `:1529`) and one `MESSAGE_DEADLINE` (`game/game.gd:1393`).
  `MESSAGE_QUEUE_MAX` is 3 (`game/hud.gd:355`), and `_queue_message` returns without
  appending when the queue is full and the lowest entry's priority is `>=` the arrival's
  (`game/hud.gd:1486`) — **`>=`, so a tie discards the new one**. With 19 producers
  tied, a busy moment silently drops the fourth onward.
  What makes that a player-facing problem rather than a curiosity is WHICH lines are
  tied. "A hungry pest ate your Corn Cobbler!" is one of the nineteen
  (`game/game.gd:1287`, no priority argument) and so is "Composted a husk for N seeds."
  (`game/game.gd:1764`). A bed being destroyed and a click paying out compete as equals,
  and in the wave where several things happen at once the loss notice is exactly as
  droppable as the receipt. Cycle 90 made this **detectable** for the first time —
  `show_message` now returns whether the line landed — so the fix is no longer a guess:
  read the return at the sites that matter and decide which of the nineteen are actually
  peers. Note before starting: raising a line's rung is not free, because the rung also
  decides what it is allowed to STOMP mid-read (`game/hud.gd:1462-1464`).
  **MEASURED in cycle 93, and the worry does not survive contact — but the mechanism was
  described wrongly here and that half does.** A real run to a full loss (waves 1-6, 54
  pests defeated, ten lives lost, a weather change, every wave transition) dropped **zero**
  lines, and the threshold is five messages inside one 2-4 s window: the row holds four and
  ordinary play does not produce four events that close together. So nothing was
  re-prioritised.
  What this entry got wrong is the failure it predicted. `_queue_message` has **two** drop
  sites and this described only the first, and the second is the one the rung actually
  buys: a higher-rung message does not evict a queued line, it **pre-empts**, which pushes
  the line it interrupted into the queue — and against a full queue of equals that
  displaced line is refused. **The cost of an urgent message is the line the player was
  mid-way through reading**, not one they had not reached. Promoting the eaten-plant notice
  would not protect it from being dropped (it never was); it would let it destroy whatever
  the player was reading when the bed died.
- **"A rule the game enforces in silence" turns out to have had exactly one member, and
  it is now spoken.** Cycle 90 gave the Chomp/winged refusal a sentence. Before filing
  more of them, the enumeration: grepped every `continue` and every `is_winged` across the
  plant scripts, and the only other skip in a targeting loop is
  `Dandelion.best_target`'s range check (`game/dandelion.gd:213-214`) — which is **not the
  same class**, because an out-of-range pest is the ordinary case and the plant already
  draws its range as a solid ring (the `OVERLAY_GRAMMAR.md` reach row). A silent refusal is
  one where the plant CAN see the pest and declines on a rule; a range miss is one where it
  cannot.
  So the third hint will not come from this well, and `-2ker`'s remaining two candidates
  (the first husk left to rot, the first bed eaten in under three seconds) are both about
  a CONSEQUENCE the player may not have connected, which is a different thing from a rule
  they were never told. Worth knowing before someone goes looking for a fourth silent
  refusal that is not there.

### New this cycle (89) — one hint, a contract for more, and a checker not worth building

- **The game has exactly ONE one-shot hint, and now has the machinery for a second.**
  Cycle 89 gave `RunConfig` two doors — `spend_hint(id, shown)` and `record_milestones` —
  which refuse each other's ids, so a hint can no longer be recorded by a path that never
  rendered it. `HINTS` (`game/run_config.gd:137`) has one member.
  **Enumerated rather than assumed**: `has_milestone` used as a SHOW gate appears once in the
  whole game, at `game/game.gd:1356`. Its other two call sites (`notebook_screen.gd:418`,
  `:573`) read earned state to draw the shelf, which is rendering, not gating a sight. So one
  member is the whole set, not an oversight.
  The idea is which teaching moments would want the second. The constraint the new contract
  imposes, and it is a real design filter rather than a formality: **a hint is spent on being
  SEEN, so a new one needs a `shown` answer at its call site — which means the decision must
  be NAMEABLE**, the way `Hud.uproot_shows_tip` is. A tip that appears "somewhere in the
  message row, usually" cannot answer the question and so cannot be a hint under this scheme.
  That rules out the vague ones and points at the few moments the game genuinely decides
  something: the first time a Chomp declines a winged pest in silence, the first husk left to
  rot, the first plant lost to a hungry beetle.
- **A checker for the vacuous-membership bug is NOT worth building, and here is the
  enumeration that says so.** Cycle 89 wrote a derived test asserting
  `Milestones.TABLE.has(id)` over the hint ids. `TABLE` is an `Array[Dictionary]` keyed by
  `"id"` (`game/milestones.gd:54`), so a String compared against Dictionaries is false for
  every id in the game — **the assertion passed, over nothing**, and was caught only by an
  unrelated `String(dict)` crash two lines later. That is exactly the shape
  `house-static-checker` exists for: invisible to `name_check` (every name resolves), invisible
  to lint (it is type-valid for a `Variant`), and a silent green.
  Grepped for it across `game/` and `test/unit/`: `.has(` against a const `Array[Dictionary]`
  occurs **zero** times outside the comment recording the mistake. The correct idiom is
  already in the codebase and was already the majority — `notebook_screen.gd:573` reads
  `String(row["id"])`. A checker with a zero denominator is one the house rules say must
  announce its own emptiness, and one that has never been observed to fire is not a checker.
  **Recorded so nobody proposes it a second time**; if a second instance ever appears, this
  entry is the first sighting and the bar is met.

### New this cycle (88) — a cue that saturates, and the ten nobody teaches

- **The husk's rot clock saturates exactly where its drawing did, and that half is a
  mechanic.** This cycle fixed the visual saturation with pips and deliberately left
  `CompostMeter.lifetime_for` (`game/compost_meter.gd:121`) alone, because it lerps
  `HUSK_LIFETIME` 10.0 → `MIN_HUSK_LIFETIME` 4.5 by the same `value_fraction` that caps
  at `FULL_VALUE = 9`. Derived from `Pest.SPECIES` × every composable mutation set: six
  of the ten reachable husk values sit at or above 9, so a 60-seed queen husk and a
  9-seed beetle husk give the player **the same 4.5 seconds**. The pips now say one is
  worth six times the other while the clock says hurry equally for both.
  **The design question comes first and is genuinely open**: is 4.5s a floor on human
  reaction time that a rich husk must not go below, or should the richest drop be the one
  you can least afford to miss? Widening `FULL_VALUE` answers it the second way for every
  husk at once, which is why this cycle refused to do it as a side effect.
- **Saturating a cue is sometimes right, and the distinguishing question is not
  "how much range is left".** Two magnitudes in this game clamp while their input keeps
  climbing — the enumeration is over `clampf`/`clampi`/`minf` across `game/*.gd`, 48
  sites, of which all but these are normalisations of a fraction into 0..1 that cannot
  overflow by construction. One was the husk bug fixed this cycle. The other is
  `Hud.THREAT_TINT_MAX = 12` (`game/hud.gd:143`), pinned red for an endless run that
  reaches ~25, and it is **correct** — the comment there argues it out: a ramp stretched
  across a logarithm would read as cream for the whole fixed campaign.
  What separates them is whether the player still has a DECISION past the saturation
  point. Past full threat the answer is always "everything you have", so more resolution
  buys nothing. Past a 9-seed husk the player is choosing which of several to sweep
  before they rot, and the cue had stopped helping. Ask that before adding resolution,
  not how much headroom the constant has.
- **The drawn grammar has ten rows and the game teaches none of them.**
  `game/OVERLAY_GRAMMAR.md` is now ten rows (12 table lines, 2 of them header) and is
  referenced only from GDScript comments — `husk_layer.gd:75`, `placement_preview.gd:3`,
  `selection_marker.gd:3` — no script loads it, so it is a developer document.
  **SHIPPED in cycle 91, and half this entry was WRONG — corrected here rather than
  deleted, because the mistake is the useful part.** The claim was that both candidate
  surfaces are the wrong shape and the game therefore needs a read-the-board surface it
  does not have. The notebook half of that is false: `NotebookScreen` was already a
  three-kind pager, and its own header at `game/notebook_screen.gd:142` says `KIND_SHELF`
  is "about the player rather than about the game" — the milestone shelf had stopped this
  being a pure design-history artefact several cycles earlier. A fourth kind was the
  precedent one screen away, and the legend shipped as `KIND_LEGEND` + `CueLegend`.
  **How the error was made is the lesson**: the entry was written from a `grep` for "husk"
  and "compost" across `notebook_screen.gd`, which returned nothing and read as "this file
  is about pencil drawings". Grepping for the SUBJECT answered a question about the file's
  contents; the claim was about its SHAPE, and `KIND_SHELF` is thirteen lines from the top.
  That is `kanban-idea-pass` rule 2 — search for the behaviour, not one implementation of
  it — failing in a form the rule does not yet name: **searching for the wrong NOUN.**
  The `PauseScreen` half stands. Its two-column list (`game/pause_screen.gd:778`) is a
  controls reference and a dashed ring has no keystroke to sit beside.

### New this cycle (87) — the mixer has a scale now, and one thing left off it

- **Every event in the game is priced except the two that arrive together.** `Sfx.PITCH`
  (`game/sfx.gd:229`) now carries six entries on a stated scale — losses below the base,
  gains above, magnitude by how grave the event is — and `PEST_KILLED_HARD` is the first
  entry added by reading a value the game already computes rather than by someone deciding a
  number. What is still flat: **a kill and the husk it drops are two sounds for one event**,
  `PEST_KILLED` then `HUSK_COLLECTED` a moment later when the player sweeps it, and the husk
  pays 1.5× or 3× while sounding identical every time. `HuskLayer` already knows the value —
  `radius_for` and `glow_for` both read it (`game/husk_layer.gd:31`, `:44`) — so the seam is
  there. The question worth asking first is whether the player can even tell two pitches
  apart *across* the gap between a kill and a sweep, which is seconds, not milliseconds.
- **Voices are pooled and now demonstrably re-tuned, which makes a per-play axis safe.**
  Cycle 74 wrote every voice property unconditionally on the argument that a pooled voice
  carries the last event's values forward; cycle 87 watched `Voice0` go 1.12 → 1.0 across two
  kills and confirm it. That removes the objection to a **per-play** variation the tables
  cannot express: a tiny random pitch jitter on the most repeated sounds (`CORN_FIRED` fires
  every 0.62 s at level 3, `PEST_KILLED` up to forty times a wave) is the standard fix for
  machine-gun sameness, and it is now provably safe to apply at `tune_voice` because nothing
  downstream inherits it. Note the tension to resolve before building: a jitter would make
  `test_no_two_events_are_the_same_sound` a statement about the TABLE rather than about what
  the player hears, and that test is currently the only thing keeping two events apart.
- **Four seams have now been extracted for the same reason and the fifth was taken up front.**
  `CornCobbler.spread_arc_span`, `Hud.uproot_shows_tip`, `Sfx.tune_voice` and
  `Sfx.kill_event_for` all exist because a mutation survived a test that asserted the INPUTS
  to a decision rather than the decision. The fourth was earned the same way; the fifth
  (`kill_event_for`) was reached for after one survival rather than after a cycle of
  argument. **A pattern with four instances is not a lesson any more, it is a default** — the
  cheapest version of `extract-a-testable-seam` is to ask, before writing a ternary at a call
  site, whether a test could name the thing that decides.

### New this cycle (86) — the garden has three idle motions and one interruption

- **The flinch completes the animation ask and exposes what it does not cover.** Sway,
  breathe and now a flinch: `Plant._wobble` (`game/plant.gd:377`) carries all three on one
  pivot. But **only the plant flinches.** `Pest._gait` (`game/pest.gd:796`) has the same
  continuous-sinusoid shape and the same available state — `gait_stretch` already varies when
  a pest is hungry — so a pest taking a kernel to the face reads exactly like one that did
  not. It has a hit flash (`game/pest.gd:247`, `HIT_FLASH_DURATION` 0.10) which is a *colour* channel and the
  only one it has; a flinch would be its second, and the plant's implementation is now the
  reference. That asymmetry is the "quiet half of a pair" generator cycle 64 named, pointing
  at the object the game creates most.
- **Re-arming beat decaying, and the reason generalises.** The flinch is re-armed every
  physics frame while a plant is being eaten rather than accumulated or state-machined, so a
  sustained shudder and a single twitch are the same three lines. `take_damage` is called
  every frame by a hungry pest, and that fact — already load-bearing for `_quiet_time` and
  for `Sfx.REPEAT_MS[PLANT_BITTEN]`'s throttle — did a third job for free. **A per-frame
  trigger you already have is worth more than a duration you have to model**, and this
  codebase now has three features leaning on the same one.
- **Transform cues can be checked without pixels, and that halves the board's untested
  surface.** Cycle 86's surviving mutation was closed by pausing, stepping, and reading
  `_sway_pivot.rotation` — three commands, no screenshot. That works for everything whose
  motion IS a node property: the sway, breathe and flinch, every event flourish on
  `_sprite.scale`, a pest's facing and gait. It does **not** work for anything drawn with
  `draw_arc`/`draw_circle` into a canvas — the rings, fans, arcs, marks, previews and the
  weather overlay — which is where cycle 85's shipped bug actually lived. `-a155` splits the
  cheap half out of `-6e2e` so the expensive half stays visible instead of looking done.

### New this cycle (85) — nothing checks the board, and a player found out first

- **Every cue on the playfield is outside every automated check this project has.** The
  sole-cover rings drew 72 px high for an unknown number of cycles — more than a full row,
  so they marked the wrong cells and floated on grass — and 587 tests did not notice, because
  every one of them asserts the POINTS handed to a draw call and none asserts where the
  drawing lands. `findings`' `ui_layout` check cannot help either: it reads Control rects,
  and the range rings, muzzle fans, chew rings, husk arcs, lane-pressure hatch, previews and
  now the weather overlay are all `Node2D` draw calls with no Control anywhere. **The board
  is the surface with the most cues on it and the only one nothing measures** — which is the
  same finding `-du7p` reached from the budget side one cycle earlier, arrived at from the
  correctness side by a screenshot.
- **`cell_to_world` returns board-local and says "world", and that is the whole bug.**
  `game/board.gd:254` is correct for the nine callers that assign a sibling's `position`
  and a trap for the two that pass it to `to_local()`. Cycle 85 added `cell_to_global`
  rather than renaming, because renaming churns nine right call sites to fix two wrong ones
  — but the trap is still there for the tenth caller. **A name that is wrong for a minority
  of its callers is a name that will be wrong again**, and the honest options are a rename
  (churn now, safe later) or a checker that flags `to_local(` applied to a `cell_to_world(`
  result, which is a one-pattern grep and exactly what the eleven house checkers are for.
- **Two cycles running, the interesting bug was in the gap between a value and its
  rendering.** Cycle 71 aimed an idle animation at a property five tweens owned; cycle 74
  asserted a table nothing read; cycle 85 asserted points whose rendered position was wrong.
  All three passed every test at the time. The shared shape is worth stating where the next
  cue is written: **asserting the input to a draw call is not asserting the drawing**, and
  the distance between them is a coordinate space — the one thing a pure test cannot hold,
  because it needs a parented node to exist.

### New this cycle (84) — the refusal held the answer

- **A measured refusal is worth more than an unanswered question, and this project keeps
  filing the question again instead of reading the refusal.** `-saaw` asked for a weather
  readout on the top bar in cycle 17. Its notes record the whole measurement — `"  rain"`
  366 px, `"  dry"` 357, `" ~"` 324, a bare `"*"` 317, all against a 312 px slot whose base
  string already takes 302 — and the consequence of widening it, `hud_stats_row` 35 px over
  budget. Cycle 77 filed `-t0vy` asking the same thing, having checked only that the code
  lacked it. **The refusal is what pointed at the right surface**: every candidate failing
  by 5-54 px is not a tuning problem, it is the bar saying weather does not belong to it.
  The general form is worth a habit — when a bead says "measured and refused", the
  measurement is a finding about WHERE the feature goes, not a wall.
- **The board is now a surface with cues on it and no budget.** `weather_overlay.gd` is the
  first thing to draw across the whole playfield rather than on one cell or one plant, and
  it went in without measuring anything, because nothing measures the board. Every HUD
  surface has a width budget (`Game.BUDGET_FLOOR` prices seven couplings) and every screen
  now computes its row ceiling — the board has neither, and it is the surface with the most
  room and the most competition for attention: the lane-pressure hatch, sole-cover marks,
  placement previews, range rings and now weather all draw there. **Worth asking what the
  board's budget IS** before the next full-playfield cue, since the answer is currently
  "whatever fits", which is how the top bar got into the state `-saaw` measured.
- **Drought is legible now and rain still is not, for a reason worth naming.** Both weathers
  draw, and only one of them changes what the player must DO. A drought doubles every
  plant's firing interval (`game/wave_director.gd:353`), which is a demand for more plants
  or better ones; rain heals beds by a fraction, which is a gift that requires nothing. So
  the overlay gives them equal visual weight for unequal stakes. That may be right — a
  weather system where you cannot tell which weather you are in is worse — but the drought
  case is the one a player needs to act on, and it currently reads as *slightly duller
  grass*. Worth measuring whether it is noticed at all, which is a question about the alpha
  rather than about the design.

### New this cycle (83) — four screens were checked for the first time and all were clean

- **Three overlay screens had never been looked at by a runtime check, and nothing was
  wrong with any of them.** The notebook, the key-binding screen and the options panel are
  now reachable by `fire-entry-point` and all three report 0 findings across `ui_layout`,
  `ui_reachable`, `signal_unconnected` and `performance`. That is a real result and it also
  bounds what the sweep is worth: **these screens are static**. They build once, from
  constants, and nothing animates or reflows on them — which is exactly the case a layout
  checker finds least. The surfaces where a `ui_layout` finding would actually be *likely*
  are the ones that change during play, and there is one: the HUD, which is checked every
  cycle already. **A clean sweep of the static screens is evidence the checks work, not
  evidence the game is checked.**
- **The pause card is the only screen whose findings must be taken frozen**, and that makes
  it the interesting one. `fire-entry-point pause` leaves `SceneTree.paused` true — correct,
  since the card IS a paused state and the bridge answers while paused. But every standing
  note in this project says to unpause before `findings`, because a frozen tree catches
  containers mid-layout (cycles 60 and 65 both lost time to it). The pause card is the
  documented exception and nothing says so. One sentence in the restart notes, or a `paused`
  flag on the entry point if the harness grows one.
- **`overlay_open()` makes the screens mutually exclusive, and that is a UX decision nobody
  wrote down.** Firing one entry point while another overlay is open silently does nothing:
  `_open_notebook`, `_open_keys` and `_open_options` all return early on `overlay_open()`.
  For a player that is right — a second click on a menu button while a screen is up should
  not stack screens. But it means there is no way to go from the notebook to the options
  without passing through the title menu, on a screen whose whole job is to be read
  alongside something. Worth asking whether the overlays should switch rather than refuse,
  now that all three are one call apart.

### New this cycle (82) — the surface that computes its limit is the one with room

- **Three of four row-limited surfaces are exactly full and the fourth is the one nobody
  had to re-derive.** Measured this cycle: `OptionsScreen` 3 of 3, the milestone shelf 7 of
  7, `RunSummary` 7 of 7 — every hand-written comment confirmed to the row — and
  `TitleScreen.menu_capacity()` (`game/title_screen.gd:169-174`), the only one that already
  computed, reports **8 against 5 used**. One data point and not a law, but the mechanism is
  plausible enough to act on: a ceiling stated in prose is a ceiling you discover by
  arithmetic while holding a feature, and by then the feature is what you are defending. A
  ceiling that is a function is one you can consult before starting. If that is right, the
  cheapest way to give a full surface slack is not to enlarge it — it is to make its limit
  legible and let the next three cycles not crowd it.
- **Every screen except the board is unreachable to a runtime check.**
  `devtools_config.json`'s `entry_points` has exactly one entry, `campaign`, which is also
  the `entry_hook`. So a session lands on the board and nothing navigates: cycle 82 changed
  four files across the options screen, the notebook and the summary card, got a clean
  `findings` across all five checks, and `reached 0/4 changed file(s)`. **Adding
  `entry_points` for the notebook, the options screen and the pause card is a config edit**
  and it converts three surfaces from "verified by unit tests only" to "drivable", which is
  what `-iiyg` needs before a UI baseline can cover named states at all.
- **`rows_that_fit` is the first shared geometry helper and there is a second one waiting.**
  Four surfaces now compute row ceilings through one function. The same shape exists one
  level down and is still hand-written everywhere: the *width* budget. `Hud.WORST_CASE_TEXT`
  measures the longest string a readout can hold, `TitleScreen` needs a destination name to
  fit 146 px, and `Game.BUDGET_FLOOR` prices seven couplings — three different mechanisms
  for "does this text fit its box", none of them shared, and the budget system already
  proved in cycle 79 that it can make a design decision when it refuses. Worth asking
  whether the width side wants its own `rows_that_fit`.

### New this cycle (81) — a pest can carry two traits and nothing on screen says which

- **A doubly-mutated pest wears one colour and nothing counts.** `Pest.apply_mutation`
  keeps the tint of the PRIMARY trait, deliberately — a blend of two hues is a third colour
  nobody has been taught. The non-colour channel composes for free (`gait_swing` reads
  `is_armoured` and `is_winged`, `gait_stretch` reads `is_hungry`, so a paired pest *moves*
  like both), which is the two-channel rule paying off in a case nobody designed it for.
  **But the player has no way to know a pair is what they are looking at**, and the pair is
  the rarest thing in the game — under 3% of pests at wave 20 (`game/wave_director.gd:51-52`
  against `mutation_chance_for`). A cue that says "two" rather than "which two" would be
  enough: the mutation marks drawn at the silhouette edge are already the non-colour half,
  and a second mark is a count rather than a new vocabulary.
- **The husk pays 3× for a hungry winged pest and the compost readout says nothing about
  it.** `husk_multiplier()` is now a product across traits, so a paired kill drops a husk
  worth 1.5 × 2.0. That is the correct economy and it is invisible: the husk's radius and
  ring brightness read `value` (`game/husk_layer.gd:31`, `:44`), so a 3× husk is simply a
  big one, indistinguishable from a big one for any other reason. The game already has a
  vocabulary for "this came from something remarkable" — `-rowt` wants the corpse's linger
  scaled by the same multiplier — and doing both would make a rare kill legible twice.
- **`SECOND_MUTATION_START_WAVE` is 20 and the campaign ends at 16, so pairs are an
  endless-only feature nobody will see in a normal run.** That is defensible — endless is
  where variety runs out — but it means the whole feature is invisible to a player who
  finishes the campaign and stops, which is most of them. Worth deciding explicitly rather
  than by arithmetic: either the campaign's last waves get a pair (wave 16 is already
  "deliberately sized to land on the pest ceiling exactly"), or the endless-only framing is
  stated somewhere the player can read it.

### New this cycle (80) — one-shots are a system and nothing treats them as one

- **Three one-shot hints exist, they are spent by three different mechanisms, and only one
  of them now checks whether the player saw anything.** `RunConfig.HINT_MOVE_PREVIEW`
  (`game/run_config.gd:114`) is the move tip, spent through `Hud.uproot_shows_tip` since
  cycle 80 — that is, only when the sentence is actually rendered. The other milestones in
  `Milestones.TABLE` are achievements rather than hints and are earned by *doing* the
  thing, which is a different contract wearing the same storage. **Nothing distinguishes
  the two kinds**, so the next hint added will be recorded the way its author happens to
  think of it, and cycle 79 is the proof: the author was me, one cycle earlier, and the
  hint got burned unseen for a whole cycle. A `RunConfig.spend_hint(id, shown: bool)` that
  refuses to record an unshown hint would make the contract impossible to get wrong.
- **A one-shot has no way to be re-offered and the notebook is the obvious place.**
  The move tip fires once per save and then never again — correct, since a hint that
  becomes wallpaper is worse than none. But a player who missed it has no route back: the
  notebook (`game/notebook_screen.gd`) documents plants and milestones and says nothing
  about the interactions the hints teach. That is a second home for exactly the content
  that currently has one showing and then vanishes, and it costs no HUD width — which
  matters because `-f9zc` is about three features competing for one row's worth of it.
- **`--snapshot-userstate` existed for eighty cycles before anything used it.** Cycle 80
  needed to clear a persisted flag in a running game to verify a fix, and clearing it
  without the flag would have written the developer's real save — the harness warns that
  this surfaces later as unrelated headless test failures. It worked first time and `quit`
  reported `restored 1 file(s)`. Worth a line in the restart notes rather than a bead, but
  worth noticing as a pattern: **the harness's rarely-used verbs are rarely used because
  nothing names the situation they are for**, and the situation here — "verify a fix to a
  once-per-save behaviour" — is one this game will keep producing.

### New this cycle (79) — the row holds one extra clause and there are three candidates

- **Three separate features now want to be the message row's one extra sentence, and only
  one can be.** Cycle 79 measured the ceiling exactly: the armed prompt plus the move tip
  plus the forfeit clause is 1064 px against an 876 px row, so `Hud.uproot_armed_message`
  (`game/hud.gd:1731-1745`) carries at most one extra and the forfeit displaces the tip.
  But `-fjqp` wants to draw the uproot countdown, `-c3h3` wants a flinch, and the
  one-shot-hint idea (`-qoil`) wants a second tip — **all of them are competing for the
  same 190 px** and none of the beads says so. The honest response is probably not to keep
  ranking clauses: it is to notice that the row is a queue with a width limit and that
  three features arriving at it means the ROW is the wrong surface for at least one of
  them. The selection panel is the obvious second home and `-r722` already wants it budgeted.
- **The move tip is now a courtesy that an upgraded plant never sees.** It fires on the
  first arm ever (`game/game.gd:1326-1328` records `HINT_MOVE_PREVIEW`), and from cycle 79
  the forfeit clause displaces it. A player whose first-ever uproot happens to be on an
  upgraded cob — which is *likely*, since uprooting something cheap is not a decision worth
  a prompt — gets the money sentence and never sees the tip at all, and the milestone is
  recorded either way so it never comes back. Two fixes and they differ in cost: record the
  milestone only when the tip is actually shown (one line, `game/game.gd:1327`), or accept
  it and drop the tip entirely, since a hint nobody reliably sees is a hint that is not
  doing its job.
- **`upgrade_spend` is the second derived-from-`LEVELS` helper and the pattern is now worth
  naming.** `CornCobbler.kernel_angle_offsets`, `spread_arc_span` and now `upgrade_spend`
  all read the same `LEVELS` table so the drawing, the firing and the economy cannot drift
  from it. That is three call sites of one idea and no name for it: `LEVELS` is the cob's
  single source of truth and every question about a cob should be a pure static over it.
  The fourth question — "what does level N cost to reach" — is one line and would let the
  shop, the panel and the prompt stop each computing their own.

### New this cycle (78) — an exception in a grammar is often a missing row

- **The Chomp's ring stopped being an exception by being renamed, not by being special.**
  `game/OVERLAY_GRAMMAR.md` listed two solid rings that are not reaches; one of them was
  the chew ring, "the only animated-radius ring in the game". Making it sweep at a fixed
  radius (`game/chomp_flower.gd:164-165`) did not add a special case — it made the Chomp
  the **second instance of a row**, the first being a husk's rot timer
  (`game/husk_layer.gd:69-77`). The exception only existed because the derivation had filed
  `husk_layer.gd` under "sprites drawing themselves", the one part of it done by judgement
  rather than by grep. **When something in a system looks unique, ask what else already
  does it** — twice now, the answer has been "a thing the census excluded".
- **Three plants own a radial readout and nothing stops a fourth from colliding.**
  `ChompFlower.CHEW_RING_RADIUS` is 22, `CornCobbler`'s muzzle fan is stated to sit inside
  ~26 (`game/corn_cobbler.gd:71-75`), `Sunflower`'s gauge puts its nearest corner at exactly
  26.0 and `test_combat` asserts that corner is outside the chew ring. So the band between
  the sprite and the cell edge is *fully spoken for* and the constraints live in three
  files plus one test. The next plant with a per-instance readout will discover this by
  overlapping something. A shared `Plant.readout_band()` naming the inner and outer radius —
  or even one comment listing who occupies what — turns a discovery into a lookup.
- **A player has never seen the mid-chew arc and nor has anyone else.**
  A chew is 0.45 s for an aphid (`game/chomp_flower.gd:154-156` computes the sweep from it),
  which is shorter than a bus round-trip, so cycle 78 shipped the change with the *full*
  ring photographed and the partial arc unphotographed after four attempts. That is fine
  for a tool and it is a real question for a player: **is 0.45 s long enough for a readout
  to say anything at all?** The design doc's claim is "takes a while eating bigger pests" —
  a beetle's chew is the case the ring is for, and an aphid's may be a flash nobody parses.
  Worth measuring against a beetle before adding any more to that ring.

- **An upgrade is unrefundable and nothing says so.** `Plant.uproot_refund()`
  (`game/plant.gd:541-544`) scales `PlantCatalog.cost(kind)` — the **base** cost — by a rate
  that slides with remaining health, and no plant overrides it (grepped: `uproot_refund` is
  declared once, in `plant.gd`, and nowhere else). So a Corn Cobbler with 65 seeds of
  upgrades in it refunds exactly what a fresh one does. The HUD shows the number
  (`game/hud.gd:1224`, "Uproot (+%d)") and cannot show what it is a fraction *of*, so the
  player sees a plausible figure and no hint that two thirds of their investment is not in
  it. This may well be the right rule — "upgrades are consumed" is a defensible economy —
  but it is currently a rule nobody stated, discovered by uprooting an expensive plant once.
  Either scale the refund by what was actually spent, or say it in the confirm prompt, which
  cycle 69 already made the one line guaranteed a place on the row.

### New this cycle (77) — three quarters of this file cites nothing

- **249 of this file's 323 entries made a claim about the code and cited no line for it**
  — measured by `tools/citation_check.py` in cycle 77, against 175 citations that all
  resolved. (Adding this section moved it to 250 of 326, which is the joke and also the
  point: the ratio is a live number, so read the tool rather than this sentence.) The cite-a-`file:line` rule arrived in
  cycle 30 and the file is 77 cycles old, so the uncited three quarters is simply everything
  written before it — and that half is invisible to this checker, to `kanban-staleness-audit`
  short of a full manual pass, and to anything that could ever be automated. **The right
  move is almost certainly not to backfill 249 citations.** It is to accept that the old
  sections can only be audited by hand, and to spend the audits on the ones that would
  become work: an uncited entry nobody will ever promote costs nothing being wrong.
  The concrete improvement is to make the *promotion* path check: an entry cannot become a
  bead without a citation, which is a rule about `bd` rather than about this file.
- **The continuation shorthand this file invented was invisible to its own audit for a day.**
  Entries here write `` (`game/sfx.gd:86`, `:91`, `:106`) `` — 44 bare `:NN` references in
  `kanban.md`, a third again on top of the full ones. The first version of the checker saw
  none of them, and teaching it the form immediately found a reference written as a bare
  `:331` in a sentence whose nearest preceding citation was `game/chomp_flower.gd`, a file
  with 183 lines. Nobody would have caught that by reading: the prose names the right file
  twice in the same sentence. **A shorthand a document invents for itself is a shorthand no
  tool knows**, and the cost is not the shorthand, it is that its errors look like prose.
- **A citation can resolve and be wrong, and only reading the landed line finds it.**
  `game/plant.gd:206` is where a plant's sprite is parented today; cycle 70's entry cited
  `:172`, correctly, and cycle 71's `Sway` pivot pushed the line 34 down. `:172` still
  resolves — onto a health-bar comment. The checker prints every landed line for exactly
  this reason and says in its own `NOT COVERED` that it cannot judge them. Worth stating as
  a rule for any citation-checking anywhere: **resolution is mechanical and support is not**,
  so a green exit means the coordinates exist, never that they point at what you meant.

### New this cycle (76) — six kinds of enemy, and one knob that raises how often

- **The endless ramp turns four dials and the variety ceiling is not one of them.**
  `Pest.mutation` is a single `StringName` (`game/pest.gd:284`), applied one at a time by
  `apply_mutation` (`:455`), and there are three of them — armoured, winged, hungry
  (`:94-96`). Two species (`:16-17`) times three mutations plus plain is **eight kinds of
  enemy, and six of them are mutated ones**. Endless mode escalates health, speed, the
  beetle column and `MUTATION_CHANCE` — the last from 0.4 toward a cap of 0.85
  (`game/wave_director.gd:22`, `:29-30`) — so past the cap the player meets the same eight
  things, more often, faster, with more health, forever. **Every dial raises intensity and
  none raises variety.** Letting a pest carry two mutations is the cheapest new kind in the
  game: `apply_mutation` already composes onto whatever the pest is, the husk multipliers
  (`:103-107`) multiply naturally, and an armoured-winged beetle is a genuinely different
  problem rather than a bigger one. It is also the sort of thing that needs a cap and a
  wave floor decided up front, which is why this is an entry and not a bead yet.
- **Every kill sounds the same, on a mixer that now knows how to say otherwise.**
  `Sfx.PEST_KILLED` is one event for every death — an aphid you sneezed on and a hungry
  armoured beetle that soaked four volleys arrive at the player as the same
  `impactSoft_heavy_000.ogg` at −3.0 dB. The game already prices that difference twice:
  `MUTATION_HUSK_MULTIPLIER` (`game/pest.gd:103-107`) pays 1.5× or 2× for the harder kill,
  and cycle 74 gave the mixer a direction — losses go lower, gains go higher. A harder kill
  is a bigger gain, so it wants to sit *above* the base kill.
  **The obstacle is real and worth naming here**: `Sfx.play(event)` takes an id and nothing
  else, and `PITCH` is keyed by id, so a per-kill pitch means either new event ids
  (`pest_killed_hard`) or a per-call override on `play`. The second is a wider change than
  it looks — every existing call site becomes a place where a caller could disagree with the
  table, which is exactly what `tune_voice` was extracted to prevent. Pairs with `-rowt`,
  which wants the corpse's linger scaled by the same multiplier.

### New this cycle (75) — four surfaces are capacity-bound and one of them computes it

- **The title screen solved "how many rows fit" properly and the other three surfaces each
  solved it again by hand.** Enumerated over every surface in the game with a row limit:
  - `TitleScreen.menu_capacity()` (`game/title_screen.gd:169-174`) **computes** the ceiling
    — it walks `hint_y(n + 1) + HINT_HEIGHT` against the backdrop's horizon and returns the
    count. Add a destination and the number moves on its own.
  - `OptionsScreen` writes the arithmetic in a comment (`game/options_screen.gd:100-108`):
    three rows from 256 at 48 foot at 392, footer at 440, gap 48 against
    `OverlayScreen.FOOTER_GAP` of 24.
  - The milestone shelf writes it in a comment (`game/notebook_screen.gd:166-168`):
    `SHELF_ROW_PITCH` 42 × 7 entries + 3 = 297 against a 300 px box.
  - `RunSummary` writes it in a comment (`game/run_summary.gd:77`): rows step
    `ROW_HEIGHT + ROW_GAP` = 38, the seventh foots at 448, `BUTTON_Y` is 476, an eighth
    would foot at 486.
  Three of the four are careful, correct, tested — and re-derived by hand, in prose, in
  three different files, by three different cycles that could not see each other. **The
  fourth shows the shape that does not rot**, and it is the oldest of them. A shared
  `rows_that_fit(top, pitch, floor)` on `OverlayScreen`, or even just each surface computing
  its own ceiling the way the title screen does, turns "read the comment and redo the sums"
  into a number that is already right.
- **The card says what the run did and never what it cost.** `RunSummary.summary_rows()`
  (`game/run_summary.gd:235-249`) reports waves, pests defeated, time, threat level, beds
  lost, compost swept and where you held them. **Not one row is about seeds** — and
  `SeedBank.seeds_earned_total` (`game/seed_bank.gd:69`) has been tracked all along. A run
  where you scraped by on 40 seeds and one where you finished sitting on 300 unspent read
  identically on the card, and "did I over-build or under-build" is the single question a
  post-mortem is for. There is no `seeds_spent_total` yet, but it is `seeds_earned_total`
  minus what is left, which the card already has.
  This lands straight into the entry above: the card is **full**, so "add a seeds row" is a
  layout decision first. That is exactly the collision the first entry predicts, arriving
  one bullet later.

### New this cycle (74) — sound is a switch, and the switch panel is full

- **Every audio control in the game is binary, and the seam that would make a dial cheap
  now exists.** `OptionsScreen.OPTIONS` (`game/options_screen.gd:83-99`) is three rows —
  colourblind bars, sound effects, music — and each is an On/Off flip
  (`:265`, `ON_TEXT`/`OFF_TEXT` at `:123-124`). **`AudioServer` appears nowhere in
  `game/`**, so there are no buses and never have been; `Music` sits at a fixed
  `BASE_VOLUME_DB` of −14.0 (`game/music.gd:53`) and effects default to 0.0. A player who
  finds the music loud has one option, and it is silence. Cycle 74 made this cheap by
  accident: `Sfx.tune_voice` is now the single place every voice property is written, and
  `Music._start` (`game/music.gd:214`) is its counterpart, so a stored trim per category is
  one line in each — no bus, no routing, no new node. The hard part was never the mixing.
- **The `PITCH` table states a scale and one test asserts one pair of it.** Its comment
  claims a rule — losses go lower, gains go higher, the routine half of a pair keeps the
  base, magnitudes graded by how grave the event is — and
  `test_tuning_a_voice_applies_both_axes_the_table_declares` checks exactly one of the five
  entries against exactly one neighbour. The rest is prose, and prose is what this project
  has sixty pages of evidence about. The direction is derivable: every id in `PITCH` is one
  half of a pair that shares a `SOUNDS` file, so the check writes itself — find the partner,
  assert the sign, and assert the gravest loss is the furthest from 1.0. That is
  `enumerate-the-pairs` on a table that is literally pairs.
- **The options panel is exactly full, and the next audio idea needs a row.**
  `OptionsScreen.PANEL` (`game/options_screen.gd:109`) is sized from the row count on
  purpose, and its own header does the arithmetic: three rows from `ROWS_TOP` 256 at
  `ROW_HEIGHT` 48 put the last button's foot at 392 against a footer starting at 440, so the
  gap is 48. `OverlayScreen.FOOTER_GAP` is 24 (`game/overlay_screen.gd:92`). **A fourth row
  puts the foot at exactly 440 — gap 0 — and trips the rule.** That is the good kind of
  wall, and it means "add a volume slider" is a panel-geometry decision before it is an
  audio one. Worth choosing the way out now (grow the panel, or split audio onto its own
  screen the way Keys already is) rather than while holding a feature.

### New this cycle (73) — twenty-two named beats, eleven sounds

- **Two pairs of sounds are literally indistinguishable, and in both a bad thing sounds
  like a routine one.** `Sfx.SOUNDS` (`game/sfx.gd:86`) maps 22 named beats onto **11
  distinct `.ogg` files**, so ten of them are shared — and only one sharing is documented
  as deliberate (`game/sfx.gd:95`: `WAVE_CLEARED` reuses `RUN_WON`'s jingle, at −9.0 dB
  against −4.0, so the same phrase reads as the smaller version of the same event, which is
  exactly right). The other nine were not reasoned about, and two of them share a file
  **and** a volume, which makes them the same sound to a player:
  - `PEST_ESCAPED` and `PURCHASE_DENIED` are both `error_002.ogg` at the default volume
    (`game/sfx.gd:91`, `:106`). **A pest reaching the house costs a life; a refused purchase
    costs nothing at all**, and they are the same noise.
  - `PLANT_DESTROYED` and `CHOMP_BITE` are both `chop.ogg` at the default (`:89`, `:119`).
    Your plant dying sounds like your plant eating.
  Two more share a file and differ only in volume: `PLANT_BITTEN` / `CORN_FIRED`
  (`impactSoft_medium_002.ogg`, −8.0 vs default) — taking damage sounds like your own gun —
  and `HUSK_ROTTED` / `BUTTON_PRESSED` (`minimize_006.ogg`, −6.0 vs −10.0). This is the
  two-channel rule the drawn cues already obey, applied to audio: **a loss and a no-op
  should not be separable only by context.** Four new files, or four pitch shifts, and the
  worst of it goes away.
- **A corpse says how a pest died and never what died.** `DEATH_LINGER` is a flat 0.35 s for
  every pest (`game/pest.gd:200`), and `corpse_rotation()` / `corpse_scale()` vary by CAUSE
  — a Chomp bite squashes, a seed bomb tilts. So an armoured beetle that took four volleys
  leaves the board on exactly the same beat as an aphid that took one. The game already
  believes harder kills are worth more: `husk_multiplier()` (`game/pest.gd:928`) pays a
  premium per mutation, and `WaveDirector`'s weather payout is the same idea one level up.
  The corpse is the one place that idea is missing, and it is the only place the player
  actually looks. Scaling `DEATH_LINGER` by the same multiplier would cost one line and make
  a hard-won kill *read* as one.
- **Ten tests kill a pest and none of them may assume the node is gone.** Cycle 73 measured
  it: a corpse survives its own kill by **18 process frames**, against the 2 that
  `run_tests.gd`'s `UI_SETTLE_FRAMES` (`tools/run_tests.gd:849`) pumps. Ten call sites of
  `.kill()` across `test/unit/` sit in that window. Nothing enforces the discipline — and
  the project already owns the checker that would: `tools/settle_read_check.py` exists
  precisely to catch a test reading a value the settle frames were still moving, and a
  corpse is that, with a name. Extending it to flag a tree read within N frames of a
  `.kill()` is the same rule on a second subject.

### New this cycle (72) — eleven animation steps nobody has ever seen run

- **The plants are the only subsystem whose animation timings are magic numbers.**
  Enumerated over every `tween_property` / `tween_method` / `tween_interval` in `game/`
  (20 steps, 14 files). Every one outside the plant family names its duration:
  `PREP_BAR_PULSE_SECONDS` 0.24, `PANEL_RISE_SECONDS` 0.16, `READOUT_PUNCH_SECONDS` 0.16
  (`game/hud.gd:171`, `:431`, `:445`), `CROSSFADE_SECONDS`, `TURN_SECONDS`, `RISE_SECONDS`,
  `FLIGHT_SECONDS`, and `Pest`'s `HIT_FLASH_DURATION` 0.10 and `DEATH_LINGER` 0.35 /
  `DEATH_FADE` 0.15 (`game/pest.gd:214`, `:200`, `:204`) — `Pest` even splits its flash
  0.35/0.65 *of* the named constant rather than writing two numbers. The five plant
  flourishes name nothing: `game/plant.gd:272-273` and `:331`, `game/corn_cobbler.gd:183-184`
  and `:331-332`, `game/chomp_flower.gd:155-156`, `game/dandelion.gd:390-391` are eleven bare
  literals between 0.05 and 0.18. They are also the ones a designer would most want to tune
  together, since they are all the same gesture — a squash and a return.
- **A plant's exit has two headless-free tests; a pest's has none, and the pest's is the
  one with a bare `tween_interval` in it.** `Plant.play_exit_and_free`
  (`game/plant.gd:329-332`) frees on the spot when animations are gated off, and
  `test_a_plant_eaten_down_to_nothing_still_frees_the_node_headless` plus
  `test_uprooting_plays_its_own_cue_and_still_frees_the_node_headless` (both in
  `test/unit/test_placement.gd`) exist because that bug shipped twice. `Pest._play_death`
  (`game/pest.gd:866-882`) takes the other route: it guards `is_inside_tree()`, then queues
  `tween_interval(DEATH_LINGER)` and a `tween_callback(queue_free)` in **both** branches, so
  headless it depends on a Tween's interval elapsing rather than on an early return. Nothing
  asserts it does. Whether that leaks is a measurement nobody has taken — and this is the
  exact failure class the plant tests were written for, on the object the game creates most.
- **The flourishes are asserted to start and end at `Vector2.ONE` and never to reach their
  peak.** The cob's recoil is written to hit `(0.88, 1.14)` (`game/corn_cobbler.gd:183`), the
  Chomp's bite `(1.18, 0.82)` (`game/chomp_flower.gd:155`), the upgrade `(0.72, 1.34)`
  (`game/corn_cobbler.gd:331` — written as a bare `:331` in cycle 72, which the
  continuation rule binds to the *preceding* citation and therefore to `chomp_flower.gd`,
  a file with 183 lines; the first continuation-aware run of `citation_check` in cycle 77
  found it), the planting pop `(1.12, 1.12)` (`game/plant.gd:272`) — four distinct shapes, and
  the extreme is the entire content of each. Until cycle 72 that was unobservable: a 0.15 s
  tween is shorter than a bus round-trip and four consecutive polls all return the landed
  value. It is observable now (`.claude/skills/read-a-moving-value/SKILL.md`, the walk
  recipe), so "does the bite actually squash" is a check that can exist. A stepped walk of
  the recoil reached 0.900 against a written 0.88, which is the sampling grid rather than a
  discrepancy — but nobody has ever confirmed which.

### New this cycle (71) — every idle motion in the game is the same sine wave

- **Nothing in the garden is ever startled.** The game now has three continuous idle
  animations and they are the same shape: `Plant._wobble` (`game/plant.gd:351`) sways and
  breathes off `sin(_wobble_time * RATE + phase)`, `Pest._gait` (`game/pest.gd:733`) swings
  and stretches off `sin(_gait_time * rate + phase)`, and `TitleScreen`'s decorative lawn
  phases the same way. A sinusoid cannot be interrupted, so nothing on the board ever
  flinches — not a plant taking a bite, not a pest walking into sap. **The state to hang a
  flinch on already exists on both sides**: `Plant._quiet_time` (`game/plant.gd:180`) is
  reset by damage and is what gates regrowth, and `Pest` already changes `gait_stretch`
  when it is hungry (`game/pest.gd:780`). A one-off amplitude spike decaying back into the
  sine — the same `_wobble_time` clock, one extra term — would make being eaten legible
  from across the board, where today a bed under attack looks exactly like one that is not.
- **The Sway pivot exists on every plant and only one thing uses it.**
  `game/plant.gd`'s `_sway_pivot` was added in cycle 71 to keep idle motion off
  `_sprite.scale`, which five event flourishes own. It is a general answer to a general
  problem and it currently carries two channels of one sine. **The other thing that wants
  it is a base pivot**: the sway rotates about the sprite's centre, so a plant wobbles
  around its middle like a tethered balloon rather than bending at the stem. Moving
  `_sprite.offset` down and the pivot up by the same 32 px would rotate about the base at
  no runtime cost — and now that the event tweens live on the sprite and the sway on the
  pivot, that change touches only the pivot and cannot disturb the planting pop, which is
  the reason it was not worth attempting before.
- **The idle motion and the drawn cues are now on opposite sides of the sprite.**
  Cycle 70 established that a plant's `_draw()` renders *behind* `_sprite` (because the
  sprite is a child) — and cycle 71's pivot puts the sprite one level deeper still, so the
  gap widened. The consequence is visible on the cob: `_draw_muzzle_fan`
  (`game/corn_cobbler.gd:159`) paints pips in the PLANT's space while the sprite they sit
  beside is now rotating and breathing on the pivot. A pip at 20 px does not follow the
  head it is meant to be a muzzle for. Nobody has looked at whether that reads as wrong or
  as a still gun on a swaying stalk; it is one screenshot, and it is the same screenshot
  `-gfpj` already asks for.

### New this cycle (70) — every plant draws underneath its own art

- **`_draw()` on a plant renders BEHIND the plant's sprite, and nobody has checked what
  that costs.** `game/plant.gd:206` parents `_sprite` under the `Sway` pivot, itself a child
  of the plant (`:202`), and a `Node2D` draws its own `_draw()` before its children — so
  every cue a plant paints is under its own art wherever they overlap, and since cycle 71 it
  is under a *moving* copy of it.
  *(Cited `:172` when written in cycle 70, which was `add_child(_sprite)` then. Cycle 71's
  pivot pushed it 34 lines down and `:172` now lands on a health-bar comment — a citation
  that still RESOLVES and no longer supports its claim, which is precisely the case
  `citation_check` says in its own NOT COVERED line it cannot see. Caught in cycle 77 by
  reading the tool's output instead of its exit code, on the first pass, which is the
  argument for printing the landed lines at all.)* Enumerated by cue radius against the 64x64 sprite box (`art_src/*.svg` are
  all `width="64" height="64"`, centred): the cob's pips sit 20-22 px out
  (`game/corn_cobbler.gd:175-176`), the Chomp's chew ring runs 16 px down to nothing
  (`game/chomp_flower.gd:24`), the Sunflower's gauge occupies x −30..−24, y 10..30
  (`game/sunflower.gd:46-49`) — three cues wholly inside the box — while the Sundew's sap
  patch is 118 px (`game/sticky_sundew.gd:34`) and the Dandelion's range ring is 176
  (`game/dandelion.gd:376`), both mostly clear of it. **Only the cob's case has been
  measured**: cycle 70 sampled the same pip reading `#ffc500` over grass at one aim and leaf
  green at another. Whether the other two are hidden depends on the art's alpha where they
  land, which is a thing a screenshot answers in one minute and nobody has spent it. If it
  is a real problem the fix is one line per plant — a cue child drawn above the sprite —
  and if it is not, that is worth writing next to `_build_visuals`.
- **The Chomp's progress ring shrinks toward nothing exactly as its news becomes urgent, and
  the husk beside it does the opposite.** `game/chomp_flower.gd:135` computes
  `CHEW_RING_RADIUS * (1.0 - chew_progress())` and returns early below 0.5 px, so "the mouth
  is nearly free" — the moment a player is deciding whether to commit a lane — is drawn
  smallest and deepest inside the flower's own sprite. `game/husk_layer.gd:69-77` faces the
  same problem and solves it the other way: the arc stays at a fixed `radius + RING_GAP`
  around the husk and sweeps its *angle* down, so a husk about to rot is as visible as a
  fresh one. Two timers, one game, opposite answers. The husk's is the better one and it
  costs nothing to copy.
- **Two plants draw where they will act next, and both only after they have already acted.**
  The cob's fan points along `_aim_angle`, set inside `_fire_at` (`game/corn_cobbler.gd:119`),
  and the Dandelion's blast circle sits on `_last_landing`, set inside its own fire path
  (`game/dandelion.gd:234`) behind a `_has_fired` gate (`:378`). Both are *post*-views wearing
  the shape of a preview: a freshly planted cob points wherever it happened to be initialised
  until its first shot, and a Dandelion shows nothing at all. The information a player wants
  before committing seeds — *which way will this thing shoot* — exists in both plants a frame
  after it stops being useful. The cob already targets `_furthest_along_in_range` every tick;
  aiming the idle fan at the current best target rather than at the last one is the same call
  it already makes.

### New this cycle (69) — the game draws two countdowns and refuses to draw the third

- **The only line with a clock behind it is the only clock the game never draws.**
  `_uproot_left` ticks down at `game/game.gd:1376` and lives entirely inside `game.gd` —
  outside it the identifier appears only in tests, never in `hud.gd`, so the HUD learns
  *armed or not* through `uproot_armed()` (`game/game.gd:1341`) and never *how much is
  left*. Meanwhile the game draws this exact thing twice already: `husk_layer.gd:69-77`
  sweeps `TAU * frac` around a husk as its rot timer runs, and `hud.gd:643-647` drains
  `PrepBar` across the whole top bar over the prep gap. A four-second irreversible
  decision is the one countdown with nothing on screen. Now that cycle 69 guarantees the
  prompt the row the instant it is armed, drawing the remaining fraction under it is the
  natural other half — and it is a shape the player has already been taught by husks.
- **"Only one line may carry a deadline" is a paragraph, and paragraphs do not fail.**
  `game/hud.gd:347` warns that two `MESSAGE_DEADLINE` lines cannot defer each other —
  whichever waits is wrong by construction — and `game/game.gd:1334` is, today, the only
  producer (`grep -rn MESSAGE_DEADLINE game/` returns the constant at `hud.gd:351`, one
  comment and that one call). The person who adds the second will be reading their own
  feature, not this constant. A test asserting the call-site count is exactly one, failing
  with the paragraph as its message, puts the warning in front of them at the moment it
  applies. Cheap, and the same move `message_corpus_check` already makes for the row's
  strings.
- **`OVERLAY_GRAMMAR.md` filed a real cue under "sprites drawing themselves".**
  Its derivation (`game/OVERLAY_GRAMMAR.md:55-56`) lists `husk_layer.gd` among the files
  that are art rather than cues. But `husk_layer.gd:69-77` draws `draw_arc(..., TAU * frac,
  ...)` whose sweep *is* the husk's remaining life — a mark that carries state, which is
  the table's own definition of a cue. Including it supplies the row the table is missing,
  **partial arc = time remaining**, and that in turn demotes `chomp_flower.gd:138`'s
  shrinking ring from a lone exception to one instance of a vocabulary the game already
  has. One cycle after the document was derived, its exclusion list is where the next
  correction was hiding — which is the same lesson as the numbers it cites moving before
  the ink dried.

### New this cycle (68) — the grammar is written; the plants do not follow it

- **Every plant draws its own range ring and none of them share the code.**
  `corn_cobbler.gd:148-149`, `dandelion.gd:376-377` and `sticky_sundew.gd:456` each build a
  fill-plus-edge ring at their own reach, with their own colours and their own alpha, and
  `chomp_flower.gd:138` draws a ring that is not a reach at all. `game/OVERLAY_GRAMMAR.md`
  now says a solid plant-sized ring means REACH — four independent implementations of one
  sentence is how a fifth plant ends up meaning something slightly different by accident.
  A `Plant.draw_reach_ring()` on the base class would make the grammar structural rather
  than advisory.
- **The Chomp's chew ring is the only animated radius in the game and reads as a range.**
  `chomp_flower.gd:138` shrinks a solid ring as a chew completes — a progress bar in ring
  form, sharing a shape with the four rings that mean "this is how far I act". It is
  documented as an exception now, which is honest and is not the same as being legible. A
  player who has learned "solid ring = reach" from three plants meets a fourth where it
  means time.
- **The lane-pressure hatch is the one cue with no entry in the grammar table.**
  `lane_pressure_overlay.gd:96` draws hatched lines whose ANGLE carries aimed-versus-unaimed
  and whose ALPHA carries how much pressure a cell took — two channels on one mark, and the
  most sophisticated cue in the game. It is absent from `OVERLAY_GRAMMAR.md`'s table because
  it is the only one drawn on the board rather than on a node, and that asymmetry is
  probably worth a row of its own rather than an omission.

### New this cycle (67) — the HUD reports how full it is; the game does not

- **`cmd budgets` now says "3 of 7 at floor" and the game itself still says nothing.**
  The count exists for whoever runs the verb, which is a developer. A designer nudging a
  font size or lengthening a plant name gets no signal until a test fails, and the failure
  names a budget rather than the change that spent it. The information is now one field
  (`at_floor_ids`) and the startup check already runs `check_budgets()` — a one-line
  warning in the editor output when a build starts with rows at floor would put it where
  the person spending it is looking.
- **Four cues now share one visual grammar and nothing writes it down.**
  Dashed rings mean a remark (`PlacementPreview._draw_risk_ring`, `SoleCoverMarks`'s
  holds-nothing ring); solid rings mean a range; filled dots mean "you would gain this";
  a doubled line width means an armed warning. Every one of those was decided in its own
  cycle with its own reasoning, and they are consistent — but the consistency is an
  accident of taste rather than a rule anyone could apply to a fifth cue. `art_src/STYLE.md`
  states the art conventions; there is no equivalent for the drawn overlays.
- **A budget resting on its floor is a design decision nobody made.** Three rows are at
  floor because each was ratcheted down in the commit that spent it — which is the correct
  local move every time, and adds up to a HUD with no slack that nobody chose. The
  `hud_message_row` slack (121 px against a floor of 40) is the only room left and exists
  only because nobody has ratcheted it. Worth asking once whether the ratchet should have
  a reserve: a floor set at *measurement plus N* rather than at the measurement, so
  spending the last of a row requires moving a number that says "reserve".

### New this cycle (66) — the HUD is at its floor on three rows out of four

- **Three budgets sit exactly at their declared floor, and nothing on screen says the HUD
  is full.** `husk_click` has 4 px of 32, `hud_readouts` 10 of 171, `hud_stats_row` 19 of
  1112 — each precisely its floor in `Game.BUDGET_FLOOR` (`game/game.gd:1916-1928`),
  because this project ratchets floors down to the measurement on purpose. The consequence
  is invisible until someone tries: the next label that grows by a pixel fires a
  regression, and a designer nudging a font size has no way to know they are spending the
  last of it. A single line on the `budgets` verb — "3 of 7 at floor" — would turn a
  per-budget reading into a state of the HUD.
- **Only one row has room, and it is the one being spent.** `hud_message_row` holds 121 px
  against a floor of 40; cycle 61 spent 185 px of it on a one-shot tutorial tip. That is
  not a mistake — the budget passed — but it means the message row is now doing duty as
  the HUD's slack fund, and there is no other. Any future "just add a short line" lands
  there because everywhere else is at zero.
- **An evidence string can read two ways and only one of them is a working budget.**
  `hud_readouts` said "Font.get_string_size() over each live readout", which parses as
  measuring the CURRENT text — a budget that passes because the counter happens to read
  "Seeds 25" today. It actually sweeps `Hud.WORST_CASE_TEXT` against each readout's live
  slot, and I misread it before opening `game/game.gd:2329`. Corrected. The general shape
  is worth watching: an evidence string naming the SURFACE is ambiguous about whether the
  worst case or the current value was measured, and those differ by everything.

### New this cycle (65) — a corpse can carry information, and only one does

- **The kernel kill is the common death and it is the one that says nothing.**
  `Pest.corpse_rotation()` and `corpse_scale()` now differ for a Chomp bite and a seed
  bomb; a kernel kill takes the default straight corpse, deliberately, so the two that
  differ read as remarkable. But a Corn Cobbler is the plant most players own most of the
  time, so the *majority* of corpses carry no information at all. A kernel arrives with a
  direction — `Kernel._physics_process` flies until it leaves the board — so a small
  knockback ALONG that travel is available and would cost one argument, unlike the two
  shipped cues which needed none. Worth doing only if the default staying plain is judged
  less valuable than every death saying something.
- **`_ever_engaged` knows whether the garden ever touched a pest, and nothing draws it.**
  `game/pest.gd:796` sets it on any damage above zero (and `:646` when a mouth holds one),
  and the run summary counts pests
  that "walked in untouched". A pest that reaches the house having been shot at and missed
  is a different story from one that strolled past an empty road, and the flag separating
  them already exists on every pest — it just never reaches the player except as an
  aggregate at the end of the run.
- **CORRECTED (cycle 66): an escape is not unmarked, and this entry said it was.**
  The original claim — "death has a sound, a corpse and a linger; escape has none of the
  three" — is false. An escape plays `Sfx.PEST_ESCAPED` (`game/game.gd:911`), tints the
  exit cell on the lane-pressure map via `_note_lane_loss(..., true)` (`:910`), and punches
  the Garden readout, because `_punch_readout(_lives_label)` fires whenever the lives text
  changes (`game/hud.gd:1072-1073`).
  What is actually missing is narrower and may not be worth fixing: an escape has no beat
  *on the pest itself*. `Pest` emits `escaped` and calls `queue_free()` in the next line
  (`game/pest.gd:936-937`), where a death gets a corpse sprite and `DEATH_LINGER`. Even
  that is arguable — the exit bracket sits at x≈928, under the side panel, so a lingering
  escapee would fade where nobody can see it, exactly as cycle 65's corpses turned out to
  land off-board.
  **The entry is kept rather than deleted because the mistake is the useful part.** It
  cited a `file:line` for the half it checked (`DEATH_LINGER`) and asserted the other half
  from memory, which made the whole thing read as sourced. See the workflow note added in
  cycle 66.

### New this cycle (64) — three surfaces are each exactly one item from full

- **The milestone shelf holds seven and has room for seven.** `SHELF_ROW_PITCH` is 42 and
  `Milestones.TABLE` has 7 entries, so `7 * 42 + 3 = 297` against a 300 px drawing box
  (`game/notebook_screen.gd:163-168`). An eighth milestone does not fit at these numbers,
  and `test_the_milestone_shelf_fits_the_page` fails the moment `TABLE` grows — which is
  the good kind of wall, but it means "add a milestone" is a layout decision rather than a
  data change. The header names the two ways out (drop the pitch, or split the shelf across
  both pages); picking one *before* someone has a milestone they want to add is cheaper
  than picking it while holding one.
- **The title screen buys its sixth destination with a shortened word.**
  `game/title_screen.gd:59-60` records that "Designer's Notebook" draws ~183 px against a
  146 px half-band cell, so the button says "Notebook". That is a sound trade and it is
  also a rule nobody stated: **a title destination's name must fit 146 px**, and the next
  one added will discover that by looking wrong rather than by failing. The notebook's own
  heading and the pause card still say the whole phrase, so the game already speaks its
  full name in two places and an abbreviation in the third.
- **Every one of the last three audited ideas became real by someone noticing an
  asymmetry, not by anyone planning it.** The Sunflower payout got a sound because the
  *husk* had one; the wave-start click got a sound because everything downstream of it did;
  the Options screen exists because the Keys screen did. That is a genuinely reliable
  generator and it is not written down anywhere as a technique: walk the game asking "what
  is the quiet half of a pair the player would expect to match?" The husk/Sunflower pair
  took ~40 cycles to spot and is one line of code.

### New this cycle (63) — the message row is fully checked; nothing else is

- **One HUD surface has three checkers and the rest have none.** The message row is now
  verified three ways — every call site resolves to the corpus, every bool variant is
  priced, and no priced producer is dead (`tools/message_corpus_check.py`). The stats row
  next to it has `WORST_CASE_TEXT` and a pair of assertions (`-rq94`, still open); the
  selection panel has comments and one hand measurement (`-r722`); the run summary has a
  clearance gate and nothing about content. The message row got this attention because it
  broke three times, which is a fine reason — but the other three surfaces have not broken
  *yet*, which is a different thing from being safe.
- **`Hud.message_corpus()` is now the only place in the game that enumerates its own
  output, and it is worth copying.** The pattern is small: one function listing every
  string a surface can show, beside the code that produces them, read by both the budget
  and a checker. `run_summary.gd` builds seven rows of text with no equivalent, and
  `notebook_screen.gd` draws a shelf whose row text comes from `Milestones.TABLE`. Either
  could carry the same declaration for the same cost.
- **Nothing prices what a surface shows over TIME.** Every check on the message row is
  about one string at one instant. `_message_queue` (`game/hud.gd`) can hold several, each
  with its own lifetime, and the player's experience is the sequence — a four-second
  irreversible prompt landing behind two ambient husk messages is a real failure that no
  width check can see. `-xvub` proposes styling importance; the sharper question is whether
  a queue that can defer an important message is right at all.

### New this cycle (62) — the corpus is checked two ways and neither is about time

- **A producer's variants are priced; a producer's *absence* still is not.**
  `message_corpus_check` now verifies that every `show_message()` call site resolves to the
  corpus AND that a producer with N bool modes appears 2^N times. What no rule covers: a
  producer that exists in `hud.gd`, is in the corpus, and is called by nothing — dead
  message text still being priced. The row's budget would then be set by a string the game
  can no longer produce, which is the same lie as an unpriced string with the sign flipped.
  `suite_reach_check` already finds functions no test names; this is functions no CALLER
  names, and the corpus makes the set enumerable.
- **Every message is priced by width and none by duration.** `show_message(text, seconds)`
  takes a lifetime at each of its fifteen call sites (`game/game.gd`), ranging 2.0 to 8.0,
  and `Hud.MESSAGE_FONT_SIZE` is fixed — so a 755 px message and a 100 px one get whatever
  seconds someone typed. Reading time scales with length and the corpus now knows every
  length. `-uhno` proposes deriving duration from it; worth noting here that the corpus
  makes it a two-line change rather than a survey.
- **The waiver reasons are now the best documentation of the message system, in two
  scattered sets.** Five call-site waivers in `game/game.gd` and one variant waiver in
  `game/hud.gd`, each explaining something true and non-obvious about what can and cannot
  be measured. `-vjr1` already proposes printing the call-site ones on a clean run; the
  variant waiver should join that output, or the answer to "what does this checker
  deliberately not price?" stays a grep across two files.

### New this cycle (61) — one-shot hints are a mechanism now, and there is only one

- **The one-shot hint pattern exists and teaches exactly one thing.**
  `RunConfig.HINT_MOVE_PREVIEW` (`game/run_config.gd`) rides in the milestone set as a
  "shown once, ever" flag, and it cost nothing to build because `record_milestones` already
  had the semantics. The move preview is not the only feature nobody is told about: the
  husk sweep, the uproot refund, the packet tiers and the colourblind toggle are all
  discovered by accident or not at all. A second hint costs one constant and one bool now.
  The restraint worth keeping is that a hint should point at a thing the player can act on
  *in that moment*, which is why this one lives on the armed prompt rather than in a
  tutorial.
- **A budget prices the ceiling, and nothing says which strings are RARE.**
  `cmd budgets` reports the message row at 755 of 876 px because the widest thing it can
  hold is a first-arm prompt seen once per save. That is the right number and a misleading
  one to plan with: the row is at 86% of capacity for a string almost no session displays.
  A budget that reported both the worst case and the worst *recurring* case would let
  someone judge whether 121 px of headroom is comfortable or not. `Game.budget_entries()`
  already returns dictionaries, so a second measurement is a field rather than a rework.
- **`Hud.uproot_armed_message` now takes a bool and two of the corpus's entries differ only
  by it.** That is fine at two forms and it is the shape that goes wrong at three —
  `message_corpus()` has to remember to append every combination, by hand, forever. The
  corpus checker verifies that call sites are covered, not that every *variant* of a
  producer is. A producer with N boolean modes has 2^N strings and only the ones someone
  typed get priced.

### New this cycle (60) — the message row is nearly full and teaching costs permanent space

- **Teaching a one-time lesson in a recurring message is a permanent tax.** The armed
  prompt now points at the move preview, and it cost 185 px of the message row's 306 px of
  headroom — every uproot, forever, to teach something once. `Game.BUDGET_FLOOR`
  (`game/game.gd:1912`) declares 40 px for that row and 121 remain, so it passes and the
  state is `tight`. `RunConfig`'s milestone set (`MILESTONE_PREFIX`, `game/run_config.gd:91`)
  is already a persisted seen-once mechanism, so a first-time-only hint needs no
  save-version bump. That is the shape every future hint should take.
- **The row has one worst case and it is now a tutorial string, not a game event.** Before
  this cycle the widest thing the message row held was the wave prep note; it is now the
  armed-uproot prompt for a Bomb Dandelion. Every plant added from here is measured against
  a sentence that exists to teach rather than to report — so a plant with a long name will
  be refused by a tutorial tip, which is a strange constraint to discover later. Worth
  either capping display names or moving the tip.
- **Nothing distinguishes a message that must be READ from one that merely informs.**
  `MESSAGE_IMPORTANT` (`game/hud.gd:336`) controls queue priority, not appearance. The
  armed prompt carries a four-second irreversible decision and looks exactly like
  "Composted a husk for 3 seeds." A weight, a colour, or a small icon on important
  messages would let a player skip the ambient ones without missing the one that matters —
  and the two-channel rule means it cannot be colour alone.

### New this cycle (59) — the move tool exists; nothing tells the player it does

- **The move preview is complete and undiscoverable.** Arming an uproot and then hovering
  a destination now shows cost and gain together, which is a real tool — and the only thing
  that hints at it is a button reading `Really uproot? (+N)` (`game/hud.gd:1206`). A player
  who arms an uproot is being asked to confirm a deletion, not invited to go looking at
  other cells. One word in that button ("Really uproot? (+12) — or hover to move") or a
  one-shot message the first time a window opens would turn a feature nobody finds into the
  main way plants get repositioned.
- **Nothing commits the move.** The window arms, previews, and then either destroys the
  plant or cancels — the player still has to uproot, re-select from the shop, and pay full
  price. Every piece needed for "click the destination to move it there" now exists:
  `arm_uproot` knows the plant, the preview knows the destination, and `uproot_refund()`
  knows the rebate. Whether a move should be free, cost the difference, or cost full price
  is a balance question worth deciding on purpose rather than by default.
- **`_update_preview` now decides two things and is named for one.** It resolves the hover
  cell AND, since this cycle, which plant the hover is about (`game/game.gd:1598`). That
  second decision is three lines of subject-selection at the top of a function whose name
  promises only "update the preview". It is fine now and it is exactly where a third mode
  would go in badly — the move preview should probably be a named predicate the way
  `new_cover_cells()` and `ring_color()` are.

### New this cycle (58) — the uproot flow is nearly a move tool

- **Arming an uproot shows what is lost but not what is gained.** The rings go red on the
  cells that go bare (`game/sole_cover_marks.gd`), and the hover dots already say what a
  new plant would newly defend — but they are two separate reads. While an uproot is armed
  the game knows both the refund and the plant's kind, so hovering a destination during
  that window could show the dots for *this* plant at *that* cell. That turns two cues into
  a move preview, which is what the player is actually doing.
- **The refund is shown as a number and never as a comparison.** `Uproot (+%d)`
  (`game/hud.gd:1209`) tells the player what they get back; nothing tells them what a
  replacement costs. For a Corn Cobbler the refund and the price are both known constants,
  so "uproot for +12, replant for 20" is a subtraction the game could do and currently
  leaves to the player mid-decision, on a four-second timer.
- **Every cue so far is about coverage; none is about time.** The rings, the dots and the
  dead-ground bar all answer spatial questions. A plant's *rate* is invisible until it is
  selected and read as text (`game/hud.gd:1154` prints damage and interval for a cob). Two
  cobs covering identical cells at different upgrade levels look identical on the board,
  which is exactly the shape of gap that made the coverage-versus-engagement work
  necessary — and the same fix applies: draw the thing that differs.

### New this cycle (57) — the selection panel is full, and that is now a known quantity

- **The selection panel has no room left and nothing prices it.** `_selection_label`
  (`game/hud.gd:720`) autowraps with a 56 px minimum inside a 152 px `SelectionBox`, and the
  VBox comment at `game/hud.gd:1203` says the stack already runs to within 16 px of the
  panel foot. This cycle measured the cob's second line at roughly 190 px of a 232 px box.
  Every one of those numbers is a comment or a measurement taken by hand — there is no
  `hud_selection_panel` entry in `Game.budget_entries()` (`game/game.gd:1957`) beside the
  five that exist. The next person who wants a line there will rediscover the constraint
  the expensive way, exactly as the third-line failure recorded in that header did.
- **Two plants can now be compared, but only one at a time.** Selecting a plant rings what
  it alone holds; selecting a different one replaces the rings. The question a player
  actually has — "which of these two should I move?" — needs both answers at once, and the
  data is already computed per plant by `Game.sole_cover_cells()`. Holding a modifier to
  keep the previous selection's rings on screen would answer it with no new computation.
- **Nothing shows what a plant would hold if it were somewhere else.** The hover dots
  answer that for an unbought plant and the rings answer it for a standing one, but
  "uproot this cob and put it there" is two separate reads the player has to hold in their
  head. Arming an uproot (`Game.arm_uproot`) is the exact moment the game knows a move is
  being considered, and it currently changes only a button's text.

### New this cycle (56) — the garden can now be read, and that suggests what to read next

- **Zero rings on a selected plant is a "move me" signal and nothing says so.**
  `SoleCoverMarks` (`game/sole_cover_marks.gd`) rings the road only the selected plant
  holds, and an empty set now means something concrete: this plant can be uprooted and
  replanted elsewhere at no cost in coverage. That is a genuinely useful state and it is
  currently indistinguishable from "you have not selected anything". A single line in the
  selection panel — "nothing depends on this one" — would turn a silent absence into the
  advice it already is. The uproot flow (`Game.arm_uproot`) is right there.
- **The two cues use different shapes for the same idea and were never seen together.**
  The hover dots are filled 4 px discs in the preview's green; the selection rings are 9 px
  yellow outlines. That was deliberate — they can be on screen at once — but nobody has
  checked what hovering a new plant *while another is selected* actually looks like, and
  the two sets can land on the same cell. A screenshot of that state is a five-minute job
  and the kind of thing `godot-hud-occlusion-audit` exists for.
- **Nothing in the game teaches that coverage is not engagement.** Three cycles have now
  measured it — a cob fires at one pest, so five cobs covering all 32 road cells lose a
  pest that seven covering the same cells stop. The player learns this, if at all, by
  losing. The run summary (`game/run_summary.gd`) already reports beds lost and pests that
  walked in untouched; a line comparing "road covered" against "pests nothing shot at"
  would name the mechanic in the one place a player is reading carefully.

### New this cycle (55) — the hover now answers "what does this buy?"

- **The dots answer reach; nothing yet answers depth, and that is now the honest gap.**
  `PlacementPreview.new_cover_cells()` (`game/placement_preview.gd`) marks the road a
  purchase would newly defend, so "this cob adds three cells, that one adds eight" is
  visible before the seeds go. What it deliberately does NOT say is how thin the road is
  where it is already covered — a cell held by one cob and one held by three look the same
  (they are both undotted). Cycle 54 measured that difference as decisive. The honest next
  step is a depth read on the SELECTED plant rather than the hovered one: select a cob,
  see which of its cells nothing else backs up.
- **`shows_redundant_coverage()` is Sundew-only and its name does not say so.**
  `game/placement_preview.gd:349` reads as a general redundancy cue and is specifically
  about patch stacking — it calls `StickySundew.added_crossing_time_multiplier` and fires
  only when a second patch multiplies crossing time by 1.0. For a Corn Cobbler the same
  word means the opposite thing, since a second cob over identical cells is worth real
  money. A reader reaching for "the redundancy cue" for cobs would find this and be wrong.
  `shows_redundant_patch_coverage()` costs nothing and removes the trap.
- **A plant's own ring never says what its neighbours already hold.** Selecting a planted
  cob draws its range ring (`game/selection_marker.gd` via `Plant`), and the ring is
  identical whether the cob is the only thing covering that road or one of three. The
  hover cue now makes this asymmetry visible: you can see what a NEW plant would add, but
  not what an EXISTING one uniquely contributes — which is the question behind "can I sell
  this one and move it?"

### New this cycle (54) — coverage and firepower are two different pictures

- **The board draws coverage and says nothing about firepower.** A cell covered by one
  cob and a cell covered by three look identical to the player, and `_furthest_along_in_range`
  (`game/corn_cobbler.gd:109`) means the difference is everything: one cob covering eight
  cells is busy with one of them. This cycle proved the gap numerically — five cobs cover
  the whole road and let a pest through, seven cover the same road and do not. A depth cue
  (a second, denser tint where two or more plants reach) would show the player the thing
  the coverage map structurally cannot, and the data is one line: count the plants whose
  reach contains the cell instead of asking whether any does.
- **A minimal garden is a real difficulty setting nobody can select.** The greedy cover
  derived in `test_combat.gd` finds the *smallest* garden that reaches every road cell —
  five cobs on the current road. That is a genuinely interesting constraint to play under
  and it already computes: "the fewest plants that reach every cell" is a puzzle-mode seed,
  or a par score shown on the run summary (`game/run_summary.gd`). The player currently
  gets no signal at all about whether their garden was efficient or merely large.
- **Dead ground moved in opposite directions for the two reaches and nothing said so.**
  Cycle 53's reshape took Corn dead ground from 15 to 11 and Chomp from 34 to 36
  (`test/unit/test_placement.gd`). A player who has learned "the top-right corner is
  useless" from one board has learned something false about the next. If a second road
  ever ships, the per-plant dead-ground cue is the only thing that will tell them — and it
  only appears once they are already holding a plant, at placement time.

### New this cycle (53) — the road can change now, and that is newly interesting

- **A second road is now a much smaller job than it looked.** `PATH_CORNERS`
  (`game/board.gd:50`) was reshaped this cycle and the five shape-dependent tests were
  re-derived rather than re-fitted — which means the cost of a road change is now *known*
  and written down, not feared. The invariant trick is the reusable part: hold 32 cells and
  2112 px and nothing reasoned from length or cell count moves at all. A `PATH_CORNERS`
  that varied per level, with the dead-ground and garden figures derived at test time
  instead of recorded, would turn "another road" into a data change. That is the real
  unlock behind `-84x0`, and it is worth more than the climb was.
- **Coverage is not engagement, and only one test knows it.** Six cobs reach all 32 road
  cells and still let a pest cross unfought, because `_furthest_along_in_range`
  (`game/corn_cobbler.gd:109`) picks exactly one target. The board's coverage cue tells a
  player a cell is covered; it cannot tell them the plant covering it is permanently busy.
  A second cue — "covered, but by a plant already committed" — is a real UX idea and the
  data is already computed for the over-promise tests.
- **The board has two big empty clearings now and nothing draws the eye to them.**
  The reshape opened enough space that the short-reach Chomp strands 36 of 94 cells
  (`test/unit/test_placement.gd`), up from 34. The dead-ground cue exists per-plant at
  placement time, but a player scanning the board before picking a plant sees uniform
  grass. A faint, permanent tint on ground *no plant in the catalogue* can use would say
  "this is scenery" without teaching anything false.

### New this cycle (52) — the row is solved; the same shape is everywhere else

- **`WORST_CASE_TEXT` is the message row's problem, one row up, and still unsolved.**
  The message row now has `Hud.message_corpus()` (`game/hud.gd:1659`) plus a checker that
  ties every `show_message()` call site to it. The STATS row has `WORST_CASE_TEXT`
  (`game/hud.gd:76`), which is still a hand-typed table of worst-case strings with no
  equivalent tie to the code that renders them — cycle 51 added assertions that the *set
  of readouts* matches, but nothing checks that `"Seeds  99999"` is actually the widest
  thing `_seeds_label.text` is ever assigned. `_wave_label.text` is built at
  `game/hud.gd:1049-1058` from three separate branches; the declared worst case is one
  string someone wrote. Same defect class, one row higher, and now much cheaper to fix
  because the pattern exists.
- **Six `show_message()` durations are hand-picked and nothing relates them.**
  4.0s (eaten), 5.0s (packet), 6.0s (wave cleared), 8.0s (opening hint), 2.0s (uproot
  cancelled, husk swept), 2.5s (mute, colourblind) — at `game/game.gd:264`, `:415`,
  `:1197`, `:1320`, `:1408`, `:1465`, `:1485`, `:1617`. A message the player must read to
  act on (the opening hint) and one that is pure confirmation (uproot cancelled) are four
  seconds apart, which is probably right, but nothing says the rule. Reading time scales
  with length, and the corpus now knows every length — a duration derived from character
  count with a floor would make the 8.0 and the 2.0 consequences of one decision.
- **The waiver reasons are the best documentation of the message system and live in five
  scattered comments.** `game/game.gd:231`, `:1398`, `:1465`, `:1469`, `:1634` each carry
  a `# message-corpus-check: ok - <reason>` that says something true and non-obvious about
  why that text cannot be measured statically. That is a good use of waivers, but it means
  the answer to "what can the row show that we cannot price?" is assembled by grep — which
  is the exact failure the corpus just fixed one level down.

### New this cycle (51) — two hand-lists describe one row, and neither knew about the other

- **The top bar's four readouts are described by three separate hand-lists.**
  `Hud.WORST_CASE_TEXT` (`game/hud.gd:76`) declares each readout's worst-case string,
  `Hud.stats_row_budget()` (`game/hud.gd:944`) sums four width constants, and
  `_add_stat()` is called four times in `_build` (`game/hud.gd:598-601`) to create them.
  Three lists, one row, and until this cycle nothing compared any pair. Both gaps are
  closed by assertions now, but the *structure* is still three lists — the durable fix is
  one table of `{name, worst_case_text, width}` that `_build`, the budget and the tests
  all read. `derive-the-list` says the recorded-list-plus-equality-assertion form is
  legitimate; it does not say three of them are.
- **`show_message()` has eight call sites and no single place says so.**
  `game/game.gd:231` (purchase refusal), `:1465` and `:1469` (mute), `:1634` (placement
  refusal), plus the four `Hud.*_message` producers. The message-row budget had to
  enumerate them by grepping call sites, got it wrong once, and got it wrong again a
  cycle later. A `Hud` surface that names its own message producers — even just a comment
  block listing them beside `_paint_message_row` — would make the budget's corpus
  checkable instead of archaeological.
- **The wave-cleared line and the prep note both compete for one row, and the player can
  lose the second to the first.** `_paint_message_row` gives a transient message
  precedence over the standing note (verified in cycle 48), and `wave_cleared_line`
  (`game/hud.gd:1655`) fires exactly when the prep note becomes relevant — at the end of
  a wave, when the player wants to read what is coming. Worth checking whether the
  cleared line's duration overlaps the window in which someone is deciding what to plant.
  This is a design question, not a defect: the precedence is deliberate and documented.

### New this cycle (50) — the road never climbs, and a mutation sweep that proved nothing

- **The road never travels up-screen, so a quarter of the pest art is unreachable.**
  `Board._build_route()` (`game/board.gd:162`) walks `_path_order` and the shipped level
  runs right, down, left, down, right — read live off a pest's `_route`, thirty-four
  points, not one of them a -Y step. `Pest._update_facing()` (`game/pest.gd:679`) has a
  `_facing = 0.0` branch for up-screen travel that no frame of a real game has ever run,
  and until this cycle no test touched it either. A level whose road **climbs** would use
  art that already exists and a code path that already works — the cheapest new-level
  variety available, and it makes the vertical axis mean something in both directions.
- **`assert_margin` is available and used almost nowhere.** `_T.assert_margin(values,
  threshold, margin, recorded)` gates a tuned constant on the corpus items sitting near
  it, which is exactly the shape of the pest gait constants (`game/pest.gd:235-245`) and
  the weather multipliers (`WEATHER_DROUGHT_SEED_BONUS`, `WEATHER_RAIN_HEAL_FRACTION` in
  `game/wave_director.gd`). Filed for the gait ones as `-frzz`; the weather ones have the
  same shape and no bead. A tuned constant with a documented justification and no test is
  a comment, not a contract.
- **The pest corpse keeps its facing, and nothing else about death is visually directional.**
  `test_a_pest_killed_mid_stride_leaves_a_straight_corpse` (`test/unit/test_selftest.gd`)
  asserts a corpse lies on its facing with the gait lean undone — a genuinely nice touch
  that already ships. The adjacent idea it suggests: pests killed by different means could
  die differently (a Chomp bite versus a kernel versus a seed bomb), which currently all
  produce the same straight corpse. Cheap juice on a system that already has the hook.

### New this cycle (49) — a user request that already ships, and a checker that was checking a stub

- **"Fix enemy facing direction" (in *Requested directly by James*, above) appears to
  already ship — do not start it without looking at the screen first.**
  `Pest._update_facing()` (`game/pest.gd:679`) picks all four cardinal rotations from the
  direction of travel, `_apply_facing()` (`game/pest.gd:696`) is the single writer of
  `_sprite.rotation` and composes facing with the gait sway rather than either clobbering
  the other, and `test/unit/test_selftest.gd:8378` asserts exactly that composition.
  The header at `game/pest.gd:675` names STYLE.md's up-screen (-Y) convention as rotation
  0 and the other three as 90-degree turns off it.
  **This is not a "delete the entry" verdict.** The request was made about what the screen
  looked like, and the code implementing a thing is not evidence the screen shows it. If
  pests still read as facing wrong, the defect is downstream — the sprite art's rest
  orientation not actually being up-screen, or a species whose art disagrees with the
  convention — and that is a different and much smaller job than "implement facing".
  Someone should look at a running game before this is either worked or closed.
- **A horizontal rule in the Workflow block silently truncated the mirror comparison.**
  Fixed this cycle (`tools/mirror_check.py`, `truncation_warning()`), but the shape is
  worth keeping in mind for the other checkers: `ENDS` contained `
---
`, ordinary
  markdown, so both files stopped at the rule and two 21-character stubs compared
  identical. Every house checker that scopes by a text marker has this failure available
  to it. The guard that catches it is cheap — assert the region you measured is as big as
  you expect — and it is the same denominator rule the house-static-checker skill already
  states for finding counts, applied to the input instead of the output.
- **Pest gait constants are tuned but not gated.** `GAIT_SWING` 0.13, `GAIT_RATE` 8.5,
  `GAIT_REFERENCE_SPEED` 60.0, `GAIT_RATE_MIN` 0.55, `GAIT_RATE_MAX` 1.9
  (`game/pest.gd:235-245`). The header explains the reference speed with real reasoning —
  between the aphid's 78 and the beetle's 38 — which is exactly the kind of constant
  `_T.assert_margin(values, threshold, margin, recorded)` exists to gate: it checks the
  corpus items sitting near a tuned value, so a new species added at speed 61 would show
  up instead of silently landing on the boundary. Nothing currently asserts these.

### New this cycle (48) — weather has an upside now, and a budget was measuring half its row

- **Rain should pay something too, or drought's bonus makes rain strictly worse.**
  `WaveDirector.seed_multiplier_for()` (`game/wave_director.gd`) returns
  `WEATHER_DROUGHT_SEED_BONUS` (1.5) for drought and 1.0 for everything else, so rain is
  now the only weather with a downside and no compensation — it heals pests
  (`WEATHER_RAIN_HEAL_FRACTION`) and pays base rate. A player reading the forecast has one
  weather they want and two they don't. Options: rain pays a smaller bonus, or rain gets a
  non-seed upside (faster regrowth, a free replant), or drought's bonus shrinks and rain's
  heal shrinks with it. This is the direct consequence of shipping 4c1l and it is worth
  deciding on purpose rather than letting drought stay the good one by accident.
- **The other five budgets have never been checked against the corpus they claim.**
  `_budget_hud_message_row` (`game/game.gd:2163`) measured four plant-name messages and
  not the prep note that shares the row, and was wrong by 36px for seven cycles while
  reporting green. `Game.budget_entries()` (`game/game.gd:1881`) builds six others the same
  way. Each one names its corpus in an `evidence` string; nothing checks that the string
  describes what the code sweeps. A checker could compare the two — or, cheaper, one pass
  reading all seven and asking "what else can reach this measurement?" The failure is
  silent by construction: a budget over a subset always reports more headroom than exists.
- **The prep note is measured at a wave number the game cannot reach.**
  `_budget_hud_message_row` now measures `Hud.next_wave_note(999, 9999, ...)`
  (`game/game.gd:2040`), deliberately — a budget is about what the format allows. But
  `Hud.next_wave_note()` (`game/hud.gd`) formats the wave number with no width cap, so the
  budget's worst case is set by a digit count nothing constrains. Either cap the formatted
  number, or say in the note's own header that its width is bounded by the budget and not
  by the format.

### New this cycle (29 of 30) — comments that make checkable claims, and one that was false

- **Five comments in `game/` name a devtools verb and one of them named a verb that
  does not exist.** Both `commit_uproot` headers said "the devtools verbs and the
  placement tests" call it; `list-commands --offline` has nothing matching `uproot`.
  The other four (`collect_husk`, `place_plant`, `start_wave`) check out. **A comment
  naming a verb is an assertion**, and `list-commands --offline` can settle it with no
  game running — so this class is checkable, cheaply.
- **Nine comments name a `test_*` function**, eight of which exist; the ninth is
  `test_selftest`, a FILE name rather than a function. This project leans hard on
  "the alarm is test_X" as documentation, and a renamed test silently turns that into
  a lie. High precision, low volume — a checker would be clean today and thin. Worth
  building only alongside the verb check above, as one "comments that cite something"
  pass.
- **`list-commands --offline` is the cheapest audit tool here and is documented as a
  discovery aid.** `CLAUDE.md` describes it for finding verbs in a running session;
  its `--offline` mode parses the registration sites statically, which is what makes
  "does this verb exist" a free question. Worth calling that out where the verb table
  lives.
- **A backtick in a shell pattern executed again this cycle** (`addons: command not
  found` from a grep). Standing lesson 20 in the global log was corrected in cycle 39
  from "stripped" to "executed"; this is the same trap in a *pattern* rather than a
  `--description`. The fix is the same and wider than either: **prose and patterns go
  to argv, never through a shell string.**

### New this cycle (28 of 30) — a node with no name is a node nothing can address

- **123 `add_child` calls in `game/`, 93 `.name =` assignments.** The selection marker
  was one of the gap: it drew on every selected plant and its path was
  `@SelectionMarker@31`, addressable from no test and no bridge command, in a project
  whose `OverlayScreen` header says outright that node paths are a contract. The
  difference between the two numbers is not all defects — a throwaway ColorRect needs
  no name — but **nothing distinguishes "deliberately anonymous" from "nobody thought
  about it"**, and the marker sat in the second group for many cycles.
- **A checker could ask this and would need a rule for "worth naming".** The honest
  candidate: a node that is `add_child`ed AND stored in a member variable is something
  the code will refer to again, so a test or the bridge probably wants to as well. That
  is derivable; "a bare `add_child(ColorRect.new())`" is derivably not.
- **`request_uproot` arms and `uproot_selected` removes**, and the names do not say
  which is which (`game/game.gd:1235`, `:1200`). I called the wrong one while writing
  this cycle's test and it silently uprooted the plant instead of arming. A caller that
  guesses wrong destroys a bed; the pair wants renaming to `arm_uproot` /
  `commit_uproot`, or one entry point with a flag.
- **The armed-uproot cue and the armed-reset cue now use different second channels** —
  a bullet mark on the Keys screen, line weight on the board — because a Label and a
  `draw_line` shape have different vocabularies. That is correct per surface and means
  **the project has no single answer to "what does armed look like"**, which is the
  kind of thing that drifts. Worth writing the pair down next to `GardenTheme.DANGER`.

### New this cycle (27 of 30) — a green test proved nothing, and the suite cannot tell

> Audited cycle 108 (`plant-tower-defense-0x2j`), together with the two sections below
> it — sections 27, 26 and 25, twelve entries, the second of the two independent
> "N of 30" runs in this file. (The first was audited at cycle 64 and came out 6 shipped
> / 2 stale / 0 wanted. This one came out **2 shipped / 0 stale / 1 drifted / 8 still
> real / 1 unresolved**, which is the opposite result: this run is mostly live work, not
> history. Cut by line number, never by heading — `### New this cycle (24 of 30)` exists
> twice in this file under two different subtitles, which is how cycle 64 nearly deleted
> 1937 lines instead of 85.)
>
> Two entries were removed as shipped. **"One test holds node references across an
> `await`"**: `test_corn_shoots_the_pest_closest_to_escaping` now asserts
> `is_instance_valid(near) and is_instance_valid(far)` immediately after
> `await _T.instantiate_scene(host)` and returns early if either has gone, so the
> targeting answer below it can no longer be about a set of one. **"`_furthest_along_in_range`
> dereferences without checking the reference"**: the guard shipped at `game/plant.gd:616`
> under `plant-tower-defense-or67` / gh#43. That entry cited `game/plant.gd:412`, which
> today lands inside `_make_world_controls_click_through` — a real line in a different
> function, which is precisely the drift `citation_check` says in its own NOT COVERED
> text that it cannot see. Everything still listed here was re-checked against the code
> and is still true; where the code moved under an entry, the entry was rewritten rather
> than deleted.

- **The suite reports assertions executed and cannot report assertions that MEANT
  something.** `test_corn_shoots_the_pest_closest_to_escaping` ran its assertion every
  time and compared two freed references; `Assertions: 12143 executed` counted it.
  `[VACUOUS]` catches a test that ran *zero* assertions and nothing catches one whose
  operands were both nothing. A cheap approximation exists: **an equality assertion
  where both sides are the same object reference is almost always a mistake** — worth a
  `_T.assert_eq` guard that refuses `a == a` on identical instance ids.
- **Nothing in the suite asserts that a hosted node is still alive when the test ends.**
  `_T.free_ui(host)` is called on every test that hosts, and a node that freed itself
  in between is indistinguishable from one that did not. A single line in `free_ui`'s
  neighbourhood — count what was hosted, count what survives — would have surfaced this
  defect as a warning on the very first run.
- **Three test files build pests with hand-set `_leg` values against hand-written
  routes** (`test_combat.gd`, `test_selftest.gd`, `test_board.gd`), and the relationship
  between "route of N points" and "the last leg you can sit on" is re-derived by eye
  each time. It is `_route.size() - 2`, it is written down nowhere, and getting it wrong
  by one is exactly this cycle's bug. A `Pest.last_survivable_leg()` — or a test helper
  that places a pest *at a fraction of its route* — removes the arithmetic.
- **`Dandelion.best_target()` is the last targeting function that dereferences a pest
  without checking it is still there.** Rewritten at the cycle-108 audit, because both
  halves of what this entry originally said have since moved. It read
  "`Plant._furthest_along_in_range` is the only targeting function in the game, and three
  plants pick targets by other means; none of them guards against a stale reference
  either". The guard shipped (`game/plant.gd:616`, `if pest == null or not
  is_instance_valid(pest)`), and the roster grew — `Nettle` now routes through the same
  function (`game/nettle.gd:209`), so it is no longer one function against three
  exceptions. Of the plants that still pick their own way, `ChompFlower` and
  `StickySundew` both guard. `Dandelion.best_target()` (`game/dandelion.gd:215-231`)
  reads `pest.global_position` twice — once building `here`, once measuring `RANGE` —
  and `game/dandelion.gd` contains no `is_instance_valid` call anywhere in the file.
  Same defect, one plant left, and the fix is the same three lines.

### New this cycle (26 of 30) — what a reverted upgrade exposed about our own tests

- **Nothing in this project records what the suite counted before a dependency
  changed.** The bisect that proved gh#43 rested on a number I happened to take by
  hand. `.devtools/verify-runs.jsonl` records `tests.total` per run, so the history is
  already there — a `verify_ledger.py stats` line reading "552 for the last 12 runs"
  would have made the regression obvious without the manual before-measurement.
- **The scaffold skill's paths are pinned to whatever plugin version the cache holds**
  (0.33.0 here, against a project on 0.38.0 and a newest cache of 0.42.0). The
  installer's downgrade guard catches the dangerous case, but nothing warns when the
  skill is simply *stale* — worth a note in the local skills that the first thing to
  check on any harness operation is which version the paths point at.

### New this cycle (25 of 30) — three screens learned the same lesson separately

- **`set_active(bool)` now exists three times under three names.**
  `TitleScreen._set_menu_active`, `PauseScreen._set_card_active` and `Hud.set_active`
  are the same eight lines — focus mode and mouse filter over a list of buttons — and
  each was written when its own screen got caught. Three copies is where an idea
  becomes a helper, and the natural home is `OverlayScreen`, which is what opens over
  all three. **It should also be the thing that CALLS them**: an overlay knows when it
  opens and closes; today each opener remembers to, and the HUD's opener forgot for
  many cycles.
- **Nothing asserts the invariant, only the instances.** The new test checks the HUD
  goes inert behind the pause card; the equivalent for the title menu and the pause
  card are separate tests written at separate times. The invariant is one sentence —
  *nothing behind a full-screen backdrop is focusable* — and it is checkable in one
  sweep: walk every `Control` under a lower `CanvasLayer` while an overlay is up.
- **The `ui_findings_baseline.json` now hides twelve real overlaps.** They are
  accepted because both controls are unreachable, but the baseline is keyed on
  (rule, node path), so a genuine overlap arriving later at the same pair is silent.
  Filed upstream as gh#42 to make the check reachability-aware; until that lands the
  baseline is load-bearing and should be re-read, not carried forward blindly.
  (Cycle-108 audit: the premise still holds — `[G-055] status: open` at
  `log-devtools.md:4170`, gh#42 not landed. The count of twelve could not be
  re-derived, and cannot be from a checkout: the baseline lives under `user://`, not
  in the repo. Treat the number as the day's observation, not as a standing figure.)
- **The plant bar is built from the catalogue and the packet bar from a tier list**,
  and `interactive_controls()` had to know both. A HUD that could name its own
  interactive set — one list, built where the buttons are built — would have made
  this a one-liner instead of a collector with two loops and a null guard.

### New this cycle (24 of 30) — glyphs are a vocabulary, and this game has two

- **The game draws glyphs from two sets that can collide, and nothing knows it.**
  `KeyBindings.SHORT_NAMES` (`game/key_bindings.gd:129`) owns ←, →, ↑, ↓ as KEY NAMES;
  the UI owns ← for "back" (`OverlayScreen.BACK_TEXT`), · as a separator, — as a dash,
  ∞ for endless, • as this cycle's revert mark. A glyph used for both is exactly the
  bug caught by screenshot this cycle. **One table naming every glyph and what it
  means** would make a collision a lint rather than a picture — and there is already a
  `derive-the-list` shape here: the UI's marks must not intersect
  `SHORT_NAMES.values()`.
- **Nothing checks that a glyph the game draws actually exists in the font.** A missing
  glyph renders as a `.notdef` box with a real width, so `GardenTheme.measure()`
  returns a plausible number and every budget passes. The only way this project has
  ever caught one is by looking at a screenshot. `Font.has_char()` exists.
- **`_set_card_active` is a pattern with one implementation and three screens that
  need it.** `PauseScreen` makes its own buttons inert under an overlay
  (`game/pause_screen.gd`); `TitleScreen._set_menu_active` does the same for its menu;
  the HUD does neither, which is `plant-tower-defense-csrc`. Three copies of an idea
  is where it becomes a shared helper — on `OverlayScreen`, which is what opens over
  all of them.
- **The armed reset is the only place this game shows a pending destructive change.**
  Uproot arms for 4 seconds and says so in a message; the plant it will remove is not
  marked. Same two-channel treatment, same reasoning, and `Game._uproot_left` already
  carries the armed state.

### New this cycle (23 of 30) — seven budgets now, and the shape they share

- **Every budget in this project prices a WIDTH, and the road ceiling is the only one
  that does not.** `husk_click`, `hud_readouts`, `hud_message_row`, `hud_stats_row`,
  `notebook_subhead` and `road_shape` are all "does this fit"; `pest_road_ceiling` is
  the only one pricing a game-design coupling (`game/game.gd`, `BUDGET_FLOOR`). The
  machinery is general and is being used for one kind of question. **Rate of fire
  against pest health, seed income against plant cost, and the compost payout against
  the packet prices are all couplings nobody can currently see spending.**
- **`GardenTheme.measure()` is now load-bearing for three budgets and four tests**,
  and it is a detached Label resolving a theme that no test asserts is the same theme
  the game uses. `test_the_cards_own_measurement_agrees_with_the_labels_it_builds`
  checks it for the pause card's font only; the message row measures at
  `MESSAGE_FONT_SIZE` and nothing compares that path against a real Label.
- **A budget with a floor nobody has approached is a guess.** `hud_message_row` was
  declared at 40px with 342px of headroom — the floor is a number I picked, not one
  anything has tested. The budgets that have been *spent* (`hud_readouts` at 10,
  `hud_stats_row` at 19) earned their floors by being pushed through them; the others
  are placeholders wearing the same clothes, and `cmd budgets` reports them
  identically.
- **Nothing prices the side panel**, which is the widest column of text in the game
  (`Hud._build_side_panel`) and carries the plant names, the blurbs and the prices —
  all of them content-driven, all of them growing when a plant is added, and none of
  them measured. It is the same defect class as the message row, one panel over.

### New this cycle (22 of 30) — the one-owner pattern, and where else it is missing

- **The banner has the same two-writer shape the message row just lost.**
  `_show_banner` is private with two public callers (`announce_wave`,
  `announce_wave_cleared`) and `show_weather` added a third
  (`game/hud.gd`), and `_fade_banner` runs on a timer. That is exactly the
  arrangement that produced two defects on the message row — several writers, one
  Control, timing between them — and the banner has no painter. It has not bitten
  yet because every claim on it is transient; the first standing one will.
- **`_idle_message` is the only claim with no priority.** `show_message` has
  `MESSAGE_NORMAL` / `MESSAGE_IMPORTANT` ordering transient lines against each other,
  and the standing note sits outside that as "the floor". Right with one note, wrong
  the moment there are two — and there is already an obvious second (an economy line
  saying what the player can afford, filed separately).
- **The last-wave note is the only place the game says a run is nearly over.** The
  prep strip, the wave counter and the threat number all describe the next wave
  without ever saying how much game is left. `WaveDirector.WAVES.size()` is static and
  `current_wave` is on every state dict, so "3 waves to go" is available everywhere
  and used nowhere.
- **Nothing tests that the message row is readable at its worst.** The note's width
  is asserted (`test_the_prep_note_says_what_the_next_wave_is_worth`), but
  `show_message` takes arbitrary text from a dozen call sites and the Label clips.
  The same `WORST_CASE_TEXT` treatment the top bar's four readouts get would catch a
  refusal string nobody measured.

### New this cycle (21 of 30) — grown from a Label two systems both write to

- **Three things now write `MessageLabel` and none of them knows about the others.**
  `show_message` (the priority queue), `_advance_message_queue` (expiry) and
  `_refresh_prep_note` (the standing note) all set `.text` on one Label
  (`game/hud.gd`), and the two defects this cycle were both about the seams between
  them. It works, and it works because each writer checks `_message_left` and the
  current text by hand. **A row with one owner and a stack of claims** — highest
  priority wins, the note is the floor — would make the arbitration a rule instead of
  three conventions that happen to agree.
- **`show_message` has a priority system the standing note does not participate in.**
  `MESSAGE_NORMAL` and its siblings order transient messages against each other, and
  the note sits outside that entirely as "whatever is left when nothing is speaking".
  That is right today with one standing note and wrong the moment there are two.
- **The prep note says what is coming and not what it costs.** It names the pest
  count, a queen and the weather; the player is deciding what to BUY, and the seed
  prices are on the side panel while the threat is on the strip. A note that said
  "you have 45 seeds and the packet is 45" is the actual decision — and needs the
  economy, which `SeedBank` has and the HUD state dict already carries.
- **Nothing says a wave is the LAST one.** `has_more_waves()` goes false and the note
  disappears (correctly — there is no next wave), so the run's final wave is the one
  moment with the least information and the most at stake. "Wave 16 next — the last
  one" is a one-branch change in `next_wave_note` and a real beat.

### New this cycle (20 of 30) — grown from the first animation this game asserts

- **The roll is the only animation in this game with a test, and there are eleven
  others.** `_arm_record_ratchet` (`game/title_screen.gd`) is asserted three ways —
  the renderer, the origin, and the final text before any tween. Every other tween
  here (`Plant._pop`, `PauseScreen._play_entrance`, `TitleScreen._play_entrance`,
  `Hud._punch_readout`, the husk fade, the banner fade) is verified by nobody, and
  headless cannot see any of them: `GardenTheme.animations_enabled()` is false there
  by design. **The pattern that made this one testable is worth generalising** — a
  pure renderer for the moving value, a final state set before the tween exists, and
  a callback that restores it if the tween is interrupted.
- **`set_game_speed` is what makes an animation observable at all**, and nothing says
  so. At 1.0 a 0.8s roll finishes inside a single bridge round-trip; at 0.05 it is
  four polls wide. That is a fact about every tween in this project and it is
  currently folklore — it belongs in the local skills, next to the harness notes on
  reading a running game.
- **Nothing rolls the seeds counter**, which moves far more often than the record
  does. `Hud._punch_readout` scales it on change (`game/hud.gd`), so the machinery for
  "this number moved" already exists and stops short of showing the movement. A
  purchase that costs 45 seeds reads as a jump; the same roll would make the price
  visible as it is paid.
- **A first-ever record is silent by design and that may be the wrong call.** The
  roll refuses when `previous_best` is 0, because counting up from a zero the player
  never held is a lie. But a first record is the most significant one they will set,
  and it currently gets less than a later, smaller one. A different treatment — not a
  roll — is the honest answer.

### New this cycle (19 of 30) — grown from the gap ledger, which is the fourth derived-status file here

- **Four files in this project record a status per entry and cannot answer "what is
  open".** `log-devtools.md` had 69 status lines over 49 ids (fixed this cycle by
  `tools/gap_ledger.py`); `kanban.md` has the same shape — an idea's real status is
  whichever of its mentions is newest, and cycles 34 and 36 each found a section
  where the newest mention was "shipped" and the heading still said "not filed yet".
  A `kanban_ledger` is the obvious sibling, and the reason it has not been built is
  that kanban entries have no ids to key on. **Giving them ids is the enabling
  change**, and it is small: a `[K-NNN]` on each entry under the idea backlog.
- **`.devtools/verify-runs.jsonl` is the one that got this right**, and is worth
  copying rather than admiring: one row per run, append-only, with
  `verify_ledger.py stats` deriving the summary. Nothing in it is ever rewritten.
  That is the same rule `gap_ledger.py` now applies to prose, and the difference is
  only that the ledger was designed for it and the log was not.
- **The `seen:` count is the most useful field in the gap log and nothing derives
  it.** G-044 reads `seen: 7`, which is the single strongest signal in the file —
  seven independent sightings of one defect. It is incremented by hand, and this
  cycle found ids where a later entry re-described the same gap without bumping it.
  `gap_ledger.py` already parses every mention; counting them IS the seen count.

### New this cycle (18 of 30) — the top bar is full, and that is now a measured fact

- **The top bar has 10px left and four readouts.** `Hud.WORST_CASE_TEXT["WaveLabel"]`
  measures 302px in a 312px slot, and the stats row as a whole is within 19px of its
  own maximum (`Hud.stats_row_budget()`, floors in `Game.BUDGET_FLOOR`). Anything the
  game gains that wants a permanent readout — weather, a combo, a modifier, a timer —
  has nowhere to go. **The next feature that needs bar space pays for a second bar
  row, not for a squeeze**, and that is a piece of work worth doing before it is
  urgent rather than during.
- **A second stats row is the obvious shape.** `TopBar` is already a container with
  `StatsRow` inside it and the constants for a two-row bar are already named
  (`BAR_ROWS` and the gap constants at the top of `game/hud.gd`). The work is the
  layout, the budget declarations for the new row, and deciding what moves down.
- **Nothing shows the player what a wave is worth before they fight it.** The bar
  shows `threat 2`; the prep gap is where a player decides what to buy, and the
  decision is "can I afford to be wrong". `WaveDirector.threat_for()` and
  `pests_in_wave()` are both static and both already exist — a "next wave" line in
  the prep gap would cost no bar space at all, because the banner slot is free
  between waves.
- **`Plant.fire_interval_scale` applies to two plants and there are five.** Chomp,
  Sundew and Sunflower pace themselves by other means (`is_busy()`, droplets, a
  growth gauge), so a drought slows the two shooters and leaves the other three
  untouched. That is arguably correct — a drought should hurt shooting, not chewing —
  but it is currently an accident of which plants read the multiplier, not a decision
  anyone wrote down.

- **Weather has no counter-play.** Rain and drought (`WaveDirector.weather_for`,
  `game/wave_director.gd`) arrive and are simply true — the player watches. The
  design brief's own version had one ("unless a plant sits next to water"), and it
  was dropped because the board has no water: `Board` is grass and dirt road only
  (`game/board.gd:56`, `GRASS_EDGE_TILE` maps four-neighbour masks over exactly two
  materials). A drought you can plan around is a mechanic; one you can only endure
  is a difficulty modifier wearing a mechanic's clothes.
- **Water tiles are the missing terrain, and they cost more than they look.**
  `Board.PATH_CORNERS`' header already warns that three numbers in other files were
  measured against the road this route produces and nothing recomputes them. A third
  material means placement rules, the edge-tile mask table, and that budget. Worth
  doing deliberately or not at all.
- **Weather is invisible between waves.** `Hud.show_weather` fires a banner as the
  wave opens and the banner fades; there is no standing readout, so a player who
  looks away has no way to ask "why is my corn slow". The top bar has `threat` and
  `Wave 2 / 16` and room beside them.
- **A drought wave is worth more compost, and nothing says so.** The run economy
  (`SeedBank`) does not know weather exists, so surviving the hardest version of a
  wave pays exactly what the easy version pays. The wave table's own threat curve is
  the natural place to hang it — `threat_for()` already exists and already rises.

### New this cycle (16 of 30) — the pause card learned to measure itself; four screens have not

- **Four more panels are hand-picked rectangles**, and the pause card just spent two
  cycles demonstrating what that costs: `KeyBindingScreen.PANEL`
  (`game/key_binding_screen.gd:76`, 700x600), `NotebookScreen.PANEL`
  (`game/notebook_screen.gd:31`, 1000x584), `OptionsScreen.PANEL`
  (`game/options_screen.gd:109`, 700x360), `RunSummary.CARD`
  (`game/run_summary.gd:51`, 640x456). Each is correct against today's contents and
  says nothing when the contents grow. The pause card's own header narrates three
  such numbers going stale in a row. `PauseScreen.card_width()` /
  `card_height()` are now the worked pattern, and `_measure()` is a nine-line static
  helper the others could share — the Keys screen is the sharpest case, because its
  rows carry the same player-chosen key names that broke the legend.
- **The keys column exists on two screens now and is aligned on one.** After this
  cycle the pause card right-aligns its keys against a gutter
  (`game/pause_screen.gd:_build_key_list`); `KeyBindingScreen` centres its `RowKey%d`
  labels in a fixed 140px column (`KEY_X`/`KEY_WIDTH`, `game/key_binding_screen.gd:85`)
  which is neither derived nor aligned with the pause card's. Two screens showing the
  same eight keys in two different alignments is the kind of thing nobody reports and
  everybody notices.
- **`_measure()` is private to PauseScreen and wants to be shared.** It resolves the
  font a Label will actually draw in, off-tree, which is the one primitive every
  "does this text fit" question in this project needs — and there are now three such
  questions in the suite (`_T.text_width` in the legend tests, the reset
  confirmation's fit assertion, this cycle's agreement test). A `GardenTheme.measure()`
  would put it where `GardenTheme.INK` already lives.

### New this cycle (15 of 30) — grown from the pause card, after widening it

- **The pause card is 440px wide and its two widest rows are 384px.** `CARD_WIDTH`
  (`game/pause_screen.gd:86`) is now sized for the worst key name a player can bind,
  which means it is oversized for the ~100% of sessions where nobody has rebound
  anything. A card that measured its own contents — the same rule `card_height()`
  already follows two constants above it — would be 360 for most players and 440 for
  the one who bound "On-screen keyboard". The blocker is that `card_rect()` is
  `static` and answers before any instance exists, so it has no font to measure
  through; solvable by measuring once at build time and re-centring, and worth doing
  because the height already proved the pattern.
- **A legend row could put the key in its own column.** `_key_row_text()`
  (`game/pause_screen.gd:654`) is `"%s   %s"` — one string, one Label, so the key and
  the phrase share a width budget and the long one eats the short one. Two Labels at a
  fixed column split would let the key be as long as it likes without touching the
  phrase, and would line the keys up vertically, which the pause card is the only
  screen that does not do (the Keys screen already has a `KEY_X` column at
  `game/key_binding_screen.gd:85`).
- **Nothing shows a player their own rebinding outside the two screens that own it.**
  The HUD's "Grow the next wave" button (visible in every pause screenshot) has a
  keyboard verb behind it and never says so. A key hint on the HUD's own buttons,
  drawn from `KeyBindings.label_for()`, would make a rebinding visible where the
  player actually is — and it is the third surface that would need the width
  discipline the card just learned, which argues for the column split above first.
- ~~**`Game.key_help()` returns every action, including the notebook's pager.**~~
  **Wrong — checked while writing the citation, which is the point of the rule that
  requires one.** `key_help()` iterates `KeyBindings.actions_in(SCOPE_RUN)`
  (`game/game.gd:50`), so the scope filter this entry proposed has been there all
  along; the pause screenshot shows five rows and no pager verbs. Left in, struck
  through, as the second worked example beside the milestone shelf above: the
  difference is that this one cost thirty seconds instead of a claimed bead, because
  the rule added last cycle made me open the function before describing it.

### New this cycle (14 of 30) — grown from the keys screen, each with the line that proves it is not already built

**Every entry here names a file:line.** Last cycle's batch did not, and three of its
five entries were wrong — one proposed a feature that already ships (the milestone
shelf), one was built on a claim about `fresh_record` that is false, one over-claimed
its scope. An entry written from the neighbourhood of the file you happen to be in is
a guess about the rest of the codebase. See `.claude/skills/kanban-staleness-audit`.

- **The rows should mark themselves while the reset is armed.** The new confirmation
  names the keys it will take (`game/key_binding_screen.gd:reset_all`), but the note is
  one 700px `clip_text` line and that is already the binding constraint — it had to drop
  the verb phrases to fit. The rows directly above have all the room in the world and
  currently do not change at all when the reset is armed (`refresh()` only ever reads
  `_listening`). Tint the moved rows, or mark their key cell, so "what am I about to
  lose" is answered where there is space to answer it.
- **`KeyBindings.SHORT_NAMES` covers 8 of the ~100 keys a player can bind**
  (`game/key_bindings.gd:121` — Esc, the four arrows, Space, and two Enters). Everything
  else falls through to the engine's own name, which is fine for `F1` and poor for the
  punctuation keys (`KEY_BRACKETLEFT` renders as something no player calls it). Worth a
  pass over what the engine actually returns for the printable range, driven by
  `derive-the-list`: derive the set the engine names badly rather than adding entries
  one complaint at a time.
- **Nothing on the keys screen says a binding is saved.** `_persist()` writes on every
  capture (`game/key_binding_screen.gd`), and the only feedback is the row's key text
  changing — which would also change if the write had failed. `RunConfig._save()` has
  three separate push_warning paths for a write that did not land, and none of them
  reaches a screen. Same shape as the save-confirmation idea below, and a strictly
  better place to start, because here the write is synchronous with a button.
- **The pause card's legend and the keys screen can now disagree about width.**
  `PauseScreen` draws the legend from `Game.key_help()` at a width measured against the
  shipped keys; a player who binds several verbs to long key names has never been
  tested against it. `_T.text_width` exists and is now used in exactly one place — this
  is the second.

### New this cycle (13 of 30) — grown from the save file, after spending a cycle inside it

- **The save remembers the run, not just the number.** `compose_save` writes two
  bare integers and the title screen shows two bare integers, so "best endless
  run: 5008" is the whole of what a player is told about the best thing they have
  done in this game. The run that set it knew far more — wave reached, which
  plants were on the board, how many pests escaped, how long it took — and all of
  it is discarded at `record_score`. Widen the record to a small struct (the v6
  format is deliberately shaped for one more block, and `VERSION_WITH_EXTRAS`
  shows how a field is added without refusing older files) and let the title
  screen say "wave 14, three Chomp Flowers, 6 got past you". A record you can
  picture is a record you want to beat; a bigger integer is a bigger integer.
- ~~**The milestone shelf.**~~ **SHIPPED, and this entry was wrong when it was
  written.** The shelf exists in full — `NotebookScreen.KIND_SHELF`, built by
  `_build_shelf()` (`game/notebook_screen.gd:425`), all seven `Milestones.TABLE`
  rows drawn with earned/unearned pips, a `shelf_progress_text()` reading
  "N of 7 earned", and tests in both `test_placement.gd:2185` and
  `test_selftest.gd:7760`. It is in the notebook rather than on the title screen
  **on purpose and with a measured reason**: the title's button column is full to
  the inch, and a fifth row at `TitleScreen.BUTTON_TOP` foots below
  `TitleBackdrop.HORIZON`. So the suggestion this entry made is the one thing that
  was already considered and rejected. Kept, struck through, as the worked example
  for `kanban-staleness-audit`: it was filed by an agent who had spent the cycle in
  `run_config.gd` and reasoned from "the data is persisted" to "nothing shows it",
  without opening a single screen. **A backlog entry written from one file's
  neighbourhood is a guess about the rest of the codebase.**
- **Saving is invisible, and this cycle proved even we could not see it.** The
  game writes a file at moments the player cannot predict (a record, a fresh
  milestone, a flipped option) and never says so. A one-second seed-packet glyph
  in the corner on every successful `_save()` costs nothing, and it makes the
  most important guarantee in the project — "your number is on disk" — a thing
  the player observes rather than assumes. It would also have made the bug this
  cycle fixed visible from the couch instead of from a stack trace.
- **The record ratchets instead of appearing.** A new high score is a label whose
  text changes. Roll it digit by digit from the old record to the new one over
  ~0.8s, with the seed-packet cue on the last digit. **Corrected:** the original
  entry said `fresh_record` was read by nothing. It is —
  `TitleScreen._best_line()` (`game/title_screen.gd:366`) appends "← just now" to
  the best-seeds line when it is set, and clears it at line 324. So the flag is
  live and the hook is already there; what is missing is only the motion, which
  makes this smaller than it was filed as, not larger.
- **"Reset to defaults" that says what it will undo.** `KeyBindingScreen.reset_all()`
  (`game/key_binding_screen.gd:170`) is wired straight to the button —
  `_reset_button.pressed.connect(reset_all)` — and goes `KeyBindings.reset_all()`
  → `_persist()` → `RunConfig.store_key_bindings()` → `_save()` with no confirm
  step anywhere in the chain. It is on disk before the player's finger leaves the
  mouse. Show what is about to go ("3 rebound keys") and make them say yes.
  **Narrowed:** the original entry claimed it also discards the three display and
  audio switches. It does not — those live on `OptionsScreen` and have no reset
  button at all. The scope is the InputMap only.

### New this cycle (12 of 30) — grown from the features above

- **The lane pressure overlay answers a question the player has already stopped
  asking.** `LanePressureOverlay` paints "how far did pests get" onto the road,
  faded by `LANE_PRESSURE_DECAY` 0.55 once per wave — so it is a readout of the
  wave that just ended, shown during the eighteen seconds you spend deciding what
  to build for the wave that has not started. The run total exists
  (`Board.run_pressure_alpha`) and is shown exactly once, by
  `show_run_pressure()` at the moment the run is already over. The number that
  would inform a purchase is the one held back until purchasing has stopped.

- ~~Every red on the board is now the same red, including the two that mean
  opposite things.~~ **Done** (commit `066cfe3`, "A solid red warns, a broken red
  records"). Lane pressure and the plant health bar were never actually
  confusable — plants only stand on buildable cells and roads never are, so the
  two are spatially disjoint. The armed Uproot cue lives on a HUD Button's
  `font_color`, not the board, and already carries two non-colour channels (the
  relabelled text and `Sfx.UPROOT_ARMED`). The pair that actually collided was
  unnamed in the original idea: `Game._update_cursor`'s blocked-cell hover wash
  and the lane pressure tint, both a flat `GardenTheme.DANGER` square stacked on
  the same road cells during prep. Lane pressure is now a 45-degree hatch
  (`LanePressureOverlay.HATCH_SPACING`/`is_hatched()`); the plant health bar
  also picked up a colour-blind-safe fix in the same commit — solid while
  bleeding, notched into `HEALTH_BAR_SEGMENTS` blocks while regrowing.
  (Re-filed and re-closed as `plant-tower-defense-4lv` after this entry was
  left unmarked — see that issue's close reason before refiling a third time.)

- **`husk_click_margin()` is a gate with no alarm.** Cycle 12 added it precisely
  because the husk-versus-placement conflict is four pixels away from being real,
  and a test asserts the clearance stays positive. But nothing tells a *designer*
  moving `PATH_CORNERS` or `COLLECT_RADIUS` that they are spending it — they find
  out when a test fails, with no indication that four pixels was the budget. The
  number wants to be in the devtools output, or in `board_info`, where someone
  tuning the road can see it before the build tells them.

- **The board has one route and every derived reading assumes it will stay that
  shape.** `PATH_CORNERS` produces 32 road cells and 2112px of walking, and at
  least four things are now calibrated against that specific route: the endless
  road budget's pests-per-cell, the Sundew's coverage arithmetic, the dead-ground
  count of 15 of 94 cells, and the husk clearance. Each is individually tested,
  which is good — but a second route would move all four at once, and nothing
  currently says which of them are properties of *a* road and which are properties
  of *this* road.


### New this cycle (11 of 30) — grown from the features above

- **The game's only explanation of anything is unreachable the moment a run
  starts.** `NotebookScreen` is constructed in exactly one place —
  `title_screen.gd`'s `_open_notebook()` — and nothing in `game.gd`, `hud.gd` or
  `pause_screen.gd` can reach it. So the player who actually needs it, the one
  mid-run holding a plant they do not understand, is the one player who cannot
  open it. The pause card is now a full-screen surface that already lists the
  keyboard verbs; a fourth button on it is the whole fix.

- **Half the catalogue has no page in the book that explains the catalogue.** The
  notebook's five pages cover the Corn Cobbler, the seed packet, the kernel, and
  the Chomp Flower twice. The Seed Sunflower and the Sticky Sundew — both tier 2,
  both unlocked late, both the plants a player has least intuition for — appear
  nowhere. The pages are keyed to the five hand-drawn source images, which is a
  good reason for the gap and not a reason it should stay: the two newest plants
  were designed in this repo and could carry their own page about what they do
  rather than where they came from.

- **`_wash_order` is a monotonic static counter, and nothing ever resets it.**
  `StickySundew` assigns each patch a rank from a class-level counter to give any
  pair a total order. It is correct and it is never reused — but it also never
  goes back to zero, not on `reload_current_scene`, not between runs. Nothing
  breaks at any plausible count; it is simply a number that only goes up for as
  long as the process lives, in a file that now also keeps a static list of live
  patches. Worth a deliberate decision rather than an accident, because the next
  static added there will be the one that matters.

- **The post-mortem counts compost swept and cannot count compost missed.**
  `CompostMeter` gained a `husk_rotted` signal in the sound pass, and
  `Game._on_husk_rotted` receives it, plays a sound and increments nothing. So the
  card reports a numerator with no denominator: "Compost swept 12" is unreadable
  without knowing whether four rotted or forty did. Every other row on that card
  is either a total or a bound, and this is the one that is neither.

- **The title screen's lawn is a museum of the first two plants.** `TitlePlants`
  draws a Sunflower, two Corn Cobblers and a Chomp — chosen when those were the
  whole catalogue. The Sundew is not on the lawn, so the first thing a new player
  sees advertises three quarters of a game that has since grown a fourth. Cheap to
  fix and the sort of thing that silently stops being true every time the
  catalogue moves, which argues for driving the lawn off `PlantCatalog.ids()`
  rather than a literal list.


### New this cycle (10 of 30) — grown from the features above

- **A husk eats the click that would have planted, and the preview has four states
  that all say the ground is fine.** `CompostMeter.COLLECT_RADIUS` is 28, so a husk
  claims a 56px-wide target on a 64px cell — 88% of it. `Game._click_at` sweeps a
  husk *before* it reaches the placement branch and returns, so a click on a cell
  the preview has just drawn as legal composts instead of planting. Meanwhile
  `PlacementPreview` now computes four states — illegal, at-risk, dead ground,
  redundant coverage — and mentions husks exactly zero times. The one thing that
  can silently take the click is the one thing the ring cannot warn about.

- **Two husks closer than 56px share a click, and `collect_at` quietly takes the
  nearer one.** It scans for the nearest husk inside `COLLECT_RADIUS` and returns
  its value; nothing marks which one went. Husks drop where pests die, and pests
  die in clumps at whatever cell is doing the killing, so overlapping targets are
  the normal case near a good cob rather than an edge case. The player sees one
  husk vanish, one remain, and no reason for the choice.

- **The clickable husk is three and a half times the size of the drawn one, and the
  generosity is invisible.** `HuskLayer` draws a husk between `BASE_RADIUS` 8 and
  `MAX_RADIUS` 15 by value, against a click radius of 28. That forgiveness is the
  right call — but because nothing shows it, a player calibrates on the picture and
  learns to click dead-centre, so the misses they do have are misses they did not
  need to have. A faint reach ring on hover, or a hover highlight, would teach the
  real rule in one run.

- **Two palettes, one game, and the HUD's half is now the bigger one.**
  `garden_theme.gd` states outright that it does not touch the in-game HUD, and
  `hud.gd` re-declares INK, PAPER, PAPER_DARK and LEAF with identical values. That
  was a fair split when the HUD had four colours. It has since grown UPROOT_ARMED,
  THREAT_WARM, THREAT_HOT, HEALTH_BACK, HEALTH_FULL and HEALTH_LOW — six more, none
  of which the title screen, the notebook or the post-mortem can reach, even though
  the post-mortem is a paper card that would want the same red for "this cost you
  something". The HUD only references GardenTheme at all for `animations_enabled()`.

- **A husk's worth is drawn but never written, and the range is 2 to 9.**
  `CompostMeter.BASE_VALUE` 2 to `FULL_VALUE` 9 is a 4.5x spread, encoded as size
  and glow. Size and glow are good for "hurry", but they are a poor way to answer
  "is this one worth crossing the board for" — and the run's post-mortem counts
  compost swept with no denominator, so a player never learns afterwards what they
  left to rot either. The number exists at every moment and is shown at none.

- **The game has no difficulty setting, and every constant that would be one is a
  `const`.** `LIVES` 10, `PREP_SECONDS` 18, `STARTING_SEEDS` 25, and
  `WaveDirector.WAVES` is a literal table. `threat_level()` can price any wave, and
  `set_seed()` exists but has only test callers — so the machinery to describe and
  to vary difficulty is both present and unreachable. The campaign is one curve for
  everyone, and the only choice on the title screen is whether it ever ends.


### New this cycle (9 of 30) — grown from the features above

- **The run tells you it beat your record only if it kills you.** `Game._end_run` opens
  with `var new_record: bool = bank_score()` (game.gd:341-342) and carries that bool all
  the way to `RunSummary._score_line()`, which turns it into "%d seeds grown — a new best"
  (run_summary.gd:131-138). Cycle 9's whole point was that a voluntary exit files a score
  too — and both new exits call `bank_score()` as a bare statement and drop the answer:
  the restart handler at game.gd:424 and the gate handler at game.gd:428, each followed
  immediately by `reload_current_scene()` / `change_scene_to_file(TITLE_SCENE)`. So the
  identical run, worth the identical seeds, is congratulated when a beetle reaches the
  house and silent when the player clicks "Back to the gate". Worse, the gate is where the
  new number is *displayed*: `TitleScreen.high_score_text()` (title_screen.gd:167-174)
  renders "Campaign %d · Endless %d" the same whether it changed one second ago or three
  sessions ago, so the one screen that shows the record cannot show that this run set it.
  The bool already exists, is already correct at both call sites, and is already worded
  for the player one file over — it is thrown away twice and never asked for a third time.

- **The pause card now derives every offset it has except the one that can overflow.**
  `key_list_offset()` (pause_screen.gd:49-53) is computed — `FIRST_BUTTON_OFFSET` 116 +
  3 buttons × 44 + 2 gaps × 12 + `KEY_LIST_GAP` 20 = 292 — and its own header says why:
  a hand-picked 268.0 once put the first key row under a button, "the same absolute-offset
  mistake that once hid the note under ResumeButton" (pause_screen.gd:34-38). Good. But
  the three `KEY_HELP` rows then run 292 → 370 at `KEY_ROW_HEIGHT` 26, against a
  `CARD.size.y` of 380 written out by hand (pause_screen.gd:33). **Ten pixels.** A fourth
  button costs 56 and a fourth key row costs 26, and either one puts text off the paper
  and onto the darkened backdrop over the live board — where it is still perfectly
  readable, still lands nothing on top of it, and so trips no gate at all. The overflow
  the derivation was built to prevent moved down one level rather than going away: the
  card height is now the only hand-written number left in the file, which makes it the
  only one that can be wrong. `card_content_height()` — `key_list_offset()` plus
  `_keys.size() * KEY_ROW_HEIGHT` plus a margin — with a test asserting `CARD.size.y` is
  at least that is the same trick applied one level up. (While in there: the header still
  opens "Same card geometry as the post-mortem" (pause_screen.gd:28-30), and
  `RunSummary.CARD` is `Rect2(128, 96, 640, 456)` against this file's
  `Rect2(288, 140, 320, 380)` — not the same size, position or aspect.)

- **The redundancy bars are silenced by one cell of new road out of three, which is what
  one step sideways buys.** `SAP_RADIUS` is `Board.CELL * 1.85` = 118.4 px
  (sticky_sundew.gd:34), so a patch covers exactly the 3×3 block of cells around it — at
  64 px pitch, (1,1) is 90.5 px and inside, (2,0) is 128 px and outside. A Sundew on grass
  beside a straight road therefore touches **three road cells**, and shifting the hover one
  cell along the lane keeps two of them and gains one. `covering_patch_count()` returns 0
  the moment a single covered road cell is new (placement_preview.gd:269-274), so that
  placement draws the ordinary green ring: thirty seeds, one cell of new slow, no cue. The
  cue is binary because the model behind it is — `added_crossing_time_multiplier()`
  answers 1.82 for `existing_sources == 0` and 1.0 for anything else (sticky_sundew.gd:
  251-254) — and `shows_redundant_coverage()` deliberately reads the answer off that
  function rather than restating the rule (placement_preview.gd:233-237), which is the
  right architecture pointed at a value model that has no fractional case. So the only
  placement the equals-sign ever fires on is a near-exact re-cover, and every 67%-wasted
  one looks like a good buy. A fraction — `float(new_cells) / float(mine.size())`, which
  `covering_patch_count()` already has both halves of — is the number, and the bars could
  simply mean "most of this is already sticky".

- **Every patch redraw walks every pest on the board.** `_draw_wash` calls
  `shared_ground_offsets()` (sticky_sundew.gd:352-369), which calls `_sibling_patches()`
  (392-401), which walks `get_parent().get_children()` — and the parent is `_entities`,
  the node that holds the board, the husk layer, the cursor, the preview, every plant
  **and every pest** (`_entities.add_child(pest)`, game.gd:277). `rewash_neighbourhood()`
  (385-389) walks it a second time. Those redraws are not rare: `_refresh_droplets()`
  (404-409) fires a `queue_redraw` whenever `droplet_radius(stuck_count())` moves, and that
  lerps continuously between 0 and `DROPLET_SWELL_AT` 3 (283-285), so a patch straddling a
  busy lane rescans the entire entity list several times a second, per patch, to answer a
  question whose answer changes only when a plant is added or destroyed. And the list it is
  scanning grows without bound in endless (see the spawn-floor entry below: wave 48
  schedules 166 pests, wave 108 schedules 376). The set of Sundews changes at exactly two
  points in the codebase — `_entities.add_child(plant)` (game.gd:522) and
  `_on_plant_destroyed` (game.gd:549) — so a cached list invalidated there costs two lines
  and removes an O(pests) scan from the draw path entirely.

- **`SAVE_VERSION` is written on every save and read on no load.** `_save` stamps
  `"v%d" % SAVE_VERSION` (run_config.gd:20, 55) and `_load` tests only
  `first.begins_with("v")` (run_config.gd:74-83) — the number after the v is never parsed
  and never compared, so a constant whose entire docstring is "Bumped when the on-disk
  shape changes" cannot change anything. A v3 file written by a later build is read as v2
  and its lines land in whichever slots v2 expects, silently. This is not hypothetical: the
  file has already migrated once (v1 → v2, run_config.gd:76-80) and that migration is the
  proof it will happen again. The same function has a second silent failure — the fields
  are read as `int(f.get_line())`, and `int("")` is 0, so a truncated or hand-edited save
  zeroes a record rather than being detected, and `record_score` "only ever raises the
  record" (run_config.gd:37-48) means the next mediocre run refills the slot and the real
  number is gone for good. Parsing the int after the `v` and refusing an unknown version
  is two lines in the one file in the project whose whole job is to outlive the process.

- **The aphid spawn interval hits its floor at wave 22 and nothing on the board fires that
  fast.** `_endless_groups` gives aphids `maxf(0.16, 0.30 - over * 0.01)`
  (wave_director.gd:149) where `over = wave - 8`, so the gap bottoms out at 0.16 s at
  wave 22 — well before health caps around wave 41 (`ENDLESS_HEALTH_MAX` 3.0 at 0.06/wave)
  and speed around 48 (`ENDLESS_SPEED_MAX` 1.6 at 0.015/wave, wave_director.gd:37-40). Past
  that point the only lever still moving is `count`, which has no cap at all: `20 + over*3`
  aphids and `6 + over/2` beetles, so wave 48 schedules 166 pests and wave 108 schedules
  376, each one built and sorted into a single `_schedule` array (wave_director.gd:260-275)
  and each one added as a child of `_entities`. Multiply the floor by the crossing: the
  road is 32 cells ≈ 2000 px, an aphid at `speed` 78 × 1.6 covers it in ~16 s, and one
  arriving every 0.16 s means **~100 aphids alive at once on an 896 px board** — one every
  9 px, a solid line rather than a lane of pests. The header on `ENDLESS_HEALTH_STEP` says
  the per-pest scales exist because "the entire late game was a quantity problem"
  (wave_director.gd:25-29); both of them stop by wave 48 and hand the late game straight
  back to quantity. Either the count ramp needs the cap the other four levers have, or the
  scales need to keep climbing past theirs — right now the game's stated fix for its own
  failure mode has an expiry date the player will reach.

- **The game has a difficulty *metric* and no difficulty *control*.** `threat_for()` prices
  any wave against wave 1 and `threat_level()` puts it on the bar (wave_director.gd:182-209)
  — the game can already say precisely how hard it is being. It cannot be told. `WAVES` is
  a literal eight-row table (wave_director.gd:48-75), `health_scale_for` and
  `speed_scale_for` return exactly 1.0 for every campaign wave by construction
  (wave_director.gd:244-257), `LIVES` is 10, `PREP_SECONDS` 18.0 (game.gd:11, 14) and
  `STARTING_SEEDS` 25 (seed_bank.gd:16) are compile-time constants, and `set_seed()` is
  called by nothing but the tests (wave_director.gd:93). So every campaign run in this
  game's life is the same eight waves in the same order at the same speed, differing only
  in mutation rolls from wave 8 — a player who finds it trivial and a player who cannot get
  past wave 5 are handed the identical board and `RunConfig` persists one bool for both.
  The title screen already offers a two-way choice and already renders two records
  (title_screen.gd:167-174), so the surface exists; the honest version is a scalar fed into
  the three `*_scale_for` functions and `LIVES`, filed alongside the score so an easy best
  cannot retire a hard one — which is exactly the two-scores lesson cycle 9 already learned
  once, for exactly the same reason.

- **Two scripts write fields onto nodes they do not own, and none of the six checkers in
  `tools/` can see the contract.** `sticky_sundew.gd` keeps a slow's entire correctness in
  node metadata on the `Pest`: `set_meta(META_BASE_SPEED, ...)` and `set_meta(META_SOURCES,
  sources + 1)` in `_claim` (182-188), read back in `_release_at` (191-205) and in the
  static `slow_sources()` (260-263). `title_screen.gd:252-253, 281-282` does the same with
  bare `"speed"` and `"offset"` string literals and no constant at all. A metadata key is a
  *string*, so `name_check.py` — which resolves names and says so — cannot see it;
  `lint_project.gd` and `import_check.py` type-check declarations and a `set_meta` key
  declares nothing; `coverage_check.py`'s eight defect classes are all about Controls,
  signals, orphans, input, scenes, shaders and names. A one-character typo on the read side
  makes `get_meta(META_SOURCES, 0)` answer 0, which reads as "not slowed", which means the
  base speed is never handed back — and this file's own header already names that outcome:
  "every bug in that lane would walk at 55% for the rest of the run with nothing on screen
  to explain it — the worst kind of bug, because it looks like balance"
  (sticky_sundew.gd:131-134). The checker is small and has `name_check.py`'s exact shape:
  collect every `set_meta`/`get_meta`/`has_meta`/`remove_meta` key in `game/`, assert every
  key read is written somewhere and every key written is read somewhere, and flag any key
  that is a bare literal instead of a declared constant. No engine, no `.godot/`,
  parallel-safe — which matters, because metadata is the one cross-script contract in this
  project that currently has no gate of any kind.

### New this cycle (8 of 30) — grown from the features above

- **In endless, the only way to bank a score is to die — and the game just shipped two
  doors that throw it away.** `RunConfig.record_score(bank.seeds_earned_total)` is called
  from exactly one place, `Game._end_run` (game.gd:324), which is reached from
  `_check_wave_cleared`'s victory branch (game.gd:249-250) and from `_on_pest_escaped`
  when lives hit 0 (game.gd:312-316). Endless never takes the first branch —
  `has_more_waves()` returns `true` unconditionally (wave_director.gd:105-108) — so the
  losing path is the whole scoreboard. Cycle 8's pause card added two more exits and
  neither touches it: `restart_requested` calls `reload_current_scene()` (game.gd:373-375)
  and `gate_requested` calls `change_scene_to_file(TITLE_SCENE)` (game.gd:376-380), both
  after `paused = false` and neither after `_end_run`. So a player who takes a
  forty-minute endless run to 3,000 seeds, gets bored, and clicks "Back to the gate"
  returns to a title screen still showing their old best — the run is gone and the number
  it earned was never filed. Worse, the correct play is now to deliberately feed ten pests
  to the exit rather than press the button the pause card offers. `_end_run` is already
  idempotent behind `_score_recorded` (game.gd:324-325) and already builds a post-mortem;
  a voluntary exit either has to route through it or call `record_score` on its way out.

- **The pause card's one sentence is a constant, it is false in the case a player is most
  likely to pause in, and it is painted underneath the first button anyway.**
  `note.text = "The wave is waiting."` (pause_screen.gd:79) is written once in `_ready()`
  and never updated, while `pause_run()` fires on any Escape or P that is not a game-over
  (game.gd:637) — so the sentence describing the frozen board reads identically with 22
  aphids and 7 beetles mid-road as it does during an empty intermission. It is also very
  nearly invisible. `FIRST_BUTTON_Y` is 232.0 (pause_screen.gd:26) and is the one offset in
  the file written as an absolute screen y instead of `CARD.position.y + N` like the
  heading at +30 and the note at +76 (pause_screen.gd:70, 80); with `CARD` at y=152
  (pause_screen.gd:23) that puts the Note's 24px box at 228-252 and `ResumeButton`'s 44px
  box at 232-276, overlapping by 20 of the note's 24 pixels — and the button is added last,
  so its opaque `paper_panel` stylebox draws on top. This is precisely the sibling-pair
  overlap `validate-ui` and `findings` structurally cannot see, since every Control here
  fits its own rect. There is room: the last button ends at 388 against a card bottom of
  452, 64px of empty paper. And everything a truthful note could say is already assembled —
  `Game.state()` carries `wave_live`, `prep_left`, `prep_total`, `lives`, `seeds` and
  `next_threat_level` (game.gd:729-737), and `Hud._refresh_prep_bar` (hud.gd:568) already
  turns two of those into "how long until the next one".

- **Uprooting a 10-seed plant takes two clicks and a red warning; discarding the whole run
  takes one.** `UPROOT_CONFIRM_SECONDS` is 4.0 and its header states the rule — "Uproot is
  the only irreversible click in the game" (game.gd:15-24) — enforced by an arm/confirm
  cycle, a relabelled button ("Really uproot? (+2)"), a `UPROOT_ARMED` red override
  (hud.gd:71) and a `Sfx.UPROOT_ARMED` cue (game.gd:543-546), all to protect ~6 seeds. As
  of cycle 8 that header is simply wrong: `RestartButton` sits 12px under
  `ResumeButton` (`BUTTON_GAP` 12.0, pause_screen.gd:27-33), is the same 248x44 size in the
  same style, and one click reloads the scene with no arm, no relabel, no colour and no
  sound. `ResumeButton` also takes focus on open (pause_screen.gd:105-106), so keyboard
  Down-then-Enter — the exact reflex the title screen teaches with "Up / Down to choose ·
  Enter to grow" (title_screen.gd:148) — lands on it. The confirm machinery already exists
  and is proven; the destructive button that needs it is the one that does not have it.

- **Regrowth painted a bed's health bar green, and the panel three inches to the right
  paints the same bed red at the same instant.** `Plant.health_bar_color` returns
  `HEALTH_BAR_REGROWING` (plant.gd:57, 312-313) whenever `is_regrowing()` is true — at any
  health — while `Hud._refresh_health` (hud.gd:801) fills its bar with
  `HEALTH_LOW.lerp(HEALTH_FULL, fraction)` between `HEALTH_LOW` red and `HEALTH_FULL`
  green (hud.gd:227-228), where green means *full*. A Corn Cobbler at 8/40 that has been
  quiet for six seconds therefore wears green over its head and red in the side panel
  simultaneously, and the panel's only text is "Health 8/40" — the one number that is
  identical whether the plant is recovering or has stopped. The information is sitting
  right there unread: `seconds_until_regrowth()` (plant.gd:197) and the static
  `seconds_to_full_from()` (plant.gd:173) have no caller anywhere outside
  `test/unit/test_combat.gd`, and the panel is already refreshed live and already prints a
  sliding `uproot_refund()` on the button below. "Whole again in 27s" against "Uproot
  (+2)" *is* the decision `REGROWTH_RATE`'s own header claims to have created
  (plant.gd:38-44), and neither half of it is currently on screen.

- **The 45-seed Corn upgrade makes the plant worse against a single pest, and the panel
  advertises it by the number that goes up.** `LEVELS` (corn_cobbler.gd:12-16) takes level
  3 to 5 kernels over 52 degrees of spread; `kernel_angle_offsets` spaces them evenly and
  symmetrically (corn_cobbler.gd:141-151), so they leave the cob at -26, -13, 0, +13 and
  +26 degrees. A kernel is a straight line (kernel.gd:28-40) with `HIT_RADIUS` 18.0
  (kernel.gd:8), so an outer kernel clears the pest it was aimed at past
  18 / tan(26°) = 37 px — well under one 64px cell — and the ±13 pair past 78px, against a
  `RANGE` of 176.0 (corn_cobbler.gd:9). Level 2's ±7 degrees, by contrast, still connects
  out to 147px. So against one beetle at two cells: level 2 lands 2 kernels per 0.72s =
  2.78 dps, and level 3 lands 1 per 0.62s = 1.61 dps. Forty-five seeds buys a 42%
  *reduction*, unless the lane is dense enough for the strays to find someone else — which
  is the real condition and is stated nowhere. `damage` is 1.0 at all three levels, so the
  ladder never helps against 16hp of beetle either. Meanwhile the panel says
  "5 kernel(s) per shot" (hud.gd:751) and the always-on muzzle fan draws a wider arc
  (corn_cobbler.gd:104-115), which `_draw`'s header calls "the board-level readout of what
  an upgrade bought" (corn_cobbler.gd:88-89) — both of them reporting the spread as the
  benefit. Either the panel
  names the condition ("wide spray — pays off against a crowd"), or level 3 stops being a
  strict spread and starts being a shorter interval.

- **"Grow the next wave" is a button whose only effect is to cost the player something.**
  It is always available between waves (`can_start_wave`, game.gd:743) and `_process`
  starts the wave on its own at `PREP_SECONDS` 18.0 anyway (game.gd:183-185), so pressing
  it never unlocks anything — it only forfeits the remainder of the gap. And the gap is
  worth real money now: every Sunflower pays `YIELD` 3 seeds per `INTERVAL` 6.0
  (sunflower.gd:11-12), i.e. 0.5/s, a chewed bed regrows at `REGROWTH_RATE` 1.5/s for the
  12 seconds past `REGROWTH_DELAY` (plant.gd:50-51), and a husk on the ground can rot in
  `MIN_HUSK_LIFETIME` 4.5s (compost_meter.gd:27). Three sunflowers and one damaged Corn
  make a full 18s gap worth ~27 seeds and ~18hp; the button hands all of it back for
  nothing. So the optimal line is always to let the strip drain, the campaign carries a
  144-second floor of pure waiting however well you play, and the only player who presses
  the button is one who wants the game to end sooner. `_refresh_prep_bar` is already handed
  `prep_left` and `prep_total` (hud.gd:568-576); a call-early bonus scaled by the fraction
  left — seeds, or a compost multiplier for the wave — would turn a dominated button into
  the tempo decision the whole prep phase is currently missing.

- **The run has four keyboard verbs and no screen in the game names one of them.**
  `Game._unhandled_input` binds R to replay after a run ends (game.gd:632), Escape and P to
  pause (game.gd:637) and M to mute (game.gd:644); `NotebookScreen` adds Left, Right and
  Escape (notebook_screen.gd:333-350). The only one ever mentioned in-game is mute, and
  only in "Sound off. Press M to bring it back." (game.gd:646) — a message that by
  construction can only be read by someone who has already found M. The title screen prints
  its own two keys, "Up / Down to choose · Enter to grow" (title_screen.gd:148), which is
  proof the project thinks this is worth saying and simply never says it about the part
  with the keys in it. The pause card is the surface every other game puts this on, it is
  now the first thing built out of `BUTTONS` (pause_screen.gd:30-34), and it has 64px of
  unused card below its last button (see the note entry above). A four-line key list there
  is the whole feature.

- **Two green gates guard the sprites and neither one can tell you the PNG came from the
  SVG.** `tools/svg_style_check.py` reads `art_src/*.svg` and never opens a raster;
  `test/unit/test_sprite_style.gd` reads `assets/sprites/*.png` against a hand-written
  `EXPECTED_SIZE` dictionary of twelve names (test_sprite_style.gd:17-30) and never opens a
  source; `tools/render_svg.gd` is the only thing that has ever seen both, and it is run by
  hand. So editing `sticky_sundew.svg` and forgetting to re-render leaves *both* gates
  passing over a shipped sprite two edits behind its source: the contract and the shipped
  art are now each certified in isolation and never once compared to each other. The same
  seam has a second hole: a thirteenth SVG is checked by the Python tool and is invisible to the
  raster gate until someone hand-edits `EXPECTED_SIZE`, and
  `test_every_sprite_declared_by_the_contract_exists` (test_sprite_style.gd:57) will
  happily report all twelve present. The checker's own LIMITS
  section (svg_style_check.py:86-106) is candid about what rasterising would take and right
  to be; this is not that. It is a mtime-or-hash comparison between two files that already
  sit in the repo, plus deriving that dictionary from the directory instead of typing it.

### New this cycle (7 of 30) — grown from the features above

- **The rare packet's tooltip names one plant, and the packet now holds two.**
  `PACKET_TOOLTIP[&"rare"]` (hud.gd:117) still reads "Costlier, but the odds reach past
  tier 1 — the only reliable way to a Seed Sunflower", written when the Sunflower was the
  only thing above tier 1. The catalogue now has two tier-2 entries — Seed Sunflower at 25
  and Sticky Sundew at 30 (plant_catalog.gd:38, 47) — so 45 seeds buys a coin flip and the
  button describes it as a purchase. `SeedBank.packet_pool(tier)` (seed_bank.gd:111)
  already returns the exact list a click could roll, and `_refresh_packet_button` already
  swaps the tooltip out for a reason when a packet cannot be bought (hud.gd:528), so the
  surface that would say "2 left: Seed Sunflower or Sticky Sundew" is built and only ever
  prints a constant. A gamble whose odds are not on screen is a gamble the player cannot
  price, and the pool shrinks by one every time it pays out.
- **"Tier" is a word this game only ever says while refusing you something.** `tier` is a
  field on every catalogue entry (plant_catalog.gd:20, 29, 38, 47) and the *only* thing the
  two packets differ by (`max_tier`, seed_bank.gd:30-33), yet the plant bar builds its
  buttons as `"%s\nlocked"` / `"%s\n%d seeds"` (hud.gd:680-684) and never mentions it. So
  the concept surfaces in exactly two places: a packet tooltip, and the refusal "A Common
  Packet only holds tier-1 seeds, and you have them all" (seed_bank.gd:139), which by
  construction can only be read by someone who has already spent the 20 seeds finding out.
  Nothing relates a locked plant to the packet that could hold it, so "Chomp Flower /
  locked" and "Sticky Sundew / locked" look like the same problem when one costs 20 to
  solve and the other 45. `PlantCatalog.tier()` (plant_catalog.gd:80) is a static call, and
  the bar is rebuilt from `PlantCatalog.ids()` on every refresh already.
- **The one plant that cannot fight back is the one plant the defenceless-plant warning
  refuses to draw for.** `Game._update_preview` sets `_preview.at_risk = _preview.reach <=
  0.0 and board.is_road_adjacent(cell)` (game.gd:685), and PlacementPreview's own header
  states the rule that encodes: the dashed amber ring is "only meaningful for a plant with
  no reach of its own" (placement_preview.gd:81-84). A Sticky Sundew's reach is
  `Board.CELL * 1.85` (sticky_sundew.gd:34), so it fails that test — while dealing "no
  damage whatsoever" (sticky_sundew.gd:25), costing 30, and being worthless unless planted
  hard against the road, which is precisely where `Pest.EAT_DPS` 14.0 (pest.gd:132) eats
  `MAX_HEALTH` 40 in 2.9 seconds. The cue tests "has a radius" as a proxy for "can defend
  itself", and the fourth plant is the first one where those two answers differ. A
  `deals_damage` flag in the catalogue — or reading it off the subclass the way
  `PlantCatalog.reach()` already does (plant_catalog.gd:92-104) — is a one-line fix to the
  predicate, not a new cue.
- **Two Sundews on the same ground cost 60 seeds, slow nothing extra, and the only thing on
  screen says the opposite.** The source count in `_claim`/`_release_at`
  (sticky_sundew.gd:136-159) is deliberate and right — a pest in two patches walks at 0.55,
  not 0.30 — but `_draw` paints `PATCH_COLOR` at alpha 0.10 (sticky_sundew.gd:79, 230) once
  per plant, so overlapping patches composite into a visibly *darker* wash over the one
  stretch of road where the second plant contributes nothing at all. Placement knows
  nothing about it either: `PlacementPreview` carries road, occupancy, affordability and
  reach (placement_preview.gd:69-92) and has no notion of ground another plant already
  covers, so nothing warns before the 30 seeds are gone. Meanwhile the plant's own priced
  justification — `crossing_time_multiplier()`, "the number the plant is priced against, so
  it is stated rather than left implied" (sticky_sundew.gd:186-190) — has no caller
  anywhere outside `test/unit/test_placement.gd:748`, and the panel prints the rate instead
  ("Slowing %d pest(s) to 55%% speed", hud.gd:745). "Every gun here gets 1.8x longer" is the
  sentence that sells the plant; "55% speed" is the sentence that describes its
  implementation.
- **The game rolls every mutation in a wave before the first bug walks, and then tells the
  player a total.** `_build_schedule` (wave_director.gd:260-275) draws all of them up front
  at `mutation_chance_for(current_wave)` — flat 0.4 through the fixed table
  (wave_director.gd:15), uniform over armoured/winged/hungry — so the instant
  `start_next_wave()` returns, `_schedule` is a list that knows exactly how many winged
  pests are coming and in what order. What reaches the player is `announce_wave(number,
  current_wave_pest_count(), escalation_note(number))` (game.gd:205-206), which renders as
  "22 pests" and nothing else, because `escalation_note` returns "" for every wave in the
  campaign table (wave_director.gd:215-217) and `wave_note` (hud.gd:896) has nothing else to
  say. Both answers to a winged pest — a Corn Cobbler, and now a Sticky Sundew — are
  placements that must be bought during `PREP_SECONDS` 18.0, i.e. before any wings exist to
  look at, so against a 40% mutation rate the only strategy is to insure against all three
  every wave or eat the loss. Every entry in `_schedule` already carries its `mutation`;
  counting them is one loop over an array the director is already holding.
- **The number endless mode is actually scored on is loaded at launch, ridden in `state()`
  every frame, and first shown to the player once the run is dead.** `RunConfig._load()`
  reads the persisted best before the title screen draws (run_config.gd:68-83),
  `Game.state()` puts `"seeds_earned_total"` and `"high_score"` into the dictionary the HUD
  re-renders many times a second (game.gd:747-748), and `Hud.refresh` reads neither — the
  two only ever meet in `RunSummary._score_line()` (run_summary.gd:131-139), on the
  post-mortem card. The top bar's four readouts are Seeds, Wave, Garden and Compost, and
  the first of those is the wallet balance, which goes *down* when you spend and is not the
  thing being recorded. So a returning player — who was shown their best on the title
  screen, and who in endless can only stop by dying — plays a forty-minute run with no idea
  whether they are ahead of it, and learns the answer in the same sentence that tells them
  they lost. This is most of the difference between a first run and a tenth, and it is one
  label.
- **Pricing the refund against health killed uproot-as-repair and left uproot-as-score
  intact.** `SeedBank.add_seeds` increments `seeds_earned_total` for any positive amount
  (seed_bank.gd:56-60), `refund()` is a direct call into it (seed_bank.gd:103-104), and the
  field's own comment says so — "Refunds count too; they are still seeds earned"
  (seed_bank.gd:37-38). That total is exactly what gets persisted:
  `RunConfig.record_score(bank.seeds_earned_total)` (game.gd:324). So planting a pristine
  Corn Cobbler for 10 and immediately uprooting it for `floor(10 * 0.6)` = 6
  (plant.gd:266, UPROOT_RATE_FULL) costs 4 seeds of wallet and adds 6 to the recorded
  score — repeatable for as long as there are spare seeds, +150 score out of a 100-seed
  float, with no wave running and no risk. Cycle 7 correctly made recycling scrap value
  rather than repair; the scoring channel the refund also feeds was never part of that
  change. Either record net seeds, or keep refunds out of `seeds_earned_total` so the name
  means what it says.
- **Every plant gets one sentence of explanation and it lives behind a mouse hover.**
  `PlantCatalog.blurb()` (plant_catalog.gd:111) has exactly one caller in the whole
  project: `button.tooltip_text` on the plant bar (hud.gd:350). The single moment a plant
  enters a run is a packet roll, and `_on_plant_unlocked` answers it with "The packet held
  a Sticky Sundew!" (game.gd:612-613) — the name, on the 15px status row, with the sentence
  explaining what the thing *does* sitting one Dictionary lookup away. The fallback
  reference is the Designer's Notebook, whose `PAGES` (notebook_screen.gd:86-117) are five
  drawings covering the Corn Cobbler, the brief, the kernel upgrade and two Chomp Flower
  poses: the Sunflower and the Sundew were designed after the sketches, so half the
  catalogue appears nowhere in the game's only reference screen. The title screen's lawn
  has the same hole — `TitleScreen.PLANTS` (title_screen.gd:40-45) is a sunflower, two cobs
  and a chomp. A plant-facts page in the notebook, keyed off `PlantCatalog` so it can never
  fall behind the catalogue again, is the surface all three of these are missing.

### New this cycle (5 of 30) — grown from the five features above

- **Eleven sounds shipped and not one of them is a plant doing its job.** `Sfx.SOUNDS`
  (sfx.gd:44-56) is pests, husks, wave starts, run enders and one button state; the
  three things the player actually bought are silent. `CornCobbler._fire_at`
  (corn_cobbler.gd:68) spawns a `Kernel` with no cue, `ChompFlower._grab`
  (chomp_flower.gd:77) and `_bite` (chomp_flower.gd:139) swallow a beetle over 5.2s
  without a noise, and `Sunflower._bloom` (sunflower.gd:158) pays out in silence. The
  economy is where that reads worst: sweeping a husk plays `handleCoins.ogg`
  (sfx.gd:50) *and* posts "Composted a husk for %d seeds." (game.gd:640), while
  `Game._on_plant_grew_seeds` (game.gd:457) is a bare `bank.add_seeds(amount)` — so the
  one plant whose entire purpose is making seeds is the only seed source that makes no
  sound. The closest thing the game has to combat audio is `PEST_KILLED` at
  `REPEAT_MS` 70 (sfx.gd:82), which is the *pest* dying, never the plant firing. A cob
  shot and a Sunflower payout are two more rows in a Dictionary that already has eleven.
- **Nothing on screen ever mentions the M key, and the screen that plays a jingle
  cannot mute it.** `Game._unhandled_input` (game.gd:588) is the only binding, and the
  only place the game says so is the toggle's own reply — "Sound off. Press M to bring
  it back." (game.gd:590) — which by construction can only be read by someone who
  already found it. `TitleScreen`'s `HintLabel` (title_screen.gd:148) reads "Up / Down
  to choose · Enter to grow" and stops there, and because the binding lives in `Game`
  the title screen and the notebook have no mute at all. `Sfx._muted` is a static var
  (sfx.gd:94) that resets every launch, and `RunConfig` (run_config.gd:22-24) persists
  `endless` plus two high scores and no audio setting — so muting is a thing you do
  again every session. There is also no volume anywhere: `VOLUME_DB` (sfx.gd:62) is a
  per-event trim constant, not a control. One line on the title screen's hint, and one
  more line in `_save()` (run_config.gd:51), is most of this.
- **The post-mortem now counts what the run won, and still cannot say what it cost.**
  `RunSummary.summary_rows()` (run_summary.gd:148-156) is seven rows and every one of
  them is an outcome — waves, pests, minutes, threat, beds, compost, weakest cell.
  Nothing counts spend: `bank.seeds_earned_total` rides in `state()` (game.gd:691) but
  seeds *spent*, plants placed and upgrades bought do not exist as numbers anywhere, so
  "3400 seeds grown" is unreadable without knowing whether that bought four plants or
  forty. Two of them are now one line each: `_on_plant_destroyed` (game.gd:446) already
  funnels every plant a hungry pest eats and does nothing but message and free it, and
  `_on_husk_rotted` (game.gd:279) already receives the missed-husk signal the previous
  cycle added — it plays `HUSK_ROTTED` and increments nothing, which is exactly why
  "Compost swept 14" still has no denominator. The signal is wired; only the `+= 1` is
  missing.
- **The one number that decides whether you lose is the one readout that never changes
  colour.** `_lives_label` is built as `_add_stat(stats, "LivesLabel", 26, PAPER,
  LIVES_LABEL_WIDTH)` (hud.gd:264) and refreshed as `"Garden  %d" % state["lives"]`
  (hud.gd:614) — identical cream at 10 lives and at 1. The readout sitting immediately
  beside it has a three-stop ramp (`threat_color`, hud.gd:553) easing between tints over
  `THREAT_FADE_SECONDS` 0.45, so the bar colour-codes how bad the *next* wave looks and
  says nothing about how close the run is to over. `LIVES` is 10 (game.gd:11) and an
  escaped pest costs exactly one (game.gd:307), so nine of those ten steps change
  nothing on screen, and `Sfx.PEST_ESCAPED` plays `error_002.ogg` at the same volume for
  the first as for the last. `board.show_run_pressure()` tells you where you bled after
  the fact; nothing tells you you are bleeding out while it is still fixable. The ramp
  already exists as a static pure function — pointing it at `lives` costs a second call.
- **There is no pause, and no way to leave a run you are done with.**
  `Game._unhandled_input` (game.gd:569-591) handles exactly four things: mouse motion,
  a left click, `KEY_R` gated on `game_over or victory` (game.gd:582), and `KEY_M`. No
  Escape, and `get_tree().paused` appears nowhere in `game/` — the only match for
  "pause" in the whole directory is a comment about wave lead-in (wave_director.gd:47).
  `TITLE_SCENE` (game.gd:28) has exactly one route into it: `RunSummary`'s
  `GateButton`, which does not exist until the run ends. In endless that means the only
  exits from a wave-200 run are deliberately feeding ten pests to the exit or killing
  the process, and `PREP_SECONDS` 18.0 (game.gd:14) keeps counting toward the next wave
  the entire time the player is away from the keyboard. The devtools notes make a point
  of the bridge answering while the tree is paused, so a pause overlay is testable the
  moment it exists.
- **The preview counts road cells and then throws the count away.**
  `PlacementPreview.covered_road_cells()` (placement_preview.gd:187) loops the whole
  grid and returns an int; its only caller, `covers_road()` (placement_preview.gd:170),
  collapses it to `> 0`, `shows_dead_zone()` (placement_preview.gd:160) collapses that
  to a bool, and `_draw` (placement_preview.gd:116) paints one bar. So the game already
  knows a cell covers 10 lane tiles and shows it the identical ring it shows a cell
  covering 1. The dead-ground pass proved the number matters at the extremes — 15 of 94
  cells dead for a Corn, 34 of 94 for a Chomp, best cell 10 road tiles, worst 0 — and
  every actual placement decision lives in the middle of that range, where the cue is
  currently silent. The loop is already run every mouse-move; a count under the
  brackets, or ring alpha keyed to it, adds no work and no node.
- **One road, every run, for both modes and for however many hundred waves.**
  `Board.PATH_CORNERS` (board.gd:19-26) is six literal corners producing 32 road cells
  out of 126, `_build_path` (board.gd:76) is the only writer of `_path_order`, and
  `Game._ready` (game.gd:110) builds one `Board` with no shape or seed argument.
  `WaveDirector.set_seed` (wave_director.gd:93) randomises the mutation rolls and
  nothing else, so the map is a constant of the executable. That makes the whole
  placement layer a fact learned once: the dead-cell counts above are properties of
  this one path, the elbows at `(9,4)` and `(3,4)` are always the best cob ground, and
  an endless high score is partly a memory test. `covered_road_cells` already takes the
  board as a parameter and `GRASS_EDGE_TILE` (board.gd:39) already derives every tile
  from a neighbour mask, so a second and third corner list — or one generated from a
  seed the title screen shows — needs no new art and no new tile work.
- **A new player's whole tutorial is one 8-second line, and wave 1 arrives whether they
  read it or not.** `Game._ready` ends on `hud.show_message("Plant your free Corn
  Cobbler on the grass, then grow the first wave.", 8.0)` (game.gd:163) — at
  `MESSAGE_NORMAL`, in the 15px clipped status row, on the same channel as husk chatter
  — and the line above it sets `_prep_left = PREP_SECONDS` 18.0 (game.gd:161), so
  `_process` starts the first wave automatically at 18 seconds whether anything is
  planted or not. Everything the sentence leaves out is never said anywhere: that a
  husk is worth clicking and can rot in `MIN_HUSK_LIFETIME` 4.5s (compost_meter.gd:27),
  that a packet is a random pull, that Uproot takes two clicks
  (`UPROOT_CONFIRM_SECONDS` 4.0, game.gd:24), that a Corn upgrades at all, or that M is
  the mute. The title screen's own `HintLabel` (title_screen.gd:146) explains only its
  three buttons. A first-run-only prompt chain keyed off the events that already fire
  (first husk dropped, first packet affordable, first plant selected), or a rules page
  in the notebook the gate already links to, would put those somewhere that does not
  erase itself.

### New this cycle (4 of 30) — grown from the five features above

- **The post-mortem can only count what the run lost, because those are the only
  numbers anything ever kept.** `RunSummary.summary_rows()` (run_summary.gd:133) lists
  five rows and four of them are damage: waves survived, threat reached, garden lost,
  compost swept, weakest ground. There is no pests-killed counter anywhere in the
  project — `Game._on_pest_died` (game.gd:255) is the single funnel every kill in the
  game passes through, and it adds seeds and drops a husk without incrementing anything.
  Same for plants: `_on_plant_destroyed` (game.gd:405) shows a 4-second message and
  frees the node, so "a hungry pest ate three of your beds" is not a fact the run
  retains. Same for time: nothing in `game/` calls `Time.` at all, so a 40-minute
  endless run and a 90-second faceplant report the same shape of card. And "Compost
  swept 14" has no denominator, because `CompostMeter._process` (compost_meter.gd:105)
  erases an expired husk from `_husks` with no signal and no tally while
  `total_collected` only ever counts the ones you caught. Four integers at four call
  sites that already exist, and `Game.state()` (game.gd:617) is already the dictionary
  they'd travel in.
- **One high score serves two different games, and the title screen calls it by the
  wrong name.** `Game._end_run` files `RunConfig.record_score(bank.seeds_earned_total)`
  (game.gd:286) with no mode check at all, so a campaign run writes the same single line
  of `user://highscore.save` (run_config.gd:11) that an endless run does — and
  `TitleScreen.high_score_text()` (title_screen.gd:160) renders it as "Best endless run:
  %d seeds grown", or "No endless run on record yet." when it is zero. Finish the
  eight-wave campaign and the gate now reports an endless record you never set. It also
  makes the campaign's own score dead on arrival: one endless run past wave 40 pins the
  number somewhere eight waves of aphids can never reach, so `RunSummary._score_line()`
  (run_summary.gd:123) tells every campaign player forever that their best is a number
  from a different mode. Two keys in the save file, or a furthest-wave record kept
  beside the seed one, and each mode gets a score it can actually beat.
- **The placement ring is drawn with exactly as much confidence over a cell that
  covers nothing.** `Game._update_preview` (game.gd:559) sets `reach`, `placeable` and
  `at_risk`, and `PlacementPreview._draw` (placement_preview.gd:76) paints the coverage
  arc at that radius whenever the cell is legal and affordable — legality being road,
  occupancy and money, never usefulness. The board is 14x9 with a 32-cell road cut
  through it, which leaves 94 buildable cells; at `CornCobbler.RANGE` 176.0 (2.75 cells)
  **15 of those 94 reach no road cell whatsoever**, and at `ChompFlower.GRAB_RADIUS`
  73.6 px it is **34 of 94**. The best cob cell on this map covers 10 road cells and the
  worst covers 0, and the preview shows both the same green circle before charging the
  same 10 seeds. The preview already holds a `Board` reference for the `is_road_adjacent`
  check that drives `at_risk` (game.gd:576) — counting road cells inside `reach` is one
  loop over the same path list, and "covers 7 lane tiles" versus "covers none" is the
  single most decision-shaped number the hover cue could carry.
- **A plant's health only ever goes down, and the cheapest repair in the game is to
  destroy it.** `Plant.health` (plant.gd:20) starts at `MAX_HEALTH` 40.0 and
  `take_damage()` is its only writer — there is no heal, no regen, no repair action, so
  a Corn Cobbler that survived a hungry pest at 6/40 stays at 6/40 for the rest of the
  run and dies to 0.43 seconds of the next one (`Pest.EAT_DPS` 14.0). Meanwhile
  `uproot_refund()` (plant.gd:114) is `floor(PlantCatalog.cost(kind) * 0.6)` read
  straight off the catalogue and never off `health`: uprooting a nearly-dead Corn pays
  the same 6 seeds as uprooting a pristine one, and replanting costs 10. So the correct
  play on any damaged plant is uproot-and-replant for a net 4 seeds, a two-click ritual
  the game never mentions, and the selection panel's new health bar exists to tell you
  to perform it. Either price the refund against remaining health — which makes a
  wrecked plant genuinely a loss — or sell an actual repair, and let the bar be a
  decision instead of a chore.
- **The rare packet is a button that works once per run, because the catalogue has
  three plants in it.** `PlantCatalog.PLANTS` (plant_catalog.gd:14) holds Corn (tier 1),
  Chomp (tier 1) and Sunflower (tier 2), and `SeedBank.PACKET_TIERS[&"rare"]`
  (seed_bank.gd:32) has `max_tier` 99 — a ceiling with exactly one plant under it. Pull
  the Sunflower and the 45-seed button greys out for good. The shape of the missing
  fourth plant is already dictated by what the board can't answer: nothing slows,
  nothing hits an area, and nothing at all counters `winged`, which
  `ChompFlower._nearest_free_pest` (chomp_flower.gd:68) skips with a bare `continue` so
  that only Corn can ever touch it. A tier-2 plant that reaches the air, or one that
  slows a lane so an armoured beetle's doubled 5.2s chew (pest.gd:212) stops taking a
  Chomp off the board, would give the rare tier a second thing to hold and give the
  mutation system its first piece of counter-play rather than only a tax.
- **The economy plant is the one plant with nothing on the board to read.** The cob
  just earned a permanent muzzle fan — pips on the exact angles it fires at
  (corn_cobbler.gd:39-47), visible without clicking anything — while `Sunflower`
  (sunflower.gd:11-12) runs a 6.0s `INTERVAL` paying `YIELD` 3 and shows it nowhere. The
  only readout is `hud.gd:562`'s "Next %d seeds in %.0fs", which costs a click on that
  specific flower, and `_bloom()` (sunflower.gd:30) is a 0.28s scale pulse that fires
  *at* the payout — the one moment the information is worthless, because the seeds have
  already landed. Five sunflowers in a corner are five identical yellow dots on
  independent clocks the player cannot see, when the interesting reading is "three of
  these pay out in the next second". A filling ring, running the opposite way to
  ChompFlower's shrinking `CHEW_RING_RADIUS` 16.0 one so the two never read as the same
  state, is the same idiom the board already speaks.
- **The escalation note is a three-second line about a permanent change, and it goes
  quiet exactly when the ramp stops.** `WaveDirector.escalation_note()`
  (wave_director.gd:215) is right to return "" inside the fixed table, but past it
  `Game._on_wave_started` (game.gd:186) folds it into a `show_message` that defaults to
  3.0 seconds (hud.gd:614) and then the state it described is simply how the game is
  now, unwritten anywhere. Worse at the caps: `health_scale_for` climbs 0.06/wave to
  `ENDLESS_HEALTH_MAX` 3.0 and `speed_scale_for` 0.015/wave to 1.6, so around wave 41
  and wave 48 those adjectives stop appearing — and the absence reads exactly like
  "nothing got worse" rather than "this is as bad as pests get", while `threat_level`
  keeps climbing past 20 on its log scale. The selection panel is empty whenever nothing
  is selected; five one-line scale readouts (`x2.4 tough · x1.5 fast · 62% strange`)
  would fill it with standing state instead of an adjective the player had to be
  looking at the status row to catch.
- **The HUD builds a full-width announcement surface every launch and nothing has
  called it since the post-mortem shipped.** `Hud._build_banner` (hud.gd:349) creates a
  48px `Label` 896px wide at y=240 with a drop shadow, and it is still in the live tree —
  `/root/Game/HUD/Root/Banner` appears in every `scene-tree` snapshot in `.devtools/`.
  But `show_banner` and `hide_banner` (hud.gd:671, 677) have zero callers anywhere in
  the repo, tests included: `_end_run` used to banner the result and now builds a
  `RunSummary` instead. So the game owns the one piece of screen real estate big enough
  to say something without competing with a clipped 15px status row, and says nothing on
  it. The moments that currently have to squeeze through the message queue and deserve
  better are all end-of-something: the last wave of a campaign starting, a new seed
  record being set mid-run rather than reported on the card afterwards, and the first
  mutated pest a player ever sees at wave 8.

### New this cycle (3 of 30) — grown from the four features above

- **The message label has one slot and no queue, and the uproot gate is what proved it
  costs something.** `Hud.show_message` (hud.gd:529) assigns `_message_label.text` and
  resets `_message_left` — a second call overwrites the first outright, and `_process`
  only ever counts one timer down. `request_uproot()` puts the whole instruction
  ("Click Uproot again to dig up your X") in that slot for exactly the 4s the arming
  lasts, so any of the four things that can speak during those seconds erases the only
  explanation of what the red button now does: a husk sweep (`"Composted a husk for %d
  seeds."`, 2s), a wave start, a Sunflower packet unlock, or a `purchase_failed` from a
  misclick on the plant bar. The armed button stays armed and red with nothing on screen
  saying why. Worse at the other end of a run: `_end_run` asks for the post-mortem line
  at 30s and `_tick_uproot_confirm` can wipe it 4s later with "Uproot cancelled." A
  two-deep queue, or a priority argument that lets a long message refuse to be stomped
  by a 2s one, is the whole fix.
- **The wave readout now says how bad the next wave is and still never says when it
  arrives.** `Game.PREP_SECONDS` is 18.0 and `_process` counts it down silently;
  `_check_wave_cleared` announces "Next one grows in 18 seconds" for 6.0s and then the
  label blanks, leaving 12 of the 18 seconds with nothing on screen ticking. The threat
  tint made "wave 14 is much worse than wave 9" preattentive, which sharpens the missing
  half rather than filling it — a player who has just read a red `threat 11` has no way
  to know whether they have twelve seconds to buy a Chomp or two. The `NextWaveButton`
  is the natural home: it already knows it is enabled, and a filling bar behind its
  label (or "Grow the next wave (12)") costs one `_process` line and no new node.
- **A mutation is a sprite tint and nothing else, and the two that change the rules are
  the two nothing names.** `Pest.apply_mutation` tints armoured `(0.58, 0.66, 0.78)`,
  winged `(0.82, 0.94, 1.0, 0.88)` and hungry `(1.0, 0.52, 0.5)` — that is the entire
  player-facing signal, over a 64px sprite that is already coloured. Winged is the one
  `ChompFlower._nearest_free_pest` skips outright (`if pest.held_by != null or
  pest.is_winged: continue`), so the player learns about it as "my Chomp is broken";
  hungry is the one that runs `EAT_DPS` 14.0/s into a plant with 40 `MAX_HEALTH`, i.e.
  destroys a Sunflower in under three seconds. The selection panel just learned to show
  a plant's health while it is being chewed — the obvious companion is naming what is
  chewing it. A one-word tag over a mutated pest, or the hungry pest's target getting the
  same dashed amber ring `PlacementPreview.at_risk` already draws at placement time, would
  make the trait readable before the bar starts moving instead of after.
- **The common packet silently becomes a cheaper rare packet, and both tooltips then
  lie.** `SeedBank.buy_packet` filters `locked` by `PlantCatalog.tier(id) <= max_tier`
  and, when that pool comes back empty, falls back to `pool = locked`. Only the Chomp
  Flower is tier 1 and locked at start, so the moment a player unlocks it the only thing
  left is the tier-2 Sunflower — and a 20-seed common packet rolls it with certainty,
  while `RarePacketButton` still sits underneath asking 45 for the same guaranteed pull.
  The tooltips are the part that hurts: `PacketButton` says "tier 1 only" and
  `RarePacketButton` says "the only reliable way to a Seed Sunflower", both false at
  exactly the point in the run where a player is deciding between them. The two packet
  buttons are the last static things in a panel whose bottom half now reports live state
  — they could say "1 plant still in packets" and disable the rare tier when its extra
  reach buys nothing.
- **Four new cues shipped this cycle and the game made no sound for any of them.** There
  is no `AudioStreamPlayer` anywhere in `game/` (the only match in the repo is the
  harness's own `scene_validator.gd:131`, checking for a missing stream on a node type
  this project never instantiates), and `assets/` holds `kenney/` and `sprites/` and
  nothing else. So a wave starting, a husk rotting, an armed Uproot, a plant being eaten
  and a threat level climbing all read through the same silent 15px label. The two
  highest-value sounds are the ones with no visual at all right now: a husk expiring in
  `CompostMeter._process`, which currently just erases the id and takes the seeds with
  it, and the uproot commit. Note that `devtools_config.json` already sets `"mute": true`,
  so adding audio does not put a noise into every headless run — the harness is set up
  for this already.
- **The HUD is now the only part of the game that never moves.** `game/hud.gd` contains
  zero `create_tween` calls; every tween in the project is in-world (`plant.gd:72` plant
  pop, `corn_cobbler.gd:70` recoil, `chomp_flower.gd:142` bite, `sunflower.gd:33` bloom,
  `pest.gd:262` death linger) or on the two `GardenTheme`-styled screens
  (`title_screen.gd:287`, `notebook_screen.gd:425`). So `_selection_box.visible = true`
  snaps a 152px panel into existence, `show_banner` pops 48px of text at full opacity,
  the Uproot relabel changes colour between one frame and the next, and `threat_color`
  jumps a whole segment of its ramp the instant a wave starts rather than easing there —
  which throws away most of what a colour ramp is for. `GardenTheme.animations_enabled()`
  (`DisplayServer.get_name() != "headless"`) is the gate that already exists and already
  keeps this out of the test runs; hud.gd's own header says it deliberately styles itself
  and that is fine, but it can still borrow the one function.
- **A Corn Cobbler at "bunch" looks exactly like one at "single".** `LEVELS` moves
  `kernels` 1 → 2 → 5 and `spread_degrees` 0 → 14 → 52, and `upgrade()` does nothing but
  `level += 1` — `Plant._build_visuals` loaded one texture off `PlantCatalog.texture_path`
  and never touches it again, and `RANGE` is a flat 176.0 at every level. The only place
  in the entire game that admits a cob is fully grown is the selection panel string
  "%s — %s\n%d kernel(s) per shot", which requires clicking that specific plant. On a
  board with six cobs at three different levels, a player deciding where to spend 45 seeds
  has to click every one. The design doc draws the upgrade as a visibly wider spray, so
  the cue is already specified: a second sprite at bunch level, or three kernel pips drawn
  under the cob by the existing `SelectionMarker`-style sibling node, which is the pattern
  that already solved "a subclass overrides `_draw()` and swallows the overlay".

### New this cycle (2 of 30) — grown from watching the five features run

- **Uproot has no undo and no confirmation.** Verifying the placement preview meant
  repeatedly rebuilding a board, and the Uproot button refunds 60% instantly with no
  "are you sure" — one stray click on a selected Sunflower late in a run silently
  destroys the economy the whole run was built on. A confirm step, or a few seconds of
  undo, costs nothing and removes the only irreversible misclick in the game.
- **The threat level should colour, not just count.** `threat_level()` now produces a
  small integer that climbs 1→25 over a long endless run, and it renders in the same
  cream as everything else on the bar. Tinting it (green → amber → red as it climbs)
  would make "this wave is worse than the last" preattentive rather than something the
  player has to read and compare.
- **Nothing shows a plant's own health.** Hungry pests chew plants down over several
  seconds, and `Plant.health` is drawn as a bar — but the *selection panel* shows only
  the name and blurb. Selecting a half-eaten Corn tells you nothing about whether to
  uproot and replant it.
- **The post-mortem is one line and then it is gone.** `_end_run` now paints the run's
  whole damage map on the board and names the worst cell in a 30s message, which expires
  while the player is still looking at the banner. A proper end-of-run panel — waves
  survived, threat level reached, seeds earned, worst cell, husks missed — has all its
  data already computed and nowhere to live.
- **Husk urgency is invisible until you know the rule.** A rich husk is bigger, brighter
  *and* on a 4.5s clock instead of 10s, but the rot ring sweeps at the same visual rate
  for both because it is normalised per husk. Two husks dropped together now empty their
  rings at visibly different speeds only if you watch closely. Making the ring's colour
  shift toward red as it empties would sell the urgency the timer already has.
- **A worktree sibling can hijack the devtools bus, and the project cannot detect it.**
  Cost most of an item's runtime pass this cycle: another checkout of this same project
  had a Godot running, `user://` is shared by project name, and its game answered every
  verb. Symptoms were `no Game in the tree` and node-not-found on paths that existed.
  A one-line project verb returning `ProjectSettings.globalize_path("res://")` would let
  any session assert it is talking to its own build. Filed upstream as G-018.

### From the previous cycle — grown from watching the four features run

- **The compost readout collides with the wave button.** Caught in a screenshot while
  verifying husk scaling: with eleven husks on the ground the HUD reads
  `Compost 0 (11 ready)` and the `(11 ready)` suffix runs underneath the "Grow the
  next wave" button. `findings` reported `0 finding(s) across 5 of 5 checks` over that
  exact frame, because the label's own rect is fine — it is the *button* that overlaps
  it, and nothing compares two sibling Controls for occlusion. Two seeds here: give the
  HUD bar a real layout (an HBoxContainer with the button in its own slot) so the
  counter cannot be run over, and file the overlap check itself upstream.
- **A husk should be worth hurrying for, visibly.** Size and glow now scale with value,
  but the *timer* does not: a 9-seed husk and a 2-seed one both rot in exactly
  `HUSK_LIFETIME` 10s. A richer husk decaying faster would make the board ask "which
  one first?", which is a real decision, where today sweeping in any order is optimal.
- **Endless has no readable difficulty number.** Health, speed, count, gap and mutation
  chance now all climb independently past wave 8, and the player can see none of them —
  the HUD says `Wave 39 / 8`. One derived "threat level" on the bar (or a wave-start
  banner naming what went up) would turn an invisible ramp into something a player can
  brace for. All five scales are already pure static functions on `WaveDirector`, so
  this is a readout, not a system.
- **The lane pressure map is per-wave; the interesting question is per-run.** The
  overlay now shows a whole wave's loss distribution, faded by one decay step per wave.
  What it still cannot answer is "which cell has bled me all game" — a second, slower
  accumulator (never faded, shown only on the end-of-run screen) would make the
  post-mortem tell you where your garden was actually weak.
- **The placement preview knows enough to warn about a hungry pest.** `PlacementPreview`
  already computes reach and legality per cell. The long-standing "a Sunflower next to
  the road should look risky" idea below is now nearly free: the preview is the node
  that would draw it, and road-adjacency is one `is_path` check on the four neighbours.
- **A base class is invisible to `verify_ledger reach`.** `game/selection_marker.gd`
  scored unreached all session despite `_draw_brackets()` running every frame, because
  the only live node running it was a `PlacementPreview` and a node reports only its own
  script. Worked around with a `reach_aliases` entry, which is a declaration standing in
  for something the tool could observe by walking `extends`. Filed as G-015.

### Grown from the previous session — grown from what the running game actually feels like

- **The chew ring needs its own colour, not orange.** Verifying it just now
  (`/verify`, 2026-08-15) found the ring hard to isolate from the Chomp Flower's own
  sprite in a screenshot — the flower's petals are already warm yellow/orange, so a
  same-hue ring reads as "the flower looks a bit brighter" rather than as a distinct
  UI element. A cool colour (cyan/white) or a dashed/outlined stroke instead of a
  filled arc would actually contrast against every pest and plant sprite in the kit,
  not just this one.
- ~~Selection needs a second cue beyond the range ring~~ and ~~lane pressure
  readout~~ both shipped this session — see **Done** above.
- **Kernels should miss.** They fly straight and hit the first body in 18 px; a
  fast aphid crossing the volley diagonally survives. That is a *good* accident —
  lean into it and let the "bunch" upgrade be about covering the miss, not damage.

#### Grown from an earlier session's five features — all four shipped 2026-08-15

~~All four items in this block are done; see **Done** above. Kept for the trail from
"noticed while watching it run" to "shipped".~~

- ~~**A husk's size/glow should say how much it's worth.**~~ `HuskLayer._draw()` draws
  every husk at the same fixed 9px radius regardless of `value` — now that a
  mutated pest's husk is worth 1.5-2x a plain one (`husk_multiplier()`), the bigger
  payout is invisible until you actually click it. Scaling the circle radius (or
  the ring's brightness) by value would let "that one's worth more" read from
  across the board, the same way the mutation tint already does for the pest
  itself.
- ~~**Endless mode's escalation is still only count/gap/mutation-chance.**~~ Pest
  `health`/`speed` stay exactly what `Pest.SPECIES` says forever, even as
  `WaveDirector._endless_groups`/`mutation_chance_for` turn everything else up.
  A long endless run gets *more* pests that mutate *more often*, but each
  individual pest is exactly as tough at wave 60 as at wave 9 — scaling health or
  speed slightly past some endless threshold (mirroring the mutation-chance climb
  this session just added) would keep late-game pressure from being pure
  quantity.
- ~~**The lane pressure overlay only ever lights up one cell.**~~ `record_lane_pressure`
  takes the single furthest-reached cell, so a wave where pests died at scattered
  points along the lane (some to a Corn Cobbler near the start, one that broke
  through near the exit) only ever shows the worst one. Recording every cell a
  pest died/escaped at (not just the maximum) would draw the whole "where the
  damage actually happened" picture instead of one hot pixel.
- ~~**The SelectionMarker pattern could cover a placement preview too.**~~ Now that
  a plant's selected-state cue lives in a sibling node instead of each
  subclass's own `_draw()`, the same trick (a corner-bracket node, dimmer/dashed)
  could show "this is where the cursor would place a plant" before the click
  lands, reusing the exact node this session just built instead of a new cursor
  overlay concept.

#### Grown from the *previous* session's six features, after watching them run

- **A Sunflower next to the road should look risky, not just cheap.** A hungry pest
  eats whatever is nearest, and a Sunflower has no way to fight back — right now
  nothing on screen tells the player "this tile is one hungry mutation away from
  losing your economy plant." A thin warning ring while placing (like the cursor's
  red/green, but keyed to road-adjacency specifically for non-combat plants) would
  make that risk legible before it's paid.
- **A mutated pest should drop a better husk.** Armoured/winged/hungry all cost the
  player more to deal with than a plain pest, but `_on_pest_died` pays the same husk
  value regardless of `mutation`. A husk worth more for a harder kill would tie the
  mutation system into the compost system instead of leaving them side by side.
- **Endless mode never mutates faster.** `WaveDirector._endless_groups` scales count
  and gap, but `MUTATION_CHANCE` stays fixed at 40% forever — an endless run at wave
  40 looks exactly as "weird" as wave 8. Scaling the chance (or widening `MUTATIONS`
  with a rarer fourth trait) past some endless threshold would keep a long run from
  going numb.
- **The chew ring's colour problem, revisited.** The eating sprite (this session) now
  gives the mouth-full state its own picture, which does more of the "busy" signalling
  the earlier "give the chew ring a cooler colour" idea was chasing — worth
  re-screenshotting before spending more effort on the ring itself; the sprite swap
  may have already solved it.
- **A beetle's 2.6s chew is long enough for a second bite frame.** Right now
  `chomp_flower_eating.png` is one fixed picture for the whole chew, aphid or beetle
  alike. A second "almost done" frame — swapped in past `chew_progress() > 0.6`,
  the same threshold the shrinking ring already reads — would sell "big pests take a
  while" without a new mechanic, just a second sprite and one `if`.

### Grown straight from the brief — ALL FOUR SHIPPED (audited cycle 34)

This section said "Not filed as beads yet — these are the ones worth building" and
had said it for many cycles. Every one of them is built. Audited with
`kanban-staleness-audit` because the workflow's step 6 now requires one item per
cycle from outside the neighbourhood of that cycle's work, and this is what came
back — a whole section reading as an open backlog that is a Done list.

- ~~**Chomp Flower is occupied while chewing.**~~ **SHIPPED** —
  `ChompFlower.is_busy()` (`game/chomp_flower.gd:113`), and the file's own header
  spends three paragraphs on the busy-mouth trade the entry describes.
- ~~**Seed packets are a gamble, not a menu.**~~ **SHIPPED** — `SeedBank` rolls the
  tier's pool (`game/seed_bank.gd:213`, `pool[_rng.randi_range(...)]`).
- ~~**Corn upgrade ladder, drawn by the designer.**~~ **SHIPPED** — three levels with
  a widening arc, `game/corn_cobbler.gd:45` maps level → firing pattern and its
  header says a hand-typed spread that breaks the nesting fails rather than ships.
- ~~**Replanting is free, uprooting refunds.**~~ **SHIPPED** — 60% refund behind a
  4-second confirm (`game/game.gd:17`, `UPROOT_CONFIRM_SECONDS`).

**What this section is worth keeping for:** it is the clearest evidence in the file
that an unaudited backlog section decays into a list of things already done, while
still reading exactly like work. Four entries, four shipped, and the heading still
said "not filed yet".

### Systems that give a short game long legs

- ~~Compost meter~~, ~~pest mutations~~, and ~~endless mode with a seed-count high
  score~~ all shipped this session — see **Done** above.
- **Weather rounds.** A rain wave heals every plant; a drought wave halves fire
  rate unless a plant sits next to water. Reuses the kit's existing water tiles.

### Feel and polish

- **Wobble on plant, punch on hit, squash on chomp.** No new art needed — the
  sprites are already centred on their vertical axis, which is what makes scale
  and rotation tweens land correctly.
- **Kernel trails and husk confetti** using the kit's existing particle-ish tiles.
- ~~A "Designer's Notebook" screen~~ shipped this session — see **Done** above.

### Accessibility

- **Colour-blind-safe pest silhouettes.** Aphid and Beetle are already different
  *shapes*, not just red vs grey — keep that invariant when new pests are added.
- **Slow-mode toggle** (global `time_scale`), so the game is playable by whoever
  drew it.

### New this cycle (14 of 30) — grown from the features above

- **The prep sentence and the hatch answer the same question in two registers,
  and nothing reconciles them.** `prep_depth_note()` now says "they got 62% of
  the way down" in words, while `LanePressureOverlay` paints where along the
  road that happened. Those are the same fact at two resolutions, and a player
  reading the sentence has no reason to look at the road, which carries the
  part the sentence flattened away. The open question is whether the sentence
  should point at the road ("deepest near the second bend") or whether the
  road should acknowledge the number.

- **The hatch angle is a free channel nobody is using.** Stripes run at 45
  degrees on a board-space lattice. That direction is currently decorative —
  but the road has a direction too, and pests walk one way along it. A hatch
  leaning WITH the walk versus against it is a second bit of information for
  free, at no extra ink and no new colour. Worth knowing whether it reads, or
  whether it just looks like a defect.

- **Every warning the player can act on is now shaped; every warning about the
  past is not.** The solid-versus-broken rule in `GardenTheme.DANGER` came out
  of one issue and happens to be a real design grammar. Nothing enforces it
  beyond a doc comment and one test per site. A rule that holds by convention
  across four files is a rule that will be broken by the fifth — the question
  is whether it can be made checkable, e.g. a test that enumerates every
  DANGER-coloured draw and demands each declare which side of the rule it is on.

- **Three of the last four issues named the wrong target and the work was
  better for it.** The husk margin was classified twice wrongly, the warning
  channel named two cues that needed nothing and missed the pair that
  collided, and the lane readout was premised on lanes the board does not
  have. The backlog is written from reading the code; the corrections all came
  from reading it *again*, harder, with a specific claim to test. That is worth
  a process note: an issue that names a specific file:line is far more likely
  to be right than one that names a concept.

### New this cycle (15 of 30) — grown from the features above

- **`_on_pest_escaped` throws away the only information it has.** Every escape is
  filed against `Board.exit_cell()`, because an escaped pest's own position is
  off-board by the time the signal fires. But the pest knows where it *entered*
  the exit cell from, how long it survived, and what it walked past untouched.
  A run that leaks eight beetles through one gap and a run that leaks eight
  stragglers spread over forty waves produce byte-identical evidence. The
  subtrahend fix made the post-mortem honest; it did not make the escape
  informative.

- **Every world-space Control now sweeps itself click-transparent, and nothing
  stops the sixth one.** `Plant` and `Pest` each grew a
  `_make_world_controls_click_through()`, deliberately duplicated rather than
  shared. That is two copies of a rule with no third enforcement — the test
  enumerates the live tree, so it *would* catch a new offender, but only if the
  offender is on screen during that test. A `Control` that only appears on a boss
  wave, or in a menu that test never opens, is invisible to it.

- **The post-mortem names a cell the road may not be reddest at.** `stop_cell` is
  now losses-minus-escapes while the tint under the translucent card is still
  painted from raw losses. On a bleeding run the named cell and the reddest cell
  genuinely differ, which is correct and is documented — but a player looking
  from the number to the picture has to be told that, and nothing tells them.
  Either the card should point at its own cell, or the tint under it should
  switch to stops.

- **Four constants now carry "moving me costs you X" comments and there is no
  index of them.** `PATH_CORNERS`, `COLLECT_RADIUS`, `SUBHEAD_MAX_WIDTH` and the
  HUD's `WORST_CASE_TEXT` budgets each warn a future editor about a coupling that
  lives in another file. That is four warnings a person only finds by editing the
  exact line. A `BUDGETS.md`, or better a devtools verb that prints every declared
  budget with its current headroom, would make the set visible before someone
  goes looking.

### New this cycle (16 of 30) — grown from the features above

- **A test that passes for its own reasons is invisible until the order changes.**
  `test_kernels_launch` read `kernels[0]` out of a tree-global group and measured a
  leaked object every run; it was green for months and red the moment four unrelated
  tests were appended. Nothing enumerates the other group reads — `pests`, `husks`,
  `kernels`, `plants` — and any of them taken by index has the same defect. A sweep
  for `get_nodes_in_group(...)[0]` in `test/` would find the rest in one pass.

- **Tests leak nodes into groups and nothing notices.** The root cause under the above:
  a test that builds a Kernel and does not free it leaves it in the group for every
  later test. `_T.free_ui` is called on hosts, but a kernel spawned by `_act` is
  parented to the host's parent, not the host. A per-test assertion that the tree's
  group counts return to where they started would catch the whole class.

- **Three budgets are tight and one is spent, and the game has no idea.**
  `cmd budgets` now says so from outside, but nothing inside the game reacts.
  `SIMULTANEOUS_PEST_CEILING` at 40 of 40 means the road has no slack for any future
  wave shape; the two HUD budgets sit within 8 px and are *coupled*, since widening a
  readout is paid out of the row sum. The interesting version is a startup
  `push_warning` when any budget crosses its own tight threshold, so the next person
  to spend one hears about it on the next run rather than on the next audit.

- **Engagement is recorded at the exit and nowhere else.** `was_engaged()` answers one
  question at one instant. The same flag, sampled per road cell, would say *where* the
  garden stopped reaching — which is the coverage-hole map the post-mortem's "walked in
  untouched" line currently only aggregates. That is the honest next step for the escape
  work, and it is a genuinely different map from lane pressure: pressure says where they
  got to, this would say where nothing could touch them.

### New this cycle (17 of 30) — grown from the features above

- **Two maps of the road now exist and neither knows about the other.**
  `coverage_frontier()` says how far the garden can reach; `LanePressureOverlay` says how
  far pests got. The prep line already compares them once, to pick which sentence to
  show. The board never does — a player sees red tint over cells and has no way to tell
  "they got here and we fought" from "they got here and nothing could touch them", which
  is the whole distinction the coverage work just established.

- **`ENGAGING_PLANTS` is a positive list and the catalogue is not checked against it at
  build time.** A fifth plant fails a test, which is the right failure — but it fails
  *after* someone has written the plant. A `PlantCatalog` entry could declare whether it
  engages, so the answer lives with the plant rather than in a list two files away that
  has to be remembered.

- **The derived coverage map is an upper bound and the gap is never shown.** A Corn shoots
  only the furthest-along pest; a busy Chomp grabs nothing; a winged pest is unreachable
  by a Chomp at all. So "covered" over-promises in exactly the situations a player is
  losing. The observed-versus-derived difference was dismissed as unbuildable from a
  monotone flag — but a *per-cell* record of "something was in range and did not fire"
  is not monotone and would measure the over-promise directly.

- **Every gate now prints a denominator except the one that matters most.** `run_tests`
  says `Suite: 7 script(s)` and `Assertions: N`, the checkers say `N of M`, lint says
  `Shaders: N of M`. Nothing says how much of the *game* the suite touches — which
  scripts are never loaded by any test. `scripts-seen` exists in the bridge and nothing
  compares it against the file list.

### New this cycle (18 of 30) — grown from the features above

- **Two tests in this repo now wait for a thing instead of assuming a frame count, and
  nothing finds the third.** `test_hosting_a_loaded_cob` asserted a volley had fired by
  the time `instantiate_scene` returned; the count is unspecified and it went red when
  unrelated tests shifted timing. Any test that reads state straight after
  `instantiate_scene` without awaiting a condition has the same exposure. A checker for
  "reads a group or a live property within N statements of `instantiate_scene`, with no
  intervening await-until" would name them.

- **15 signals still have nothing asserting what they carry.** Down from 17. The purse's
  three are done and were worth doing — one mutation showed a refund could stop
  announcing while still moving the purse. The remaining clusters are `Hud`'s five
  button signals, `PauseScreen`'s four, `Pest.died`/`escaped` and `WaveDirector`'s two.
  `Pest.died` is the highest value: it is the income path with the most wiring under it.

- **The reach gate can be satisfied without being served, and says so.** `naming is a
  floor, not exercise` — a test writing `WaveDirector.reset()` and asserting nothing
  counts. The honest upgrade is not a stricter name match but a second signal: whether
  the named symbol appears inside an `assert_*` argument, or only in a statement. That
  distinguishes "called it" from "checked it" without pretending to understand the test.

- **Coverage is now measured in both directions and neither number is in the game.**
  Under-promise: 7 kills on unaimed ground at up to 202px. Over-promise at the pest:
  zero of 116. Both live only in commit messages and a comment. The board says
  "unaimed", which is exactly right, but a player never learns that unaimed ground still
  gets kills — which is the thing that would stop them over-buying cover.

### New this cycle (20 of 30) — grown from the features above

- **Corn Cobbler counts down to its next shot in a private variable, and nothing about
  the plant says whether it is loaded.** Sunflower's payout clock got a gauge that
  fills as the next `INTERVAL` nears (sunflower.gd:150-156, always on, no click
  required) and Chomp Flower's chew gets a shrinking ring the instant its mouth is full
  (`_draw`, chomp_flower.gd:130-136) — but `CornCobbler._cooldown` (corn_cobbler.gd:88,
  decremented every frame at corn_cobbler.gd:95-97) is read by nothing outside `_act()`.
  The always-on muzzle fan (`_draw_muzzle_fan`, corn_cobbler.gd:141-152) is a readout of
  the *last* shot's spread, not the *next* one's timing, so a cob mid-reload and a cob
  about to fire are pixel-identical.

- **A Sticky Sundew catching a pest is a metadata write with no picture and no sound.**
  `_claim()` (sticky_sundew.gd:244-250) sets `META_BASE_SPEED`/`META_SOURCES` and
  multiplies `pest.speed` by `SLOW_FACTOR` — the entire content of "this pest is now
  stuck" — and calls neither `Sfx.play()` nor a tween nor anything that touches the
  caught pest's own sprite. Corn's `_recoil()` fires from `_fire_at()` and Chomp's
  `_bite()` fires from `_grab()` — every other plant marks its verb at the instant it
  lands, and Sundew is the one whose defining moment is currently silent on both ends.

- **A field named for the fix already exists on `Plant`, and nothing ever writes to
  it.** `var _wobble_time: float = 0.0` sits at plant.gd:104, and no method in the
  class — not `_physics_process`, not `_act`, not `_draw` — reads or increments it.
  Between events a placed plant is a completely static sprite, so a Corn Cobbler that
  fired ten seconds ago and one that has never fired at all look the same at rest. A
  small `sin(_wobble_time * k)` sway on `_sprite.rotation`, gated behind
  `GardenTheme.animations_enabled()` the way `_bloom()` already gates itself
  (sunflower.gd:171), would use the field for what its own name already promises.

- **Selecting a plant is the one interactive click in the game with no motion attached
  to it.** `Plant.set_selected()` (plant.gd:462-468) toggles
  `_selection_marker.visible` directly, and `SelectionMarker._draw_brackets()`
  (selection_marker.gd:41-46) draws the four corner brackets at a fixed size the
  instant the flag flips — nothing between invisible and full-size, no tween anywhere
  in either file. Contrast the plant underneath it: `_build_visuals()` pops the sprite
  in from 0.4x scale over 0.22s on placement (plant.gd:187-190). The one moment a
  player deliberately reaches for — clicking a plant to read its state — is the one
  moment nothing on the board acknowledges having happened.

- **A pest exists at full opacity the instant it exists; there is no frame where the
  game says "one is coming."** `Game.spawn_pest` (game.gd:630) creates a `Pest`, adds
  it as a child and calls `setup()`, which sets `position = _route[0]` in the same
  call (pest.gd:192). Nothing tweens alpha or scale up from zero at the road's entry
  cell, and each wave's own `lead` (0.5–2.0s in every `WAVES` row, wave_director.gd:96-121)
  is spent silently before the first spawn rather than visibly counting it down.
  `SunFlower._bloom_flash` (sunflower.gd:70, 176-181) already shows the codebase's
  pattern for a `tween_method` ramp-in; nothing plays it at the moment every pest's
  whole run begins.

- **`kill()` is the single door every death walks through, so a kernel that ticks off
  the last hit point and a Chomp that finishes a held meal look identical.** Both land
  in the same `_play_death()` (pest.gd:484-505): swap to the dead-eyes texture, drop
  the tint, hold `DEATH_LINGER` 0.35s, free. A pest shot from 176px away and a pest
  held motionless in a mouth for 2.6s are staged by completely different plants, and
  the corpse gives no sign which one actually happened — a ranged kill could stagger
  back or crumple where it stood, and a Chomp kill could vanish into the mouth instead
  of lingering on the road at all.

- **`_on_pest_escaped` touches the scoreboard and nothing on the board.** The whole
  handler (game.gd:697-718) is a sound cue, `lives -= 1`, and a HUD refresh — no flash
  at `board.exit_cell()`, no shake, nothing keyed to the position the loss actually
  happened at. The one thing that does record where it happened, `_note_lane_loss`
  (game.gd:288-294), is not painted until wave end (`_commit_lane_pressure()`,
  game.gd:304-313) — so even the lane pressure hatch is silent at the instant of the
  escape it is about. A run can lose three lives in five seconds and the board looks
  exactly as calm through all three as it did through zero.

- **Wave 8 is the wave the whole mutation system switches on, and the banner cannot
  tell the difference between it and wave 7.** `WaveDirector.MUTATION_START_WAVE` is 8
  (wave_director.gd:14) — the first wave a player can see an armoured, winged or
  hungry bug at all. But `Hud.announce_wave` always renders `wave_headline(number)`,
  which is unconditionally `"Wave %d" % number` (hud.gd:991-992), through the
  identical wave-started cue every wave plays. `escalation_note()` only speaks past
  the fixed table (wave_director.gd:384-385), so wave 8's own banner note is empty
  too — the wave that hands the player a new kind of bug reads with strictly less
  text than a wave 40 endless escalation gets for merely being "tougher."

- **`RunSummary._play_entrance` rises fourteen labels and two buttons in the same 0.28
  seconds, and the card that most wants a sequence gets none.** It loops
  `get_children()` and hands every non-`Backdrop` Control its own `create_tween()` at
  identical `RISE_SECONDS` (run_summary.gd:462-470) — no delay, no offset between
  rows — so all seven stat rows and both buttons arrive at once, the one card whose
  whole point is a player reading down a list of numbers computed just now.
  `TitleScreen._play_entrance` already solves exactly this with `ENTRANCE_STAGGER`
  0.07 between its seven rows (title_screen.gd:389-391); the post-mortem's rows are
  already built from one ordered table (`summary_rows()`), so a per-row delay keyed to
  loop index costs the same borrowed constant and turns a stat dump into a card being
  read out.

- **Every HUD readout that changes every frame changes by simply overwriting `.text`.**
  `Hud.refresh()` sets `_seeds_label.text`, `_lives_label.text` and
  `_compost_label.text` outright on every call (hud.gd:731, 753, 755) — the same
  method that already eases the wave label's *colour* toward `threat_color()` with a
  killed-and-restarted `Tween` rather than snapping it (`_ease_threat_tint`,
  hud.gd:898-911). A short scale-punch on the label that just changed, gated the same
  way `_ease_threat_tint` already is, would give the one motion vocabulary this file
  has proven out to the readouts that fire the most often — a kill payout, a life
  lost, a husk composted.

- **`NotebookPage`'s page dots repaint instantly while the page they are counting
  turns with a tween.** `current_page`'s setter calls `queue_redraw()` and nothing
  else (notebook_page.gd:38-41), so the filled dot jumps to the new page the instant
  `go_to()` writes it, in the same frame `_play_turn()` is still 0.18 seconds into
  fading the drawing and sprite in (notebook_screen.gd:577-587). The one readout built
  specifically to answer "how much is left" is the one piece of the page turn that
  never turns.

- **`PauseScreen` is the only card-over-the-board screen with no tween anywhere in its
  file.** Its own header calls it "shaped after RunSummary" for being "the same kind
  of object: a card over a live board" (pause_screen.gd:12-14), but `RunSummary` and
  `TitleScreen` both rise their content in against
  `GardenTheme.animations_enabled()`, and `PauseScreen` has no `create_tween` or
  `modulate` write at all — the card appears with `add_child` and disappears on
  `_pause_layer.queue_free()` (game.gd:821) on the same frame Escape is pressed. It is
  also the screen a player reaches for most often, mid-run, under time pressure, and
  the one that currently snaps both ways while its two siblings ease at least one.

- **The seed count only ever teleports.** `Hud.refresh()` sets `_seeds_label.text =
  "Seeds  %d" % bank.seeds` (hud.gd:731) on every refresh, so a Sunflower's 3-seed
  yield, a husk worth up to 9, and a 20-seed packet cost leaving the purse all land as
  the same instantaneous digit swap. `SeedBank.seeds_changed` only ever carries the
  new total, not the amount that moved, so there is not even the data a HUD-side cue
  could read without diffing it itself. The compost stat two labels over already knows
  how to show a delta — `_compost_label.text += "  +%d" % husks` (hud.gd:762) — but
  that pattern never reaches the number every transaction in the game actually
  changes.

- **A refused purchase has a sentence and nothing else.** `SeedBank.pay_for_plant()`
  and `buy_packet()` both emit `purchase_failed` with only a reason string on every
  refusal (seed_bank.gd:111-121, 179-190), and `Game._ready` wires it straight to
  `hud.show_message(reason)` — a caption in the shared status line, nothing more.
  `Sfx.SOUNDS` has an entry for a plant going in, a plant dying, a pest dying, even a
  wave starting, but none for a purchase bouncing. A one-frame red shake on the button
  actually clicked, plus a short cue added to `SOUNDS`, would put the "no" where the
  click landed instead of only in text a player mid-wave may not be reading.

- **The packet's whole gamble resolves in the same frame it is bought.**
  `SeedBank`'s own header calls a packet purchase "a gamble rather than a menu" and
  says "with a short catalogue that reads as suspense" (seed_bank.gd:8-10), but
  `buy_packet()` deducts the cost, rolls the pool and emits `plant_unlocked` in one
  synchronous call (seed_bank.gd:192-197), landing as a text banner the instant the
  button is released. There is no beat between spending the seeds and knowing the
  result — no packet opening, no flicker through the tier-eligible pool before landing
  on one — so the suspense the code's own comment promises is written in a docstring
  and skipped entirely on screen.

- **A swept husk vanishes and the seeds it paid appear somewhere else on the screen.**
  `CompostMeter.collect_at()` erases the husk from `_husks` the instant it is clicked
  (compost_meter.gd:147), and `Game._click_at` hands the value straight to
  `bank.add_seeds(swept)` (game.gd:1205) — which lands in the Seeds stat at the top of
  the HUD, well away from wherever on the board the click happened. A seed glyph that
  flies from the husk's own position to the Seeds label, sized off
  `HuskLayer.radius_for(value)` the way the husk already was, would carry the payout
  across the screen instead of asking the player to read the same number twice in two
  different places.

- **The game binds four keys and none of them live in an `InputMap`.**
  `project.godot` has no `[input]` section at all — every binding is a raw scancode
  compared inline: `key.keycode == KEY_R` gated on `game_over or victory`
  (game.gd:1109), `KEY_ESCAPE or KEY_P` for pause (game.gd:1114), `KEY_M` for mute
  (game.gd:1121), and `NotebookScreen` repeats the pattern for its own three keys.
  `Game.KEY_HELP` is the one place these are named, and it only ever renders as a
  legend on the pause card — nothing has ever called `InputMap.add_action`. A settings
  screen that reads/writes those four bindings through a real `InputMap`, persisted
  beside `RunConfig`'s two scores, turns the printed legend into a configurable one.

- **Every run computes its own post-mortem and none of it survives the scene it was
  born in.** `RunSummary.summary_rows()` totals waves survived, pests killed, threat
  reached, and more from data `Game` has been accumulating the whole run, and
  `RunConfig._save()` writes exactly three lines — a version header,
  `campaign_high_score`, `endless_high_score` (run_config.gd:268-270) — throwing every
  one of those totals away the instant the title screen loads. A small persisted set
  of milestone flags, checked once at `_end_run` against numbers the game is already
  holding, is most of an achievements system without a single new gameplay counter.

- **The Designer's Notebook already has a page for every plant, unlocked for a player
  who has never planted one.** `NotebookScreen.PAGES` covers all four catalogue
  entries, reachable from the title screen before a seed has been spent. But which
  plants a save has actually pulled from a packet is never recorded —
  `SeedBank.packet_pool()` draws are per-run and vanish with the scene, so a
  brand-new player and someone who has cleared endless past wave 100 are handed the
  exact same book. Gating each page behind "drawn at least once," backed by a small
  persisted set next to `RunConfig`'s scores, would turn the packet gamble into a
  discovery mechanic.

- **The two readouts a player watches hardest in combat are both a single red-green
  lerp, and the accessibility list only ever promised to protect the pests.** A
  plant's health bar is `HEALTH_LOW.lerp(HEALTH_FULL, fraction)` (hud.gd:879, with the
  constants at 281-282) and `threat_color()` eases cream through amber to the same red
  across the whole difficulty ramp (hud.gd:692-702). The existing Accessibility entry
  commits to keeping aphid and beetle visually distinct shapes as new pests are added;
  it says nothing about these two bars, which are hue-only cues carrying the two
  questions a run turns on — is this plant about to die, is the next wave about to
  hurt. A colorblind-safe palette swap or a second channel — a tick mark, a hatch
  density — for exactly these two ramps is the natural next entry under that same
  heading.

### New this cycle (21 of 30) — grown from the features above

- **Upgrading a Corn Cobbler is `level += 1` and a redraw, with nothing marking the
  instant it happens.** `CornCobbler.upgrade()` (corn_cobbler.gd:290-297) bumps
  `level` and calls `queue_redraw()` so the muzzle fan picks up the new pip count on
  its next paint — but that is a static fact about the plant at rest, not a cue at
  the moment the player actually spent the seeds. Contrast `ChompFlower._bite()`
  (chomp_flower.gd:139-144), which squashes its sprite through `Vector2(1.18, 0.82)`
  and back on every single meal. A cob levelling up is a rarer, bigger moment than
  any one bite and currently reads as quieter than one.

- **Both ways a plant leaves the board end in the same bare `queue_free()`, and one
  of them is completely silent.** `Game._on_plant_destroyed` (game.gd:987-995) at
  least plays `Sfx.PLANT_DESTROYED` before freeing the eaten plant on the same
  frame; `Game.uproot_selected` (game.gd:1084-1093) refunds the seeds and calls
  `plant.queue_free()` with no `Sfx.play()` call anywhere in the function and no
  animation in between — a plant the player deliberately removes just vanishes.
  Neither path tweens the sprite out the way `_build_visuals()` tweens one in
  (`plant.gd:187-190`, 0.4x to 1.12x to 1.0 over 0.22s); a `create_tween()` shrinking
  `_sprite.scale` toward zero before either `queue_free()` call, gated behind
  `GardenTheme.animations_enabled()`, would give leaving the board the same care
  arriving on it already gets.

- **Clearing a wave is the payoff for everything that happened in it, and it gets a
  single status-row sentence.** `Game._check_wave_cleared()` (game.gd:322-338) sets
  `_wave_live = false`, commits the lane pressure map, and calls
  `hud.show_message(Hud.wave_cleared_line(...), 6.0)` — no `Sfx.play()`, no flash,
  nothing on the board itself. `_on_wave_started` two hundred lines away plays
  `Sfx.WAVE_STARTED` (game.gd:272) into a 48px banner the instant a wave begins
  (`Hud.announce_wave`, hud.gd:1044-1053). The wave a player survives currently
  announces itself more quietly than the wave that is about to attack them.

- **None of the three plants that actually fight ever calls `Sfx.play()` for their
  own attack.** `CornCobbler._fire_at()` (corn_cobbler.gd:116-132) spawns kernels
  and calls `_recoil()` (corn_cobbler.gd:174) with no sound; `ChompFlower._grab()`
  (chomp_flower.gd:77-84) closes the mouth and calls `_bite()` the same way. Every
  combat sound in the game is centralised in `game.gd` and fires on the *pest's*
  reaction instead — `Sfx.PEST_KILLED` when something dies, `Sfx.PLANT_BITTEN` when
  a pest bites back — so a Corn Cobbler volleying five kernels at once and a Chomp
  Flower snapping shut are both silent on the attacker's end. (The Sticky Sundew's
  `_claim()`, sticky_sundew.gd:244-250, already got this note last cycle; it turns
  out the same gap runs through all three attacking plants, not just that one.)

### New this cycle (22 of 30)

- **`Plant` has a field for idle sway and nothing ever writes to it.**
  `_wobble_time: float = 0.0` (plant.gd:104) is declared and never read or written
  anywhere else in the file — a sweep of every `var` declared in `game/` turned up
  exactly one field with no second reference, and this is it. It reads like a stub
  for exactly the ambient motion James already asked for directly ("animate all the
  plants and enemies", see the backlog entry above); the hook is already sitting
  there, unwired.

- **A pest's corpse pops out of existence the instant `DEATH_LINGER` ends.**
  `_play_death()` (pest.gd:484-505) swaps to the dead-eyes texture and holds it for
  0.35s, then `tween.tween_callback(queue_free)` — nothing tweens `modulate.a`
  first, so the corpse is at full opacity on its very last frame and simply gone on
  the next. Every other exit in this game fades: `Plant.play_exit_and_free()`
  shrinks a sprite to zero before freeing it, and `Pest`'s own arrival fades it in
  from nothing. The one death every wave produces dozens of is the one exit left
  un-eased.

- **The prep strip drains to zero with no final-second urgency.** `_refresh_prep_bar`
  (hud.gd:671-682) shrinks `_prep_bar` in lockstep with `prep_left` and tints it by
  `next_threat_level`, which is real information calmly delivered — but the last
  second before a wave lands is exactly the moment a player most wants a nudge, and
  today it gets the same steady shrink as the other seventeen. A brief pulse on
  `_prep_bar.modulate` once `left` drops under a couple of seconds — the same
  `_ease_threat_tint`-style kill-and-restart shape `t5l` reused for the readout
  punches last cycle — would put the same clock the bar already draws under the
  player's eye right as it matters most.

- **A won run and a lost run rise onto the same card the same way.** `RunSummary`
  picks a different heading text and colour for victory (`_build_heading`,
  run_summary.gd:144-153, "The garden holds!" vs "The garden is eaten") but
  `_play_entrance()` (run_summary.gd:462-470) rises every Control by the identical
  `RISE_OFFSET` over the identical `RISE_SECONDS`, with no branch on `won`
  anywhere in it. The two headings already disagree about how the run went; the
  motion carrying them onto the screen currently does not.

### New this cycle (23 of 30) — grown from the features above

- **A kernel that connects and a kernel that whiffs both just vanish.** `Kernel._physics_process`
  (kernel.gd:60-72) has exactly two exits: leave `_bounds` and `queue_free()`, or land
  inside `HIT_RADIUS` of a pest, call `take_damage()`, and `queue_free()` — same call,
  same frame, no distinction drawn on screen between the two. Every plant now has an
  attack cue of its own (`y62`, this cycle) and every pest death fades instead of
  popping (`3t9`, this cycle); the projectile connecting them is the one link in that
  chain with no impact flash, spark, or even a differently-timed vanish to say a hit
  landed rather than sailing off the board.

- **The title screen is the first thing every player sees, and it is the one screen
  in the game with zero motion.** `TitleBackdrop` (title_backdrop.gd) draws sky, glow,
  ground, a scalloped grass edge and tufts — six `_draw_*` functions, all of them
  static geometry, none of them touched by a `Tween` or a per-frame value. Contrast
  everywhere else this session has been busy: plants sway idly (`04x`), selection
  brackets grow in (`yx0`), HUD readouts punch (`t5l`), cards rise and fall (`c03`,
  `9ti`). The screen a player stares at before any of that exists is the one place
  none of it happens.

- **This game has no music, only one-shot cues.** `Sfx.SOUNDS` (sfx.gd:68+) is
  entirely footsteps, impacts, and stingers — every entry plays once and stops.
  There is no `AudioStreamPlayer` anywhere driving a loop, no title theme, no bed
  under a wave. Eight-plus attack/death/UI cues now layer onto complete silence
  between them, which is a bigger gap the louder the sound design gets.

- **The notebook's page counter repaints instantly while the page it is counting
  turns with a tween.** `NotebookPage.current_page`'s setter calls `queue_redraw()`
  and nothing else (notebook_page.gd:38-41), so the filled dot jumps to the new page
  the instant `_page` changes (notebook_screen.gd:547), in the same frame
  `_play_turn()` (notebook_screen.gd:577) is still partway through fading the
  drawing and sprite in. The one readout built specifically to answer "how many
  pages are left" is the one piece of the page turn that never turns.

### New this cycle (24 of 30) — grown from the features above

- **Music shipped with exactly one volume: on or off.** `Music.BASE_VOLUME_DB`
  (music.gd:53) is a fixed constant every track plays at; the only lever anywhere is
  `Sfx.set_muted()` / `KEY_M`, which now silences both the sound effects and the two
  new music beds together. `Sfx.SOUNDS` has grown to eight-plus distinct cues this
  session alone, layered over a bed that is always either full volume or gone — no
  in-between for a player who wants the music quieter than the effects, or vice
  versa. A settings surface (or even just two sliders reachable from the pause
  card) is the natural next step now that there is a mix to actually balance.

- **The denial cue covers two of the three ways a purchase can be refused, and
  stops one short.** `Hud.shake_plant_button()`/`shake_packet_button()` plus
  `Sfx.PURCHASE_DENIED` (game.gd:1128, 1303) now fire when a plant or a packet is
  refused — but `Game.upgrade_selected()` (game.gd:1012-1026) still answers an
  underfunded upgrade with a bare `hud.show_message()` and nothing else, the exact
  gap `8kx` closed everywhere else this session. The Upgrade button is a `BaseButton`
  like the other two; the same shake call is one line away.

- **`Pest.flash_hit()` exists now, and only `Kernel` ever calls it.** The new hit
  cue (`7o3`, kernel.gd:76) is a method on `Pest` itself, not something private to
  the projectile — but a Chomp Flower's bite and a Sticky Sundew's claim, which
  land just as real a hit, never call it. A ranged kernel now visibly marks the
  pest it connects with; a melee plant's damage is exactly as invisible as it was
  before this session started.
### Audited and removed: the "grown from the features above" sections 25-27 (cycle 64)

Eight entries, resolved one at a time against the code with `kanban-staleness-audit`.
**Six SHIPPED, two STALE, none still wanted** — so the sections went rather than being
pruned. The verdict table and its evidence are in this commit's message, which is
searchable and does not add eight entries to a Done section nobody reads (`-tkdz` is open
to prune that one).

Three findings kept out here rather than buried in a log:

- **A number that reproduces exactly is the most convincing kind of wrong.** The title
  screen entry quoted `BUTTON_TOP` 208, heights 44/40 and `BUTTON_GAP` 8. All four still
  reproduce today. Its conclusion — "there is no sixth row available at any price" — is
  false: `game/title_screen.gd:45-62` pairs secondary destinations two to a row,
  `menu_capacity()` computes the ceiling and a test gates it. Both shapes the entry asked
  someone to choose between are considered and rejected there, with reasons.
- **An entry points at where the problem was, not where the fix landed.** "Starting a wave
  has no click of its own" cited the button in `hud.gd`. The button is unchanged; the sound
  went into the handler (`game/game.gd:308-309`). Checking only the cited line would have
  produced a confident, wrong "still real".
- **These headings are not unique.** `### New this cycle (25 of 30)` appears twice, in two
  independent numbering runs with different subtitles — so `uniq -d` on the headings finds
  nothing and a naive `index()` on one deletes from the wrong place. Cut this file by line
  number, never by heading.

### New in cycle 110 — grown from the Barrier Bramble (`plant-tower-defense-3mhn`)

- **The word "held" now means two different things, and the file that owns it argued
  itself into the collision.** `game/run_summary.gd:468` is the row's heading and `:838-851` (`_stop_cell_text`) the text under it, printing
  "Where you held them", and `:830-837` spends a paragraph choosing that word over
  "stopped" on exactly this reasoning: *"'Held' is true of a kill and false of an escape,
  so it cannot be read off the tint at all."* The number behind it is `stop_cell_stops` —
  `Board`'s per-cell losses with escapes subtracted (`game/board.gd:150-162`), i.e. KILLS.
  As of this cycle the game has a plant whose entire mechanic is holding and which kills
  nothing: a pest stopped by a Barrier Bramble stands there, chews through, and walks on,
  contributing zero to that row. So a run won on a wall of Brambles and cobs reports the
  cobs' cell, and a run where Brambles bought every one of those seconds says nothing
  about them at all.
  Both readings are defensible and the entry is NOT "rename the row". The card has one
  spatial row and now two spatial stories — where they died, and where they were made to
  wait — and the interesting question is whether the second is worth its own row, its own
  tint on the map underneath, or nothing at all. Decide before adding a second wall-shaped
  plant, because the ambiguity is cheap now and expensive once two plants share it.

- **The selection panel's health readout is true and misleading on exactly one plant.**
  `game/hud.gd:2365` computes `fraction = plant.health / Plant.MAX_HEALTH` and `:2373`
  prints `"Health %d/%d"` against the same constant. Both are correct for all nine plants —
  `Bramble` does not change `MAX_HEALTH`; it scales the incoming bite in `take_damage`
  (`game/bramble.gd:174`, `BITE_RESISTANCE` 0.25). So a Bramble at "Health 40/40"
  survives four times longer under a mouth than a Corn Cobbler reading the same 40/40, and
  nothing on screen says so.
  Note which claim is being made: not that the number is wrong, but that the panel has no
  vocabulary for *toughness* as distinct from *health*, and this is the first plant that
  needs one. `Bramble.hold_seconds(n)` already computes the honest answer in seconds and is
  currently read only by a test (lint: `hold_seconds() is referenced only from tests`).
  The cheap version is a second line on the panel for a plant that resists; the expensive
  version is a second bar. Taste: a line, and only on plants where the two numbers differ.

- **Nothing in the game changes a plant's picture as it is damaged, and a wall is where
  that first stops being acceptable.** Searched for the property rather than the API: every
  assignment to `_sprite.texture` in `game/` is in `chomp_flower.gd:745-785` (idle → gape →
  eating → late-bite, driven by `chew_progress()`) and `dandelion.gd:374` (fluff frames,
  driven by ammo). Both are STATE machines; neither reads `health`. Grepping `health`
  across `game/*.gd` for any texture, sprite or frame term returns nothing on any plant.
  So damage is shown only by the in-world bar (`Plant.HEALTH_BAR_ORIGIN`) and the flinch.
  On eight plants that is fine — they are damaged incidentally. A Barrier Bramble is
  damaged *as its function*, the player is watching it specifically to judge whether it
  will last, and the whole readout is a 32×5 px bar. Two or three chewed-through frames
  would put the answer in the silhouette, where the player is already looking. `art_src/`
  already has four-frame precedent (`dandelion`, `dandelion_thinning`, `dandelion_sparse`,
  `dandelion_bare`) and `test_sprite_style.gd`'s `EXPECTED_SIZE` documents that set as one
  drawing at four densities, which is the same shape a chewed bramble wants.

### New in cycle 111 — grown from the toughness readout and the surveys

- **Drought does nothing at all to a wall, and that is a free seam for the weather
  counter-play question.** Enumerated rather than exampled: every consumer of the weather
  factor is a call to `Plant.composed_interval` (`game/plant.gd:150-151`), and there are
  exactly three — `game/corn_cobbler.gd:592`, `game/dandelion.gd:277`,
  `game/nettle.gd:253`. All three are firing intervals. A Barrier Bramble fires nothing,
  so `WaveDirector.fire_interval_scale_for` reaches it and changes nothing; the only
  weather that touches it is rain, through `Game._apply_weather`'s flat
  `Plant.MAX_HEALTH * heal_fraction_for(next)` loop (`game/game.gd:425`).
  Two consequences, and the second is the interesting one. (a) A drought wave is strictly
  easier for a garden built on walls than for one built on cobs, which nobody chose. (b)
  That rain heal is a FLAT amount of health, so on a plant with `bite_resistance()` 0.25
  it buys four times as many seconds as it buys anywhere else — the same multiplier
  `game/bramble.gd`'s header argues makes the Salve Aloe worth having behind a wall, except
  this one arrives from the sky every fifth wave whether it is wanted or not.
  `-oo7e` is open and says weather has no counter-play and must not be built until James
  picks a direction. This entry is not a proposal to build one; it is the observation that
  the ninth plant quietly created an asymmetry the decision now has to account for, and
  that "drought dries out a bramble and it is chewed faster" is a counter that needs no
  terrain — which is exactly the cheap option `-oo7e`'s notes ask for.
  (Note while you are in there: `game/wave_director.gd:814` says "three of the eight plants
  in the catalogue". The three is still right; the eight is not.)

- **The plant most obviously wanting an upgrade ladder is the one that cannot be upgraded,
  and only two of nine can.** Searched for the behaviour, not one class: `upgrade_ladder()`
  is a `Plant` virtual (`game/plant.gd:853`) and exactly two subclasses override it —
  `game/corn_cobbler.gd:403` and `game/chomp_flower.gd:332`. That enumeration is already
  gated: `test_the_seed_sink_is_finite_while_the_seed_income_is_not` asserts the override
  set is exactly `["chomp_flower", "corn_cobbler"]`, so this is checked rather than
  remembered.
  A wall is the classic thing to thicken, the vocabulary already exists on the panel as of
  this cycle ("Holds 11s against one pest"), and a ladder is the one seed sink this game
  has (same test: "only two of nine plants can absorb a seed after they are placed"). A
  Bramble is also the first plant that is a RECURRING cost, since it is consumed by working
  — so "spend more on this one so you replace it less often" is a decision the economy does
  not currently offer anywhere.
  Taste, no citation offered: two rungs, and the second should buy TIME rather than health
  — a higher `bite_resistance()`, not a bigger pool — so the Aloe interaction scales with
  it instead of being diluted by it. That is the same argument `game/bramble.gd`'s header
  makes for choosing resistance in the first place, applied one level up.

### New in cycle 112 — grown from confirming a bead and reading a sentence

- **Nothing in this project can tell whether a sentence is TRUE, and cycle 112 found one
  that had quietly stopped being.** `Hud.eaten_message` (`game/hud.gd:3593`) read "A hungry
  pest ate your %s!" and was correct for every plant death in the game until the ninth
  plant: `Pest._physics_process` reaches `_adjacent_plant()` only inside its `is_hungry`
  branch (`game/pest.gd:1282-1286`), so a hungry pest really was the only thing that could
  destroy a plant. A Barrier Bramble is chewed by `_blocking_plant()`, which every pest
  runs. Nineteen checkers, lint and 897 tests were green over it throughout.
  The entry is not the fix, which shipped this cycle. It is the class: **this project has
  built fifteen checkers for things a machine can decide, and the message corpus is the
  closest it gets to prose — and `message_corpus_check.py` verifies that a line is PRICED,
  never that it is accurate.** Every one of the ~30 producer strings in `Hud` is a factual
  claim about the game, several are years of cycles old, and nothing has ever re-read them
  against the code. A sweep is cheap once and would not be a checker: read every producer,
  ask what has to be true for it, and cite the line that makes it so. Do it once, record
  the misses, and decide afterwards whether any of it can be mechanised.

- **The three overlays are opened and found three different ways, which is why the new
  inert sweep has to name them.** Enumerated: `KeyBindingScreen.NODE_NAME` is
  `"KeysScreen"` (`game/key_binding_screen.gd:34`) and `OptionsScreen.NODE_NAME` is
  `"OptionsScreen"` (`game/options_screen.gd:54`), but `NotebookScreen` declares no
  `NODE_NAME` at all — `PauseScreen.notebook_open()` reads a `_notebook` field instead
  (`game/pause_screen.gd:712-713`). `name_check` caught a new test reaching for the
  constant that does not exist, which is the cheap version of this bill.
  The cost is that `test_every_overlay_makes_everything_under_it_unfocusable` carries a
  hand-written list of three and asserts its own length, rather than discovering overlays
  from the tree — and `-cs2k`'s whole ambition was to "catch the fourth screen nobody has
  written yet". Giving `NotebookScreen` a `NODE_NAME` like its two siblings, and
  `PauseScreen` one accessor that returns whichever overlay is up, would make that sweep
  genuinely automatic. Small, and it is the difference between a test that fails when a
  fourth screen arrives and one that covers it.

### New in cycle 113 — grown from the move-preview mis-promise

- **One function returns both success sentinels, and a test comment already misreads it.**
  Every `-> String` method on `Game` follows one convention: `""` means it worked, a
  non-empty string is the reason it refused, and the callers print it
  (`game/game.gd:1490` `place_plant`, `:1711` `upgrade_selected`, `:1911` `commit_uproot`).
  `arm_uproot` (`game/game.gd:1762`) breaks it in the most confusing available way: the
  first press returns `"confirm needed"` (`:1822`) and the second returns `""` — via
  `commit_uproot()` at `:1778` — so the SAME function uses the refusal sentinel for one
  success and the success sentinel for another.
  The cost is already visible in the suite rather than hypothetical. Five call sites assert
  the literal, and `test/unit/test_placement.gd:255` labels it *"the first click refuses"* —
  which is what the convention says that value means and is not what happens; the first
  click arms a live four-second window and posts a message. A cycle-113 test asserted `""`
  there and failed on its own precondition, which looks identical to failing on the bug.
  Taste: an enum or a bool-plus-reason pair, not a third magic string. The interesting part
  is that this is a *convention* violation nothing can check — `Game` has seven such methods
  and their contract lives only in the reader's head.

- **An armed move still draws its ring over ground the plant could never occupy.**
  Cycle 113 stopped the preview PROMISING those cells (`_preview.placeable` now requires the
  moved plant could stand there too), but the ring, the reach and the coverage dots still
  paint from a road cell when a cob is armed — `_update_preview` sets `_preview.reach` and
  `_preview.plant_id` from `previewing` unconditionally (`game/game.gd:2240-2245`). So the
  cue now says "not here" and "here is what your cob would reach from here" in the same
  frame, which is honest and slightly odd.
  Deliberately left, because the alternative decides an open question by accident: whether a
  move should be a single action at all is `-h5w6`. If the answer there is "yes, clicking
  moves it", the ring over illegal ground becomes plainly wrong and this entry becomes a
  bug; if the answer is "no, the preview is only ever a comparison", it is arguably correct
  as-is. **Do not tidy this before `-h5w6` is answered** — that is the whole entry.

### New in cycle 114 — grown from the wall's damage frames

- **The game teaches three rules a player cannot infer, and the ninth plant added a fourth
  that REVERSES one they already learned.** The mechanism exists and is deliberate:
  `RunConfig.HINT_MOVE_PREVIEW` / `HINT_CHOMP_IGNORES_FLIGHT` / `HINT_UPGRADE_EXISTS`
  (`game/run_config.gd:166`, `:195`, `:212`), each a one-shot tip with a matching notebook
  card in `Hud.HINT_CARDS` (`game/hud.gd:3505`), and
  `test_every_hint_has_a_notebook_card` fails on either half missing.
  Look at what those three teach: a flier ignores a Chomp; a plant already down can grow;
  Uproot compares before it digs. Each is a rule the board does not state. **"You may build
  on the road" is a bigger one than any of them, because it is not a gap in what the player
  knows — it is the opposite of what eight plants spent the whole game teaching.**
  `Board.is_buildable` refused every road cell for the entire history of this project, and
  `place_plant` still answers "pests walk there" for eight of nine plants. A player who has
  internalised that will not try, and the Barrier Bramble's shop line ("Grows across the
  road itself") is a sentence they have every reason to read as flavour.
  A fourth hint costs one entry in each of two lists and the gate keeps them together. What
  it needs deciding is the TRIGGER: on first seeing the Bramble in the shop, on first
  selecting it, or on the first refusal of a road-plant-on-grass — the last is the most
  teachable moment and the only one that fires when the player is already confused.

- **The frame swap is a cut, not a change.** The three damage frames are swapped straight
  into `_sprite.texture` (`game/bramble.gd`, `_refresh_damage_sprite`) with no transition —
  correct as a first version, and worth watching. `Plant` already flinches on every bite
  (`_flinch_left`, `FLINCH_SECONDS`), so the swap lands inside a shudder that is already
  happening, which is why this reads acceptably rather than as a pop. That is also the
  argument against adding motion: a second gesture on the same event would fight the flinch.
  Taste, no citation offered: leave it. If it ever reads as a pop, the fix is to align the
  swap to the flinch's peak rather than to add a tween — the frame changing at the moment
  the plant is already moving hides the cut for free.

### New in cycle 115 — grown from reading all 33 HUD sentences

- **A sentence that interpolates what it describes cannot outlive it; one that names a
  mechanism in prose can.** This is the residue of `-u9zb`'s sweep and it is the only
  reviewable rule that came out of it. Counted rather than estimated: of the 33 producers in
  `game/hud.gd` matching the sentence-producer pattern, **21 interpolate the thing they are
  describing** — `corn_detail` ("%.1f dmg / %.2fs, %d kernel(s)"), `sundew_detail`
  ("Slowing %d pest(s) to %d%% speed."), `wave_cleared_note` ("%d pests turned back.") and
  so on. A retune moves the number and the sentence follows. Every defect found in two
  cycles of looking has been in the handful that name a mechanism instead:
  `eaten_message`'s "A hungry pest" (fixed cycle 112, `game/hud.gd:3632`) and
  `idle_detail`'s "waiting for a pest" (fixed cycle 115, `:2444`).
  Not a checker — `-u9zb`'s close records why, and the short version is that accuracy is a
  claim about the relationship between English and code with no shared vocabulary to check.
  What it is worth is one line in `message_corpus()`'s header: **prefer interpolating the
  thing you are describing over naming it**, so the next producer is written in the safe
  shape rather than audited into it two cycles later.

- **The one-shot teaching tips name a single answer where the catalogue now has three.**
  `Hud.flight_tip` (`game/hud.gd:3489`) reads "That pest flies over Chomp Flowers. Corn
  Cobblers can still hit it." Both halves are true. But a winged pest is also reachable by
  the Bomb Dandelion (its blast hits whatever is standing there) and by the Prickly Nettle,
  which exists *specifically* to sting the mutations — armoured, winged, hungry — and whose
  notebook card says so.
  So the tip is accurate and narrow, and narrowing may be correct: it is shown once, to a
  player watching a specific bug walk over a specific mouth, and "Corn Cobblers can still
  hit it" is more memorable than a list of three. The entry is not "fix it" — it is that
  **nobody has decided** whether a teaching line should name the cheapest answer or the
  complete one, and there are three such lines (`flight_tip`, `upgrade_tip`, the move tip)
  that will all face the same question as the catalogue grows.
  Taste: name the cheapest answer, always, and let the notebook carry the complete one —
  which is what the notebook cards are already for.

### New in cycle 116 — grown from a tool that falsified its own caveat

- **Forty-seven sentences describe what this project's checkers cannot do, and nothing
  checks any of them.** Counted: 22 of the 29 files under `tools/` carry a `NOT COVERED:`
  line and there are 47 occurrences between them. Every one is a factual claim about the
  code around it, several are cycles old, and they are trusted more than ordinary comments
  because they are **printed to the operator on every run** — a caveat on screen reads as
  current by construction.
  Cycle 116 broke one and shipped it. `citation_check.py`'s line said drift was "the one
  nothing can automate"; the same commit made it automatable, and the sentence went on
  printing under every run of the tool that had just disproved it. It was caught only
  because I went back to verify a claim I had written about my own work.
  This is the `idle_detail` shape (cycle 115) and the `eaten_message` shape (cycle 112) for
  the third time, and the third instance is the one that says it is a class rather than
  three accidents: **a sentence naming what something cannot do goes stale the moment
  somebody makes it do that.** `-3w66` already proposes writing the safe-sentence rule into
  `message_corpus()`'s header for player-facing copy; this is the same rule for operator
  copy, and the population is 47 sentences nobody has re-read.
  Not a checker — for the same reason `-u9zb` concluded, and the conclusion is now
  load-bearing enough to reuse rather than re-derive. What is worth doing is one sweep, the
  way `-u9zb` swept the 33 HUD producers: read all 47, verdict each, fix what has rotted.
  The `-u9zb` sweep found two real defects in 33 sentences; there is no reason to expect a
  better ratio here, and these are the sentences a person consults when deciding whether to
  trust a green run.

- **A `NOT COVERED:` line is the one place a checker admits a gap, which makes it the one
  place to look for the next feature.** `citation_check`'s admission was a to-do list
  disguised as a limitation, and reading it as one produced `-5sxj`. Worth doing
  deliberately rather than by accident: sweep the 47 for the ones that say "cannot" about
  something that is merely *unimplemented*, as against genuinely undecidable. The two are
  written identically today and only one of them is work.
  Taste: the distinction belongs in the sentences themselves. "Cannot, by construction" and
  "does not, yet" are different promises to the reader, and a checker that conflates them
  teaches its operator to stop reading the line.

### New in cycle 117 — grown from the fourth hint and 48 stale citations

- **The drift checker found 48 stale citations on its first real cycle, where the manual
  read-back had been catching two or three.** Cycle 116 built `--snapshot` / `--against` on
  the strength of drift having bitten twice. Its first genuine use, one cycle later,
  reported **48 drifted** — every one a citation written by an earlier cycle, silently moved
  by this cycle's edits to `game.gd`, and every one reported CLEAN by `citation_check`'s
  ordinary run because each still landed on a real line.
  The number is the entry. Step 3's rule has always been "read every citation back after the
  edits", and it was being honoured — for the two or three citations written *that* cycle.
  Nothing was ever going to re-read the other 348, and a citation written in cycle 60 has
  had sixty cycles of other people's edits to drift under. **A manual discipline scoped to
  what you wrote cannot maintain what everyone else wrote.**
  All 48 are fixed. What is worth doing next is running `--against` from a snapshot taken at
  a much older commit — the 48 found here are only the ones this cycle moved.

- **A drift report that names the target is half a report; it has to name where the citation
  is WRITTEN.** Fixing the 48 meant locating each in a 4000-line markdown file, and 20 of
  them were bare `:NNNN` continuations whose number appears two or three times — so the
  report named a target line and left the reader grepping for it. (Quoting the actual
  example here is not possible: a stale `path:line` written in this prose is indistinguishable
  from a live citation, and the drift checker flags it — which it did, on the first draft of
  this very entry.) `citation_check` already
  knew the citing line (`md_line`, used in its own findings) and did not print it in the
  drift output; it does now (`written at kanban.md:1827`), which turned the last third of
  that job from a search into an edit.
  Taste, and it generalises past this tool: **a finding should name the place you go to act
  on it, not only the place the problem is.** `message_corpus_check` and `suite_reach_check`
  both already do this; the drift report was the outlier because it was written to answer
  "what moved" rather than "what do I do".

### New in cycle 118 — grown from a decision that was already half made

- **A decision pinned only where it holds is not pinned.** The husk rot floor was defended
  by two assertions — nothing rots faster than 4.5s, and everything at or above `FULL_VALUE`
  shares it — and BOTH are satisfiable by flattening the curve entirely. Making every husk
  rot at 4.5s would "fix" the inconsistency the bead complained about and pass them. Only a
  third assertion, that below the saturation point a richer husk rots STRICTLY faster,
  distinguishes "the floor is deliberate" from "the whole curve was deleted". Confirmed by
  mutation rather than argued: `HUSK_LIFETIME = MIN_HUSK_LIFETIME` fires that one and
  neither of the others.
  The general shape, and it is worth carrying: **when you pin a decision that something is
  FLAT over a range, you must also pin that it is NOT flat outside that range** — otherwise
  the cheapest way to satisfy the gate is to make the flatness total. This is the same class
  as a non-empty denominator, one level up: a denominator stops a check passing over
  nothing, and this stops a check passing over everything.

- **The knob's comment and the design question are different questions, and only one was on
  the record.** `CompostMeter.FULL_VALUE` (`game/compost_meter.gd:97`) carries a long,
  correct argument for not widening it — "a balance change wearing a legibility fix's
  clothes". Reading it, it is easy to conclude the matter is settled. It is not: it settles
  the KNOB and says nothing about whether the behaviour it produces is wanted, which is what
  `-ix76` actually asked.
  Worth watching for elsewhere, because this repo is dense with exactly this kind of
  comment: **an argument for why a constant has its value is not an argument that the
  resulting behaviour is right.** The two read alike, the first is far more common here, and
  a reader looking for the second will accept the first. `-zfmv`'s sweep of the 47
  `NOT COVERED` sentences is the same shape a level down; this is the version for balance
  constants, and nobody has swept those.

### New in cycle 119 — grown from a cue that was already promised

- **A cue's ABSENCE is a claim, and it is the half nobody designs.** `-l86t` asked whether
  the chew ring's 0.45s flash is readable, and the more important question turned out to be
  what the ring's absence says: a Chomp mid-chew cannot grab (`is_busy()` is
  `_held != null`), so the ring means BUSY and no ring means FREE. Suppressing it under a
  threshold — the bead's proposal — would have made a busy mouth read as a free one at the
  moment a player is scanning for one to use.
  Worth applying to the other drawn cues, and this is the entry: **for each, ask what it
  means when it is NOT there.** `game/OVERLAY_GRAMMAR.md` documents what each shape means
  when present and says nothing about absence, which is where the asymmetry lives. A range
  ring absent means "not selected", harmless. A dead-ground bar absent means "this cell is
  fine", which is a claim. A husk's glow absent means "cheap", also a claim. Nobody has
  swept which of them are load-bearing when missing.

- **The shop blurbs are design decisions the code can drift away from, and only two of nine
  are checked.** The Chomp's line ("Eats small pests instantly. Big ones take a while — and
  it is busy the whole time.") is now pinned against `Pest.SPECIES` — the quickest meal is
  the smallest pest, every other species is 4x longer, and the plant is busy for even the
  quickest. The Nettle's ("Dead weight until wave 8") was already pinned against
  `WaveDirector.MUTATION_START_WAVE`.
  That leaves seven blurbs making factual promises with nothing checking them: the Sundew
  claims it slows "wings included, which no Chomp can say"; the Aloe claims it is "Too slow
  to save one being eaten"; the Mint claims neighbours "shoot a third again as fast"; the
  Bramble claims "Winged pests go straight over". **Every one of those is a number or a rule
  living somewhere else in the code**, and every one is read by a player deciding how to
  spend seeds. This is the same class as cycle 115's HUD-sentence sweep, on the sentences
  that cost the player money.

### New in cycle 120 — grown from a save that could not say it had failed

- **`RunConfig._save()` can now report, and four other things that write still cannot say
  whether they landed.** The Keys screen was the right place to start — the bead said so and
  it was correct, because a capture is synchronous with a button press and there is an
  unambiguous moment to report. Everything else that persists has no such moment: the
  options toggles (mute, sfx, music, garden speed, colourblind bars) write on a click with
  the screen staying put, and the high-score write happens as a run ends while the player is
  reading a post-mortem card.
  The mechanism now exists — `_save()` returns a bool and `store_key_bindings` threads it —
  so this is a design question rather than a plumbing one: **what does a settings toggle do
  when its own write fails?** The toggle has already moved on screen, so silence is a lie
  and reverting it is worse. Probably: leave the toggle, say it in the same place the Keys
  screen says it. Nobody has decided, and the honest answer may be "these are not worth a
  sentence and here is why", which is also a decision.

- **A sentence a player will almost never see is the one most likely to ship misspelled.**
  `KeyBindingScreen.persisted_note`'s failure branch is unreachable without a filesystem
  fault, so nothing in normal play or normal testing renders it. It is a pure static
  precisely so both branches can be asserted with no screen and no failing disk — and the
  same shape is worth looking for elsewhere: every `push_warning` string in
  `RunConfig._save`, the refusal strings in `Game.place_plant` that only one test drives,
  and whatever `OverlayScreen` says when a footer is flush.
  Taste: any sentence a player can reach only through a fault should be built by a pure
  function and asserted, or it is decoration. The cost is one static per sentence and the
  benefit is that the one time it appears, it is right.

### New in cycle 121 — grown from a skill whose first use disproved one of its own sections

- **The separation between a sprite and its ground lives in the RIM, and nothing had written
  that down.** `art_src/STYLE.md` mandates *"outline = darker shade of the fill, 2 px"* and
  explains it as matching the Kenney kit's look. It is doing a second job nobody stated:
  because the rim carries the contrast, **the fill is free to sit anywhere**, and several
  sprites' dominant colours are within 20 luminance points of the surface they stand on —
  Garden Mint 13, Salve Aloe 9, the aphid, Shield Bug and Queen all 17–18. Every one of them
  reads perfectly, because of the rim.
  This is worth adding to STYLE.md's shading section, which currently justifies the outline
  only as a Flash-export lookalike. **Its real function is legibility against the ground**,
  and a future sprite that skips it — or a future style change that thins it — loses
  something the table does not mention. The measured numbers are in
  `.claude/skills/palette-against-the-background`.

- **The 2px rim is the first thing to disappear when a sprite is drawn small, and one set of
  sprites is drawn small.** The rim is 2px at 64px. `Pest.SPECIES` scales sprites per
  species — an aphid renders at 0.72 — so its rim is under 1.5px, on the pest whose fill is
  18 luminance points from the road it walks. Nothing has ever looked at whether the aphid's
  outline survives its own scale.
  Not filed as a defect, because it plainly reads in play and I have watched it. It is the
  one configuration the cycle-121 audit named as worth a second look — low fill contrast
  plus a scaled-down rim — and the honest next step is to sample the rendered frame at the
  drawn scale rather than the source PNG, which `sample-pixels` can do on a live game and
  the audit cannot.

### New in cycle 122 — grown from a touch layer whose obvious design was wrong

- **The emulated mouse event arrives BEFORE the touch that produced it, and that fact is
  worth more than the feature it blocked.** Measured on the running game rather than
  reasoned about: `PROBE mouse press device=-1 touch_index=-1` then `PROBE screen touch
  pressed index=0 device=0`. Every design that guards the mouse path with a flag set by the
  touch handler is therefore wrong, and looks right — the first implementation of the touch
  layer planted at the press cell, which is precisely the behaviour commit-on-release
  exists to remove.
  The general form, and it is why this is an entry rather than just a comment: **when two
  input paths can describe one gesture, the order they arrive in is a measurement, not an
  assumption**, and it is cheap to take — a `print()`, one bridge verb, read
  `.devtools/launch_stdout.log`. Two minutes. The project has three other places where two
  paths can describe one action (a key vs an `InputEventAction` from the bridge, a `press`
  verb vs a real click, an emulated drag vs a real one) and none has ever been measured.

- **Every Button in this game is a Control that answers MOUSE events, which is what pins
  emulation on.** `emulate_mouse_from_touch` cannot be turned off — the shop bar, the pause
  card, the Back button on every overlay and the notebook pager all rely on it, on exactly
  the devices touch support is for. That constraint is now load-bearing and is written where
  the guard is, but it is worth knowing more widely: **any future "handle input properly"
  work inherits it**, and a change that switches emulation off to clean something up will
  break every screen at once and pass every headless test, because a headless test presses
  buttons through `pressed.emit()` rather than through the pointer.

### New in cycle 123 — grown from the shop and the panel disagreeing

- **The same fact is rendered in two places with different rounding, and one of them was
  wrong.** The Sundew's shop line said "half speed" while the panel printed "55% speed",
  because `SLOW_FACTOR` is 0.55 — both on screen, one click apart. Fixed, but the SHAPE is
  the entry: **wherever a number is described in prose in one place and printed in another,
  the two can drift and nothing connects them.** The panel interpolates and cannot rot; the
  blurb narrates and can. Other pairs worth checking against each other rather than against
  the code: the Aloe's "slowly" against its panel line, the Mint's "a third again" against
  what the buffed cob's own detail shows, and the Dandelion's "grows its fluff back" against
  `dandelion_regrowing_detail`'s countdown.
  The general rule this suggests, and it is cheap: **when prose and a readout describe the
  same number, the prose should be checked against the READOUT, not only against the
  constant.** Both being individually true of the constant is not enough — "half" and "55%"
  are each defensible and together they are a contradiction.

- **One blurb clause is true and not mechanically checkable, and that is worth writing down
  rather than leaving as a gap in a table.** The Barrier Bramble's "Hurts nothing" is an
  absence of damage code, not a value. `engages` is the obvious key and is the wrong one —
  the Bramble engages, because it HOLDS, which is precisely the divergence
  `PlantCatalog.engages`'s header calls the mirror of the Sundew's. There is no `damages()`
  anywhere and adding one to satisfy a test would be a field invented for a gate.
  Taste: leave it. The interesting question this raises is whether the catalogue wants a
  `damages` key at all — `engages` currently answers "damage OR hold", and three separate
  readouts have wanted "damage" specifically (the coverage note, this blurb, and the
  post-mortem's "held" row from `-fohy`). Three is usually the number at which a distinction
  is real; it is filed nowhere yet.

### New in cycle 124 — grown from breaking the detector with the defect it detects

- **A gate whose exit code should depend on WHICH QUESTION it answered cannot live in a pool
  that runs it one way.** `heredoc_survey` now has two modes over one pair of detectors:
  history (how often has this happened — advisory, because every hit is already fixed and
  gating on them is permanently red) and `--worktree` (is the tree broken right now — gates).
  `tools/check_all.py` runs each discovered file with one command and has nowhere to say
  "run this one with a flag", so a genuinely parallel-safe check stayed out of the pool for a
  structural reason rather than a technical one.
  Worth deciding rather than working around: **should `check_all` learn a per-tool argv?**
  Its `NOT_PARALLEL_SAFE` and `NOT_A_CHECKER` maps already carry per-tool knowledge, so a
  third map is not a new idea — but every entry is a hand-maintained fact in a file whose
  whole argument is that its list is DERIVED. Taste: no. Two commands the loop names
  explicitly beat one command with a table of exceptions, and `survey_all` already
  established that two runners on two clocks is the honest shape.

- **A fixture that is not tracked is invisible to any check that asks git what to scan.**
  The positive control for `--worktree` needed `git add -N` before the survey could see it —
  `git ls-files` lists tracked paths, so a freshly-written fixture file scans as nothing and
  the control passes over an empty set. This is the third fixture this session to be vacuous
  on its first run for a different reason each time: cycle 116's citation fixture used an
  absolute Windows path the regex could not match, cycle 121's palette audit read the wrong
  colour, and this one was untracked.
  The pattern is worth stating: **run the fixture's SETUP and read its denominator before
  trusting what the assertion says.** All three announced themselves — `0 citation(s)`,
  `5 findings`, `scanning 63 files` with no fixture among them — and in each case the number
  was visible and I nearly did not look at it.

### New in cycle 125 — grown from a rung name that broke a layout budget

- **Names are priced here, and a table of names is a table of widths nobody thinks of that
  way.** `Hud.selection_corpus` crosses every plant name with every upgrade-rung name, so
  the longest PAIR sets the height of the whole selection stack — and adding a ladder whose
  top rung was called "deep thicket" pushed `hud_selection_panel` 25 px through its floor
  before a single pixel of it was drawn. The budget check named the number and the three
  ways out.
  The entry is not the fix. It is that **three separate name tables in this project are
  budgeted and only one of them says so**: the rung names (now documented in
  `game/bramble.gd`'s `LEVELS` header), the plant `display` names, and `Hud.HINT_CARDS`'
  titles. Each is written where a designer picks words, none of the other two mentions a
  width, and the failure mode is a panel that grows a row and pushes its buttons off the
  bottom. Worth one sentence in each, pointing at the corpus that prices it.

- **A detector's NAME is not its coverage, and this one is much narrower than it reads.**
  `heredoc_survey`'s SIGNATURE B is described as "a comment block whose leading '#' is
  missing". Its `PROSE` regex requires the line to start with a **capitalised** word, and
  `CODE_TOKEN` excludes any line containing parens, a colon or an arrow — so a wrapped
  comment continuing mid-sentence, or one citing `some_function()`, is invisible to it.
  This codebase's comments cite function names constantly, so the excluded set is large and
  is exactly the prose most likely to lose its marker in a bulk edit.
  Filed as `-n228`, deliberately with "build the control case first" rather than "widen the
  regex": the survey's own first version reported **554 false positives**, and a survey
  nobody believes is a survey nobody runs. The prior question it also asks is whether
  SIGNATURE B is worth detecting at all — the history sweep says **0 instances in 1028 file
  versions** ever survived into a commit, because lint catches them the same day. Its only
  real value is the parallel case where lint cannot run.

### New in cycle 126 — grown from a checker reading one citation in six

- **A convention a document GROWS is invisible to a tool written from the outside — third
  sighting, and this file already says so twice.** `tools/citation_check.py:81-86` records
  it about `game/OVERLAY_GRAMMAR.md` citing its neighbours bare, and `:90-94` records it
  again about the `` `:NN` `` continuation form. Cycle 126 walked into it a third time:
  `bd` stores `description` and `close_reason` as PLAIN TEXT, nothing renders them, so
  nothing rewards backticks — 95 backticked citations against 495 unbackticked. The first
  working version of `--beads` demanded the markdown backticks and printed
  `468 bead(s) ... 0 finding(s)` over an input set that was 84% invisible.
  The entry is not "add PLAIN". It is that **the three sightings share a shape and the
  file's own comments predicted this one**: a document written by a different hand, or
  stored by a different tool, grows its own citation convention within a cycle or two. The
  question worth asking before the next source is added is not "does my regex work" but
  "who writes this file, and what does rendering reward them for". Filed as `-yla3`.

- **The only thing that caught it was a denominator, and a denominator is something a
  reader has to notice.** Ten new citations from 468 beads is implausible, and it was
  printed in the same line as `0 finding(s)`. `tools/citation_check.py` now carries a
  `--self-check` whose five cases include the unbackticked form, and mutating the regex
  back fails it with "this is the 95-of-590 bug returning". Three of the five cases are
  about ROUTING rather than detection (open gates, closed advisory, waiver suppresses) —
  which is where this repo's checkers keep going wrong, because routing has no output of
  its own to read.

- **A waiver a document can trip by DESCRIBING the waiver is worse than no waiver.** The
  first bead ever closed by the `--beads` mode waived itself: its close reason contains the
  sentence "marker `citation-check: ok` anywhere in the bead's prose drops the whole bead",
  which was true and thereby made itself false. Bead count 468 → 467, three citations out
  of the denominator, and nothing said a word. Fixed by requiring the marker to open its own
  line (`tools/citation_check.py:71`), but the general point is filed as `-vvww`: **every
  suppression marker in this repo is a bare substring** and the beads and logs that discuss
  suppression are exactly the documents most likely to quote one. Found only because the
  checker was re-run over the close it had just been handed.

- **An opt-in mode on a pooled checker never runs.** `tools/check_all.py` called
  `run_one(name, [])` — no arguments, ever — so `--beads` would have shipped inert and the
  pool's `citation_check.py clean` line would have kept meaning "kanban.md only". Fixed with
  `CHECKER_ARGS`, plus exit 2 when a key names a checker the pool does not run. Worth
  stating because the pool is designed to DERIVE its members rather than list them, and
  this is the one thing it cannot derive: what each member needs in order to cover
  everything it can.

### New in cycle 127 — grown from a page showing a right number and a wrong one at once

- **The notebook is structurally derived nearly everywhere, and both places it is not were
  hand-written English sentences.** The audit (`-pa4g`) went page by page expecting to find
  stale mechanics and found the opposite: the header count, the shelf score, the hint
  pagination and the page label all derive from their tables and each carries a comment
  saying why. Every finding was in prose. The legend page is the sharpest case — its source
  line has always derived `CueLegend.row_count()` while its note, one field over, said "the
  five here" beside a six-row table (`game/cue_legend.gd:172`). **The page displayed a
  correct count and an incorrect one simultaneously, which is exactly why the incorrect one
  survived**: anything comparing the two would have caught it in a second, and nothing was
  comparing.
  The entry is that this is the SECOND hand-written count on this screen to go stale and the
  first already has a comment about it (`game/notebook_screen.gd:618`, "Counted from PAGES,
  not written out. The hard-coded \"Six pages\" outlived the sixth page by about four
  minutes"). Two is not a pattern — the audit enumerated every other count on the screen and
  found no third — so it stayed a fix rather than becoming a checker. Recording the
  enumeration is the point: the answer to "should this be a checker" was "no, and here is
  the list that says so".

- **A `const Array[Dictionary]` cannot call a function, which is what kept the count
  hand-written.** The obvious fix — derive it in `PAGES` — is not available in GDScript, and
  that constraint is invisible until you try it. The shape that works is the one this class
  already used twice for the same reason (`shelf_progress_text`, `shelf_note_text`): keep a
  TEMPLATE in the const and fill it from a static at build time. Worth knowing before the
  next stale number in a const table, because the first instinct is to conclude the
  derivation is impossible and hand-write it again.

- **A test asserting the filled string is not enough; assert the template is still a
  template.** Two of the three new assertions pass if somebody deletes the `%s` and
  hard-codes "six" — which is the original defect with a newer number. The third reads
  `PAGES[...]["note"]` and requires it to contain `%s`. Generalising: **when a fix replaces a
  literal with a derivation, at least one assertion has to be about the DERIVATION, not the
  value it currently produces.** Every value-assertion is also satisfied by a fresh literal.

- **`_T.assert_equal` does not exist in this suite and reports as a pass.** Writing it cost
  one run: the method aborts, returns `""`, and `run_tests.gd` prints `[PASS]`. Only
  `run_tests.py`'s stderr and `Assertions: 0 executed` saw it. The suite uses `assert_eq`
  (625 uses), `assert_true` (831), `assert_float_eq` (227), `assert_gt` (220),
  `assert_false` (206), `assert_gte` (47) — and now zero `assert_equal`. Filed nothing;
  the lesson is the one CLAUDE.md already states, arriving on schedule.

### New in cycle 128 — grown from a zero that meant "nobody played this"

- **Four controls, not one, before believing a counter.** `messages_refused` = 12 sitting
  next to four packet purchases is a correlation, and this bead existed *because* cycle 93
  accepted one of those. What made the finding real was the three runs that produced nothing
  — a purchase on a quiet row, a purchase over a held ambient line, twelve pest kills with no
  purchase — and one that reproduced the refusals **with no purchase at all**. The last is
  the strongest: it turns "purchases refuse messages" into "an `IMPORTANT` line held longer
  than the next `IMPORTANT` post's patience refuses messages", which is a statement about
  `Hud`, not about packets.
  Worth stating as a rule: **a control that produces zero is what converts a non-zero
  reading into a cause.** Three of the four runs here were expected to be boring and all
  three earned their place.

- **The code comment was true and still pointed at the wrong producer.** `game/game.gd`'s
  flourish says "each flicker replaces the last rather than queuing up behind it", and the
  preempt control confirms it — for ONE flourish. The refusals come from
  `_reveal_plant_unlock` holding the row at `MESSAGE_IMPORTANT` for 5.0s, so a *second*
  purchase inside that window is equal priority and cannot preempt. **A comment that is
  accurate about the single case reads as coverage of the general one**, and both cycle 93's
  close and this bead's own prime suspect were written from it. The case nobody commented on
  is the case that drops lines. Filed as `-47v7`.

- **`cycle-log.md` carries a durable note that did not hold, and it is not edited.** "A plant
  is selected by a real click, which `cmd touch_press`/`touch_release` at its
  `global_position` will deliver" — four attempts at `224,296` left `selected_placed` empty.
  Three explanations are live (stale note; needs `set-feature --touchscreen` before the
  scene loads; the emulated-mouse guard in `_unhandled_input` changed which events reach the
  handler) and none was checked, so **correcting the note now would be replacing one
  unverified sentence with another**. Filed as `-cfvb` with the check named. This is the
  `kanban-staleness-audit` bar applied to the durable-knowledge file itself.
