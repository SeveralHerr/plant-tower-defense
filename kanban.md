# Plant Tower Defense — Kanban

The design brief is `image1.jpg`–`image6.jpg` (hand-drawn). Canonical task state
lives in **beads** (`bd list`); this board is the readable view of it plus the
idea backlog that isn't filed yet.

> "I want it to be a tower defence game. Plants fight bugs. You get one free
> plant to start with, some aren't free. You have to buy plant seeds to get plants."

---

## Done

- **Style contract measured, not guessed** — `art_src/STYLE.md` records the Kenney
  Tower Defense kit's real conventions: 64x64 canvas, top-down, up-screen facing,
  outline = darker shade of the fill (never black), and the 32-colour palette
  sampled by frequency from the kit's own PNGs. `plant-tower-defense-udz`
- **First sprite set** — Corn Cobbler, Chomp Flower, Aphid, Beetle, corn kernel,
  seed packet. SVG sources in `art_src/`, rasterised to `assets/sprites/` (1x) and
  `assets/sprites/retina/` (2x) by `tools/render_svg.gd`.
- **The contract is a gate** — `test/unit/test_sprite_style.gd` fails the build on
  a sprite that drifts: wrong size, missing retina copy, blank render, off-centre
  axis, clipped edge, or a colour that isn't a kit colour or a blend of two.
- **Kit vendored** — `assets/kenney/` (299 sprites + tilesheet + CC0 licence).
- **The game is playable end to end.** 14x9 board with a dirt road cut through the
  grass, both plants, both pests, eight waves, seeds, packets, upgrades, uproot,
  win and lose. `game/game.tscn` is the main scene. `plant-tower-defense-iks`,
  `-95o`, `-cv3`, `-el9`, `-wn0`, `-1e9`
- **The road tiles are derived, not eyeballed** — `Board.GRASS_EDGE_TILE` maps a
  four-neighbour mask to the Kenney tile whose edges match, worked out by sampling
  every kit PNG. A test fails the build if the path shape ever needs a tile the kit
  does not ship.
- **Eight project devtools verbs** (`game_state`, `place_plant`, `spawn_pest`,
  `add_seeds`, `start_wave`, `buy_packet`, `upgrade_plant`, `board_info`) plus a
  status provider, so a runtime check is a command rather than a mouse.
- **Selection is wired up, and the two readouts it unlocks both ship.** Clicking a
  placed plant flips `Plant._selected` (`Game._select()` is the one place that ever
  touches it), which closed a real dead-code gap from last session — `set_selected()`
  had no caller and the range ring could never draw; `/verify` confirmed the fix with
  `sample-pixels` (ring visible only while selected, gone on deselect). Chomp Flower's
  mouth also gets a shrinking ring keyed off `chew_progress()`, so "this mouth is busy
  and your lane is open" is now something the player sees. `plant-tower-defense-how`,
  `-x7h`

