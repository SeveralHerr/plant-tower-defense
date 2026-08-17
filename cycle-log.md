# Cycle 35

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 35 taught

**The game gained a rule.** Weather rounds: rain every 5th wave heals every bed 35%,
drought every 7th doubles how long each plant waits between shots. It is the first thing
in this game that changes how a wave *plays* rather than what is in it, and it came out of
the step-6 rule added last cycle — the first item that rule produced.

Two things about it worth keeping. The weather is **derived from the wave number** rather
than typed into `WAVES`, so it can be asserted against every wave out to 300 including the
endless ones no table row reaches. And `Plant.fire_interval_scale` is an **instance**
variable rather than a static, because a static would leak across the shared test process
and surface later as an unrelated plant "not shooting" in a test that never mentions
weather — the exact shape this project already paid for once with `RunConfig`.

**What runtime caught was not what runtime was for.** The prediction was that the banner —
words arriving on a screen — was the unassertable part. It was fine. The find was that the
selection panel prints `1.0 dmg / 0.80s` straight from the level table, so under a drought
it tells the player 0.80s while the cob fires every 1.60s. The rule reached the plants and
not the surface that describes the plants. Filed rather than fixed.

**And the honest note:** most of this cycle was cheaper headless, and the ledger row says
so. The derivation, the multiplier and the heal are pure enough to assert without a game.
The runtime half earned its place on exactly two things.

## Where things stand

Fourteen beads ready, none blocked. Suite 542/542 with 12008 assertions; lint 0/0; mirror
identical; `findings` clean; the real save's md5 unchanged, and `--snapshot-userstate` has
now behaved twice running against one miss. Eight skills, backlog empty.

## Waiting on the user

Nothing is blocking. One question is now concrete enough to be worth your word rather than
a guess, and it is the interesting one about weather:

**Weather currently has no counter-play.** Rain and drought arrive and are simply true —
the player watches. The brief's own version had a counter ("unless a plant sits next to
water"), and it was dropped because the board has no water: `Board` is grass and dirt road
over exactly two materials. Adding a third is not cosmetic — `PATH_CORNERS`' own header
warns that three numbers in other files were measured against this route and nothing
recomputes them. So: **water tiles and a real counter, or a cheaper counter that needs no
terrain (a plant or upgrade that ignores drought), or leave weather as a difficulty
modifier?** `plant-tower-defense-oo7e` is filed and says the same thing; it will not get
built until you pick, because building the wrong one of those three is expensive.

The standing question from last cycle also still stands, and this cycle is the first
evidence in the other direction: one player-facing feature shipped, and the loop found it
by looking outside its own footprint.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. Bump the number at the top
of this file every time you refill.
