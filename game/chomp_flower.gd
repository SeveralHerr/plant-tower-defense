class_name ChompFlower
extends Plant

## The melee plant. The design doc's words are "eats small pests easily, takes a
## while eating bigger pests", so this is not a damage-per-second tower — it is a
## body blocker.
##
## Grabbing a pest holds it still AND occupies the flower for the whole chew. An
## aphid is gone in under half a second; a beetle ties the mouth up for two and a
## half, during which every other bug in the lane walks straight past. A player
## who fills a lane with Chomps has a lane full of busy mouths and nothing
## shooting, which is the entire rock-paper-scissors of the game.

## Must exceed one cell: a Chomp stands on grass and the pest walks the road, so
## the closest they ever get is exactly CELL apart. At 62 the flower could not
## reach the lane beside it and never ate anything — with no error anywhere,
## because "found no prey" and "there is no prey" look identical. Kept under two
## cells so it still only covers the lane it is actually next to.
const GRAB_RADIUS: float = Board.CELL * 1.15

## HOW FAR PAST THE FLOWER a pest has to walk before the mouth will close on it.
##
## Without this the Chomp bites at the LEADING edge of its circle — the bug is caught
## before it is even level with the plant, which reads as a trap rather than as an
## ambush. The flower now lets them come on a bit and snaps from behind.
##
## A quarter of a `Board.CELL`, and it is an ABSOLUTE rather than a fraction of
## `grab_radius()` on purpose: the ladder buys reach (1.00 -> 1.13 -> 1.26), and a lead
## scaled to reach would mean a flower that costs more waits LONGER before eating, which
## is not what any rung is selling. 16 px is "a little past the stem" at every rung.
##
## THE ARITHMETIC THIS NUMBER LIVES OR DIES BY, because the failure mode is silence. A
## Chomp stands on grass and its prey walks the road one `Board.CELL` away, so the reach
## only covers a chord: at rung 1 the half-width along the road is
## sqrt(73.6^2 - 64^2) = 36.3 px. Requiring 16 px of it leaves a 20.3 px window. The
## fastest pest in the table is the aphid at 78 px/s, doubled by `GameSpeed`'s 2x step,
## which is ~2.6 px per physics frame — about eight frames to notice the bug in the
## window and close on it.
##
## Push this number past the chord's half-width and the flower eats NOTHING, with no
## error anywhere, because "found no prey" and "there is no prey" look identical — the
## same failure `GRAB_RADIUS` above records from when it was 62. That is why
## `test_the_pass_window_stays_open_for_every_species_at_double_speed` exists and why it
## is written against frames rather than pixels.
const GRAB_LEAD: float = Board.CELL * 0.25

## The mouth's ladder — the second one in the game, and the first that is not the
## cob's (see `Plant.upgrade_ladder` for the surface this fills in).
##
## Both stats are SCALES of this class's own constants rather than absolute numbers,
## so level 1 is the flower that shipped, exactly, by construction rather than by a
## pair of numbers someone has to keep in step with `GRAB_RADIUS` and the pest table.
## `PlantCatalog.reach(CHOMP)` still answers `GRAB_RADIUS` and is still right: it is
## asked before anything is planted, and every flower is planted at level 1.
##
## What a level buys, and why it is a behaviour rather than a bigger number:
##
##   * `reach_scale` — 1.15 -> 1.30 -> 1.45 cells (73.6 -> 83.2 -> 92.7 px). Still
##     under two cells at the top, which is the rule GRAB_RADIUS's header states: a
##     Chomp covers the lane it is beside and never the one after it. The player sees
##     a mouth close on a bug it used to let past.
##   * `chew_scale` — the meal itself, not the plant's own clock. A Chomp's real cost
##     is the mouth being shut (see this class's header), so the only upgrade worth
##     buying for a body blocker is one that gives the lane back sooner: a beetle goes
##     2.6s -> 2.08s -> 1.69s, an aphid 0.45s -> 0.29s.
##
## Deliberately gentle at the top, and this is the one number in the table that is a
## balance decision rather than an arithmetic one. `Pest.SPECIES[QUEEN]`'s 11-second
## chew is documented at `game/pest.gd:145` as the trade for eating a queen at all —
## "the whole rest of the wave walking past a shut mouth". At 0.65 that is 7.15s, which
## is still most of a wave, so the trade survives the ladder rather than being bought
## out of it. A `chew_scale` near 0.4 would have deleted it.
##
## Both columns move the same way at every rung and neither can reverse — reach only
## grows, chew only shortens — so level N grabs everything level N-1 would have grabbed
## and finishes sooner, at every distance, against any pest. That is the same "there is
## no configuration in which upgrading can lose" property `CornCobbler.KERNEL_STEP_DEGREES`
## spends thirty lines establishing, and here it is free because the table is monotone;
## `test_combat` pins it anyway, because free is not the same as checked.
##
## Costs: 25 then 45, against corn's 20 then 45. A Chomp costs 15 to plant where a cob
## costs 10, and a ladder on a dearer plant opening dearer is the same gradient
## `PlantCatalog` already prices tiers on. 45 stays the dearest single upgrade in the
## game rather than being beaten by a new one.
##
## The names are NOUNS, like the cob's "single / triple / bunch" and unlike the
## adjectives that first went in here. `Hud.upgrade_message` puts the level name in a
## sentence ("... is now a %s."), and a sentence is what makes "gaping" wrong and
## "gaping maw" right — the selection panel would have taken either.
const LEVELS: Array[Dictionary] = [
	{"name": "bud", "chew_scale": 1.00, "reach_scale": 1.00, "upgrade_cost": 25},
	{"name": "toothy maw", "chew_scale": 0.80, "reach_scale": 1.13, "upgrade_cost": 45},
	{"name": "gaping maw", "chew_scale": 0.65, "reach_scale": 1.26, "upgrade_cost": 0},
]

## Radius of the "mouth full" ring. **Fixed**, and the arc's swept ANGLE carries the
## progress — the idiom `HuskLayer` has used since the husks existed
## (`game/husk_layer.gd:69-77`: a fixed `radius + RING_GAP`, `TAU * frac` of it drawn).
##
## It used to shrink from 16 to nothing instead, and that was backwards. A shrinking
## ring is smallest exactly when its news is most urgent — "the mouth is nearly free"
## is the moment a player decides whether to commit a lane — and `Node2D` paints its
## own canvas below its children, so the last of it disappeared behind the flower's
## own sprite. Two timers in one game had opposite answers and the husk's was the
## better one.
##
## 22 px is pinned between three things, none of them taste:
##   * **above** the old 16, so the arc clears the flower's head rather than being
##     drawn under it (cycle 70 measured a Corn Cobbler pip at 20 px reading leaf
##     green at one aim and its own gold at another);
##   * **below 26.0**, which is where `Sunflower`'s gauge puts its nearest corner —
##     `test_combat` asserts that corner is strictly outside this ring so the two
##     radial-looking readouts never share a pixel;
##   * **below 32**, half a `Board.CELL`, so it stays inside its own cell.
##
## Those three bounds are two neighbours and a cell edge, written as a pair each. The
## whole set of neighbours now lives in `ReadoutBand` (game/readout_band.gd), which
## derives this ring's interval from the two constants below rather than restating them
## and holds it against every other mark drawn at a fixed radius on a plant. **Read that
## file before moving this number or adding a mark of your own** — the band is full, and
## the widest unclaimed slice left in it is 3.0 px.
const CHEW_RING_RADIUS: float = 22.0
const CHEW_RING_WIDTH: float = 3.0
## Named rather than inline now that two places would otherwise spell it.
##
## DARKENED (plant-tower-defense-75os): the mid-meal cue is a live, informational
## ring — how close a pest is to being freed — not a decoration, so it owes
## `GardenTheme.GROUND_SEPARATION_MIN` the way `PlacementPreview.BLOCKED_COLOR` does,
## and it was never in the sweep that priced that one. ChompFlower stands only on
## grass, and the original `Color(1.0, 0.55, 0.15)` sits at luminance 0.617 against
## grass's 0.642 — a base separation of 0.026, which even at alpha 1.0 clears less
## than a quarter of the floor. This is that hue `.darkened(0.22)`: luminance 0.481,
## base separation 0.161, and at the ring's own 0.85 alpha that is 0.137 — clearing
## by 0.017. See
## test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at.
const CHEW_RING_COLOR := Color(0.78, 0.43, 0.12, 0.85)

