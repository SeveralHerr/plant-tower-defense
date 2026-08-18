---
name: palette-against-the-background
description: Choose a sprite's colours against the surface it will actually sit on, measured rather than assumed — and check an existing sprite the same way. Use before drawing any new sprite, when a piece of art "looks fine in isolation" but vanishes or muddies in the game, when a sprite moves to a different surface, and whenever picking a palette family from a style guide. Also use when reviewing art someone else added, because the failure is invisible in the asset and only appears composited.
---

# Choosing colour against a background you have measured

A sprite is never seen on its own. It is seen on a surface, and the only thing that matters
is the pair. This skill is about measuring that surface first, and about the two ways the
measurement gets skipped.

**The failure is invisible where you look for it.** Open the PNG and it is a perfectly good
drawing. Every geometry gate passes — size, centring, margin, palette membership. The sprite
disappears only when composited, and only on the one surface it was drawn for.

## 1. Measure the background. Do not name it.

The style guide names families. The background is a number, and it is usually not the
number the family implies.

```bash
python - <<'PY'
from PIL import Image
import collections
im = Image.open('<the tile or backdrop the sprite sits on>').convert('RGBA')
c = collections.Counter(px[:3] for px in im.getdata() if px[3] >= 128)
for col, n in c.most_common(4):
    print('#%02X%02X%02X' % col, n)
PY
```

In this project that produced two facts nobody had written down: the grass tile is
**`#2ECC71` exactly** — which is `GardenTheme.LEAF`, i.e. the kit's Foliage green *base* —
and the road tile is a **flat `#BB8044`**, one colour across all 4096 pixels.

"The grass is green" is not a measurement. `#2ECC71` is, and it is what makes the trap
below obvious instead of surprising.

## 2. The trap: the family that fits the SUBJECT is the family that matches the GROUND

A plant is green. Grass is green. A bramble is brown. Dirt is brown.

**The palette family that most obviously belongs to the object is very often the family its
background already occupies**, and choosing it makes the sprite disappear. This is not a
rare edge case — it is the default outcome of picking colours by what the thing *is*.

Three instances in this project, each written up in the SVG that paid for it:

| Sprite | Obvious family | Background | What happened |
|---|---|---|---|
| Garden Mint | Foliage green | grass `#2ECC71` | drawn in the lawn's own hue; vanished |
| Prickly Nettle | Foliage green | grass `#2ECC71` | the near-misses `#229C56`/`#1F8A4C` differ from the lawn in **luminance only** — a one-channel cue on the one plant whose whole point is telling at a glance whether it is working |
| Barrier Bramble | Dirt/seed brown | road `#BB8044` | `#C48647` against `#BB8044` is nine points on the red channel and nothing anywhere else |

The third is the one that proves it generalises: the same mistake, a different family, a
different surface, arrived at by the same reasoning two cycles later.

## 3. Prefer a LUMINANCE gap over a hue gap

Compute both. Hue contrast is what the eye notices first and luminance is what survives:

- **colour vision deficiency** — brown/green and red/green are the common confusion axes,
  and two colours can be far apart in hue while being the same to a deuteranope.
- **downscaling** — the sprite is 64px and gets smaller; hue detail averages away, relative
  lightness does not.
- **whatever is drawn between them** — a rim, a shadow, an overlay tint.

```
luma = 0.299*R + 0.587*G + 0.114*B
```

The Bramble's sand `#ECDCB8` is luma 215 against the road's 139: a 76-point gap, the largest
any family in that palette offers over that ground without going to flat white. A green at
luma 146 would have been *near-complementary in hue* and nearly identical in lightness — the
worst combination, and the one that reads best on a monitor in isolation.

**Say the number in the file.** "Chosen for contrast" is not reviewable; "215 against 139"
is.

## 4. Which families are already taken, and by what

Contrast with the background is necessary and not sufficient. A sprite also has to not be
mistaken for something else on screen.

Enumerate before choosing: in this project Red is every pest, so a red plant is a plant the
player reads as a target; Blue-grey is the Sundew's dew and Mint's leaves; Stone is every
carapace. That left Orange — listed in the style table as "Orange (fx)" and used by nothing
— for the Nettle.

