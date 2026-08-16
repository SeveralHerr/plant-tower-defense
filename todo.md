# todo

**Cycle 11 of 30.** Bump this each time you refill the Items list. See the Workflow
loop at the top of `CLAUDE.md` — when this list is done, refill it and start again.

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

- [ ] A truncated save silently zeroes a high score that can never be restored —
      `int("")` is 0 and `record_score` only raises (`plant-tower-defense-5el`)
- [ ] Every Sundew redraw walks every pest on the board, and redraws are most
      frequent when the pest count is highest (`plant-tower-defense-fp5`)
- [ ] Node metadata is a cross-script contract that no gate can see
      (`plant-tower-defense-dka`)
- [ ] Add cool new features or concrete improvements (UX, game juice,
      animations, enhancements, or full features) to `kanban.md`