- **Six features shipped and /verify'd in one session** — sprite pass 2, pest mutations,
  seed packet tiers with a third plant, the compost meter, a title screen with endless
  mode, and the Designer's Notebook. `plant-tower-defense-eeq`, `-5fu`, `-b5k`, `-d0w`,
  `-e0w`, `-1qo`
  - **Sprite pass 2** — a Chomp mid-bite and X-eyed dead pests are separate sprites, not
    tints, per the design doc: `art_src/chomp_flower_eating.svg`,
    `pest_aphid_dead.svg`, `pest_beetle_dead.svg`. A killed pest now lingers 0.35s
    showing its corpse instead of vanishing.
  - **Pest mutations** — from wave 8, a spawned pest may roll armoured (2x chew time),
    winged (a Chomp's mouth can't reach it), or hungry (eats an adjacent plant down to
    0 health instead of walking past — plants now have `health`/`take_damage`, drawn
    with the same health-bar look as a pest's).
  - **Seed packet tiers + Seed Sunflower** — common packets (20 seeds, tier-1 only) vs.
    rare (45 seeds, reaches tier 2). The third plant, `Sunflower`, fights nothing and
    pays out seeds on a clock — the first plant that makes a tile a pure economy choice.
  - **Compost meter** — a killed pest drops a husk worth half its seed value; click it
    before `CompostMeter.HUSK_LIFETIME` (10s) to collect the bonus, or it rots.
  - **Title screen + endless mode** — `game/title.tscn` is now `run/main_scene`; Start
    plays the fixed 8 waves, Endless keeps `WaveDirector` escalating past the table
    forever. `RunConfig` (autoload) persists a seed-count high score to `user://`.
  - **Designer's Notebook** — pages through `image1.jpg`–`image6.jpg` beside the
    finished sprite for each plant, reachable from the title screen.
  - Two real layout bugs only a live screenshot caught, both fixed: the notebook's
    backdrop resolved to a 0x0 rect (`PRESET_FULL_RECT` on a Control with no sized
    Control ancestor to anchor against — silent on the bare title screen, fatal on an
    overlay meant to hide what's under it), and its preview images blew up to fill the
    screen (`EXPAND_FIT_WIDTH_PROPORTIONAL` outside a Container). See `log-devtools.md`
    2026-08-15 for the full writeup, including two tests that verified nothing until a
    GDScript lambda-capture gotcha was found.

- **Five more shipped and /verify'd, one session each with runtime evidence** —
  selection's second visual cue, the lane pressure readout, husk value scaled by
  mutation, endless mode mutating faster over time, and a second bite frame for a
  beetle's long chew. `plant-tower-defense-42t`, `-4wv`, `-1rh`, `-1qi`, `-rrx`
  - **SelectionMarker** — a separate child node, not code inside each plant's own
    `_draw()`. CornCobbler and ChompFlower both fully override `_draw()` for their
    own overlays and never call `super._draw()`, so a cue placed there would have
    been silently dropped by exactly the subclasses most likely to want one — which
    is how ChompFlower ended up with no selection feedback at all before this.
  - **Lane pressure readout** — `Board.record_lane_pressure()` tints the road cell
    where pests got furthest last wave, fading whatever an earlier wave lit up.
    Caught live, not on read: losing the last life mid-wave sets `game_over`, and
    `Game._process`'s own early-return guard meant the one place that committed
    this never ran on that path — a run lost outright left the readout stuck on
    whatever the previous wave showed, forever. Fixed and covered by a unit test
    that reproduces the bug.
  - **Husk value scaled by mutation** — `Pest.husk_multiplier()` (armoured/winged
    1.5x, hungry 2x, since hungry destroys a plant outright). Ties the mutation and
    compost systems together instead of leaving them side by side.
  - **Endless mode mutates faster** — `WaveDirector.mutation_chance_for(wave)`
    climbs 0.02/wave past the fixed table, capped at 0.85, instead of holding the
    flat 40% forever.
  - **Second bite frame** — `chomp_flower_eating_late.png` swaps in past
    `chew_progress() > 0.6`, the same fraction the shrinking chew ring reads.
  - A real harness gap surfaced verifying the last of these: three separate zombie
    Godot processes were found alive at once mid-session, all still answering the
    devtools bus — `quit`'s "STILL ALIVE" pid is the bus-answering engine process,
    but on Windows the console-wrapper `launch` reports as "Launched pid" doesn't
    reliably take that child process down with it when killed. Presented as
    newly-spawned pest nodes reporting "Node not found" seconds after `scene-tree`
    had just listed them. See `log-devtools.md` 2026-08-15 (G-012).

- **Four more shipped and /verify'd, one commit each** — husk size/glow by value,
  endless scaling the pests themselves, lane pressure as a distribution, and a
  placement preview. `plant-tower-defense-afd`, `-nps`, `-j1h`, `-rfh`
  - **Husk size/glow scales with value** — `HuskLayer.radius_for()`/`glow_for()` are
    static and pure so the size↔value relationship is assertable without a viewport,
    and the constants are pinned to the drops the game can actually produce (2 for a
    plain aphid, 9 for a hungry beetle). A live board with eleven husks down returned
    exactly those two values, and the largest husk's outer edge is checked to sit
    inside `CompostMeter.COLLECT_RADIUS`, so no drawn pixel is unclickable.
  - **Endless scales the pests, not just the count** — `health_scale_for()` /
    `speed_scale_for()` take the same `over <= 0` shape as `mutation_chance_for()`, so
    campaign is untouched by construction rather than by a mode flag. Health is the
    bigger lever (3.0x cap), speed the smaller (1.6x). Verified live at wave 38:
    8.4 hp / 113.1 px/s aphids, and all 18 sampled pests still on road cells.
  - **Lane pressure is a distribution, not one pixel** — every cell a wave lost a pest
    at is tallied and committed as one batch, normalised against the wave's own worst
    cell so five pests and eighty read the same, with a `MIN_ALPHA` floor so "one got
    through here" stays visible. Batching is load-bearing: N single-cell calls would
    fade each cell by its own wave-mates. Also deleted the per-frame scan over every
    live pest — the `died`/`escaped` signals say everything the high-water mark did
    and more. Live wave 1 painted four cells at two strengths.
  - **Placement preview** — `PlacementPreview extends SelectionMarker`, so the hover
    brackets are literally the shape the plant will wear once placed, one size out and
    dimmer. Adds the coverage ring, which was previously invisible until *after* the
    seeds were spent. `PlantCatalog.reach()` reads each plant's own constant rather
    than re-listing numbers. Verified through the 72px HUD offset: mouse (200,300)
    puts the preview at screen (224,296).
  - Two harness gaps surfaced: `find-nodes --class X` does not match a script
    `class_name` and reports the miss as an empty result (G-013), and `validate-ui`
    measures a multiline Label as one joined line, gating on a banner that renders
    correctly (G-014). Plus G-015, reach treating a base class as unreached.

- **Cycle 2 of 30 shipped five more** — the HUD top bar rebuilt as a container, husk
  lifetime scaled by value, a readable endless threat level, an unfaded per-run lane
  pressure post-mortem, and a hungry-pest warning on the placement preview.
  `plant-tower-defense-kcj`, `-kh9`, `-o1p`, `-dbg`, `-8bb`
  - **HUD top bar cannot self-collide** — four labels at hand-picked x positions became
    an HBoxContainer with an expanding spacer and a clipped width budget per readout.
    Two non-obvious failures on the way: an HBox will not shrink a child below its
    minimum, so the spacer-only version shoved the button 97px off-screen instead of
    overlapping; and trimming the button to 34px to fit two rows put it under the 40x40
    minimum touch target, which `findings` flagged.
  - **Richer husks rot faster** — 4.5s against 10s, so sweep order is a decision. The
    value→urgency curve moved into `CompostMeter.value_fraction()` and `HuskLayer`
    delegates to it, so size, glow and clock cannot disagree.
  - **Readable threat level** — `threat_for()` prices a wave as total pest health scaled
    by every endless multiplier; `threat_level()` is the log-scaled small integer the bar
    shows, because the raw multiple hits x897 by wave 108. The wave-start message names
    what climbed and drops a scale once it caps.
  - **Per-run lane pressure** — the live overlay fades by design, so `Board` now also
    keeps an unfaded run total and `_end_run` swaps the board to it. Verified on a real
    lost run: painted map came out exactly `run_losses / max`, worst cell was the exit.
  - **Hungry-pest warning** — a dashed amber ring on a defenceless plant hovering within
    one cell of the road. Only plants with no reach of their own; a Corn Cobbler there is
    the point of a Corn Cobbler.
  - Four more harness gaps found and filed: `step-time` cannot isolate a state shorter
    than a bus round-trip (G-016), a clipped Label's trimming is reported identically to
    a real overflow (G-017), a sibling worktree silently answers your bus (G-018), and
    `set-state` on a typed Array silently no-ops (G-019).

## Next up

See the fresh checklist in `todo.md`. **Cycle 3 of 30** is filed and ready:
`plant-tower-defense-zr4` (uproot confirm), `-5zc` (plant health in the panel),
`-cw1` (end-of-run summary panel), `-cuk` (tint the threat level), `-gqs`
(project-identity devtools verb).

---

## Cool new features (idea backlog)

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
  (`title_screen.gd:287`, `notebook_screen.gd:415`). So `_selection_box.visible = true`
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

### Grown straight from the brief

Not filed as beads yet — these are the ones worth building *because* they fall out
of what the design doc already says, rather than being bolted on.

- **Chomp Flower is occupied while chewing.** The doc's own words — "takes a while
  eating bigger pests" — make the Chomp a *body blocker*, not a DPS tower. A beetle
  that walks into one buys the lane several seconds, and the player who over-invests
  in Chomps has a lane full of busy mouths and nothing shooting. That single rule is
  the whole plant/pest rock-paper-scissors, for free.
- **Seed packets are a gamble, not a menu.** "You have to buy plant seeds" — a packet
  costs seeds and gives a *random* plant of its tier. Cheap packets for commons,
  expensive ones with a better roll. Buying is then a decision instead of a queue.
- **Corn upgrade ladder, drawn by the designer.** The doc literally shows one corn
  → a spread of kernels. Ship it as an in-run upgrade: `single → double → bunch`,
  each level costing seeds and visibly widening the spread.
- **Replanting is free, uprooting refunds.** Small mercy, big for a young player.

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