## The Chomp's hue for the SHARED reach ring (plant-tower-defense-snnp). Alpha comes
## from `Plant.REACH_RING_ALPHA` rather than being a second copy of it, which is the
## whole point of the shared helper: five plants had independently arrived at 0.55 and
## the sixth would have been a coin toss.
##
## This plant had no reach ring at all until cycle 111, and that was a GAP rather than
## a decision: `PlantCatalog.reach(CHOMP)` already answers `GRAB_RADIUS`, so the
## placement preview draws this exact circle while the player is deciding where to put
## the flower -- and then selecting the placed flower withdrew it. The hover promised a
## reach the selection would not repeat. It repeats it now.
const RING_COLOR := Color(0.86, 0.44, 0.62, Plant.REACH_RING_ALPHA)

## The fang crown: what an upgraded mouth WEARS, always on, whether or not it is
## chewing.
##
## This exists for the reason `CornCobbler`'s muzzle fan exists, and the reason is
## worth restating because it is the whole standard for a ladder in this game: an
## upgrade the board does not show is an upgrade that reads as nothing having
## happened. The cob learned that at 45 seeds a level. A Chomp's two stats are a
## reach and a chew time, and neither of them can be seen on an idle flower — the
## chew ring only appears mid-meal, and a mouth that is not eating anything looks
## identical at every level.
##
## COUNT, not hue, and not size: `level - 1` PAIRS of teeth, so the plain flower
## wears none, and the vocabulary is the one the board already speaks — the health
## bar's notches, `PlacementPreview`'s one-bar/two-bar ground cue.
##
## Geometry, all four of which are constraints rather than taste. A tooth is 5.4 px
## across, rim included, and it has to fit in a band 8 px wide — every number below
## is that band being divided up, which is why they are as specific as they are:
##   * FANG_RADIUS 28 sits OUTSIDE the sprite. `Node2D` paints its own canvas below
##     its children, so anything drawn under the flower is invisible rather than
##     dimmed — the same trap `Sunflower`'s gauge header documents. chomp_flower.svg's
##     nine petals are ellipses centred 17 px out with ry 6 and a 2 px stroke, so the
##     ring of petals ends at r = 24; a tooth's inner edge is at 25.3 and its outer at
##     30.7, inside the 32 px half-cell.
##   * That inner edge also clears the chew ring's outer edge (22 + half of 3 = 23.5),
##     so the two readouts on this one plant can never share a pixel — the same
##     clearance rule `test_combat` already pins between that ring and a Sunflower's
##     gauge.
##   * The crown sits in the TOP half only (±39° from straight up at the top level).
##     The two leaves in the sprite are drawn at 55° and 125° — down-right and
##     down-left — and they reach r = 31, so the bottom half is the only part of this
##     plant that would swallow a tooth at this radius.
##   * FANG_STEP_DEGREES is fixed, and each level adds one PAIR outside the pair
##     below, so level N's angles are a strict superset of level N-1's. Straight from
##     `CornCobbler.KERNEL_STEP_DEGREES`: a readout whose marks MOVE when you pay for
##     it reads as a different thing, not as more of the same thing.
##
## A fourth constraint this header did not know about, found by `ReadoutBand`
## (game/readout_band.gd) the moment the hand-written pairs became a sweep: the crown's
## outer rim at 30.7 overlapped the sole-cover alone ring's inner edge at 30.0 by
## 0.7 px, so a SELECTED, upgraded Chomp holding no road cell alone drew two of its
## four teeth under a dash. That ring was removed in cycle 179 and the collision went
## with it; the entry is kept because the SWEEP is what found it, not a reader. It was
## recorded as a live defect in `test_placement.gd`'s
## `READOUT_BAND_KNOWN_COLLISIONS` rather than fixed here: neither mark has anywhere to
## go — see that entry — so which of the two gives up the outer band is a decision about
## the cue grammar, not a nudge to a number.
const FANG_RADIUS: float = 28.0
const FANG_STEP_DEGREES: float = 26.0
const FANG_SIZE: float = 1.8
const FANG_RIM_WIDTH: float = 0.9
## The sprite's own tooth white over the maw's own dark red, so the crown reads as
## this flower's teeth rather than as a new object parked beside it — and as neither
## the chew ring's orange nor the cob's gold.
const FANG_COLOR := Color(1.0, 0.98, 0.94, 0.95)
const FANG_RIM_COLOR := Color(0.34, 0.11, 0.08, 0.90)

## The design doc draws a Chomp mid-bite as its own picture, not a tinted idle
## sprite — swapped in for the whole chew and back on release.
const EATING_TEXTURE_PATH := "res://assets/sprites/chomp_flower_eating.png"

## The threshold is a fraction of chew_progress(), the same one the shrinking
## chew ring already reads, so it fires for any pest — an aphid crosses it
## too, just with only ~40% of its already-brief 0.45s chew left to show it,
## which reads as instant either way. A beetle's 2.6s chew is long enough
## that the last ~1s actually gets to show a second picture instead of the
## mouth just staying wide open the whole time.
const LATE_BITE_THRESHOLD: float = 0.6

## IS 0.45s LONG ENOUGH FOR THE CHEW RING TO SAY ANYTHING? Asked by
## plant-tower-defense-l86t, which suspected the answer was no and proposed suppressing the
## ring below some threshold, the way `LATE_BITE_THRESHOLD` above gates the sprite swap.
##
## MEASURED FIRST. `Pest.SPECIES` chew_seconds: aphid 0.45, beetle 2.6, Shield Bug 3.0,
## Nurse Beetle 5.0, Queen 11.0 — and `MUTATION_ARMOURED` doubles any of them, so the real
## range is 0.45s to 22s. The aphid is not merely the shortest, it is **5.8x shorter than
## the next one up**, and it is also the commonest pest in the game.
##
## DECIDED: NO SUPPRESSION. Three reasons, and the third is the one that settles it:
##
##   * THE RING MEANS BUSY. A Chomp mid-chew cannot grab anything, and the ring is what
##     says so. Suppress it under a threshold and a busy Chomp reads as a free one for
##     exactly as long as the suppression lasts — at the moment a player is most likely to
##     be looking for a mouth to throw the next pest at.
##   * IT WOULD HIDE THE MAJORITY CASE. The aphid is the pest the player sees most, so a
##     threshold anywhere above 0.45s removes the ring from most chews in the game and
##     leaves a cue too rare to learn.
##   * A FLASH IS THE PROMISE THE SHOP MAKES. `PlantCatalog`'s entry reads "Eats small pests
##     instantly. Big ones take a while — and it is busy the whole time." A 0.45s sweep
##     reading as instantaneous is not a failure of the cue; it is the cue agreeing with the
##     sentence the player was sold. The ring exists for "big ones take a while", and there
##     it has between 2.6 and 22 seconds to work in.
##
## `test_the_chomps_shop_line_is_true_of_the_chew_table` pins all three clauses of that
## blurb against `Pest.SPECIES`, so a retune that makes an aphid slow to eat — or a beetle
## quick — fails rather than quietly making the shop lie.

## How many discrete bites a meal is eaten in.
##
## SOURCE: a player, verbatim -- "the attack animation for the chomp flower doesn't
## really look like it's taking bites out of the bugs, improve the animation
## dramatically" (plant-tower-defense-h4v1).
##
## The flower's half was already substantial -- a 7px lunge, a squash, three textures
## and a chew ring draining round the rim -- and none of it touched the PEST. A held
## bug walked in place, unmarked, took one flash at the grab and nothing after, then
## became a corpse in a single frame. So the meal was a continuous drain with one
## event at each end, and "taking bites" is exactly what a continuous drain is not.
##
## Three, and the number is doing work. Two reads as start-and-finish, which is what
## it already looked like. Four inside CHEW_SECONDS puts the bites close enough
## together that the pest's own HIT_FLASH_DURATION (0.10) has not finished before the
## next one begins, so they smear into one long flash instead of reading as separate
## bites.
const BITES_PER_MEAL: int = 3


## How many bites have been taken by a given point in the chew. Pure and static, so
## the cadence is assertable with no board, no frame and no open animation gate --
## the same treatment lunge_offset() and Nettle.sting_lean_skew() get, and for the
## same reason.
##
## The last bite lands when the chew COMPLETES rather than before it, which is why
## this floors a scaled progress rather than rounding: at progress 1.0 the meal ends
## and Pest.kill() takes over, so a third bite landing at 0.999 would be a bite the
## player never sees separately from the kill.
static func bites_taken_for(progress: float) -> int:
	var p: float = clampf(progress, 0.0, 1.0)
	return mini(int(floorf(p * float(BITES_PER_MEAL))), BITES_PER_MEAL)
