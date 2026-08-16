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
