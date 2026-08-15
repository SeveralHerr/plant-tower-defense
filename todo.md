# todo

## The brief (original)

I have added a bunch of pictures to this repository as requirements for this game.

You will need to generate a few assets from the images in the Kenny asset style.

Here is the assets you can use with /kenney-asset-kit.
Path: `C:\Users\gotmi\Downloads\Kenney Game Assets All-in-1 3.6.0\2D assets\Tower Defense\`

## What the drawings say

- Tower defence. **Plants fight bugs.** (`image2.jpg`)
- **One free plant to start.** Others cost seeds — you buy seed packets. (`image2.jpg`)
- **Corn Cobbler** — corn cob with a face; fires kernels, upgrading to a
  "bunch of corn" spread. (`image1.jpg`, `image3.jpg`, `image6.jpg`)
- **Chomp Flower** — toothy flower; "eats small pests easily, takes a while
  eating bigger pests". (`image4.jpg`, `image5.jpg`)
- **Pests** — small ones and bigger ones. (`image3.jpg`, `image5.jpg`)

## Items

- [x] Sprite pass 2: damaged / eating / dead states (`plant-tower-defense-eeq`)
- [x] Chomp Flower "occupied" readout — the chew timer is the balance lever and
      nothing on screen shows it (`chew_progress()` already exists, unused)
- [x] Corn range indicator on the selected plant — placement is currently blind
- [x] Seed packet tiers, so the packet is a gamble with stakes rather than a
      two-item shuffle (needs a third plant) (`plant-tower-defense-e0w`) — third
      plant is the Seed Sunflower
- [x] Compost meter: pests leave husks, sweeping them pays seeds
      (`plant-tower-defense-d0w`)
- [x] Pest mutations from wave 8 (armoured / winged / hungry)
      (`plant-tower-defense-b5k`)
- [x] Title screen + endless mode with a seed high score
      (`plant-tower-defense-5fu`)
- [x] A "Designer's Notebook" screen showing `image1.jpg`–`image6.jpg` beside the
      finished sprite for each plant (`plant-tower-defense-1qo`)
- [x] Add cool new features to `kanban.md` — see "Cool new features" there,
      including a fresh batch grown from watching this session's six features run

All items closed 2026-08-15 — see `log-devtools.md` for the /verify writeup and
`kanban.md` for the readable Done/backlog board. `bd ready` is empty; nothing new
is filed yet. Canonical task state is **`bd ready`**; the readable board is
`kanban.md`.