const EATING_LATE_TEXTURE_PATH := "res://assets/sprites/chomp_flower_eating_late.png"

## The jaw at full gape, worn for the instant of the bite and no longer.
##
## plant-tower-defense-81g9, the flower's half of a player report -- "the attack
## animation for the chomp flower doesn't really look like it's taking bites out of
## the bugs". The pest's half (-h4v1: three visible bites, the bug shrinking as it is
## eaten) shipped first. This is the other one: the mouth already had three textures
## and NONE of them was open. It lunged and squashed while wearing the same closed
## head it wears through the whole chew, so the bite had no instant -- the frame a
## player's eye lands on was a flower that had already finished.
const GAPE_TEXTURE_PATH := "res://assets/sprites/chomp_flower_gape.png"

## How far the mouth throws itself at what it just caught, in px.
##
## The designer's note asked for an attack that READS as an attack, and the answer is a
## direction rather than more scale. A squash is symmetric: (1.18, 0.82) looks identical
## whether the meal is to the left, the right or straight up, so the only board-level
## evidence a Chomp did anything was a pest that stopped moving. Corn has a kernel that
## visibly leaves the plant and travels at somebody; this is the melee version of that
## sentence — the plant, not a projectile, is what moves at the target.
##
## 7 px is bounded on both sides rather than picked. **Above ~4**, or it disappears into
## `Plant.WOBBLE_RADIANS`' idle sway, which already swings the corner of a 64 px sprite
## about 1.8 px and would make the lunge read as one more breath. **Small enough that the
## sprite stays in its own cell**: `chomp_flower.svg`'s painted content runs 8.2..55.8 in
## x, so the body reaches 23.8 px from centre and 7 more puts its leading edge at 30.8,
## inside the 32 px half-`Board.CELL`. A lunging flower therefore never draws itself into
## the neighbouring square, where it would read as a plant standing there.
##
## Note what does NOT travel with it: the chew ring and the fang crown are drawn in this
## node's own `_draw()`, not on `_sprite`, so both stay put while the head moves. That is
## the right split rather than an oversight — they are READOUTS (mouth busy, level bought)
## and a readout that lurches every time the plant acts is harder to read, not livelier.
const LUNGE_DISTANCE: float = 7.0

## The bite's four durations. Declared here rather than taken from `Plant.TWITCH_*`
## because the bite is the one gesture in the family that genuinely does not fit
## either tier: the lunge's out is the twitch's 0.05, but everything else is longer,
## and both channels come home slower than a recoil does. A bite has further to
## travel than a squash — `LUNGE_DISTANCE` above moves the whole head — so it gets
## its own numbers rather than being rounded onto a shared pair it does not match.
##
## The two channels are deliberately staggered by a hundredth of a second in each
## direction, position leading on the way out and lagging on the way back. That is
## what these numbers ALREADY were, preserved exactly. Whether the stagger was ever
## intended or just drifted while nothing named it is a question only a pair of eyes
## on the running game can answer, and no gate in this project can: a duration is
## invisible to lint, to `name_check`, and to a headless suite that pumps no frames.
## Naming them is what makes the question askable at all.
##
## `BITE_SQUASH_OUT_SECONDS` is the outward beat's real length (it is the longer of
## the two outs, and `chain()` below waits for it), so it is the window anything
## swapped in for the duration of the open jaw should be shown for.
const BITE_LUNGE_OUT_SECONDS: float = 0.05
const BITE_SQUASH_OUT_SECONDS: float = 0.06
const BITE_LUNGE_BACK_SECONDS: float = 0.13
const BITE_SQUASH_BACK_SECONDS: float = 0.12

## THE CATCH — the vines, the haul, and where the meal sits while it is eaten.
##
## What this replaces: a grab used to be a 0.05s lunge and a texture swap, and the bug
## simply stopped where it stood on the road. Nothing showed the flower REACHING and
## nothing showed the bug being TAKEN, so a Chomp at work read as a bug that had halted
## next to a flower that twitched once.
##
## The shape now, in three beats off one clock (`_capture_elapsed`):
##
##   lash  — vines shoot from the flower's base out to the bug, curving as they go.
##   haul  — the vines retract and straighten, and the bug arcs up onto the flower.
##   chew  — the bug sits in `CARRY_ANCHOR` with the vines clasping it, and the bite,
##           the champ, the chew ring and the eating sprites all play as before.
##
## THE MEAL CLOCK IS NOT TOUCHED. `_chew_left` starts counting on the frame the mouth
## closes exactly as it always has, and the lash and the haul happen inside the first
## fraction of it. That is a deliberate refusal to change balance: `chew_seconds` is a
## table half a dozen tests and the whole playtest sweep assert against, and a catch
## animation that added a third of a second to every meal would be a nerf hidden in an
## animation commit.
##
## NO TWEEN OWNS ANY OF IT. Everything below is a pure function of `_capture_elapsed`,
## which `_chew` advances every frame — `.claude/skills/assert-an-animation`'s first
## rung. The alternative (tween the pest onto the flower, tween it back) puts the pest's
## drawn position inside something headless never runs, and this project has paid for
## that shape twice already.

## Where a caught bug is eaten, in the flower's own space. Straight up: STYLE.md puts a
## plant's long axis up-screen, so this is the mouth, and any sideways component would
## read as the bug perched on a leaf.
##
## -20 rather than something bigger: the flower's petals reach r=24 and the fang crown
## sits at r=25.3-30.7 (see `_build_chew_layer` for where those numbers were measured),
## so a bug at 20 px sits INSIDE the crown with its own body overlapping the head. That
## is the picture — held in the mouth. Lifting it clear of the fangs would read as a bug
## hovering above a plant that is not touching it.
const CARRY_ANCHOR := Vector2(0.0, -20.0)

## How high the bug is thrown on the way up, above the straight line from road to mouth.
## The arc is what makes the haul read as a YANK rather than a slide; at 0 the bug tracks
## the chord and looks magnetised.
const HAUL_ARC_HEIGHT: float = 16.0

## The catch's two beats at full length, for a meal long enough to afford them.
##
## An aphid's whole `chew_seconds` is 0.45 (`Pest.SPECIES`), so a fixed 0.32s catch would
## be five sixths of an aphid's life in a mouth — the bug would land on the flower and be
## killed almost immediately, and the eating sprite would barely appear.
## `capture_seconds_for` therefore caps the catch at a FRACTION of the meal rather than
## spending a constant: a beetle gets the full lash-and-haul, an aphid gets a fast snatch
## at the same shape.
const LASH_SECONDS: float = 0.10
const HAUL_SECONDS: float = 0.22
const CAPTURE_SECONDS: float = LASH_SECONDS + HAUL_SECONDS

## The cap. 0.40 leaves an aphid (0.45s meal) 0.18s of catch and 0.27s of visible eating,
## which is the smallest split where the eating sprite is still a thing a player sees.
const CAPTURE_CHEW_FRACTION: float = 0.40

## Three vines, because three is the smallest number that can clasp something from more
## than one side — two read as a pair of tongs, and the grip pads below are placed on a
## ring, so two would sit opposite each other and the bug would look pinched rather than
## held.
const VINE_COUNT: int = 3
const VINE_SEGMENTS: int = 10

## How far apart the vines leave the flower, and how far apart they take hold of the bug.
## The roots fan across the head; the grips sit on a small ring around the meal.
##
## MEASURED, and both numbers were moved once for the same reason. At a spread of 5 and a
## grip radius of 7 the whole vine, once the bug had landed, lived inside the 24 px the
## beetle sprite covers: the lash and the haul read perfectly and the CHEW -- which is
## most of a meal, and all of a beetle's two and a half seconds -- showed a bug sitting on
## a flower with nothing visibly holding it. Photographed at 90x90 px, cycle 175.
##
## 13 and 11 put the roots out near the petal line and the grips out on the bug's rim, so
## three vines are still visible on either side of the meal for the whole chew. Both stay
## inside the fang crown's band (r=25.3-30.7, see `_build_chew_layer`), so a holding vine
## never crosses the level readout.
const VINE_ROOT_SPREAD: float = 13.0
const GRIP_RADIUS: float = 11.0

## The bow in a vine that is still reaching, in pixels of sideways displacement at its
## midpoint. Alternating in sign per vine (see `vine_bow`), so the three do not overlay
## into one thick line.
const VINE_BOW: float = 9.0

