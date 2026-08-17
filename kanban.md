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
  first arm ever (`game/game.gd:1325-1327` records `HINT_MOVE_PREVIEW`), and from cycle 79
  the forfeit clause displaces it. A player whose first-ever uproot happens to be on an
  upgraded cob — which is *likely*, since uprooting something cheap is not a decision worth
  a prompt — gets the money sentence and never sees the tip at all, and the milestone is
  recorded either way so it never comes back. Two fixes and they differ in cost: record the
  milestone only when the tip is actually shown (one line, `game/game.gd:1326`), or accept
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
  `_uproot_left` ticks down at `game/game.gd:1375` and lives entirely inside `game.gd` —
  outside it the identifier appears only in tests, never in `hud.gd`, so the HUD learns
  *armed or not* through `uproot_armed()` (`game/game.gd:1340`) and never *how much is
  left*. Meanwhile the game draws this exact thing twice already: `husk_layer.gd:69-77`
  sweeps `TAU * frac` around a husk as its rot timer runs, and `hud.gd:643-647` drains
  `PrepBar` across the whole top bar over the prep gap. A four-second irreversible
  decision is the one countdown with nothing on screen. Now that cycle 69 guarantees the
  prompt the row the instant it is armed, drawing the remaining fraction under it is the
  natural other half — and it is a shape the player has already been taught by husks.
- **"Only one line may carry a deadline" is a paragraph, and paragraphs do not fail.**
  `game/hud.gd:347` warns that two `MESSAGE_DEADLINE` lines cannot defer each other —
  whichever waits is wrong by construction — and `game/game.gd:1333` is, today, the only
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
  1112 — each precisely its floor in `Game.BUDGET_FLOOR` (`game/game.gd:1887-1899`),
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
  slot, and I misread it before opening `game/game.gd:2203`. Corrected. The general shape
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
  (`game/game.gd:1883`) declares 40 px for that row and 121 remain, so it passes and the
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
  cell AND, since this cycle, which plant the hover is about (`game/game.gd:1569`). That
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
  `hud_selection_panel` entry in `Game.budget_entries()` (`game/game.gd:1921`) beside the
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
  `:1197`, `:1319`, `:1407`, `:1464`, `:1484`, `:1588`. A message the player must read to
  act on (the opening hint) and one that is pure confirmation (uproot cancelled) are four
  seconds apart, which is probably right, but nothing says the rule. Reading time scales
  with length, and the corpus now knows every length — a duration derived from character
  count with a floor would make the 8.0 and the 2.0 consequences of one decision.
- **The waiver reasons are the best documentation of the message system and live in five
  scattered comments.** `game/game.gd:231`, `:1397`, `:1464`, `:1468`, `:1605` each carry
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
  `game/game.gd:231` (purchase refusal), `:1464` and `:1468` (mute), `:1605` (placement
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
  `_budget_hud_message_row` (`game/game.gd:2037`) measured four plant-name messages and
  not the prep note that shares the row, and was wrong by 36px for seven cycles while
  reporting green. `Game.budget_entries()` (`game/game.gd:1852`) builds six others the same
  way. Each one names its corpus in an `evidence` string; nothing checks that the string
  describes what the code sweeps. A checker could compare the two — or, cheaper, one pass
  reading all seven and asking "what else can reach this measurement?" The failure is
  silent by construction: a budget over a subset always reports more headroom than exists.
- **The prep note is measured at a wave number the game cannot reach.**
  `_budget_hud_message_row` now measures `Hud.next_wave_note(999, 9999, ...)`
  (`game/game.gd:2071`), deliberately — a budget is about what the format allows. But
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
- **`Plant._furthest_along_in_range` is the only targeting function in the game**, and
  three plants pick targets by other means (`ChompFlower` grabs, `StickySundew`
  slows in radius, `Dandelion` arcs). None of them guards against a stale reference
  either, and they were not part of this fix because nothing crashed in them.

### New this cycle (26 of 30) — what a reverted upgrade exposed about our own tests

- **One test holds node references across an `await` and it is the one that crashed.**
  `test_corn_shoots_the_pest_closest_to_escaping` (`test/unit/test_combat.gd:288`)
  builds `near` and `far`, hosts them, awaits `instantiate_scene`, and only then puts
  them in a typed array. Under 0.42.0 one is already freed by then. Whether or not the
  harness caused it, **the test is written the way the project's own
  `settle_read_check.py` exists to catch** — a value read after settle frames that
  were still moving. Worth auditing every test that hosts nodes and then names them.
- **`_furthest_along_in_range` dereferences without checking the reference**
  (`game/plant.gd:412`). It takes `Array[Pest]` and reads `pest.global_position` with
  no `is_instance_valid`. Game builds that array fresh from the group each frame, so
  it is safe today by construction rather than by contract — and a targeting function
  that crashes on a stale entry is a crash in a shipped game, not a failed assertion.
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
  `_build_shelf()` (`game/notebook_screen.gd:415`), all seven `Milestones.TABLE`
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