Ask three questions, in this order:
1. What is the background, as a number?
2. What else on screen already owns this family, and would a viewer confuse them?
3. Is the gap luminance or only hue?

## 5. Auditing a sprite that already exists

**Measure the sprite's best major colour against the background, NOT its dominant one.**
That distinction is the whole of this section and it was learned the hard way: the first
version of this audit read the dominant colour's `dL` and reported **five findings out of
five sprites it flagged, every one false**.

The reason is structural, and it is why a naive contrast audit is useless on any art with an
outline convention. This project's `art_src/STYLE.md` mandates *"outline = darker shade of
the fill, 2 px"* — so the **silhouette's separation from the ground lives in the rim, and
the fill is free to sit anywhere.** Reading the fill alone flags every sprite whose body is
mid-luminance, which is most of them, by design.

What the corrected audit found once it read the rim too:

| Sprite | Surface | fill `dL` | best major `dL` | verdict |
|---|---|---|---|---|
| Garden Mint | grass | 13 | 47 (`#1F8A4C`) | rim carries it |
| Salve Aloe | grass | 9 | 74 (`#ECDCB8`) | rim carries it |
| aphid / Shield Bug / Queen | road | 17–18 | 48–49 (`#AF392D`) | rim carries it |

Five sprites that a fill-only check condemns and that are all fine.

```bash
python - <<'PY'
from PIL import Image
import collections
def luma(c): return 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
bg = (0x2E, 0xCC, 0x71)                      # MEASURED, per section 1 — not assumed
im = Image.open('assets/sprites/<sprite>.png').convert('RGBA')
c = collections.Counter(px[:3] for px in im.getdata() if px[3] >= 128)
tot = sum(c.values())
major = [(col, n) for col, n in c.items() if n / tot >= 0.05]   # ignore 2-pixel highlights
dom  = max(major, key=lambda t: t[1])[0]
best = max(major, key=lambda t: abs(luma(t[0]) - luma(bg)))[0]
print('fill dL %3.0f | best major dL %3.0f' % (abs(luma(dom) - luma(bg)),
                                               abs(luma(best) - luma(bg))))
PY
```

**Read it as: a finding is `best major dL` under about 40.** The `5%` floor matters — without
it the "best" colour is whatever two-pixel highlight happens to be brightest, and the check
passes on everything for the opposite reason.

A fill `dL` under 25 with a healthy rim is not a finding, but it IS the configuration to
look at twice when a sprite is going to be **scaled down or drawn small**: the rim is 2px at
64px and the first thing to disappear, and when it goes the fill is all that is left.

```bash
python - <<'PY'
from PIL import Image
import collections
def luma(c): return 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
bg = (0x2E, 0xCC, 0x71)                      # measured, not assumed
im = Image.open('assets/sprites/<sprite>.png').convert('RGBA')
c = collections.Counter(px[:3] for px in im.getdata() if px[3] >= 128)
print('bg luma %.0f' % luma(bg))
for col, n in c.most_common(6):
    print('  #%02X%02X%02X  n=%-5d luma %3.0f  dL %3.0f' % (col + (n, luma(col), abs(luma(col)-luma(bg)))))
PY
```

Read the **dominant** colour's `dL`, not the brightest — the brightest is often a two-pixel
highlight. A dominant `dL` under about 25 on the surface the sprite actually sits on is the
finding.

## What this cannot tell you

**It cannot see the rim doing its job unless you tell it to** — see section 5, where the
first version of this skill's own audit produced five false positives out of five by reading
the fill alone. Any project with an outline convention has this property, and the fix is to
read the best major colour rather than the dominant one.

It compares colours. It does not know **where** on screen the sprite goes, so a plant sprite
audited against grass is audited against the wrong surface the day it moves to the road —
that is exactly what happened here, and the only guard is asking question 1 again whenever
placement changes. It says nothing about shape, and a silhouette that reads is worth more
than a palette that contrasts. And a "clean" result is a statement about the two colours you
gave it, not about the composited frame: overlays, tints, and a health bar drawn on top all
change the pair after this has finished.