## What the bow shrinks to once the vine is pulling. A vine hauling a bug is under load
## and a loaded rope is straight; keeping the full bow through the haul reads as three
## slack ribbons that happen to be moving.
##
## Not zero, and that is the same measurement VINE_ROOT_SPREAD records: this is also the
## bow a vine keeps for the whole CHEW, and three straight lines 20 px long behind a
## beetle are three lines nobody can see.
const VINE_TAUT_SLACK: float = 0.45

## The writhe: the bow breathes while the vine is out, so a vine that is holding a beetle
## for two and a half seconds is not a frozen curve. Faster than the plant's own breathe
## (`Plant.BREATHE_RATE` 2.0) for the reason the champ is faster than it too — a cue that
## does not out-read the idle motion reads as nothing.
const VINE_WRITHE_RATE: float = 7.0
const VINE_WRITHE_AMOUNT: float = 0.22

## Drawn as a dark rim with a lighter core down the middle, the same two-pass shape the
## fang crown uses, and for the same reason `.claude/skills/palette-against-the-background`
## gives: a vine crosses BOTH surfaces of this board on its way to a bug — grass #2ECC71
## and road dirt #BB8044 (`Board`'s header sampled both) — and no single green is clearly
## legible on both. A near-black green rim is, on either.
const VINE_RIM_WIDTH: float = 4.0
const VINE_CORE_WIDTH: float = 1.8
const VINE_RIM_COLOR := Color(0.05, 0.18, 0.10, 1.0)
const VINE_CORE_COLOR := Color(0.29, 0.60, 0.32, 1.0)

## The grip pad at each vine's tip. It wears the reach ring's pink rather than a green,
## so the point of contact is the one part of the vine that cannot be mistaken for a leaf
## of the plant or a blade of the grass it is crossing.
const VINE_TIP_RADIUS: float = 2.6
const VINE_TIP_COLOR := Color(0.86, 0.44, 0.62, 1.0)

var _held: Pest = null
var _chew_left: float = 0.0
## How many bites of the current meal have landed. Reset per meal, so a flower that
## releases one pest and grabs another starts the new bug at zero rather than
## finishing it in one.
var _bites_taken: int = 0
var _chew_total: float = 0.0
var _idle_texture: Texture2D = null
## The canvas the chew ring paints on, above the flower. See _build_chew_layer.
var _chew_layer: Node2D = null
var _eating_texture: Texture2D = null
var _gape_texture: Texture2D = null
var _eating_late_texture: Texture2D = null
## Where the last bite threw the mouth, in the sprite's own space.
##
## Composed on EVERY bite and ABOVE the animation gate — `_bite` writes it before it
## returns headless — which is the whole reason it is a field instead of a local. The
## direction is the part of this animation that can be WRONG (a lunge that points away
## from the meal is a perfectly plausible picture, which is this project's documented
## 2D-placement failure mode), and it is unreachable behind `animations_enabled()`,
## false for every test in the suite by construction. Recording it splits "which way
## does the mouth go" from "does a Tween get to play it", and only the second needs a
## frame. `test_a_chomps_bite_records_a_lunge_toward_the_meal` asserts it off `_grab`,
## so deleting the composition from `_bite` goes red rather than silently aiming the
## flower at the origin.
##
## This is the ONLY source the tween below reads, so the field and the picture cannot
## disagree.
var _bite_lunge: Vector2 = Vector2.ZERO

## Seconds since the mouth closed on the current meal. The single clock every part of the
## catch is derived from — see the CATCH block above. Reset by `_grab` and by `release`,
## advanced by `_chew`, and it keeps running past the end of the haul because the vines
## writhe for the whole meal.
var _capture_elapsed: float = 0.0

## The vector the current meal's BODY has to travel to reach the mouth, in the pest's own
## space, recorded once when the mouth closes.
##
## Recorded rather than recomputed per frame because the pest's node does not move while
## it is held, so the answer cannot change — and because recomputing it from the pest's
## drawn position would make the haul chase its own tail.
var _carry_travel: Vector2 = Vector2.ZERO

## The canvas the vines paint on. Added BEFORE the chew ring's layer so the countdown
## reads over the top of them: the vines are flavour and the ring is a number.
var _vine_layer: Node2D = null


## This flower's ladder. The one override the generic upgrade surface needs — see
## `Plant.upgrade_ladder`.
func upgrade_ladder() -> Array[Dictionary]:
	return LEVELS


## Pure: how far a flower at `for_level` can close its mouth, in pixels. Derived from
## GRAB_RADIUS so level 1 IS GRAB_RADIUS rather than a number that happens to match it.
static func grab_radius_for(for_level: int) -> float:
	return GRAB_RADIUS * float(ladder_row(LEVELS, for_level).get("reach_scale", 1.0))


## Pure: how long a flower at `for_level` takes over a meal whose own chew is
## `base_seconds` (`Pest.chew_seconds`, mutations already applied).
##
## Takes the pest's number as an argument rather than reading a Pest, for the reason
## `Plant.seconds_to_be_eaten` takes a dps: it keeps this file ignorant of the pest
## table, and it makes the test that pins the queen's 11 seconds name the 11.
static func chew_seconds_for(for_level: int, base_seconds: float) -> float:
	return base_seconds * float(ladder_row(LEVELS, for_level).get("chew_scale", 1.0))


## How much faster the next rung eats, as a proportion (plant-tower-defense-jvnm).
##
## A PROPORTION AND NOT A NUMBER OF SECONDS, and that is forced rather than chosen: how
## long a chew takes belongs to the PEST — `Pest.chew_seconds` runs from 0.45 for the
## smallest to 2.6 for the queen — so a flower on its own has no absolute to name. What it
## can say is by how much it shortens whatever meal arrives, which is exactly what
## `chew_scale` is. Naming a number of seconds here would mean picking a pest and calling
## it typical.
##
## `reach_scale` climbs on the same rung and is deliberately NOT in this phrase. The
## button holds one line beside a price; two gains make it a sentence, and the reach is
## already drawn on the board as the flower's own ring, which is the better channel for it.
func upgrade_gain() -> String:
	if is_max_level():
		return ""
	var now: float = float(ladder_row(LEVELS, level).get("chew_scale", 1.0))
	var next: float = float(ladder_row(LEVELS, level + 1).get("chew_scale", 1.0))
	if now <= 0.0:
		return ""
	# NO VERB, for the reason the Bramble's gain carries: "eats 20%% faster" measured
	# 238px in a 232px box and the width test refused it. Every phrase on this button is
	# now as short as its unit allows, which is what a 232px node buys.
	return "%d%% faster" % int(round((1.0 - next / now) * 100.0))


## This flower's reach right now — what `_act` and `_nearest_free_pest` both close on,
## so an upgrade cannot widen one without widening the other.
func grab_radius() -> float:
	return grab_radius_for(level)


