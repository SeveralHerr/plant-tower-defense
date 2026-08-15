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

## Next up

Nothing filed right now — `bd ready` is empty. See the idea backlog below for what's
worth turning into the next beads.

---

## Cool new features (idea backlog)

### New this session — grown from what the running game actually feels like

- **The chew ring needs its own colour, not orange.** Verifying it just now
  (`/verify`, 2026-08-15) found the ring hard to isolate from the Chomp Flower's own
  sprite in a screenshot — the flower's petals are already warm yellow/orange, so a
  same-hue ring reads as "the flower looks a bit brighter" rather than as a distinct
  UI element. A cool colour (cyan/white) or a dashed/outlined stroke instead of a
  filled arc would actually contrast against every pest and plant sprite in the kit,
  not just this one.
- **Selection needs a second cue beyond the range ring.** Right now the *only* sign a
  plant is selected is a translucent circle that, for a Chomp Flower (no ring drawn
  at all — that's Corn's trick), means selecting it shows nothing whatsoever. A
  thin outline or corner brackets on the sprite itself, drawn in `Plant` rather than
  per-subclass, would make selection legible for every plant that gets added later.
- **Lane pressure readout.** The board is one road, so "which end is losing" is
  always answerable — tint the road segment red where pests got furthest last wave.
- **Kernels should miss.** They fly straight and hit the first body in 18 px; a
  fast aphid crossing the volley diagonally survives. That is a *good* accident —
  lean into it and let the "bunch" upgrade be about covering the miss, not damage.

#### Grown from *this* session's six features, after watching them run

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
