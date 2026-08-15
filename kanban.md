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

## Next up

| Card | Bead |
|---|---|
| Sprite pass 2: damaged / eating / dead states | `plant-tower-defense-eeq` |
| Chomp "occupied" readout — the chew bar the balance depends on | not filed |
| Corn range indicator on the selected plant | not filed |
| Title screen, restart button, endless mode | not filed |

---

## Cool new features (idea backlog)

### New this session — grown from what the running game actually feels like

- **Show the chew.** `ChompFlower.chew_progress()` exists and nothing draws it. The
  entire Chomp/beetle trade — "this mouth is busy for 2.6 seconds and your lane is
  open" — is currently invisible, so the player cannot make the decision the design
  is built around. A shrinking ring around the flower is the whole fix.
- **Range ring on the selected plant.** Placement is blind: the cob reaches 176 px
  and nothing says so, which makes the difference between a good plot and a wasted
  one unlearnable.
- **Lane pressure readout.** The board is one road, so "which end is losing" is
  always answerable — tint the road segment red where pests got furthest last wave.
- **Kernels should miss.** They fly straight and hit the first body in 18 px; a
  fast aphid crossing the volley diagonally survives. That is a *good* accident —
  lean into it and let the "bunch" upgrade be about covering the miss, not damage.

### Grown straight from the brief

Not filed as beads yet — these are the ones worth building *because* they fall out
of what the design doc already says, rather than being bolted on.

### Grown straight from the brief

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

- **Compost meter.** Pests killed leave husks; sweep them for a burst of seeds.
  Rewards active play without adding a second currency to read.
- **Weather rounds.** A rain wave heals every plant; a drought wave halves fire
  rate unless a plant sits next to water. Reuses the kit's existing water tiles.
- **Pest mutations.** From wave 8, a random pest type gains one trait (armoured =
  Chomp chews twice as long; winged = ignores ground plants; hungry = eats the
  plant instead of walking past). Turns a fixed wave table into a different run.
- **Endless mode with a seed-count high score**, so "how far did you get" has an
  answer.

### Feel and polish

- **Wobble on plant, punch on hit, squash on chomp.** No new art needed — the
  sprites are already centred on their vertical axis, which is what makes scale
  and rotation tweens land correctly.
- **Kernel trails and husk confetti** using the kit's existing particle-ish tiles.
- **A "Designer's Notebook" screen** that shows the original pencil drawing next to
  the finished sprite for each plant. The drawings are the source material; they
  should be in the game.

### Accessibility

- **Colour-blind-safe pest silhouettes.** Aphid and Beetle are already different
  *shapes*, not just red vs grey — keep that invariant when new pests are added.
- **Slow-mode toggle** (global `time_scale`), so the game is playable by whoever
  drew it.