## Pure: where the crown's teeth sit, in the plant's own space, for a level — one per
## tooth, left to right, empty at level 1.
##
## Pure and public for the reason `CornCobbler.muzzle_pips` is: what gets drawn is then
## checkable without rendering a frame, and the "bare mouth versus a crown of teeth"
## difference a player reads at a glance is one function rather than a condition at the
## draw site.
static func fang_points(for_level: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for offset: float in fang_offsets(for_level):
		out.append(Vector2.UP.rotated(offset) * FANG_RADIUS)
	return out


## Pure: the angles, in radians off straight up and in left-to-right order, that a crown
## at `for_level` puts its teeth on. `level - 1` pairs, each pair one FANG_STEP_DEGREES
## outside the pair below, so every level's set contains every lower level's set.
static func fang_offsets(for_level: int) -> PackedFloat32Array:
	var pairs: int = maxi(0, for_level - 1)
	var out := PackedFloat32Array()
	for k: int in range(pairs, 0, -1):
		out.append(deg_to_rad(-FANG_STEP_DEGREES * (float(k) - 0.5)))
	for k: int in range(1, pairs + 1):
		out.append(deg_to_rad(FANG_STEP_DEGREES * (float(k) - 0.5)))
	return out


## A hungry pest that eats the flower out from under a meal must not leave the
## mouth stuck "busy" pointing at a freed pest.
func _on_setup() -> void:
	destroyed.connect(func(_p: Plant) -> void: release())
	# Vines first, so the chew ring's canvas is added after them and paints on top.
	_build_vine_layer()
	_build_chew_layer()


## The chew ring's own canvas, added AFTER the sway pivot so it paints OVER the
## flower instead of under it.
##
## MEASURED, which is the whole reason this exists (plant-tower-defense-gfpj asked for
## exactly this evidence). A Node2D paints its own `_draw()` before its children, and
## `_sprite` is a child -- so the ring at CHEW_RING_RADIUS 22 was drawn beneath a
## flower whose petals reach r=24 and whose two leaves reach r=31. Sampling the
## rendered pixels at r=22 across six angles INSIDE the swept arc found the ring at
## exactly one of them:
##
##     30deg #bd9400 petal   45deg #198c4a leaf    55deg #29c56b leaf
##     65deg #bd9400 petal   75deg #bd9400 petal   90deg #ef8429 RING
##
## So the countdown a player is supposed to read was mostly invisible, and broke up as
## it swept past each petal. The fang crown escapes only because it sits at r=25.3-30.7,
## outside the petals -- which is also why moving the ring out is not available: the
## fangs own that band and 32 is the half-cell.
##
## A `draw` signal on a bare Node2D rather than a new script: the layer has no state
## and no behaviour, and a second class for eight lines of arc would be the heavier
## answer. `Plant` frees it with the rest of the subtree.
func _build_chew_layer() -> void:
	if _chew_layer != null and is_instance_valid(_chew_layer):
		return
	_chew_layer = Node2D.new()
	_chew_layer.name = "ChewRing"
	add_child(_chew_layer)
	_chew_layer.draw.connect(_draw_chew_ring)


## Painted on the layer, not on the plant. Same arc, same radius, same colour as
## before -- only the canvas it lands on changed.
## The layer is a sibling canvas, so the plant's own queue_redraw() does not reach
## it. Paired at every call site rather than folded into one, because a Chomp that
## repaints its crown and not its ring is the bug this whole change is about.
func _redraw_chew_layer() -> void:
	if _chew_layer != null and is_instance_valid(_chew_layer):
		_chew_layer.queue_redraw()


func _draw_chew_ring() -> void:
	if _held == null or _chew_layer == null or not is_instance_valid(_chew_layer):
		return
	_chew_layer.draw_arc(Vector2.ZERO, CHEW_RING_RADIUS, 0.0,
		chew_arc_end(chew_progress()), 24, CHEW_RING_COLOR, CHEW_RING_WIDTH, true)


## Emitted when this Chomp is sitting still and the reason is flight — see
## `idle_only_because_of_flight`. Rising edge only: the condition is true for every
## frame a winged pest spends crossing the reach, and a per-frame signal would put the
## same sentence on the message row sixty times a second.
##
## Carries nothing. `Game` has the plant in hand from the connection, which is the same
## split `destroyed(plant)` and `grew_seeds` already use here.
signal flight_ignored

## True while `flight_ignored` has already fired for the current stretch of being
## walked past. Cleared when the condition goes false, so the next winged pest to
## arrive is a fresh edge — which is also the retry path when the message row was too
## busy to show the hint the first time.
var _flight_noted: bool = false


func _act(delta: float, pests: Array[Pest]) -> void:
	if _held != null:
		_chew(delta)
		return
	var prey: Pest = _nearest_free_pest(pests)
	if prey != null:
		_grab(prey)
		_flight_noted = false
		return
	# After the grab attempt, not before: a mouth that just closed on something is not
	# idle, whatever else is in reach.
	var winged: int = 0
	var grabbable: int = 0
	for pest: Pest in pests:
		if pest.held_by != null:
			continue
		if pest.global_position.distance_to(global_position) > grab_radius():
			continue
		if pest.is_winged:
			winged += 1
		else:
			# Counted WITHOUT the lead check above. This number feeds
			# `idle_only_because_of_flight`, whose whole sentence is "everything in
			# reach flies" — and a walker that has not gone past yet does not make that
			# sentence true, it just makes it early. Folding the lead in here would put
			# the flight hint on screen for the fraction of a second before every
			# ordinary catch, which is the one thing that signal's rising edge exists
			# to avoid.
			grabbable += 1
	if not idle_only_because_of_flight(winged, grabbable):
		_flight_noted = false
		return
	if _flight_noted:
		return
	_flight_noted = true
	flight_ignored.emit()


## The state the flight hint explains, as a pure function of what is within reach.
##
## Both halves matter and only together. A winged pest in reach is not confusing if a
## grabbable one is there too — the mouth closes on that one, the player sees the plant
## working, and nothing needs saying. It is confusing when EVERYTHING in reach flies,
## because then a bug walks over a mouth that does not move.
##
## Static and pure so the condition has a name a test can assert directly, rather than
## being an `and` buried in `_act` that can only be reached by staging two pests in a
## live tree. `Hud.uproot_shows_tip` is the same move for the same reason.
static func idle_only_because_of_flight(winged_in_reach: int, grabbable_in_reach: int) -> bool:
	return winged_in_reach > 0 and grabbable_in_reach == 0


## Pure: how far past this flower the pest has walked, in pixels along its OWN
## direction of travel. Negative while it is still coming, 0 as it goes by the stem,
## positive once it is leaving.
##
## A projection and not a coordinate comparison, which is the whole reason it is a
## function: the road turns four times, so "past" is a different axis and a different
## sign in each leg of it. `PATH_CORNERS` walks +X, then +Y, then -X, then +Y, then +X,
## then -Y, then +X — a rule written as `pest.x > plant.x` would be correct on the three
## legs that run +X, backwards on the one that runs -X, and simply meaningless on the
## three vertical ones.
##
## Static and pure so the sign is assertable for all four headings with no board, no
## pest and no frame — see `test_a_chomp_waits_for_a_pest_to_pass_from_every_direction`.
static func pass_distance(plant_at: Vector2, pest_at: Vector2, heading: Vector2) -> float:
	if heading.length_squared() <= 0.0001:
		return 0.0
	return (pest_at - plant_at).dot(heading.normalized())


## Pure: is this pest far enough past the flower for the mouth to close?
##
## A pest with NO heading is grabbable, and that default is deliberate rather than
## incidental. `travel_direction()` cannot currently answer zero — `_facing` is set at
## spawn — but if it ever did, the two available failures are "eats slightly early" and
## "never eats again, silently". This class has already paid for the second one once
## (see `GRAB_RADIUS`), so the degenerate case falls back to the behaviour that shipped.
static func is_past_enough(plant_at: Vector2, pest_at: Vector2, heading: Vector2,
		lead: float) -> bool:
	if heading.length_squared() <= 0.0001:
		return true
	return pass_distance(plant_at, pest_at, heading) >= lead


## Pure: the widest a pest can be caught in, along the road, for a flower at `for_level`.
##
## Half the chord the reach cuts across a lane one `Board.CELL` away, minus the lead the
## bug has to spend getting past first. This is the number that goes to zero when the
## lead is set too long, and `0.0` here means a flower that never eats.
static func pass_window_for(for_level: int) -> float:
	var reach: float = grab_radius_for(for_level)
	var across: float = reach * reach - Board.CELL * Board.CELL
	if across <= 0.0:
		return 0.0
	return maxf(0.0, sqrt(across) - GRAB_LEAD)


func _nearest_free_pest(pests: Array[Pest]) -> Pest:
	var best: Pest = null
	var best_distance: float = grab_radius()
	for pest: Pest in pests:
		# Winged (doc: "ignores ground plants") flies over a Chomp's reach — the
		# mouth simply cannot close on it. It still walks into Corn's kernels.
		if pest.held_by != null or pest.is_winged:
			continue
		# The ambush. Checked BEFORE the distance so a bug still approaching is not
		# merely out-ranked by a nearer one — it is not prey yet at all, and a Chomp
		# with one bug in front of it and nothing else must stay idle rather than
		# closing early on the only thing it can see.
		if not is_past_enough(global_position, pest.global_position,
				pest.travel_direction(), GRAB_LEAD):
			continue
		var d: float = pest.global_position.distance_to(global_position)
		if d <= best_distance:
			best_distance = d
			best = pest
	return best


## How long THIS flower takes over a meal whose own chew is `base_seconds` — the rung's
## scale and the sport's, together.
##
## An instance method beside the static above, and the split is the same one
## `CornCobbler.fire_interval` makes against its own LEVELS table: the static answers
## "what does a flower at rung N do", which a readout reasoning about an upgrade needs,
## and this answers "what will THIS flower do", which is what the mouth acts on. Before
## the sports they were the same number and the static was enough.
##
## Applied where the meal is SIZED rather than where it is counted down: a Snap Flower
## that started an eleven-second queen and then had its scale read would otherwise finish
## the mouthful the ordinary flower's clock began.
func chew_seconds_against(base_seconds: float) -> float:
	return chew_seconds_for(level, base_seconds) * sport_rate_scale()


func _grab(pest: Pest) -> void:
	_held = pest
	pest.held_by = self
	_chew_total = chew_seconds_against(pest.chew_seconds)
	_chew_left = _chew_total
	# The catch, and note it is composed here rather than inside `_bite()` alongside the
	# lunge: the lunge is the flower's own head moving and belongs to the bite, while the
	# haul is a fact about THIS MEAL that outlives the 0.05s the bite lasts.
	#
	# Above every animation gate, the same rule `_bite_lunge` follows. The direction and
	# length of the journey are the part of this animation that can be WRONG, and the
	# whole of `_draw_vines` is unreachable headless.
	_capture_elapsed = 0.0
	_carry_travel = (global_position + CARRY_ANCHOR) - pest.global_position
	pest.set_carried(true)
	# Explicitly zero on the frame of the grab rather than left to the first `_chew`:
	# `carry_offset_at(travel, 0)` IS `Vector2.ZERO`, and writing it makes a flower that
	# grabs a pest a previous flower had half-hauled put the body back on the road first.
	pest.set_carry_offset(carry_offset_at(_carry_travel, 0.0))
	_bite()
	# ONLY if the gape did not take. `_bite()` wears the open jaw for
	# BITE_SQUASH_OUT_SECONDS and its own timer hands over to the eating sprite, so
	# calling _show_eating_sprite() unconditionally here overwrote the gape on the
	# very same frame and it never reached a screen. Every gate stayed green --
	# name_check, lint and 769 tests all pass either way, because no test can watch a
	# texture that is correct for 60ms. It was found by stepping a live bite frame by
	# frame (plant-tower-defense-81g9).
	#
	# The fallback still matters: with animations off `_bite()` returns before the
	# gape, and the mouth must still show that it is full.
	if _sprite == null or _gape_texture == null or _sprite.texture != _gape_texture:
		_show_eating_sprite()
	queue_redraw()
	_redraw_chew_layer()
	_redraw_vine_layer()


func _chew(delta: float) -> void:
	if not is_instance_valid(_held) or not _held.is_alive():
		release()
		return
	_chew_left -= delta
	# The catch, ABOVE the animation gate and before the bites, for the reason
	# `.claude/skills/assert-an-animation` gives at its first rung: the body's position is
	# a pure function of a clock this object already advances, so it is correct on every
	# frame including the ones a headless run never renders. There is no Tween anywhere in
	# the haul, which is what makes `release()` able to put the bug back by writing a zero.
	_capture_elapsed += delta
	_held.set_carry_offset(carry_offset_at(_carry_travel,
		haul_progress(_capture_elapsed, _chew_total)))
	# The bites. Recorded and applied ABOVE the animation gate, because the fraction
	# eaten is game state the suite reads and only its DRAWING is gated -- the rule
	# test_combat.gd:6331 states for every animation in this game.
	var taken: int = bites_taken_for(chew_progress())
	if taken > _bites_taken:
		_bites_taken = taken
		_held.set_chewed(float(taken) / float(BITES_PER_MEAL))
		# Once per bite, not once per meal. The single grab-time flash was the whole
		# of the pest's feedback before plant-tower-defense-h4v1.
		_held.flash_hit()
	if chew_progress() > LATE_BITE_THRESHOLD and _sprite != null and _sprite.texture != _eating_late_texture:
		_show_eating_late_sprite()
	queue_redraw()
	_redraw_chew_layer()
	_redraw_vine_layer()
	if _chew_left <= 0.0:
		var meal: Pest = _held
		# Killed BEFORE the release, which is a REVERSAL of the order this line had and is
		# load-bearing. `Pest.kill()` sets `_alive` false and then calls back into
		# `release()` through `held_by` itself, and `Pest.set_carried(false)` deliberately
		# refuses to let go of a dead pest's carry offset. In the old order the meal was
		# put back down on the road and killed one line later, so the corpse of a bug
		# eaten on top of a flower appeared a cell away on the path.
		#
		# Bitten, so the corpse is squashed rather than straight -- a Chomp closes
		# on the whole pest (plant-tower-defense-f5z6).
		meal.kill(Pest.DEATH_BITTEN)
		# The belt to kill()'s braces. A meal that somehow reached here without a
		# `held_by` pointing back at this flower would leave the mouth wedged shut.
		if _held != null:
			release()


## Drops whatever is in the mouth and frees the flower. Called by Pest.kill() too,
## so a pest shot out of the mouth by a stray kernel does not wedge the plant shut.
func release() -> void:
	if _held != null and is_instance_valid(_held):
		_held.held_by = null
		# A pest released UNHARMED goes back to full size. A Chomp destroyed mid-chew
		# lets its meal go (see this function's header), and a bug that walked away
		# permanently two-thirds eaten would be a Chomp that killed something without
		# the kill ever being scored.
		if _held.is_alive():
			_held.set_chewed(0.0)
		# Back on the road, and instantly rather than over an eased return. The offset is
		# the only thing standing between where the pest is DRAWN and where every other
		# system already thinks it is, so an animated climb-down would be a window in
		# which a kernel passes visibly through a bug it is entitled to hit. A pest
		# released dead keeps its offset — see `Pest.set_carried`.
		_held.set_carried(false)
	_held = null
	_chew_left = 0.0
	_bites_taken = 0
	_chew_total = 0.0
	_capture_elapsed = 0.0
	_carry_travel = Vector2.ZERO
	_show_idle_sprite()
	queue_redraw()
	_redraw_chew_layer()
	_redraw_vine_layer()


func is_busy() -> bool:
	return _held != null


func held_pest() -> Pest:
	return _held


## 0.0 when the mouth just closed, 1.0 when the meal is about to finish.
func chew_progress() -> float:
	if _chew_total <= 0.0:
		return 0.0
	return clampf(1.0 - _chew_left / _chew_total, 0.0, 1.0)


## The champ, and the answer to an asymmetry this plant shipped with: the pest in the
## mouth shows the meal — `_chew` calls `set_chewed` on it and `Pest._gait` multiplies
## that into its sprite scale every frame — while the flower doing the eating swayed
## exactly like an idle one. The only tell a chewing Chomp had was the drawn chew ring,
## a timer readout, and one channel is not enough in this game.
##
## `Plant.idle_scale_multiplier`'s hook rather than a Tween, for the reason
## `.claude/skills/assert-an-animation/SKILL.md` gives at its first rung: the value is a
## function of a clock this object already owns, so deriving it leaves the plant in a
## correct state on every frame including the ones headless never renders. A Tween here
## would also be overwritten within one frame, since `_wobble` rewrites the whole pivot
## transform every frame — the same trap `Pest._gait`'s own header records for
## `chewed_scale`.
##
## Vertical squash, not horizontal: a mouth closes along the body's long axis, which
## STYLE.md puts up-screen. `1 + s` on X and `1 - s` on Y is a head flattening and
## widening, which is a bite; the other sign is a yawn.
##
## Faster and deeper than the breathe on purpose. BREATHE_RATE is 2.0 and BREATHE_AMOUNT
## is 0.022, and a champ that does not clearly out-read the idle motion reads as nothing —
## the same rule `Plant.FLINCH_RADIANS` and `Pest.FLINCH_RADIANS` are both pinned by, and
## the same mutation that survived cycle 71 when every assertion was written as a multiple
## of the amplitude rather than against an absolute.
const CHAMP_AMOUNT: float = 0.075
const CHAMP_RATE: float = 9.0


## Pure: the champ's scale at a point on the clock, or the identity when the mouth is
## empty. Split out for the reason `Plant.breathe_scale` and `Pest.gait_yaw` are —
## everything in `_wobble` past the `animations_enabled()` gate is unreachable headless,
## so a test that pumps the plant and reads its pivot is asserting an early return.
static func champ_scale(clock: float, chewing: bool) -> Vector2:
	if not chewing:
		return Vector2.ONE
	var s: float = sin(clock * CHAMP_RATE) * CHAMP_AMOUNT
	return Vector2(1.0 + s, 1.0 - s)


## Chews visibly, or does not move at all. `is_busy()` and not `chew_progress()`: the
## progress is 0.0 on the frame the mouth closes AND on every frame with no pest in it,
## so a champ keyed to progress would be invisible at exactly the moment the bite lands.
func idle_scale_multiplier(clock: float) -> Vector2:
	return champ_scale(clock, is_busy())


## How far round the chew ring is drawn: a full circle when the mouth has just
## closed, sweeping down to nothing as the meal finishes.
##
## Pure, so the shape is assertable without a rendered frame — and so the draw site
## below carries no branch of its own. At the end the two ends coincide and
## `draw_arc` draws nothing, which is the same reason `CornCobbler._draw_muzzle_fan`
## lost its `if`: one place decides, and a test can reach it.
static func chew_arc_end(progress: float) -> float:
	return TAU * clampf(1.0 - progress, 0.0, 1.0)


## The ring around the flower while the mouth is full — the whole Chomp/beetle
## trade-off ("mouth busy, lane open") made visible. Fixed radius, swept angle; see
## CHEW_RING_RADIUS for why round that way.
func reach_ring_radius() -> float:
	return GRAB_RADIUS


func reach_ring_color() -> Color:
	return RING_COLOR


func _draw() -> void:
	# The shared reach ring first, so everything this plant draws sits on top of it.
	# `Plant.draw_reach_ring` gates itself on selection; this is an unconditional call
	# by design, because the alternative is a seventh copy of that condition.
	#
	# This override exists at all — rather than inheriting Plant._draw() the way Mint,
	# Nettle and Aloe now do — because the crown and the fangs are this plant's own.
	# SelectionMarker's header is the reason it is a CALL and not something Plant._draw
	# does and hopes for: this class does not chain to super, and never has.
	draw_reach_ring()
	# Always, and before the ring: the crown is what this flower's LEVEL looks like and
	# the ring is what its current MEAL looks like. A cue the player has to catch the
	# plant mid-chew to see cannot be the readout for something they bought.
	_draw_fang_crown()
	# The chew ring is NOT here any more -- it is on _chew_layer, above the sprite.
	# See _build_chew_layer for the pixel measurements that moved it.


## Level 1 draws nothing here and that is decided in `fang_offsets`, not by an `if`
## at this site — the same split `_draw_muzzle_fan` made after cycle 70 watched a
## mutation to the rule survive a test that only asked the other function.
func _draw_fang_crown() -> void:
	for tooth: Vector2 in fang_points(level):
		draw_circle(tooth, FANG_SIZE + FANG_RIM_WIDTH, FANG_RIM_COLOR)
		draw_circle(tooth, FANG_SIZE, FANG_COLOR)


## Which way this bite throws the head, and how far — pure, so the direction is
## assertable with no board, no frame and no open animation gate.
##
## Returns a vector FROM the flower TOWARD the meal, `LUNGE_DISTANCE` long: the sign
## and the axis are the entire content of the animation, and a squash tween cannot
## carry either. Degenerate input (a pest exactly on top of the flower, which
## `_nearest_free_pest` genuinely permits at distance 0) returns `Vector2.ZERO` rather
## than a normalised NaN — a lunge nowhere is the correct picture for a meal that is
## already here.
static func lunge_offset(from: Vector2, to: Vector2) -> Vector2:
	var delta: Vector2 = to - from
	if delta.length_squared() <= 0.0001:
		return Vector2.ZERO
	return delta.normalized() * LUNGE_DISTANCE


## Pure: how long THIS meal's catch lasts, given the meal's whole chew.
##
## The cap is the point — see CAPTURE_CHEW_FRACTION. `maxf(0.0, ...)` rather than trusting
## the caller: `_chew_total` is 0.0 for a flower with an empty mouth, and every progress
## function below divides by a span derived from this.
static func capture_seconds_for(chew_total: float) -> float:
	return minf(CAPTURE_SECONDS, maxf(0.0, chew_total) * CAPTURE_CHEW_FRACTION)


## Pure: how much of that catch is the vines reaching out, the rest being the haul.
## The two beats keep their full-length RATIO whatever the cap does to their sum, so a
## snatched aphid and a hauled queen are the same gesture at different speeds rather than
## two different gestures.
static func lash_seconds_for(chew_total: float) -> float:
	return capture_seconds_for(chew_total) * (LASH_SECONDS / CAPTURE_SECONDS)


## Pure: 0.0 as the vines leave the flower, 1.0 when they have reached the bug.
##
## Answers 1.0 for a zero-length catch rather than dividing by it. That is the correct
## answer and not a guard: a catch with no time in it is one that has already finished,
## and the alternative (0.0) would leave the vines permanently retracted on exactly the
## meals too short to show them.
static func lash_progress(elapsed: float, chew_total: float) -> float:
	var span: float = lash_seconds_for(chew_total)
	if span <= 0.0:
		return 1.0
	return clampf(elapsed / span, 0.0, 1.0)


## Pure: 0.0 while the vines are still reaching, then 0.0 -> 1.0 as the bug is dragged in,
## then 1.0 for the whole of the chew.
static func haul_progress(elapsed: float, chew_total: float) -> float:
	var lash: float = lash_seconds_for(chew_total)
	var span: float = capture_seconds_for(chew_total) - lash
	if span <= 0.0:
		return 1.0
	return clampf((elapsed - lash) / span, 0.0, 1.0)


## Smoothstep, clamped. Named rather than inlined at its four call sites so a test can pin
## the endpoints once: `smooth(0) == 0` and `smooth(1) == 1` are what make every geometry
## function below land EXACTLY on its endpoints instead of near them.
static func smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Pure: where the meal's body is, relative to where its node stands, at a point in the
## haul. This is the value `Pest.set_carry_offset` receives.
##
## `travel` is the whole journey, road to mouth. At 0 the answer is exactly `Vector2.ZERO`
## — the bug is still on the road, which is where every other system thinks it is — and at
## 1 it is exactly `travel`, because `smooth(1)` is 1 and `sin(PI)` is 0. Both endpoints
## being exact is what lets `release` restore the road position by writing a zero rather
## than by remembering one.
##
## The lift is a half-sine over the whole haul, so it is zero at both ends and highest in
## the middle: the bug goes UP off the road, over, and down into the mouth.
static func carry_offset_at(travel: Vector2, haul_t: float) -> Vector2:
	var t: float = clampf(haul_t, 0.0, 1.0)
	return travel * smooth(t) + Vector2(0.0, -sin(t * PI) * HAUL_ARC_HEIGHT)


## Pure: where vine `index` leaves the flower, in the flower's own space. A fan across the
## head rather than three vines from one point, which would read as one thick vine.
static func vine_root(index: int) -> Vector2:
	if VINE_COUNT <= 1:
		return Vector2.ZERO
	var across: float = float(index) / float(VINE_COUNT - 1) - 0.5
	return Vector2(across * 2.0 * VINE_ROOT_SPREAD, 0.0)


## Pure: where vine `index` takes hold of the meal, relative to the meal's centre. A ring,
## so the three grips clasp the bug from three sides instead of all landing on its middle.
static func grip_offset(index: int) -> Vector2:
	var angle: float = TAU * float(index) / float(VINE_COUNT) + PI * 0.5
	return Vector2(cos(angle), sin(angle)) * GRIP_RADIUS


## Pure: where vine `index`'s tip is, in the flower's own space.
##
## `prey_local` is where the BODY is being drawn right now — the pest's node position plus
## whatever `carry_offset_at` has done to it — so this one expression covers all three
## beats: during the lash it scales out from the flower toward a stationary bug, and from
## the end of the lash onward (`smooth(1) == 1`) it simply IS the bug's grip point, which
## the haul is meanwhile dragging home. The vines cannot drift off the meal because they
## are not independently animated.
static func vine_tip(index: int, prey_local: Vector2, lash_t: float) -> Vector2:
	return (prey_local + grip_offset(index)) * smooth(lash_t)


## Pure: how much bow is left in a vine at this point in the haul. Full while reaching,
## VINE_TAUT_SLACK once the load is on. See VINE_TAUT_SLACK.
static func vine_slack(haul_t: float) -> float:
	return lerpf(1.0, VINE_TAUT_SLACK, smooth(haul_t))


## Pure: the sideways displacement of vine `index`'s midpoint, sign included.
##
## Alternating sign is what separates the three; the writhe is what keeps them alive
## through a long meal. Pinned against VINE_BOW rather than expressed only as a multiple
## of the writhe, so zeroing VINE_WRITHE_AMOUNT does not leave every claim about this
## function trivially true (`assert-an-animation`'s second failure mode).
static func vine_bow(index: int, clock: float, slack: float) -> float:
	var side: float = 1.0 if index % 2 == 0 else -1.0
	var writhe: float = 1.0 + sin(clock * VINE_WRITHE_RATE + float(index) * 1.7) * VINE_WRITHE_AMOUNT
	return side * VINE_BOW * writhe * clampf(slack, 0.0, 1.0)


## Pure: one vine, as a polyline. A quadratic Bezier with its control point pushed
## `bow` px off the perpendicular bisector of `from` -> `to`.
##
## The first and last points are EXACTLY `from` and `to` — a Bezier's endpoints are its
## endpoints — which is the property worth having: a vine that stops short of the bug or
## starts short of the plant is the failure this shape rules out by construction rather
## than by tuning.
##
## A degenerate span (bug on top of the flower, which `_nearest_free_pest` permits at
## distance 0) leaves the control point at the midpoint and draws a dot, rather than
## normalising a zero vector into NaN — the same guard, for the same reason, as
## `lunge_offset`.
static func vine_curve(from: Vector2, to: Vector2, bow: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = maxi(2, segments)
	var span: Vector2 = to - from
	var normal := Vector2(-span.y, span.x)
	if normal.length_squared() > 0.0001:
		normal = normal.normalized()
	else:
		normal = Vector2.ZERO
	var control: Vector2 = (from + to) * 0.5 + normal * bow
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	return points


## The vines' own canvas, above the flower and below the chew ring. Same reasoning as
## `_build_chew_layer`, which measured the problem: a Node2D paints itself before its
## children, so anything drawn in this class's own `_draw()` lands UNDER `_sprite`. A vine
## drawn there would be a vine behind the plant.
func _build_vine_layer() -> void:
	if _vine_layer != null and is_instance_valid(_vine_layer):
		return
	_vine_layer = Node2D.new()
	_vine_layer.name = "Vines"
	add_child(_vine_layer)
	_vine_layer.draw.connect(_draw_vines)


## Paired with every `_redraw_chew_layer()` call rather than folded into it: they are two
## canvases and a Chomp that repaints one and not the other is exactly the bug
## `_redraw_chew_layer`'s own header was written about.
func _redraw_vine_layer() -> void:
	if _vine_layer != null and is_instance_valid(_vine_layer):
		_vine_layer.queue_redraw()


## The vines, drawn frame by frame from `_capture_elapsed`. Every number in here comes
## from a pure static above; this function decides nothing.
func _draw_vines() -> void:
	if _held == null or not is_instance_valid(_held) or not _held.is_alive():
		return
	if _vine_layer == null or not is_instance_valid(_vine_layer):
		return
	# Where the body is being DRAWN, not where the node stands — the carry offset is the
	# difference and it is the whole animation. See `Pest._carry_offset`.
	var prey: Vector2 = _vine_layer.to_local(_held.global_position + _held.carry_offset())
	var lash_t: float = lash_progress(_capture_elapsed, _chew_total)
	var slack: float = vine_slack(haul_progress(_capture_elapsed, _chew_total))
	for index in range(VINE_COUNT):
		var tip: Vector2 = vine_tip(index, prey, lash_t)
		var curve: PackedVector2Array = vine_curve(vine_root(index), tip,
			vine_bow(index, _capture_elapsed, slack), VINE_SEGMENTS)
		# Rim first, then the core down the middle of it — the fang crown's two-pass
		# shape. See VINE_RIM_COLOR for the two surfaces this has to survive.
		_vine_layer.draw_polyline(curve, VINE_RIM_COLOR, VINE_RIM_WIDTH, true)
		_vine_layer.draw_polyline(curve, VINE_CORE_COLOR, VINE_CORE_WIDTH, true)
		_vine_layer.draw_circle(tip, VINE_TIP_RADIUS + 1.0, VINE_RIM_COLOR)
		_vine_layer.draw_circle(tip, VINE_TIP_RADIUS, VINE_TIP_COLOR)


func _bite() -> void:
	# Ahead of the tree-guard below: the mouth closing is the game event, and
	# it happens whether or not there is a tree to play the squash tween in —
	# Sfx.play() gates its own headless silence, so there is nothing here for
	# a unit test calling _grab() directly to trip over.
	Sfx.play(Sfx.CHOMP_BITE)
	# The catch itself, not a kill — the meal doesn't die until _chew_left runs
	# out, so unlike Kernel's post-damage guard this is never racing a death
	# this same frame. Same is_alive() guard anyway, kept for the pattern.
	if is_instance_valid(_held) and _held.is_alive():
		_held.flash_hit()
	# Also ahead of the guard, and for a different reason than the two above: this is
	# not a game event, it is the one part of the ANIMATION that has a right and a
	# wrong answer. See `_bite_lunge`.
	_bite_lunge = Vector2.ZERO
	if is_instance_valid(_held):
		_bite_lunge = lunge_offset(global_position, _held.global_position)
	# `animations_enabled()` joins this guard as of the lunge, which it should have
	# been on all along: `_on_upgraded` below claims to be gated "exactly as every
	# cosmetic Tween in this class and in `Plant` is" and this one was the exception
	# that made the sentence false. Everything a headless run needs from a bite — the
	# sound, the flash, the hold, and now the lunge VECTOR — is already settled above.
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	# Position and scale in parallel, then both back: the squash is what a bite feels
	# like and the lunge is who it is aimed at, and playing them in sequence would read
	# as two separate twitches. `_sprite.position` is otherwise unwritten on a plant —
	# idle sway and flinch live on `_sway_pivot` and every event tween owns
	# `_sprite.scale` (see `Plant._sway_pivot`), so this adds a third channel rather
	# than joining the queue for the second.
	#
	# The offset is applied in the sway pivot's frame, so a lunge is rotated by whatever
	# the idle sway is doing at that instant — at most FLINCH_RADIANS (0.16 rad, 9°),
	# which leans the lunge without ever pointing it at the wrong neighbour. Deliberate:
	# the body leaning at its meal is the picture, and un-rotating it would decouple the
	# head from the stem it is attached to.
	# The open jaw, on the same frame the lunge starts (plant-tower-defense-81g9).
	# Inside the animations gate with the rest of the bite: a texture swap the player
	# has turned animation off for is a flicker, not information.
	_show_gape_sprite()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "position", _bite_lunge, BITE_LUNGE_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2(1.18, 0.82), BITE_SQUASH_OUT_SECONDS)
	tween.chain().tween_property(_sprite, "position", Vector2.ZERO, BITE_LUNGE_BACK_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, BITE_SQUASH_BACK_SECONDS)


## The teeth coming in: a snap wider than `_bite`'s and held longer, the same
## relationship `CornCobbler._upgrade_flourish` has to its own `_recoil` — one payment
## for a whole level against one of hundreds of bites.
##
## Note what this deliberately does NOT do: re-time the meal already in the mouth.
## `_chew_total` was set when the mouth closed, at the level it closed at, and a bug
## already half-swallowed finishing early because the player bought something is a
## refund the ladder is not offering. The next meal is where the upgrade lands.
##
## Gated exactly as every cosmetic Tween in this class and in `Plant` is: headless
## pumps no frames, so a Tween queued here would never run. The level, the reach, the
## chew scale and the crown are all already correct without it.
func _on_upgraded() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.30, 0.74), FLOURISH_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, FLOURISH_BACK_SECONDS)


