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

- [ ] HUD compost counter collides with the "Grow the next wave" button — the
      `(N ready)` suffix runs under it, and no check catches sibling-Control
      occlusion (`plant-tower-defense-kcj`)
- [ ] A richer husk should rot faster, so sweep order becomes a decision
      instead of every husk sharing one 10s timer (`plant-tower-defense-kh9`)
- [ ] Show a readable threat level for endless mode — five scales now climb
      independently and the player can see none of them
      (`plant-tower-defense-o1p`)
- [ ] Per-run lane pressure for the end-of-run post-mortem, alongside the
      per-wave map that fades (`plant-tower-defense-dbg`)
- [ ] Placement preview should warn when a non-combat plant is road-adjacent —
      the preview already knows reach and legality (`plant-tower-defense-8bb`)
- [ ] Add cool new features or concrete improvements (either gameplay or UX)
      to `kanban.md` — mine what this session's own work revealed, not just
      abstract ideas
