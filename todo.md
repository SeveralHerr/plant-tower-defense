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

- [x] Selection needs a second cue beyond the range ring — outline/corner
      brackets drawn on the sprite in the base `Plant` class, since Chomp
      Flower shows no ring at all when selected (`plant-tower-defense-42t`)
- [x] Lane pressure readout — tint the road segment red where pests got
      furthest last wave, fading each wave (`plant-tower-defense-4wv`)
- [x] Mutated pests should drop a better husk — scale husk value by mutation
      instead of paying the same amount regardless of `mutation`
      (`plant-tower-defense-1rh`)
- [ ] Endless mode should mutate faster over time — `MUTATION_CHANCE` stays
      fixed at 40% forever past wave 8; scale it (or widen `MUTATIONS`) as
      endless mode runs longer (`plant-tower-defense-1qi`)
- [ ] Second bite frame for a beetle's long chew — swap in an "almost done"
      sprite past `chew_progress() > 0.6` so a 2.6s beetle chew reads
      differently than a quick aphid one (`plant-tower-defense-rrx`)
- [ ] Add cool new features or concrete improvements (either gameplay or UX) to `kanban.md` — mine what this session's own
      work revealed, not just abstract ideas