## The gape, and the timer that takes it off again.
##
## BITE_SQUASH_OUT_SECONDS and not one of the other three bite constants: it is the
## LONGER of the two outward channels (0.06 against the lunge's 0.05) and the one the
## tween's chain() waits on, so it is literally the window the mouth is travelling
## open for. Ending the gape earlier would close the jaw while the head is still
## moving out; later would hold it open into the recovery.
##
## Guarded on still holding the SAME meal: a 0.06s timer outlives a release, and a
## flower that let go mid-bite must not have a gaping mouth painted back onto it.
func _show_gape_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _gape_texture == null:
		_gape_texture = load(frame_texture_path(GAPE_TEXTURE_PATH)) as Texture2D
	if _gape_texture == null:
		return
	_sprite.texture = _gape_texture
	var meal: Pest = _held
	var timer: SceneTreeTimer = get_tree().create_timer(BITE_SQUASH_OUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or _sprite == null:
			return
		if _held == null or _held != meal:
			return
		_show_eating_sprite())


func _show_eating_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _eating_texture == null:
		_eating_texture = load(frame_texture_path(EATING_TEXTURE_PATH)) as Texture2D
	if _eating_texture != null:
		_sprite.texture = _eating_texture


func _show_eating_late_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _eating_late_texture == null:
		_eating_late_texture = load(frame_texture_path(EATING_LATE_TEXTURE_PATH)) as Texture2D
	if _eating_late_texture != null:
		_sprite.texture = _eating_late_texture


func _show_idle_sprite() -> void:
	if _sprite != null and _idle_texture != null:
		_sprite.texture = _idle_texture
