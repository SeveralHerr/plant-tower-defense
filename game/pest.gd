class_name Pest
extends Node2D

## A bug walking the road. Seven species: a small fast one (aphid), a big slow one
## (beetle), a plated one that shrugs off small hits (the Shield Bug), a Leafhopper
## and a Locust that ask two more questions damage never touches, and two bosses —
## the Aphid Queen the campaign builds toward, and the Nurse Beetle that walks up
## the middle of a wave putting back what the garden has chipped off it.
##
## Three of the seven are answered by damage and differ only in how much of it they
## need. The other four each break a rule the garden is built on, and a different
## rule each: the Shield Bug is answered by a different KIND of damage; the
## Nurse Beetle is answered by damage aimed somewhere other than the FRONT of the
## queue; the Leafhopper is answered by WHEN a hit lands rather than how much or
## what kind, since its speed itself is not constant (see `hop_speed_multiplier`);
## and the Locust is answered by WHO you kill first, since a lone one is the
## slowest ordinary bug on the board and it only picks up danger from the OTHER
## Locusts near it (see `_swarm_neighbor_count`). Every argument is written out on
## its own SPECIES entry.
##
## The interesting state here is `held_by`. A Chomp Flower that grabs a pest does
## not delete it — it holds it in place for `chew_seconds` while the pest stays on
## the board blocking nothing and taking no ground. That is what makes the Chomp a
## body blocker rather than a damage source, which is the whole plant/pest balance.

signal died(pest: Pest)
signal escaped(pest: Pest)

const APHID := &"aphid"
const BEETLE := &"beetle"
const SHIELDBUG := &"shieldbug"
const QUEEN := &"queen"
const NURSE := &"nurse"
const HOPPER := &"hopper"
const LOCUST := &"locust"

## species -> stats. `chew_seconds` is the design doc's "eats small pests easily,
## takes a while eating bigger pests" expressed as a number.
##
## Five optional groups sit alongside the stats every species carries, one per
## mechanic, and each belongs to exactly one species today:
##
##   * `split_species` / `split_count` — the Aphid Queen's. A species that names
##     them bursts into that many of that species WHERE IT DIED rather than simply
##     leaving the board.
##   * `shell_absorb` / `shell_hits` — the Shield Bug's plate.
##   * `heal_radius` / `heal_amount` / `heal_period` — the Nurse Beetle's aura.
##   * `hop_period` / `hop_crouch_fraction` — the Leafhopper's rhythm. See
##     `hop_speed_multiplier`.
##   * `swarm_radius` / `swarm_cap` / `swarm_step` — the Locust's crowd. See
##     `_swarm_neighbor_count` / `swarm_speed_multiplier`.
##
## `boss` is the sixth optional key and the only one that is not a mechanic: it
## is what `WaveDirector.wave_carries_boss` reads, so "which species are bosses"
## is a fact stated once, on the species, rather than a name written into a
## comparison in another file (which is what it was until the second boss landed).
##
## Every one of them is read through an accessor below — split_species() /
## split_count() / shell_absorb() / shell_hits() / heal_radius() / heal_amount() /
## heal_period() / hop_period() / hop_crouch_fraction() / hop_leap_multiplier() /
## swarm_radius() / swarm_cap() / swarm_step() / is_boss() — and never off the raw
## Dictionary, so an ordinary pest answers "&"" / 0 / 0.0 / false" instead of
## erroring on a missing key.
const SPECIES: Dictionary = {
	APHID: {
		"display": "Aphid",
		"texture": "res://assets/sprites/pest_aphid.png",
		"dead_texture": "res://assets/sprites/pest_aphid_dead.png",
		"health": 3.0,
		"speed": 78.0,
		"seeds": 3,
		"chew_seconds": 0.45,
		"scale": 0.72,
		"big": false,
	},
	BEETLE: {
		"display": "Beetle",
		"texture": "res://assets/sprites/pest_beetle.png",
		"dead_texture": "res://assets/sprites/pest_beetle_dead.png",
		"health": 16.0,
		"speed": 38.0,
		"seeds": 9,
		"chew_seconds": 2.6,
		"scale": 1.0,
		"big": true,
	},
	## The Shield Bug (plant-tower-defense-4du6). The one pest on the board that is
	## answered by a different KIND of damage rather than by more of it.
	##
	## ONE SENTENCE: its plate eats up to `shell_absorb` off every hit for its first
	## `shell_hits` hits, so a Corn Cobbler's stream of small kernels bounces off it
	## entirely while a Dandelion's bigger seed and a Chomp's mouth do not care —
	## which asks the player to change WHICH plant answers the lane, not where they
	## aim it.
	##
	## The numbers, and what each is for:
	##   * shell_absorb 1.5 — chosen against the two damage sources the game actually
	##     has, not picked. `CornCobbler.LEVELS` tops out at 1.4 damage per kernel
	##     (corn_cobbler.gd:51) and `Dandelion.SEED_DAMAGE` is 3.0 at the centre of a
	##     blast (dandelion.gd:105), so 1.5 is the only band where EVERY corn kernel
	##     at EVERY level is stopped dead and a centred seed still puts half its
	##     damage through. Both halves are asserted in test_combat rather than
	##     written down here, so a balance pass on either plant fails loudly instead
	##     of quietly turning this species into a beetle.
	##   * shell_hits 6 — the shell counts HITS, not damage, and that is the whole
	##     mechanic. If it counted damage it would cost every weapon exactly the same
	##     6 x 1.5 and the small-versus-big axis would not exist; counting hits makes
	##     a level-1 cob waste six entire shots (4.8 s of firing) while six Dandelion
	##     seeds still land 9 damage on the way through. Six is also what stops the
	##     species being unkillable by the free starter plant: the plate always comes
	##     off, so the worst a stream of 1.0 kernels can do is arrive late.
	##   * health 10 — between an aphid's 3 and a beetle's 16. Once the plate is off
	##     it is an ordinary bug; the difficulty is meant to be the plate, not a
	##     second health pool wearing its name.
	##   * speed 54 — between the aphid's 78 and the beetle's 38, and deliberately NOT
	##     slow. "Slow and tough" is already the beetle, and a second slow tough pest
	##     is a beetle with a new number. A brisk walk is what stops the player simply
	##     out-firing the plate with the cobs they already own.
	##   * seeds 6 — between the aphid's 3 and the beetle's 9. Also chosen against
	##     `CompostMeter.husk_value_for`: 6 seeds drops husks worth {3, 5, 6, 9}
	##     across the four composable mutation multipliers, of which only 6 is new to
	##     the reachable set and all four sit at or below `CompostMeter.FULL_VALUE`.
	##     So the husk cues keep telling every drop apart and `HuskLayer.overflow_pips`
	##     is untouched — a new species must not silently collapse two husks into one
	##     picture (test_selftest.gd:2251 is the gate that would catch it).
	##   * chew_seconds 3.0 — longer than a beetle's 2.6 on less than two thirds the
	##     health, because the mouth has to work through the plate. That is the third
	##     answer to this pest and the reason it is a plan change rather than a wall:
	##     a Chomp ignores the shell completely and pays in time instead.
	##
	## The shell is deliberately NOT scaled by `apply_wave_scaling`. Health and speed
	## ride the endless ramp; a fixed six-hit tax is a wall at wave 10 and a formality
	## by wave 30, which is the right shape for a variety mechanic — the alternative
	## is a pest whose defining trait grows without bound.
	##
	## Not to be confused with MUTATION_ARMOURED, which shares none of this: that
	## trait only doubles `chew_seconds` and never touches damage, and it announces
	## itself with the drawn PLATE arcs in _draw(). This species carries its plate in
	## its own sprite and wears no marker at all — species are read from the drawing,
	## mutations from the marks, which is how the aphid, beetle and queen already work.
	SHIELDBUG: {
		"display": "Shield Bug",
		"texture": "res://assets/sprites/pest_shieldbug.png",
		"dead_texture": "res://assets/sprites/pest_shieldbug_dead.png",
		"health": 10.0,
		"speed": 54.0,
		"seeds": 6,
		"chew_seconds": 3.0,
		"scale": 0.88,
		"big": true,
		"shell_absorb": 1.5,
		"shell_hits": 6,
	},
	## The Leafhopper (plant-tower-defense-4zyb). The first pest on the board that
	## is answered by WHEN a hit lands rather than by how much or what kind — every
	## other species walks at one constant speed for its whole crossing, and this
	## one does not.
	##
	## ONE SENTENCE: it spends most of its time nearly motionless — an open shot for
	## anything already in range — then covers a burst of road almost too fast to
	## follow, which asks the player to notice the rhythm and time a hit to the
	## still half of it rather than simply pointing a plant at the lane and walking
	## away.
	##
	## The numbers, and what each is for:
	##   * hop_period 2.0s, hop_crouch_fraction 0.70 — a 1.4s CROUCH followed by a
	##     0.6s LEAP, on repeat for the whole crossing. 1.4s clears
	##     `CornCobbler.LEVELS[0]["interval"]` (0.80s) with room to spare, so a
	##     level-1 cob already locked on gets at least one whole shot cycle inside
	##     every crouch regardless of where in the cycle it happened to arm; 0.6s
	##     does NOT clear it, which is what makes the leap a real denial rather than
	##     a cosmetic wobble.
	##   * `hop_leap_multiplier()` is not a third stored number — it is DERIVED from
	##     the two above so the cycle's time-weighted average multiplier is always
	##     exactly 1.0. That is what keeps `speed` meaning what it means for every
	##     other species (an average px/s over the whole crossing), so nothing that
	##     reasons about a species' crossing time — `wave_director.gd`'s road-budget
	##     arithmetic, most of all — has to special-case this one. At these two
	##     numbers it works out to 3.10x during the leap against HOP_CROUCH_MULT's
	##     0.10x during the crouch: 0.70 * 0.10 + 0.30 * 3.10 = 1.0 exactly.
	##   * speed 40 — a shade above the beetle's 38. Despite reading as erratic, it
	##     is no faster than a beetle averaged over a full lane; the difficulty is
	##     entirely in the rhythm, not in a bigger number, the same restraint the
	##     Shield Bug's SPECIES entry argues for its own speed.
	##   * health 5.0 — a solo level-1 cob (1.25 dps rated) only gets meaningful
	##     dwell time during the CROUCH 70% of the cycle, so its effective rate
	##     against this species is close to 0.70 * 1.25 = 0.875/s. 5.0 / 0.875 is
	##     about 5.7s of crouch-equivalent time, roughly three hop cycles (6.0s) —
	##     comparable to the aphid's ~2.4s (3.0 / 1.25) but stretched by the
	##     species' own mechanic rather than by a bigger health pool.
	##   * seeds 4 — between the aphid's 3 and the Shield Bug's 6, and chosen
	##     against `CompostMeter.husk_value_for` the same way every species since
	##     the Shield Bug has been: at multipliers {1.0, 1.5, 2.0, 3.0} it drops
	##     husks worth {2, 3, 4, 6} — all comfortably under `CompostMeter.FULL_VALUE`
	##     (9), so every one of them sits in the smooth radius/glow range and none
	##     can collide with another species' husk the way a value past
	##     `HuskLayer.PIP_MAX * CompostMeter.FULL_VALUE` could.
	##   * chew_seconds 2.2 — clears `test_the_chomps_shop_line_is_true_of_the_chew_table`'s
	##     4x-the-aphid floor (0.45 * 4 = 1.8) with margin, and sits just under the
	##     beetle's 2.6: no plate, but the same coiled legs that spring it across the
	##     road keep kicking against the mouth almost as long as a beetle's whole
	##     body does.
	##   * scale 0.80 — between the aphid's 0.72 and the Shield Bug's 0.88. An
	##     ordinary small pest, not a boss and not armoured.
	##
	## Deliberately NOT "an aphid but faster" or "a beetle with a stutter": the
	## Leafhopper's average speed is unremarkable (see above), and what it changes
	## is the shape of its exposure over time, which none of the six other rows in
	## this table do at all.
	HOPPER: {
		"display": "Leafhopper",
		"texture": "res://assets/sprites/pest_hopper.png",
		"dead_texture": "res://assets/sprites/pest_hopper_dead.png",
		"health": 5.0,
		"speed": 40.0,
		"seeds": 4,
		"chew_seconds": 2.2,
		"scale": 0.80,
		"big": false,
		"hop_period": 2.0,
		"hop_crouch_fraction": 0.70,
	},
	## The Locust (plant-tower-defense-4zyb). The first pest on the board answered
	## by WHO you kill first rather than by how much damage lands on any one of
	## them — every other species is exactly as dangerous alone as it is in a
	## crowd, and this one is not.
	##
	## ONE SENTENCE: alone it is the slowest ORDINARY bug in the game (SHY of even
	## the queen's 30), and its speed only climbs the more OTHER living Locusts are
	## near it (see `_swarm_neighbor_count` / `swarm_speed_multiplier`) — so a
	## garden that thins a Locust group early keeps meeting the slow version, and
	## one that lets a group survive together meets a fast one, on the exact same
	## wave row.
	##
	## The numbers, and what each is for:
	##   * speed 24.0 — below the queen's 30, deliberately: alone, this species is
	##     barely worth the click. The whole point is that the number on this row
	##     understates the danger the way a Shield Bug's `health` understates its
	##     plate and a Nurse Beetle's `health` understates its aura.
	##   * swarm_radius 128.0 — two cells (`Board.CELL` is 64), the same "under the
	##     lane spacing" guard the Nurse's `heal_radius` uses: `Board.PATH_CORNERS`
	##     runs its three rows 192px apart, so a Locust never links up with one
	##     walking a lane it does not share, while a column spawned in single file
	##     on its own lane (see the wave rows) is well within reach of its
	##     neighbours the moment it is on the board.
	##   * swarm_cap 5, swarm_step 0.45 — NOT guessed: chosen so a fully massed
	##     column tops out at EXACTLY `SPECIES[APHID]["speed"]` (78.0), the fastest
	##     anything moves in this game today. `1.0 + 5 * 0.45 = 3.25`, and
	##     `24.0 * 3.25 = 78.0`. However dense the swarm gets, it never outpaces the
	##     species this game already uses as its speed ceiling — the mechanic asks
	##     the player to manage the crowd, not to fear a number nothing else in the
	##     game can already produce.
	##   * health 4.0 — a shade above the aphid's 3.0. Individually it should die
	##     about as fast as an aphid, so "kill it before it masses" is a real
	##     option for a garden that already answers aphids, not a second health
	##     check layered on top of the crowd mechanic.
	##   * seeds 5 — against `CompostMeter.husk_value_for` at {1.0, 1.5, 2.0, 3.0}:
	##     {3, 4, 5, 8}, all under `CompostMeter.FULL_VALUE` (9) for the same
	##     collision-safety reason the Leafhopper's seeds are.
	##   * chew_seconds 2.0 — clears the same 1.8s floor the Leafhopper's does, with
	##     margin; a Chomp holding one silences the whole swarm question for that
	##     one bug exactly as `held_by` already freezes every other mechanic on this
	##     board (see `_physics_process`).
	##   * scale 0.70 — the smallest scale in the game, at or under the aphid's
	##     0.72. Alone, this species should read as the LEAST threatening thing on
	##     the board, because the danger is entirely in what it becomes in a crowd
	##     and never in what it looks like by itself.
	LOCUST: {
		"display": "Locust",
		"texture": "res://assets/sprites/pest_locust.png",
		"dead_texture": "res://assets/sprites/pest_locust_dead.png",
		"health": 4.0,
		"speed": 24.0,
		"seeds": 5,
		"chew_seconds": 2.0,
		"scale": 0.70,
		"big": false,
		"swarm_radius": 128.0,
		"swarm_cap": 5,
		"swarm_step": 0.45,
	},
	## The SECOND boss (plant-tower-defense-gsai), and the whole reason it exists is
	## that it asks a question the Aphid Queen does not.
	##
	## The queen's question is WHERE: killing her makes three more problems, so the
	## player is deciding which stretch of road her death lands on. Every plant in
	## the garden can answer her; only the placement is in doubt.
	##
	## The Nurse Beetle's question is WHAT YOUR DAMAGE IS AIMED AT. Every damaging
	## plant in this game shoots the pest FURTHEST ALONG the road
	## (`CornCobbler._furthest_along_in_range`, `Dandelion`'s own pick) — the player
	## never chooses a target, the rule does. A Nurse walking behind the front of the
	## queue is therefore something the garden's own targeting will not shoot at
	## while it heals everything the garden IS shooting at. The answers are the two
	## plants that do not obey the rule: a Chomp Flower at the mouth of the lane
	## grabs whatever walks into it, and a Bomb Dandelion's blast lands on an area
	## rather than on a pest. So the decision is "does my garden own anything that
	## can hit the BACK of a wave", which nothing else on this board has ever asked.
	##
	## It is deliberately NOT "the queen with more health" — it has 48 against her 80
	## and no split at all. The difficulty is the aura and the aura only.
	##
	## The numbers, and what each is for:
	##   * heal_amount 3.0 every heal_period 1.5 s — i.e. 2.0 health a second put
	##     back into every OTHER living pest inside heal_radius. That rate is picked
	##     against the one damage source every player is guaranteed to own:
	##     `CornCobbler.single_target_dps(1, d)` is 1 kernel x 1.0 damage / 0.80 s =
	##     1.25/s at every distance in its ring. So ONE level-1 cob loses the race
	##     outright and never finishes anything inside the aura, TWO of them win it
	##     at a net 0.5/s, and one MAXED cob at the rim of its own ring (2.26/s)
	##     just clears it. The band is the decision: trickle damage spread thin over
	##     a lane does nothing here, and the same seeds concentrated do. Both ends
	##     are asserted in test_combat against the cob's own table rather than
	##     written down, so a balance pass on corn fails loudly instead of quietly
	##     turning this species into a beetle.
	##     Read it next to `Aloe.HEAL_PER_SECOND`, which is the mirror image: the
	##     garden's healer is tuned to LOSE its race with one pest by design, and
	##     this one is tuned to WIN its race with one plant. That asymmetry is the
	##     boss.
	##     One pulse is also exactly one whole aphid (3.0 = APHID health), which is
	##     what makes the aura legible: a swarm inside it visibly stops dying.
	##   * heal_radius 160 — two and a half cells, and chosen under
	##     `CornCobbler.RANGE` (176) rather than over it. A cob that can reach the
	##     Nurse can therefore reach everything she is protecting, so "shoot the
	##     healer" is never a shot the player cannot take from a plant already
	##     placed. It is also under the 192 px between the board's parallel road
	##     rows (Board.PATH_CORNERS runs at y = 1, 4 and 7), so an aura never leaks
	##     across into a lane the Nurse is not walking.
	##   * health 48 — three beetles, and read the same way the queen's 80 is. Her
	##     exposure crossing one cob's ring one cell off the road is 328 px of chord
	##     at 44 px/s = 7.45 s, and a maxed cob at that rim does 2.26/s, so one cob
	##     takes 16.8 off her and TWO still do not kill her while THREE do. Lower
	##     than the queen on purpose: a boss that both undoes the garden's damage
	##     and carries the queen's health pool is a wall, and the ask was a
	##     different decision, not a bigger one.
	##   * speed 44 — the only boss in the game that HURRIES. The queen at 30 is
	##     slower than everything and the wave arrives around her; the Nurse is
	##     faster than the beetle column (38) she is scheduled behind, so she walks
	##     UP into it and the aura finds a crowd instead of waiting for one. It also
	##     means the window in which a lane can kill her before she reaches the
	##     column is short, which is the part of this fight the player can plan for.
	##   * chew_seconds 5.0 — nearly double a beetle's 2.6 and less than half the
	##     queen's 11.0, and that gap is deliberate. A Chomp is one of the only two
	##     answers to this species, so eating her must be a real option rather than
	##     the trap the queen's mouthful is; a mouth shut for 5 s is a price, not
	##     the rest of the wave. A held Nurse also stops healing entirely — see
	##     `_physics_process`, where the aura tick sits AFTER the `held_by` guard.
	##   * seeds 39 — a shade under the queen's 40, because she is the lesser boss.
	##     Not a free number: `CompostMeter.husk_value_for` crossed with the four
	##     composable mutation multipliers turns a seed value into four husks, and
	##     `HuskLayer`'s radius and glow both saturate at `CompostMeter.FULL_VALUE`,
	##     so above that only the pip COUNT tells two husks apart. In the whole band
	##     from 24 to 40 only 39 and 40 leave every husk this game can drop still
	##     tellable from every other — `test_the_only_husks_that_look_alike_are_the`
	##     `_ones_the_pip_cap_lumps_together` in test_selftest.gd is the gate that
	##     would catch it; 39 is the one of those two that is not simply the queen's.
	##   * scale 1.30 — bigger than any ordinary pest (a beetle is 1.0) so she reads
	##     as a boss at a glance, and under the queen's 1.45 so the queen is still
	##     the biggest thing on the board.
	##
	## SHE WEARS A BEETLE'S SPRITE, AND THAT IS A KNOWN DEBT rather than a design.
	## A new species needs a 64 px SVG in art_src/, a render, a retina variant and a
	## row in test_sprite_style.gd's EXPECTED_SIZE — none of which the lane that
	## built her could do. `scale` 1.30 is doing the whole job of saying "this is not
	## an ordinary beetle", which is thinner than the Shield Bug's plate or the
	## queen's brood sac. See the bead for the follow-up.
	##
	## Like the queen, she can still roll a mutation — a winged Nurse cannot be
	## grabbed by a Chomp at all, which removes one of her two answers. Left in
	## rather than excluded, because the queen has carried exactly that exposure
	## since she shipped and `MUTATION_EXCLUSIONS` is a rule about PAIRS of
	## mutations, not about species. At MUTATION_CHANCE 0.4 over three traits it is
	## about one Nurse in eight.
	NURSE: {
		"display": "Nurse Beetle",
		# Her own art since plant-tower-defense-cnn7. She wore pest_beetle.png until
		# then, which made a whole boss mechanic unreadable: the one bug whose identity
		# changes what the player should do looked exactly like the fifteen ordinary
		# beetles walking beside her.
		"texture": "res://assets/sprites/pest_nurse.png",
		"dead_texture": "res://assets/sprites/pest_nurse_dead.png",
		"health": 48.0,
		"speed": 44.0,
		"seeds": 39,
		"chew_seconds": 5.0,
		"scale": 1.30,
		"big": true,
		"boss": true,
		"heal_radius": 160.0,
		"heal_amount": 3.0,
		"heal_period": 1.5,
	},
	## The boss (plant-tower-defense-74a). Deliberately NOT a fourth mutation and
	## deliberately not "a beetle with more health": what makes a queen a
	## different fight is that killing her is a decision about WHERE, not about
	## whether. She bursts into three aphids at the spot she falls, so a garden
	## that only reaches the last stretch of road converts one slow boss into
	## three fast pests with almost no road left to shoot them on, while the same
	## kill made at the entrance is simply free. Nothing else on the board makes
	## the player care where a kill lands.
	##
	## The numbers, and what each is for:
	##   * health 80 — measured against CornCobbler.single_target_dps. A level-3
	##     cob does 2.26 dps and holds a pest crossing its ring for ~11 s at this
	##     speed, so one cob is ~25 damage: a lone Corn Cobbler cannot take her,
	##     four maxed ones can, which is exactly the band the issue asks for.
	##   * speed 30 — slower than a beetle, so she is on the road a long time and
	##     the swarm behind her arrives while she is still walking. Also what
	##     makes the 11 s exposure above true.
	##   * chew_seconds 11 — a Chomp CAN eat her, and pays for it with the whole
	##     rest of the wave walking past a shut mouth. A gaping maw (the top of the
	##     Chomp's ladder, cycle 101) cuts that to 7.15 s, which is the point of the
	##     upgrade and still most of a wave. Note the mouth is beside
	##     the road, so a Chomp kill bursts the brood right next to the plant
	##     that is now busy for another eleven seconds. That is the trade, not a
	##     loophole.
	##   * seeds 40 — a beetle is 9. She is worth the wave.
	##   * scale 1.45 — 64 px of authored art (STYLE.md's canvas) drawn at 93 px
	##     on a 64 px cell. Nothing else on the board overflows its own cell.
	QUEEN: {
		"display": "Aphid Queen",
		"texture": "res://assets/sprites/pest_queen.png",
		"dead_texture": "res://assets/sprites/pest_queen_dead.png",
		"health": 80.0,
		"speed": 30.0,
		"seeds": 40,
		"chew_seconds": 11.0,
		"scale": 1.45,
		"big": true,
		"boss": true,
		"split_species": APHID,
		"split_count": 3,
	},
}

## From wave 8 (WaveDirector.MUTATION_START_WAVE) a spawned pest may carry one of
## these. Each is a single trait, not a new species — the wave table stays the
## same shape, a run just stops being identical every time.
const MUTATION_ARMOURED := &"armoured"
const MUTATION_WINGED := &"winged"
const MUTATION_HUNGRY := &"hungry"

## A mutated pest costs the player more to deal with than a plain one — the
## husk it leaves should too, or the mutation and compost systems sit side by
## side without ever touching. Armoured/winged both cost extra effort to kill
## (double chew time; unreachable by a Chomp at all); hungry costs the most,
## since a plant it reaches is destroyed outright rather than merely delayed.
const MUTATION_HUSK_MULTIPLIER: Dictionary = {
	MUTATION_ARMOURED: 1.5,
	MUTATION_WINGED: 1.5,
	MUTATION_HUNGRY: 2.0,
}

## The one pair that must never be rolled together, and the reason is mechanical
## rather than a balance opinion.
##
## `MUTATION_ARMOURED`'s **only** effect on play is `chew_seconds *= 2.0` — a Chomp's
## mouth tied up twice as long (`apply_mutation` below; the rest of `is_armoured`'s
## readers are `gait_swing`/`gait_rate`, which are cosmetic). And a winged pest cannot be
## grabbed by a Chomp at all (`game/chomp_flower.gd:85`). So an armoured winged pest is
## armoured in name and in husk payout and in nothing else: **the mutation's mechanic is
## dead the moment it lands.**
##
## The bead that asked for pairs (`-1d07`) worried the combination might be UNKILLABLE.
## Checked before building rather than after, and it is the opposite — the pair is
## redundant, not lethal. A pest that pays 1.5 x 1.5 for a trait it cannot use is a
## payout bug wearing a difficulty costume, which is worse than an easy pest.
##
## Stated as data rather than an `if` so a fourth mutation forces its author to say which
## pairs it can appear beside, and `test_every_mutation_pair_states_whether_it_composes`
## fails on a pair nobody has classified.
const MUTATION_EXCLUSIONS: Array[Array] = [
	[MUTATION_ARMOURED, MUTATION_WINGED],
]


## Whether two mutations may sit on the same pest. Symmetric, and false for a mutation
## against itself — applying the same trait twice would double a payout for nothing.
static func mutations_compose(a: StringName, b: StringName) -> bool:
	if a == b:
		return false
	for pair: Array in MUTATION_EXCLUSIONS:
		if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
			return false
	return true

## Each mutation's hue. Still applied as a sprite tint — but hue is the one
## channel that survives neither colour blindness nor a greyscale screenshot,
## and two of these three change what the player must do (winged is unreachable
## by a Chomp at all; hungry destroys a bed in MAX_HEALTH / EAT_DPS seconds).
## So every entry here is paired with a drawn silhouette marker below, and the
## marker — not the colour — is what carries the meaning.
const MUTATION_TINT: Dictionary = {
	MUTATION_ARMOURED: Color(0.58, 0.66, 0.78),
	MUTATION_WINGED: Color(0.82, 0.94, 1.0, 0.88),
	MUTATION_HUNGRY: Color(1.0, 0.52, 0.5),
}

## The non-colour half of a mutation's read: a shape at the silhouette edge.
## Named ids rather than raw draw calls so markers_for() is a pure, assertable
## function and the geometry below is only ever the rendering of its answer.
const MARKER_PLATES := &"plates"
const MARKER_WINGS := &"wings"
const MARKER_JAWS := &"jaws"

## Which mutation's hue each marker borrows. Markers never invent a colour —
## they take STYLE.md's three-value rule (dark rim / base / light facet) and
## apply it to the tint that is already in MUTATION_TINT.
const MARKER_SOURCE: Dictionary = {
	MARKER_PLATES: MUTATION_ARMOURED,
	MARKER_WINGS: MUTATION_WINGED,
	MARKER_JAWS: MUTATION_HUNGRY,
}

const MARKER_LIGHTEN: float = 0.42
const MARKER_DARKEN: float = 0.52
const MARKER_ALPHA: float = 0.95
const MARKER_LINE: float = 2.0

## Half of the 64 px sprite canvas STYLE.md mandates. Every marker below is
## placed in fractions of this times the species' own sprite scale, so an
## aphid's marks hug its silhouette exactly as tightly as a beetle's hug its.
const SPRITE_HALF: float = 32.0

## Armour: two concentric arcs hugging the sides and underside — an outline
## thickening, per the doc's "plate". The arc deliberately stops short of the
## top (-15 deg round to 195 deg) because the health bar lives up there.
const PLATE_OUTER: float = 1.06
const PLATE_INNER: float = 0.92
const PLATE_FROM: float = -PI / 12.0
const PLATE_TO: float = PI * 13.0 / 12.0
const PLATE_SEGMENTS: int = 22
const PLATE_WIDTH: float = 3.0
const PLATE_SEAM_WIDTH: float = 2.0

## Winged: a swept wing either side, rooted at the body and reaching past the
## silhouette. Drawn on the parent's canvas item, i.e. BEHIND the sprite child,
## which is why every point sits outside the sprite's own art rather than on it.
const WING_ROOT_IN := Vector2(0.40, -0.22)
const WING_TIP := Vector2(1.10, -0.92)
const WING_TIP_OUT := Vector2(1.06, -0.34)
const WING_ROOT_OUT := Vector2(0.52, 0.02)

## Hungry: a row of teeth along the lower edge, the same tooth language the
## Chomp Flower's maw uses — on the bug this time, which is the point.
const JAW_TEETH: int = 3
const JAW_TOP: float = 0.78
const JAW_TIP: float = 1.14
const JAW_HALF_WIDTH: float = 0.19
const JAW_SPACING: float = 0.40

## The fought mark: a broken ring around any pest the garden has actually touched
## (plant-tower-defense-wlyz).
##
## WHAT IT IS FOR. `_ever_engaged` has always known the difference between a pest
## that strolled past an empty road and one that was shot at, slowed, bitten and got
## through anyway. Those are two different sentences about the same lost bed — "you
## had no answer there" and "your answer was not enough" — and until this the player
## only ever met them added together in the run summary. This is that flag, on the
## board, on the bug, while there is still time to do something about it.
##
## WHY IT IS ON THE LIVING PEST RATHER THAN ON THE ESCAPE. `_escape()` emits and then
## `queue_free()`s in the same frame, so a mark painted at the moment of escape would
## be on screen for exactly zero frames. A pest wearing this all the way down the road
## is wearing it when it reaches the exit, which is the distinction the bead asks for —
## and it is legible earlier, when the answer is "put a plant in that lane" rather than
## "read the summary".
##
## WHY A BROKEN RING, AND NOT A NEW SHAPE. `game/OVERLAY_GRAMMAR.md`: a dashed ring is
## "a REMARK about the thing inside it", and this is a remark about the pest inside it.
## It adds no row to that table — adding one fails
## `test_the_legend_names_as_many_shapes_as_the_grammar_documents` until someone decides
## whether it is taught — it is the second instance of a row that already has one
## (`placement_preview.gd`'s at-risk ring), and the dash construction below — count,
## step, gap, segments — is copied from that one verbatim on purpose, so both read as
## one language rather than as two people's idea of "dashed".
##
## The at-risk remark is 30 px and this one is 29 px on an aphid, which is not a
## collision: what a remark is ABOUT is the thing inside it, and one of them is drawn
## on a bed and the other on a bug. Same row, different subject.
##
## THE TWO-CHANNEL RULE. The signal is the BREAK: a solid ring at this size on a bug
## would be read as a reach, a full ring is not what is drawn, and nothing else on a
## pest is a loop at all — the armour plates are a partial arc across the underside and
## stop at 1.06. Throw the colour away and a haloed bug and a bare one are still two
## different pictures.
##
## RADIUS. 1.28 silhouettes, so it clears PLATE_OUTER (1.06) by a visible margin on
## every species at once — an aphid at scale 0.72 wears it at 29 px and the queen at
## 1.45 at 59 — and scales with the pest for the same reason every marker above does.
## Drawn on the Pest's own canvas item, i.e. behind the sprite and behind the health
## bar, so the topmost dash passes under the bar rather than fighting it.
const FOUGHT_RING_RADIUS: float = 1.28
const FOUGHT_RING_DASHES: int = 8
const FOUGHT_RING_WIDTH: float = 2.0
const FOUGHT_RING_SEGMENTS: int = 4
## A pale bone ink rather than any mutation's hue: the mark is about what the GARDEN
## did, not about what the pest is, and borrowing a MUTATION_TINT would say the
## opposite. Kept light because it sits behind the sprite on dark road tiles.
const FOUGHT_RING_COLOR := Color(0.94, 0.93, 0.82, 0.72)

## How close a hungry pest has to be to a plant to start eating it. Same
## reasoning as ChompFlower.GRAB_RADIUS: a pest walks the road, a plant stands
## one cell off it, so anything under one cell can never reach either.
const EAT_RADIUS: float = Board.CELL * 1.15
const EAT_DPS: float = 14.0

## The health bar's box, and how far above the pest's centre it floats.
##
## The offset scales with the sprite, and only ever upward. A queen is drawn at
## scale 1.45, so her silhouette reaches 46 px from her centre and a bar pinned
## at 30 would be painted across her own back — the one readout a boss fight is
## actually about, hidden inside the boss. maxf(1.0, ...) is what keeps this
## change to one sprite: an aphid at 0.72 keeps the bar exactly where every pest
## in the game has always had it rather than sliding down into its body.
const HEALTH_BAR_SIZE := Vector2(32, 5)
const HEALTH_BAR_TOP: float = -30.0


## Where a pest drawn at `sprite_scale` floats its bar. Pure, so the placement is
## assertable without a viewport.
static func health_bar_top_for(sprite_scale: float) -> float:
	return HEALTH_BAR_TOP * maxf(1.0, sprite_scale)


## How long a killed pest's corpse (dead-eyes sprite) stays on screen before it
## is actually freed. Long enough to read as a beat, short enough not to pile up.
const DEATH_LINGER: float = 0.35

## How much of DEATH_LINGER's tail is spent fading out rather than held solid —
## the corpse reads for a beat first, same as before this existed, then goes.
const DEATH_FADE: float = 0.15

## The ceiling on how far `husk_multiplier()` may stretch that beat
## (plant-tower-defense-rowt).
##
## 3.0 is exactly the hardest pest the game can roll today — hungry (2.0) paired with
## armoured or winged (1.5), the only pairs `mutations_compose` permits — so the cap
## costs nothing now and is here for the fourth mutation. `husk_multiplier()` is a
## PRODUCT, so a fourth trait would multiply into it and quietly hand the board
## multi-second corpses; a corpse outstaying its wave is a bug, and a cap that has to
## be raised on purpose is the cheap way to find out.
const DEATH_LINGER_MAX_MULTIPLIER: float = 3.0


## How long a corpse worth `multiplier` holds before it is freed. Pure, so "a hard-won
## kill lingers longer than an easy one" is one assertion rather than two stopwatches.
##
## Scaled by `husk_multiplier()` at the call site and by nothing else: the game already
## prices a harder kill twice (`Game._on_pest_died` reads it for the husk AND for
## `Sfx.kill_event_for`), and the corpse is the third place that idea belongs — the one
## the player is actually looking at. Inventing a second difficulty number here would
## give the same pest two contradictory answers to "how hard was that".
##
## Clamped at the bottom too: nothing under 1.0 is reachable through
## `MUTATION_HUSK_MULTIPLIER`, and a corpse that vanished FASTER than the plain default
## would read as the game dropping frames rather than as an easy kill.
static func death_linger_for(multiplier: float) -> float:
	return DEATH_LINGER * clampf(multiplier, 1.0, DEATH_LINGER_MAX_MULTIPLIER)

## A kernel connecting and a kernel missing (leaving the board unaimed) used to
## look identical — Kernel._physics_process called queue_free() on either exit
## with nothing in between (plant-tower-defense-7o3). A killed pest already gets
## its own unmistakable cue (the corpse swap and fade below, plus Sfx.PEST_KILLED
## from Game._on_pest_died), so this is only for the other case: a hit that the
## pest survives, where the health bar shrinking was the only tell.
##
## Total time the flash takes to rise and fall back to the sprite's normal tint.
const HIT_FLASH_DURATION: float = 0.10
## How hard the flash boosts the sprite's current colour channels — deliberately
## a multiply, not a replacement, so a flash on an armoured or hungry pest still
## reads as that pest's own hue gone bright, not as a third, unrelated colour.
const HIT_FLASH_BOOST: float = 1.9

## The walk cycle (plant-tower-defense-iue). Plant._wobble() is the reference
## idiom: one accumulated clock per instance, one `sin()` off it per frame, no
## Tween anywhere. That shape is the whole reason this is affordable — this runs
## on every pest on the road, and WaveDirector.SIMULTANEOUS_PEST_CEILING puts
## that at 40 at once. Two `sin()` calls and two property writes per pest per
## frame is 4,800 sines a second at the ceiling, which is nothing; forty Tweens
## being created and destroyed as pests spawn and die would not be.
##
## A bug seen from above does not bob up and down — it slews. So the motion is
## a yaw waggle *around the facing rotation* plus a body-axis stretch: the
## silhouette narrows and lengthens as it scuttles, which is exactly the shape
## the drawn sprites already have (long axis up-screen, per STYLE.md).
##
## Peak yaw either side of the direction of travel. Read the composition rule in
## _apply_facing(): this is added to `_facing`, never written over it.
const GAIT_SWING: float = 0.13
## Waggles per second at GAIT_REFERENCE_SPEED, in radians of clock.
const GAIT_RATE: float = 8.5
## The speed a pest walks at to get exactly GAIT_RATE, so the fast ones scuttle and
## the slow ones plod without any of them needing a per-species constant.
## Endless-mode speed scaling rides along for free (a hasted pest visibly hurries),
## clamped either side so a wave-30 beetle flails rather than blurs.
##
## THIS WAS PICKED AS A MIDPOINT AND IS NO LONGER ONE. It was chosen between the
## aphid's 78 and the beetle's 38 when those were the only two species. There are
## five now — aphid 78, shieldbug 54, nurse 44, beetle 38, queen 30 — so 60.0 sits
## ABOVE FOUR OF THE FIVE, the corpus midpoint is 54 (the Shield Bug's own speed),
## and the queen at 30 is already below the GAIT_RATE_MIN clamp before any wave
## scaling touches her. What the mechanic needs is weaker than a midpoint and is
## still true: species on both sides, and none of them sitting so close to the
## reference that its gait reads as neutral. Both are asserted in test_combat.gd
## (plant-tower-defense-frzz) against a corpus derived from SPECIES, so the next
## species added at speed 61 fails there instead of landing on the line in silence.
## Do not restore the midpoint claim without re-deriving it.
const GAIT_REFERENCE_SPEED: float = 60.0
const GAIT_RATE_MIN: float = 0.55
const GAIT_RATE_MAX: float = 1.9
## Body-axis squash/stretch, as a fraction of the species' own sprite scale.
const GAIT_STRETCH: float = 0.06
## Strides per waggle: the body pulses twice per side-to-side sway, which is
## what stops the two reading as one motion.
const GAIT_STRETCH_RATE: float = 2.0

## The recoil, and the second channel a damaged pest speaks on.
##
## Until this existed a pest's only tell for a hit it survived was HIT_FLASH_DURATION's
## 0.10s of hue, so a bug taking a kernel to the face and a bug that took nothing
## differed in colour and in nothing else — against this project's standing rule that
## colour is never the only signal. `Plant` already solved the same problem for the
## other side of the fight (`plant.gd:211-231`) and its whole argument transfers:
##
##   * RE-ARMED rather than accumulated, in flash_hit(), so a pest under sustained fire
##     shudders continuously and decays out once the shooting stops. Same three lines
##     for a twitch and for a shudder.
##   * Clearly bigger than the idle motion or it reads as nothing. GAIT_SWING is the
##     largest yaw any pest walks with (the two multipliers only ever shrink it), and
##     FLINCH_RADIANS is a shade over three times it, matching the plant's ratio.
##   * Its own fast clock, not a multiple of the gait's, so the two never phase-lock
##     into one larger waggle — which would read as "walks harder when shot".
##
## FLINCH_RATE is where the pest differs from the plant, and it is not a taste call:
## the plant sways at 1.15 and can pick any fast number, but a winged pest at the speed
## clamp runs its gait clock at GAIT_RATE * GAIT_RATE_MAX * WINGED_RATE_MULTIPLIER =
## 38.8 rad/s, so anything slower than that is SLOWER than the walk it is supposed to
## interrupt. This sits above the fastest gait clock any pest can reach, and
## test_combat.gd asserts that against the trait matrix rather than against this
## sentence.
const FLINCH_RADIANS: float = 0.40

## How hard a cue that did NOT follow damage shakes the bug (plant-tower-defense-zdy2).
##
## THE BEAD ASKED ABOUT THE SUNDEW AND THE ENUMERATION FOUND THREE. Six things call
## `flash_hit`, and only three of them ever damaged the pest:
##
##   Kernel, SeedBomb, Nettle   damage landed        -> full recoil, unchanged
##   ChompFlower (catch, bite)  no take_damage AT ALL
##   StickySundew               no take_damage at all
##
## The Chomp calls nothing that damages — `grep take_damage game/chomp_flower.gd` is empty;
## it holds a pest, chews it cosmetically through `set_chewed`, and kills it when the clock
## runs out. So half the callers were saying "a hit landed" in motion about a pest that had
## taken nothing.
##
## WHAT EACH ONE GETS, and the split is between VIOLENCE and RESTRAINT rather than between
## damage and no damage:
##   * THE CHOMP KEEPS THE FULL RECOIL. Being eaten alive is the most violent thing in this
##     game, and routing it through `_chew_left` instead of `take_damage` is an
##     implementation detail the bug does not care about. A gentler shake there would be
##     the cue lying about the situation to be consistent with a function call.
##   * THE SUNDEW GETS THIS. Nothing struck it; it walked into glue and slowed down. Before
##     this, "stuck" and "shot" were the same word in the game's vocabulary of movement,
##     which is the bead's own sentence and is exactly right.
##   * A PLATE-BLOCKED HIT GETS THIS TOO, and that half was a defect rather than a
##     judgement. `SHELL_FLASH_DIM` already dims the colour to 0.45 against
##     `HIT_FLASH_BOOST`'s 1.9 — a 4.2x split saying "that did nothing" — while the recoil
##     said "that hit hard" in the same frame. Two channels, one event, opposite claims.
##
## 0.35 rather than zero: something DID happen, and a bug that is grabbed or that shrugs a
## kernel off should not be indistinguishable from one nothing touched. Above
## `GAIT_SWING` 0.13 once multiplied (0.40 * 0.35 = 0.14) so it still out-reads the walk,
## and asserted as that rather than as a fraction — a scale that drops below the gait is
## not a quiet cue, it is no cue.
const GLANCE_FLINCH_SCALE: float = 0.35
const FLINCH_RATE: float = 46.0
const FLINCH_SECONDS: float = 0.28

## Each mutation's gait tell, so the trait is readable from movement alone and
## not only from the hue + marker pair above. Winged flutters (fast, shallow);
## armoured plods (slow, stiff); hungry lunges — see gait_stretch() for why that
## one is a shape change rather than a bigger number.
const WINGED_RATE_MULTIPLIER: float = 2.4
const WINGED_SWING_MULTIPLIER: float = 0.45
const ARMOURED_RATE_MULTIPLIER: float = 0.8
const ARMOURED_SWING_MULTIPLIER: float = 0.6
const HUNGRY_STRETCH_MULTIPLIER: float = 2.2

## Per-pest phase, so nine aphids spawned in a column read as nine creatures
## rather than one animation played nine times. The golden angle: successive
## spawns land as far apart on the circle as any sequence can, so even the two
## pests either side of a single spawn beat are visibly out of step.
const GAIT_PHASE_STEP: float = 2.399963
## The spawn counter wraps here rather than climbing for the length of an
## endless run — `index * GAIT_PHASE_STEP` at a few million loses the precision
## that makes neighbouring phases distinct, and 64 distinct phases is already
## more than SIMULTANEOUS_PEST_CEILING can put on the road at once.
const GAIT_PHASE_PERIOD: int = 64

var species: StringName = APHID
var health: float = 1.0
var max_health: float = 1.0
var speed: float = 60.0
var seed_value: int = 1
var chew_seconds: float = 0.5
var is_big: bool = false

## The live half of the Shield Bug's plate. Both are 0 for every other species,
## which is what makes `take_damage` a single branch rather than a species check —
## an unshelled pest has nothing left to block with from the frame it spawns.
##
## `shell_blocks` counts HITS remaining, not damage remaining; see the SHIELDBUG
## entry for why that distinction IS the mechanic. It is public because it is state
## a player is being asked to track, so a devtools read and a test should be able to
## ask the same question the sprite is trying to answer.
var shell_blocks: int = 0
## How much of ONE hit a block eats. Seeded from the species and never scaled.
var shell_strength: float = 0.0

## The Nurse Beetle's pulse clock, in seconds since the last pulse. 0.0 and idle
## for every other species, because `heal_period()` answers 0.0 for them and the
## tick in `_physics_process` is gated on it.
##
## Deliberately NOT reset when the pest is grabbed. A Chomp that holds a Nurse
## silences her (the tick sits after the `held_by` guard), and a clock that also
## rewound would hand a released Nurse a fresh full period on top — paying the
## player twice for one grab and making the pause longer than the grab was.
var _heal_clock: float = 0.0

## The Leafhopper's hop clock, in seconds since it last started a cycle. 0.0 and
## idle for every other species, same reason and same shape as `_heal_clock`
## above: `hop_period()` answers 0.0 for them, and it only advances in the same
## branch of `_physics_process` that actually moves the pest — a held Leafhopper
## does not move, so it does not hop either, and it resumes exactly where its
## cycle left off rather than being handed a fresh crouch on release.
var _hop_clock: float = 0.0

## Set by a Chomp Flower while it is eating this pest. A held pest does not move.
var held_by: Node = null

## Where the Chomp holding this pest has dragged its BODY to, in this node's own space.
##
## PURELY COSMETIC, and that split is the entire reason this field exists rather than the
## flower simply writing `position`. Everything that decides what happens to a pest reads
## `position` or `global_position` — `Kernel._hit_pests` (game/kernel.gd:69), the escape
## route in `_advance`, `_adjacent_plant`, `_blocking_plant`, the husk `Game._on_pest_died`
## drops. Hauling the node one cell off the road onto the flower would silently take a held
## pest out of every cob's line of fire, which is a nerf to the Chomp/Corn pairing that no
## balance table records and no test would have caught.
##
## So the node stays on the road and the PICTURE moves: this offset is added to `_sprite`,
## to both health bars, and to the marker ring in `_draw()`. Every reader of the offset is
## a drawing.
##
## It shares `_sprite.position` with the death knockback, which is the one other writer of
## that channel (see `_play_death`). They do not collide: the carry stops updating the
## instant `_alive` goes false, and the corpse folds the last carry offset into its shove
## so a bug eaten on top of a flower does not drop through it to the path.
var _carry_offset: Vector2 = Vector2.ZERO

## True from the moment a Chomp's vines take hold to the moment it lets go. Distinct from
## `held_by != null` only in what it is FOR: `held_by` is the mechanic (this pest does not
## walk), this is the picture (this pest is drawn above the plant eating it, and its body
## may be somewhere its node is not).
var _carried: bool = false

## Where the health bars sit at rest, recorded by `_build_visuals`. See `_apply_carry`.
var _bar_origin: Vector2 = Vector2.ZERO

## What a carried pest's `z_index` becomes, so the bug hauled onto a flower is drawn on
## top of it rather than behind it.
##
## `z_index` is otherwise unused across the whole of `game/` — every other layer question
## in this project is answered by tree order — so this is not competing with anything. It
## has to be a z and not a reparent: a pest re-parented mid-run would break `_route`, which
## is expressed in the parent's space.
##
## 1, not a large number: `_entities` holds the board, the plants, the pests and the husk
## layer, and the intent is "just above the flower", not "above the whole world".
const CARRY_Z_INDEX: int = 1

## The PRIMARY mutation — the first one applied, and the one whose hue the sprite wears.
## Kept as its own field rather than derived on read because it is what every existing
## reader means by "which mutation is this", and because a pest with two of them still has
## only one tint to wear.
##
## `mutations` is the whole set. The two are a cache and its source: the invariant is
## `mutation == mutations[0]` when there is one and `&""` when there is not, asserted by
## `test_a_second_mutation_composes_onto_the_first` rather than trusted.
var mutation: StringName = &""
## Every mutation on this pest, in the order applied. Empty for a plain one, one entry
## for the common case, at most two by `WaveDirector`'s roll — but nothing here caps it,
## because the cap is a balance decision and this is the mechanism.
var mutations: Array[StringName] = []
var is_armoured: bool = false
var is_winged: bool = false
var is_hungry: bool = false

## The cosmetic skin the player has chosen for this species — purely decorative,
## picked on the Skins screen and BOUGHT with petals in the Shop. It used to be
## unlocked by a milestone (plant-tower-defense-ncfv); ownership is now per target
## and per family, and `RunConfig.selected_skin()` falls back to DEFAULT_SKIN for a
## family this player has not bought for this species, which is also how a v10 save's
## selections survive the parse and are simply not worn.
## See `game/skins.gd` for the table and `set_pest_skin()` below, which is the only
## writer, for how it reaches the sprite.
var skin_id: StringName = Skins.DEFAULT_SKIN

var _route: PackedVector2Array = PackedVector2Array()
var _leg: int = 1
var _sprite: Sprite2D
var _health_bar: ColorRect
var _health_back: ColorRect
var _alive: bool = true
var _dead_texture: Texture2D = null
## How small a pest is chewed down to before the flower finishes it. Not zero: see
## chewed_scale(). 0.55 leaves the bug plainly diminished while still legible as
## the species it is, which is what makes the shrink read as being EATEN rather
## than as walking away.
const CHEWED_MIN_SCALE: float = 0.55

var _sprite_scale: float = 1.0

## How much of this pest has been eaten, 0.0 to 1.0. Written by the ChompFlower
## holding it; nothing else touches it.
##
## SOURCE: a player, verbatim -- "the attack animation for the chomp flower doesn't
## really look like it's taking bites out of the bugs, improve the animation
## dramatically" (plant-tower-defense-h4v1).
##
## The report was exactly right and the reason was that the flower's side was rich
## and the pest's side was empty. A held pest ran its full walk cycle on the spot,
## unblemished, receiving one flash_hit() at the instant of the grab and nothing
## after, until it swapped to a corpse in a single frame. Nothing was taken out of
## the bug because nothing in the code took anything out of the bug.
##
## Kept as a plain fraction rather than a scale so the SHAPE of the mapping lives in
## `chewed_scale()` where a test can read it, and so `set_chewed` can be asserted
## without an open animation gate -- the pattern test_combat.gd:6331 requires of
## every animation in this game.
var _chewed: float = 0.0

## How this pest died, so the corpse can say so (plant-tower-defense-f5z6).
##
## Every death used to leave the same straight corpse, which is a fair default and
## makes three quite different events look identical: a Chomp chewing something to
## pieces, a seed bomb going off underneath it, and a kernel arriving. The cue is
## the corpse itself rather than a new effect, because a corpse is already drawn,
## already lingers for DEATH_LINGER, and is already the thing a player looks at.
##
## `&""` — the default — is the straight corpse, and it is what a kernel kill and
## any future unattributed kill both get. That is deliberate: the plain corpse
## should be the common case, so the two that differ read as remarkable.
const DEATH_BITTEN := &"bitten"
const DEATH_BLASTED := &"blasted"

## Squash along the body axis for a chewed corpse. A Chomp closes on the whole
## pest, so the corpse is SHORTER rather than displaced — shape, not position,
## which is also the channel a screenshot can be asserted against.
const BITTEN_SQUASH: float = 0.62

## Rotation off the facing for a blasted corpse, in radians. A bomb throws the
## body off its line of travel; nothing else in the game rotates a corpse away
## from `_facing`, so the tilt reads as "something moved this" without needing a
## second colour. Deliberately not a multiple of PI/2 — the four cardinals are
## spoken for by _update_facing and a corpse at one of them would read as a
## living pest that stopped.
const BLASTED_TILT: float = 0.55

## The kernel kill's cue (plant-tower-defense-6v39), and the DECISION that bead asked
## for before the change: the plain corpse stops being the majority case.
##
## Cycle 65 left a kernel kill on the straight default on purpose, so the bitten and
## blasted corpses would read as remarkable. That reasoning holds for a rare cause and
## fails for the common one — a Corn Cobbler is the plant most players own most of the
## time, so "the exception" was most of the corpses a player ever sees, and the moment
## of death carried nothing at all. So the kernel gets a cue, and it is the third
## CHANNEL rather than a third value of `_death_cause`: rotation says blasted, scale
## says bitten, and position now says shot. A corpse can therefore be chewed AND shoved
## without the two cues having to agree on one enum.
##
## The straight corpse still keeps its path, which the bead requires and
## `test_a_corpse_lies_differently_depending_on_what_killed_it` reads: a knockback of
## `Vector2.ZERO` is the default for `kill()` and `take_damage()`, so a Chomp's meal, a
## bomb's victim and any direct kill lie exactly where they always did.
##
## 9 px is a shove, not a throw: well under a quarter cell (Board.CELL is 64), so a
## corpse never slides into the neighbouring square or off the road it died on.
const DEATH_KNOCKBACK_PX: float = 9.0
## How long the shove takes. A fraction of DEATH_LINGER's shortest form (0.35), so the
## body has visibly settled before the fade starts rather than still sliding under it.
const DEATH_KNOCKBACK_TIME: float = 0.09


## Which way a corpse is shoved by a hit that arrived from `from`, and how far.
##
## Same shape as `ChompFlower.lunge_offset()` and `Nettle.sting_thrust_offset()`
## deliberately — a direction is the one thing about an animation that can be flatly
## wrong while still rendering a plausible frame, so it comes out into a pure static a
## test can read with no board, no frame and no open animation gate.
##
## `to - from`, i.e. AWAY from the shooter and along the kernel's own travel: a body
## knocked back toward the thing that shot it is the sign error this exists to catch.
## Degenerate input returns `Vector2.ZERO` rather than a normalised NaN — `Kernel`'s hit
## test is a distance check that a pest sitting exactly on the kernel passes.
static func knockback_offset(from: Vector2, to: Vector2) -> Vector2:
	var delta: Vector2 = to - from
	if delta.length_squared() <= 0.0001:
		return Vector2.ZERO
	return delta.normalized() * DEATH_KNOCKBACK_PX

var _death_cause: StringName = &""

## The two things about this death that are settled the instant it happens, and are
## therefore recorded ABOVE every animation gate — the rule `set_chewed()` states and
## `_bite_lunge` / `_sting_thrust` follow. Headless never opens the gate, so a value
## composed inside it is a value no test in this project can ever see: deleting the
## shove or the scaled hold has to go red, not go quiet.
##
## `_death_knockback` is a SPRITE offset and nothing else reads it. That is deliberate
## and load-bearing: `died` is emitted before `_play_death()` runs, and
## `Game._on_pest_died` drops the husk and files the lane loss at `pest.position`, so
## moving the body would move a husk the player has to click and shift a number the
## balance sims count. The corpse is a picture by the time it is shoved.
var _death_knockback: Vector2 = Vector2.ZERO
## How long this particular corpse holds, from `death_linger_for(husk_multiplier())`.
var _death_linger: float = DEATH_LINGER

## The walk cycle's own state. `_facing` is the cardinal rotation
## _update_facing() decides; `_sway` is the gait's offset from it. They are kept
## apart precisely because two features write one property: whichever of them
## ran last would otherwise erase the other, and since _advance() calls
## _update_facing() every single frame, the loser would always be the gait.
var _facing: float = 0.0
var _sway: float = 0.0
var _gait_time: float = 0.0
var _gait_phase: float = 0.0
## Seconds of recoil left. Armed by flash_hit(), decayed by _gait().
var _flinch_left: float = 0.0
## How hard THIS recoil shakes, 0..1. Set beside `_flinch_left` so the two can never
## disagree about which cue is running, and read in `_gait` rather than folded into the
## decay — scaling the SECONDS would make a glance shorter instead of gentler, which is a
## different sentence: a brief full-strength shake still says "struck".
var _flinch_force: float = 1.0

## Handed out at setup() and wrapped at GAIT_PHASE_PERIOD. Static because the
## thing being spread out is *between* pests — a per-instance seed cannot know
## what the pest beside it chose. StickySundew._next_wash_order is the same
## pattern; unlike that one this needs no reset, because a phase is cosmetic and
## the wrap keeps it bounded on its own.
static var _next_gait_index: int = 0

## Did anything in the garden ever lay a finger on this pest?
##
## Set by exactly the two things that can. A kernel landing (take_damage) and a
## Chomp holding it still are the whole list: a Sundew "deals no damage
## whatsoever" by its own doc comment, it only slows, and a Sunflower never
## touches a pest at all. So a pest that walked a field of Sundews and reached
## the exit really was never engaged, and this does not overstate the garden.
##
## Held counts, even though a Chomp does no damage. A Chomp eaten out from under
## its meal calls release() (chomp_flower.gd wires `destroyed` to it) and hands
## back a live pest at full health — which had very much been fought, and would
## otherwise report itself as having strolled past an empty lane.
##
## The reading this exists for is at the moment of escape; see Game._note_escape.
## It is also drawn now, as the fought mark — see FOUGHT_RING_RADIUS.
var _ever_engaged: bool = false

## Whether the fought mark is currently part of this pest's picture.
##
## A separate field from `_ever_engaged` rather than a read of it, and written here in
## game code rather than decided inside `_draw()`, for the reason `set_chewed()` gives:
## headless runs no `_draw()` at all, so a cue whose only record is a draw call is a cue
## no test can see. `shows_fought_mark()` is the state; `_draw_fought_mark()` is only
## its rendering, and deleting the rendering leaves the state to be checked against a
## screenshot while deleting the STATE goes red.
var _shows_fought_mark: bool = false

## Did the most recent damaging hit fail to get through the plate?
##
## Recorded rather than passed as an argument because the two halves of one hit are
## made by two different objects a frame apart: `Kernel._physics_process` calls
## `take_damage()` and then `flash_hit()` (game/kernel.gd:70, :76), and a third
## caller (SeedBomb) does the same. Widening `flash_hit()` to take the answer would
## mean editing every call site to pass back something the pest already knows.
##
## Only ever read by `flash_hit()`, and reset at the top of every `take_damage()`
## so a blocked hit cannot colour the flash of the landed hit after it.
var _last_hit_blocked: bool = false


func setup(which: StringName, route: PackedVector2Array) -> void:
	species = which
	var stats: Dictionary = SPECIES[which]
	max_health = float(stats["health"])
	health = max_health
	speed = float(stats["speed"])
	seed_value = int(stats["seeds"])
	chew_seconds = float(stats["chew_seconds"])
	is_big = bool(stats["big"])
	shell_strength = shell_absorb(which)
	shell_blocks = shell_hits(which)
	_route = route
	_leg = 1
	if not _route.is_empty():
		position = _route[0]
	add_to_group("pests")
	_gait_phase = gait_phase(_next_gait_index)
	_next_gait_index = (_next_gait_index + 1) % GAIT_PHASE_PERIOD
	_build_visuals(String(stats["texture"]), float(stats["scale"]))
	# After _build_visuals(), which is what builds _sprite -- set_pest_skin()'s tint
	# is a no-op before it exists. Before any apply_mutation() call, so the ordinary
	# case just wears the skin; see set_pest_skin()'s own comment for the one that
	# does not.
	set_pest_skin(RunConfig.selected_skin(Skins.KIND_PEST, which))
	var dead_path: String = String(stats.get("dead_texture", ""))
	if dead_path != "":
		_dead_texture = load(dead_path) as Texture2D
	_make_world_controls_click_through()
	if _route.size() > 1:
		_update_facing(_route[1] - _route[0])


## Drops a pest that has already been setup() into the middle of that walk.
##
## The brood a boss bursts into (see split_species) has to arrive where its
## parent fell, not at the entrance — a queen killed at the exit whose aphids
## restarted from the gate would turn the entire mechanic upside down and reward
## exactly the play it is meant to punish. `leg` is the waypoint index the pest
## is walking TOWARD, which is what the parent's route_leg() hands back, so the
## child inherits the walk rather than re-deriving it from a position.
##
## Clamped to the route's own bounds: a leg past the end would make the very
## next _advance() call _escape() on a pest that had not walked anywhere, and a
## leg below 1 would send it back to a waypoint it is already past.
func enter_road_at(at: Vector2, leg: int) -> void:
	if _route.is_empty():
		return
	position = at
	_leg = clampi(leg, 1, _route.size() - 1)
	_update_facing(_route[_leg] - position)


## The waypoint index this pest is walking toward. Public because a burst boss
## has to hand its own place in the walk to the brood it leaves behind, and that
## is the only honest way to say "here, on this road, facing this way".
func route_leg() -> int:
	return _leg


## What `species` bursts into when it dies, or &"" for a pest that simply dies.
static func split_species(which: StringName) -> StringName:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return StringName(stats.get("split_species", &""))


## How many of split_species() it bursts into; 0 when it bursts into nothing.
##
## Reads the same entry the sprite counts out: pest_queen.svg draws exactly
## three eggs on the brood sac, so the picture and the number are the same
## claim. test_the_queens_sprite_counts_out_the_brood_it_bursts_into holds them
## together.
static func split_count(which: StringName) -> int:
	if split_species(which) == &"":
		return 0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return int(stats.get("split_count", 0))


## How much of a single hit `which`'s plate eats, or 0.0 for a species with no
## plate. Same shape as split_species() above and for the same reason: `SPECIES`
## rows are optional-key dictionaries, and every reader going through an accessor
## is what keeps a missing key from being an error at three separate call sites.
static func shell_absorb(which: StringName) -> float:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("shell_absorb", 0.0))


## How many hits that plate stops before it comes off; 0 for a species with none.
##
## Reads `shell_absorb` first rather than its own key, so a row that names a hit
## count and forgets the amount is unshelled instead of being a plate that eats
## nothing while still swallowing six shots' worth of the player's time.
static func shell_hits(which: StringName) -> int:
	if shell_absorb(which) <= 0.0:
		return 0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return int(stats.get("shell_hits", 0))


## Is `which` a boss?
##
## Stated on the species rather than asked as `species == QUEEN` at the call site,
## which is what `WaveDirector.wave_carries_boss` did until a second boss existed.
## That comparison was correct and unextendable at the same time: the day a second
## boss landed it would have gone on answering `false` for it, silently, and the
## two things that read it — the HUD's "a boss is coming" note and the rule that
## drought never lands on a boss wave — would both have quietly stopped applying
## to half the bosses in the game. A flag on the row cannot do that: a boss added
## without it is a boss nobody claimed was one.
static func is_boss(which: StringName) -> bool:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return bool(stats.get("boss", false))


## Every species that is a boss, derived from the flag above rather than listed.
## In `SPECIES` order, which is insertion order and therefore stable to read and to
## compare against.
static func boss_species() -> Array[StringName]:
	var out: Array[StringName] = []
	for which: StringName in SPECIES:
		if is_boss(which):
			out.append(which)
	return out


## How far the Nurse Beetle's aura reaches, in pixels; 0.0 for a species with no
## aura. Same shape and same reason as shell_absorb() above — it is the GATE key,
## so the two below read it first and a row that names a rate and forgets the reach
## heals nothing rather than healing the whole board.
static func heal_radius(which: StringName) -> float:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("heal_radius", 0.0))


## Health put back into each pest in reach, per pulse. 0.0 without a reach.
static func heal_amount(which: StringName) -> float:
	if heal_radius(which) <= 0.0:
		return 0.0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("heal_amount", 0.0))


## Seconds between pulses. 0.0 without a reach, which is also what `_physics_process`
## tests to decide whether this pest has an aura at all.
static func heal_period(which: StringName) -> float:
	if heal_radius(which) <= 0.0:
		return 0.0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("heal_period", 0.0))


## The number the whole species is balanced on: health a second put back into one
## pest standing inside the aura. Pure, and the thing to compare against a plant's
## dps — `CornCobbler.single_target_dps(1, d)` is 1.25, and this sits above it and
## below twice it deliberately. See the NURSE entry.
##
## A pulse rate of zero answers 0.0 rather than dividing by it, so this is safe to
## call for every species in a sweep.
static func heal_per_second(which: StringName) -> float:
	var period: float = heal_period(which)
	if period <= 0.0:
		return 0.0
	return heal_amount(which) / period


## How near-motionless the Leafhopper's CROUCH half of its cycle is, as a
## fraction of its ordinary speed. A mechanic constant rather than a per-species
## stat — only one species hops today, and this is the definition of what
## "crouch" means, the same way PLATE_OUTER defines what "plate" means rather
## than living on the Shield Bug's own row.
const HOP_CROUCH_MULT: float = 0.10

## Seconds per full crouch-then-leap cycle; 0.0 for every species but the
## Leafhopper, which is also what `hop_speed_multiplier` and
## `_physics_process` test to decide whether a pest hops at all.
static func hop_period(which: StringName) -> float:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("hop_period", 0.0))


## What fraction of one hop cycle is spent crouched rather than leaping; 0.0
## without a period. Reads hop_period() first for the same "the gate key comes
## first" reason shell_hits() reads shell_absorb() and heal_amount() reads
## heal_radius() — a row naming a fraction and no period never hops at all.
static func hop_crouch_fraction(which: StringName) -> float:
	if hop_period(which) <= 0.0:
		return 0.0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("hop_crouch_fraction", 0.0))


## The leap's speed multiplier — DERIVED, not a third stored number. Chosen so
## the cycle's time-weighted average multiplier is always exactly 1.0:
## `fraction * HOP_CROUCH_MULT + (1.0 - fraction) * hop_leap_multiplier == 1.0`.
## That is what keeps a hopping species' `speed` meaning the same thing every
## other species' `speed` means — an average px/s over the whole crossing — so
## nothing reasoning about crossing time has to special-case this one, and a
## future tuning pass cannot desync the two halves of the cycle the way two
## independently hand-picked constants could.
static func hop_leap_multiplier(which: StringName) -> float:
	var fraction: float = hop_crouch_fraction(which)
	if fraction <= 0.0 or fraction >= 1.0:
		return 1.0
	return (1.0 - fraction * HOP_CROUCH_MULT) / (1.0 - fraction)


## Pure: this species' instantaneous speed multiplier `elapsed` seconds into its
## hop cycle. 1.0 (an ordinary, constant pace) for every species without a
## period, so this is safe to call for every species in a sweep the same way
## heal_per_second() is.
static func hop_speed_multiplier(which: StringName, elapsed: float) -> float:
	var period: float = hop_period(which)
	if period <= 0.0:
		return 1.0
	var t: float = fposmod(elapsed, period)
	if t < period * hop_crouch_fraction(which):
		return HOP_CROUCH_MULT
	return hop_leap_multiplier(which)


## How far the Locust's crowd sense reaches, in pixels; 0.0 for a species with
## no swarm mechanic. Same shape and same reason as heal_radius() above — the
## GATE key, so swarm_cap()/swarm_step() read it first.
static func swarm_radius(which: StringName) -> float:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("swarm_radius", 0.0))


## How many nearby Locusts the crowd bonus counts before it stops climbing; 0
## without a reach.
static func swarm_cap(which: StringName) -> int:
	if swarm_radius(which) <= 0.0:
		return 0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return int(stats.get("swarm_cap", 0))


## How much faster one more nearby Locust makes this one, as a fraction of its
## own base speed; 0.0 without a reach.
static func swarm_step(which: StringName) -> float:
	if swarm_radius(which) <= 0.0:
		return 0.0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return float(stats.get("swarm_step", 0.0))


## Pure: the speed multiplier for a pest with `neighbor_count` others of its own
## kind within reach, given a `cap` and a per-neighbor `step`. 1.0 at zero
## neighbours — alone, a Locust is exactly as fast as its own SPECIES row says
## and nothing about this mechanic makes it faster than that.
static func swarm_speed_multiplier(neighbor_count: int, cap: int, step: float) -> float:
	return 1.0 + float(clampi(neighbor_count, 0, cap)) * step


## Pure: how much of an `amount`-sized hit reaches the flesh under a plate with
## `blocks_left` blocks still on it.
##
## The whole species in one expression, and split out here precisely so it is
## assertable without a tree, a plant, or a projectile. Note what it does NOT do:
## it never consumes the block, because a pure function that mutated its own
## argument's meaning would make the interesting case — "what would a 1.0 kernel
## do right now" — impossible to ask without spending it.
##
## A hit at or under `strength` is stopped completely. It still costs the shell a
## block; the caller in take_damage() is where that happens, and the SHIELDBUG
## entry argues at length why counting hits rather than damage is the mechanic
## rather than an implementation detail.
static func damage_through_shell(amount: float, strength: float, blocks_left: int) -> float:
	if amount <= 0.0 or strength <= 0.0 or blocks_left <= 0:
		return amount
	return maxf(0.0, amount - strength)


## Endless mode's per-wave difficulty multipliers, from
## WaveDirector.health_scale_for / speed_scale_for. Called after setup(), which
## is what seeded the species defaults these scale.
##
## `health` moves with `max_health` rather than being left at the species value,
## so a scaled pest still spawns with a full bar — a beetle arriving at 16/48
## would read as pre-damaged and the bar would barely move for its first three
## hits. Mutations do not touch health or speed, so this composes with
## apply_mutation() in either order.
func apply_wave_scaling(health_multiplier: float, speed_multiplier: float) -> void:
	max_health *= health_multiplier
	health = max_health
	speed *= speed_multiplier


## Applies one wave-8+ trait. Called by whoever spawns this pest, after setup()
## so the sprite already exists to tint. A no-op for &"" (the common case).
##
## Setting the flag is what matters: markers() reads the flags, not `mutation`,
## so calling this twice leaves a pest wearing both marks rather than only the
## last one's. Nothing in the game does that today, but a Chomp already reads
## `is_winged` directly, and a cue that disagreed with the rule it advertises
## would be worse than no cue at all.
## Applies a mutation, composing onto whatever this pest already carries. Returns false
## and changes nothing when the trait is already present or cannot sit beside one that is
## — see `MUTATION_EXCLUSIONS` for the one pair that cannot, and why.
##
## The tint stays the PRIMARY's, deliberately. A blend of two hues is a third colour the
## player has never been taught, and the non-colour half of a mutation's read composes for
## free without it: `gait_swing` and `gait_rate` already take `is_armoured` and
## `is_winged`, and `gait_stretch` takes `is_hungry`, so a doubly-mutated pest MOVES like
## both while wearing one colour. That is the two-channel rule paying off in a case
## nobody designed it for.
func apply_mutation(which: StringName) -> bool:
	if not MUTATION_HUSK_MULTIPLIER.has(which):
		return false
	for existing: StringName in mutations:
		if not mutations_compose(existing, which):
			return false
	mutations.append(which)
	if mutation == &"":
		mutation = which
	match which:
		MUTATION_ARMOURED:
			is_armoured = true
			# The doc's "armoured" — a Chomp's mouth is tied up twice as long.
			chew_seconds *= 2.0
		MUTATION_WINGED:
			is_winged = true
		MUTATION_HUNGRY:
			is_hungry = true
	_tint(tint_for(mutation))
	queue_redraw()
	return true


## The hue for a mutation; white (i.e. untinted) for &"" and anything unknown.
static func tint_for(which: StringName) -> Color:
	if not MUTATION_TINT.has(which):
		return Color.WHITE
	var colour: Color = MUTATION_TINT[which]
	return colour


func _tint(colour: Color) -> void:
	if _sprite != null:
		_sprite.modulate = colour


## Sets the cosmetic skin and, unless a mutation has already claimed the sprite's
## colour, applies its tint through the same `_tint()` a mutation's own hue goes
## through above.
##
## A PEST SKIN IS STILL A TINT, and that is the one place the two sides of the board
## deliberately differ. `Plant._build_visuals` now takes `Color.WHITE` for a family
## with real art and loads that art instead, because a plant skin is a generated
## drawing with its own ramp and its own added geometry. There is no pest equivalent
## and there is not meant to be: `tools/gen_skin_svg.py` derives its stems from the
## PLANT catalogue, a pest is drawn at a fraction of a plant's tile (`SPECIES.scale`)
## where a crown or three ice shards would be noise rather than silhouette, and five
## species times three families is fifteen more drawings bought for nothing. So this
## function keeps reading `Skins.tint_for`, which is exactly why `tint` stays on every
## FAMILIES row even for the families a plant no longer multiplies by.
##
## A MUTATION STILL WINS OUTRIGHT, exactly the priority `apply_mutation`'s own
## comment states for two mutations composing onto one tint: MUTATION_TINT carries
## gameplay information (see that constant's header) and a skin carries none, so a
## skin never has an opinion once a mutation has one. `setup()` calls this before
## any mutation can have landed, so the ordinary case is simply "wear the skin";
## the guard only matters for a pest skinned and then mutated in the same frame
## (`Game.spawn_pest` applies mutations after `_new_pest` finishes `setup()`).
func set_pest_skin(id: StringName) -> void:
	skin_id = id
	if mutation == &"":
		_tint(Skins.tint_for(skin_id))


## Which silhouette marks this pest wears. Pure and flag-driven, so a pest
## carrying two traits reports both, a plain pest reports none, and a test can
## ask the question without a viewport, a frame, or a pixel.
func markers() -> Array[StringName]:
	return markers_for(is_armoured, is_winged, is_hungry)


## Draw order: plates first so they sit under wings and jaws — a plated bug
## that also flies should read as "plated, and also winged", not as a shell
## with something scribbled over it.
static func markers_for(armoured: bool, winged: bool, hungry: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if armoured:
		out.append(MARKER_PLATES)
	if winged:
		out.append(MARKER_WINGS)
	if hungry:
		out.append(MARKER_JAWS)
	return out


func _build_visuals(texture_path: String, sprite_scale: float) -> void:
	_sprite_scale = sprite_scale
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)

	# Recorded rather than local: `_apply_carry()` re-places both bars at
	# `_bar_origin + _carry_offset` every frame a Chomp is holding this pest, and it
	# has no other way to recover where they sit at rest.
	_bar_origin = Vector2(-HEALTH_BAR_SIZE.x * 0.5, health_bar_top_for(sprite_scale))
	var bar_origin := _bar_origin

	_health_back = ColorRect.new()
	_health_back.color = Color(0.12, 0.12, 0.12, 0.65)
	_health_back.position = bar_origin
	_health_back.size = HEALTH_BAR_SIZE
	_health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_back)

	_health_bar = ColorRect.new()
	_health_bar.color = GardenTheme.LEAF
	_health_bar.position = bar_origin
	_health_bar.size = HEALTH_BAR_SIZE
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_bar)


## Every Control this pest owns stops taking mouse input.
##
## The same defect Plant._make_world_controls_click_through() documents at
## length, on a target that moves. A Control parented to a Node2D is picked by
## the viewport's GUI pass in world space, and that pass runs before the
## `_unhandled_input` Game._click_at lives in — so a pest's 32x5 bar at the
## default MOUSE_FILTER_STOP is a strip of board where the player's clicks stop
## existing, and it walks the road at `speed` px/s.
##
## Worse here than on a plant, in a way worth naming: every husk in the game
## lands on the road (Board.route() is one point per road cell, and pests only
## ever walk it), so this bar drifts over the compost the player is trying to
## sweep and blanks the only click that would collect it. A plant's bar sits
## still and can at least be clicked around.
##
## Runs once from setup(), after the bars exist — a pest has no subclasses and
## builds nothing later, so there is no second call site to keep in step.
func _make_world_controls_click_through() -> void:
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The mutation cues. Drawn here rather than in a child node because Pest has no
## subclasses — the trap SelectionMarker exists to dodge (CornCobbler and
## ChompFlower each fully override Plant._draw() and never chain to super) has no
## instance on this side of the board. If a Pest subclass ever appears, the fix
## is `super._draw()` in it, and the per-marker methods below are already split
## out so it can reuse them piecemeal.
##
## Note that a Node2D paints its own canvas item BEFORE its children, so every
## shape here lands *behind* the sprite. That is why the geometry sits at and
## past the silhouette edge: a marker drawn over the body would simply not exist.
func _draw() -> void:
	if not _alive:
		return
	# The markers, the plates and the fought ring belong to the BODY, and a Chomp can be
	# holding the body somewhere this node is not. Shifting the whole canvas item once
	# here keeps every shape below written against Vector2.ZERO, which is what makes them
	# assertable as geometry rather than as geometry-plus-a-carry.
	if _carry_offset != Vector2.ZERO:
		draw_set_transform(_carry_offset)
	var r: float = SPRITE_HALF * _sprite_scale
	for marker: StringName in markers():
		match marker:
			MARKER_PLATES:
				_draw_plates(r)
			MARKER_WINGS:
				_draw_wings(r)
			MARKER_JAWS:
				_draw_jaws(r)
	# Outside the marker loop, and not in MARKER_SOURCE: the three markers above say
	# what this pest IS and are derived from its mutations, where this says what has
	# been DONE to it. Folding it in would put it in `markers()`, which several tests
	# read as the mutation list.
	if _shows_fought_mark:
		_draw_fought_mark()


func _draw_plates(r: float) -> void:
	draw_arc(Vector2.ZERO, r * PLATE_OUTER, PLATE_FROM, PLATE_TO, PLATE_SEGMENTS,
		marker_ink(MARKER_PLATES), PLATE_WIDTH, true)
	draw_arc(Vector2.ZERO, r * PLATE_INNER, PLATE_FROM, PLATE_TO, PLATE_SEGMENTS,
		marker_fill(MARKER_PLATES), PLATE_SEAM_WIDTH, true)


func _draw_wings(r: float) -> void:
	for sx: float in [-1.0, 1.0]:
		var mirror := Vector2(sx, 1.0)
		_draw_marker_shape(PackedVector2Array([
			WING_ROOT_IN * mirror * r,
			WING_TIP * mirror * r,
			WING_TIP_OUT * mirror * r,
			WING_ROOT_OUT * mirror * r,
		]), MARKER_WINGS)


func _draw_jaws(r: float) -> void:
	var middle: float = float(JAW_TEETH - 1) * 0.5
	for i: int in range(JAW_TEETH):
		var cx: float = (float(i) - middle) * JAW_SPACING * r
		_draw_marker_shape(PackedVector2Array([
			Vector2(cx - JAW_HALF_WIDTH * r, JAW_TOP * r),
			Vector2(cx + JAW_HALF_WIDTH * r, JAW_TOP * r),
			Vector2(cx, JAW_TIP * r),
		]), MARKER_JAWS)


## The rendering of `_shows_fought_mark`, and nothing more — every decision it makes
## is read out of the two pure functions above so the picture is checkable headless.
func _draw_fought_mark() -> void:
	var radius: float = fought_ring_radius(_sprite_scale)
	for dash: Vector2 in fought_ring_dashes():
		draw_arc(Vector2.ZERO, radius, dash.x, dash.y, FOUGHT_RING_SEGMENTS,
			FOUGHT_RING_COLOR, FOUGHT_RING_WIDTH, true)


## Filled light shape with a darker rim of its own hue — STYLE.md's rule, so a
## drawn marker sits in the same visual language as the authored sprites.
func _draw_marker_shape(points: PackedVector2Array, marker: StringName) -> void:
	draw_colored_polygon(points, marker_fill(marker))
	var rim: PackedVector2Array = points.duplicate()
	rim.append(points[0])
	draw_polyline(rim, marker_ink(marker), MARKER_LINE, true)


static func marker_fill(marker: StringName) -> Color:
	var colour: Color = tint_for(_marker_source(marker)).lightened(MARKER_LIGHTEN)
	colour.a = MARKER_ALPHA
	return colour


static func marker_ink(marker: StringName) -> Color:
	var colour: Color = tint_for(_marker_source(marker)).darkened(MARKER_DARKEN)
	colour.a = MARKER_ALPHA
	return colour


static func _marker_source(marker: StringName) -> StringName:
	if not MARKER_SOURCE.has(marker):
		return &""
	var source: StringName = MARKER_SOURCE[marker]
	return source


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	# Before the held/eating guards below on purpose: a pest in a Chomp's mouth
	# or chewing a bed is still a live creature, and freezing it solid the moment
	# it stopped travelling would put the static sprite back exactly where the
	# player is looking hardest.
	_gait(delta)
	# Split out of the combined guard this used to share with `_alive`: being held
	# is the one non-damaging way the garden engages a pest, and a Chomp that is
	# destroyed mid-chew releases it unharmed. See _ever_engaged.
	if held_by != null:
		_mark_engaged()
		return
	# The Nurse Beetle's aura, and note where it sits: AFTER the `held_by` return
	# above, so a Chomp that closes on a Nurse silences her for the whole
	# `chew_seconds` rather than merely holding a still-nursing pest in place. That
	# is what makes the Chomp one of the two real answers to this species instead of
	# a body block that changes nothing. BEFORE the `is_hungry` branch below on
	# purpose too: a Nurse stopped at a plant bed is not being held by anything, and
	# a wave allowed to stand still healing itself while the player watches would be
	# the worst version of this fight.
	_tick_aura(delta)
	# The Barrier Bramble, and note that it is checked for EVERY pest rather than behind
	# a mutation the way the meal below is. That is the whole of what the plant sells: a
	# wall the ordinary aphid walks past is not a wall.
	#
	# It sits ABOVE the `is_hungry` branch on purpose. Both branches end in a bite and
	# both return, so the order only matters when a pest could satisfy both at once — a
	# hungry pest standing on a Bramble with a cob one cell off the road. Whichever wins,
	# something gets eaten; putting the wall first means the thing in its way is what it
	# eats, which is what a player watching it expects. The alternative has a hungry pest
	# reaching PAST the plant blocking it to chew something behind, and no picture of that
	# reads as anything but a bug.
	var wall: Bramble = _blocking_plant()
	if wall != null:
		# Held by the garden, so a pest that only ever met a Bramble still counts as
		# engaged -- the same reason `held_by` marks it above. A wave stalled at a wall
		# and shot dead by the cobs behind it was fought, not ignored.
		_mark_engaged()
		wall.take_damage(EAT_DPS * delta)
		return
	if is_hungry:
		var meal: Plant = _adjacent_plant()
		if meal != null:
			meal.take_damage(EAT_DPS * delta)
			return
	# The Leafhopper's clock only advances here, in the one branch that actually
	# walks the pest — the same rule `_heal_clock` follows and for the same
	# reason: a held or blocked pest is not hopping either, so its cycle waits
	# rather than running unseen and handing it a fresh crouch the instant it is
	# free to move again.
	if hop_period(species) > 0.0:
		_hop_clock += delta
	_advance(delta * _effective_speed())


## The doc's "hungry" trait: eats the plant instead of walking past. Only ever
## looks at the lane it is currently beside — same one-cell reach as a Chomp's
## grab, so a hungry pest cannot reach across the road to a different lane.
## The Barrier Bramble standing in this pest's way, or null.
##
## Deliberately shaped like `_adjacent_plant()` below rather than like something
## cleverer, and the two differ in exactly three ways, each of which is the mechanic:
##
##   * the radius. `Bramble.STOP_RADIUS` is 0.6 of a cell against EAT_RADIUS's 1.15,
##     because a Bramble is ON the road and a meal is one cell OFF it. Its header has
##     the geometry.
##   * the type. `as Bramble` is the whole "which plants block" question, so there is no
##     second list of blocking ids to drift from `PlantCatalog.on_road`.
##   * the wings. `Bramble.stops()` is asked rather than `is_winged` read directly, for
##     the reason `mutation_markers()` gives about cues that re-decide a rule: the plant
##     owns its own counter, and a pest re-deriving it is how the shop line and the
##     behaviour end up disagreeing.
##
## It walks the tree-global `plants` group, which `.claude/skills/godot-test-isolation`
## warns can return a second Game's plants when the suite hosts two scenes at once. That
## is a known and accepted shape here because `_adjacent_plant()` has always had it and
## a divergence between the two would be worse than the shared hazard; the pest-side
## tests build one board.
func _blocking_plant() -> Bramble:
	if not Bramble.stops(is_winged):
		return null
	for node: Node in get_tree().get_nodes_in_group("plants"):
		var wall := node as Bramble
		if wall == null or wall.is_destroyed():
			continue
		if wall.global_position.distance_to(global_position) <= Bramble.STOP_RADIUS:
			return wall
	return null


func _adjacent_plant() -> Plant:
	var best: Plant = null
	var best_distance: float = EAT_RADIUS
	for node: Node in get_tree().get_nodes_in_group("plants"):
		var plant := node as Plant
		if plant == null or plant.is_destroyed():
			continue
		var d: float = plant.global_position.distance_to(global_position)
		if d <= best_distance:
			best_distance = d
			best = plant
	return best


## One frame of the Nurse Beetle's aura clock. A no-op for every other species,
## which is why `_physics_process` calls it unconditionally rather than behind a
## species check — the same shape as the plate in `take_damage()`, where an
## unshelled pest simply has nothing to block with.
##
## A `while` rather than an `if`: a frame long enough to span two periods (a stall,
## or a headless test stepping a whole second by hand) owes the wave two pulses,
## and a heal rate that quietly halves itself under load is a difficulty setting
## nobody chose.
func _tick_aura(delta: float) -> void:
	var period: float = heal_period(species)
	if period <= 0.0:
		return
	_heal_clock += delta
	while _heal_clock >= period:
		_heal_clock -= period
		pulse_aura()


## Put `heal_amount(species)` back into every OTHER living pest within
## `heal_radius(species)`. One pulse of the aura.
##
## Public on purpose. It is the entire species, and a test that had to pump sixty
## physics frames to watch it happen once would be measuring the frame pump; the
## bridge can also fire it against a live board with
## `run-method --node ... --method pulse_aura`.
##
## It never heals ITSELF, for exactly the reason `Aloe.reaches` refuses
## `from_cell == to_cell`: a boss that also repairs its own bar is a bigger health
## pool wearing a mechanic's name, and this species exists so the difficulty sits
## somewhere other than its own bar.
##
## It DOES heal another Nurse. Two inside one aura would top each other up for as
## long as they both live, which is why no wave schedules two — asserted in
## test_combat rather than left to whoever edits the table next.
func pulse_aura() -> void:
	if not _alive or not is_inside_tree():
		return
	var reach: float = heal_radius(species)
	if reach <= 0.0:
		return
	var amount: float = heal_amount(species)
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var other := node as Pest
		if other == null or other == self or not other.is_alive():
			continue
		if other.global_position.distance_to(global_position) > reach:
			continue
		other.heal(amount)


## How many OTHER living Locusts are within `radius` of this one. The live half
## of the swarm mechanic — walks the same tree-global "pests" group
## `pulse_aura()` above already reads, for the same reason: a second, private
## way to ask "who is nearby" is how the Nurse's aura and a Locust's crowd sense
## end up disagreeing about what counts as a neighbour.
##
## Same species only, deliberately — a Locust does not read a nearby aphid or
## beetle as part of its crowd, which is what makes this a rule about Locusts
## interacting with EACH OTHER rather than a second, quieter version of the
## Nurse's aura reading every pest on the board.
func _swarm_neighbor_count(radius: float) -> int:
	if not is_inside_tree():
		return 0
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var other := node as Pest
		if other == null or other == self or other.species != species or not other.is_alive():
			continue
		if other.global_position.distance_to(global_position) <= radius:
			count += 1
	return count


## This pest's actual px/s right now, folding in whichever of the two movement
## mechanics (if either) its species carries. Every other species simply
## answers `speed`, unmodified — the same "an ordinary pest has nothing to
## apply" shape `damage_through_shell` and `pulse_aura`'s reach guard both use.
##
## The two branches are mutually exclusive by construction (`SPECIES` gives
## `hop_period` and `swarm_radius` to different rows), so there is no ordering
## decision buried here the way there is between the Bramble and a hungry
## pest's meal in `_physics_process`.
func _effective_speed() -> float:
	if hop_period(species) > 0.0:
		return speed * hop_speed_multiplier(species, _hop_clock)
	var reach: float = swarm_radius(species)
	if reach > 0.0:
		var neighbors: int = _swarm_neighbor_count(reach)
		return speed * swarm_speed_multiplier(neighbors, swarm_cap(species), swarm_step(species))
	return speed


## Pure: what a pest on `health_now` out of `ceiling` sits at after `amount` of
## healing. Never past the ceiling, and never backwards — a negative amount heals
## nothing rather than turning a nurse into a second mouth, which is the guard
## `Aloe.heal_for` spends its own `maxf` on.
static func healed_to(health_now: float, amount: float, ceiling: float) -> float:
	return minf(ceiling, health_now + maxf(0.0, amount))


## Restore health and repaint the bar.
##
## A dead pest is left alone. A corpse is on screen for DEATH_LINGER seconds and a
## Nurse pulsing over one must not stand it back up — `_alive` is already false by
## then and `died` has already been emitted, so the seeds and the husk are paid.
func heal(amount: float) -> void:
	if not _alive:
		return
	health = healed_to(health, amount, max_health)
	_refresh_health_bar()


## The one place the health bar's width is written. Split out of `take_damage()`
## when healing arrived: two callers each computing the same fraction is how a bar
## ends up honest about damage and stale about repair.
func _refresh_health_bar() -> void:
	if is_instance_valid(_health_bar):
		_health_bar.size = Vector2(HEALTH_BAR_SIZE.x * (health / max_health), HEALTH_BAR_SIZE.y)


## Walk `distance` px along the remaining route, spending it across legs so a fast
## pest cannot skip a corner at low frame rates.
##
## WHERE THE END OF THE ROAD IS, since two different numbers get called "the last leg"
## and confusing them is a live bug this project has already paid for once.
##
## `_leg` is the waypoint index being walked TOWARD, so on a route of N points:
##
##   * `N - 1` is the last leg the model has. `enter_road_at` clamps to exactly it,
##     and a pest sitting on it is on its FINAL STEP — reaching `_route[N - 1]` takes
##     `_leg` to `N`, and the next pass round this loop escapes.
##   * `N - 2` is the last leg with a whole leg of road still in front of it. That is
##     not a rule of the game — it is what a test needs, because `instantiate_scene`
##     pumps settle frames that call this function before the test body runs, and a
##     pest parked on its final step is freed by them.
##
## The second number is therefore deliberately NOT exposed here: it is a fact about
## the harness, not about a bug walking a road, and a `Pest` method returning `N - 2`
## would state as a game rule something only a hosted test cares about. It is written
## down instead as `test_the_last_leg_of_a_route_is_the_one_a_pest_escapes_off`
## (test/unit/test_combat.gd), which pins both numbers against this loop.
func _advance(distance: float) -> void:
	while distance > 0.0:
		if _leg >= _route.size():
			_escape()
			return
		var target: Vector2 = _route[_leg]
		var to_target: Vector2 = target - position
		_update_facing(to_target)
		var gap: float = to_target.length()
		if gap <= distance:
			position = target
			distance -= gap
			_leg += 1
		else:
			position += to_target / gap * distance
			distance = 0.0


## Turns the sprite to face the leg it is currently walking. `PATH_CORNERS`
## (Board.gd) is expanded to one waypoint per grid cell, so every leg of the
## route is axis-aligned — never a diagonal — which is what makes a snap to
## one of the four cardinal rotations exactly right rather than an approximation.
##
## Only `_sprite` rotates, not this Node2D: the health bar and the mutation
## markers (`_draw()`, drawn on the Pest's own canvas item) are deliberately
## screen-locked — PLATE_FROM/PLATE_TO already carve out the top of the ring
## because "the health bar lives up there", and a marker that spun with travel
## direction would fight that same fixed layout.
##
## STYLE.md's convention is up-screen (-Y) at rest, i.e. rotation 0 here; the
## other three are 90-degree turns off that art, which Godot's rotation turns
## clockwise: +90 deg (PI/2) faces +X (right), 180 deg faces +Y (down), -90 deg
## faces -X (left).
## Which way this pest is walking, as a unit vector in the parent's space.
##
## Derived from `_facing` rather than from `_route[_leg] - position`, and the difference
## matters at exactly one moment: a pest standing ON its next waypoint has a zero-length
## leg vector and would answer `Vector2.ZERO`, while `_facing` still holds the direction
## it arrived travelling. `_update_facing` snaps it to one of four cardinals and runs on
## every advance, including once at spawn (see `_build_route`), so this is exact from the
## first frame and never mid-turn.
##
## Kept through a stall on purpose. A pest held in a Chomp, stopped by a Bramble or
## chewing a plant bed is not advancing, and the last direction it walked is the honest
## answer to "which way is this bug facing" — `corpse_rotation()` already relies on the
## same property.
##
## STYLE.md's convention is up-screen at rest, so `Vector2.UP.rotated(_facing)` is the
## heading `_facing` was built to describe.
func travel_direction() -> Vector2:
	return Vector2.UP.rotated(_facing)


func _update_facing(direction: Vector2) -> void:
	if _sprite == null:
		return
	if absf(direction.x) < 0.01 and absf(direction.y) < 0.01:
		return
	if absf(direction.x) > absf(direction.y):
		_facing = PI / 2.0 if direction.x > 0.0 else -PI / 2.0
	else:
		_facing = PI if direction.y > 0.0 else 0.0
	_apply_facing()


## The one place `_sprite.rotation` is written. Facing and gait each own one
## term of the sum and neither can clobber the other; with animations off
## `_sway` is a standing 0.0, so this reduces to exactly the bare cardinal
## rotation that shipped before the gait existed — a correct static state, not
## a half-applied transform.
func _apply_facing() -> void:
	if _sprite != null:
		_sprite.rotation = _facing + _sway


## One step of the walk cycle. Advances the clock unconditionally, the same way
## Plant._wobble() does, so a mid-run animations toggle picks up a meaningful
## phase instead of every pest on the board snapping from a frozen 0.
func _gait(delta: float) -> void:
	_gait_time += delta
	# Decayed OUTSIDE the gate, for the same reason the clock above advances outside it:
	# a mid-run animations toggle should find a meaningful recoil, not one frozen at
	# whatever it held when the toggle went off. Plant._wobble() decays its own for the
	# same reason.
	_flinch_left = maxf(0.0, _flinch_left - delta)
	# Composed ABOVE the gate -- see gait_compute()'s own header for why. Cheap (four
	# pure calls and two sines) even on the frames it is about to be thrown away.
	var composed: Dictionary = gait_compute(_gait_time, _gait_phase, speed, is_armoured,
		is_winged, is_hungry, _flinch_left, _flinch_force)
	if _sprite == null or not GardenTheme.animations_enabled():
		return
	_sway = composed["yaw"]
	_apply_facing()
	# Local to the sprite, so it follows the facing rotation: -Y is the body's
	# long axis (STYLE.md's up-screen convention), which makes +Y stretch a
	# lengthening and -X squash a narrowing, whichever way the bug is walking.
	var stretch: float = composed["stretch"]
	# chewed_scale() rides the gait rather than being a separate tween: the gait
	# rewrites _sprite.scale every frame, so a tween on the same property would be
	# overwritten within one frame and look like nothing happened.
	var eaten: float = chewed_scale()
	_sprite.scale = Vector2(_sprite_scale * eaten * (1.0 - stretch), _sprite_scale * eaten * (1.0 + stretch))


## Pure: the whole walk-cycle composition `_gait` writes, with no gate and no sprite.
## Everything past `animations_enabled()` inside `_gait` used to be unobservable
## headless -- the four calls this makes (`gait_rate`, `gait_yaw`, `gait_swing`,
## `flinch_amount`, `gait_stretch`) each already have their own tests, but nothing
## could assert `_gait` actually reached them rather than a constant
## (plant-tower-defense-3k81; measured: replacing either the `gait_swing(...)` or the
## `gait_stretch(...)` call-site result with `0.0` survived the full suite with zero
## failures). Split out the same way `flash_hit` arms its recoil before its own gate
## and `ChompFlower.champ_scale` is split from `idle_scale_multiplier`: the
## composition moves above the gate, the sprite write stays below it, gated.
##
## Returns `{"yaw": float, "stretch": float}` -- a Dictionary, this file's own
## convention for a multi-value pure return, rather than a bespoke struct.
static func gait_compute(gait_time: float, phase: float, for_speed: float, armoured: bool,
		winged: bool, hungry: bool, flinch_left: float, flinch_force: float) -> Dictionary:
	var clock: float = gait_time * gait_rate(for_speed, armoured, winged) + phase
	var yaw: float = gait_yaw(sin(clock), gait_swing(armoured, winged),
		sin(gait_time * FLINCH_RATE), flinch_amount(flinch_left) * flinch_force)
	var stretch: float = gait_stretch(sin(clock * GAIT_STRETCH_RATE), hungry)
	return {"yaw": yaw, "stretch": stretch}


## Pure: how fast this pest's walk cycle runs, in radians of clock per second.
## Split out (with the two below) so the whole gait is assertable without a
## viewport, a frame, or animations being on at all.
static func gait_rate(for_speed: float, armoured: bool, winged: bool) -> float:
	var scaled: float = clampf(for_speed / GAIT_REFERENCE_SPEED, GAIT_RATE_MIN, GAIT_RATE_MAX)
	var rate: float = GAIT_RATE * scaled
	if winged:
		rate *= WINGED_RATE_MULTIPLIER
	if armoured:
		rate *= ARMOURED_RATE_MULTIPLIER
	return rate


## Pure: peak yaw either side of the direction of travel, in radians. Both
## multipliers apply to a pest carrying both traits — markers_for() promises the
## same thing about the drawn marks, and a gait that quietly picked one would
## contradict a rule this file already advertises.
static func gait_swing(armoured: bool, winged: bool) -> float:
	var swing: float = GAIT_SWING
	if winged:
		swing *= WINGED_SWING_MULTIPLIER
	if armoured:
		swing *= ARMOURED_SWING_MULTIPLIER
	return swing


## Pure: the body-axis stretch for one point of the stride wave (`wave` in
## -1..1). A hungry pest's is cubed rather than merely larger: cubing flattens
## the middle of the wave and keeps the extremes, so the body sits still and
## then snaps — a lunge. Raising the amplitude alone would only have given the
## same scuttle, bigger.
static func gait_stretch(wave: float, hungry: bool) -> float:
	if hungry:
		return wave * wave * wave * GAIT_STRETCH * HUNGRY_STRETCH_MULTIPLIER
	return wave * GAIT_STRETCH


## Pure: how much recoil is left, as a 0..1 fraction, with `left` seconds on the clock.
##
## Clamped at the top rather than allowed past 1.0 so a pest under continuous fire —
## flash_hit() re-arms this every connecting shot — shudders at a fixed amplitude
## instead of winding up into a spin.
static func flinch_amount(left: float) -> float:
	return clampf(left / FLINCH_SECONDS, 0.0, 1.0)


## Pure: the total yaw the gait puts on the sprite, added to `_facing`.
##
## Split out (with the three above) for the reason `Plant.sway_transform` was: everything
## in `_gait` past the `animations_enabled()` gate is unreachable headless, so a test that
## pumps `_gait` and reads `_sprite.rotation` is asserting an early return. This is the
## seam the suite actually asserts against.
static func gait_yaw(wave: float, swing: float, flinch_wave: float, flinch: float) -> float:
	return wave * swing + flinch_wave * FLINCH_RADIANS * flinch


## Pure: the phase the `index`-th pest spawned this run walks on.
static func gait_phase(index: int) -> float:
	return fposmod(float(index) * GAIT_PHASE_STEP, TAU)


## `knockback` is the offset a corpse is shoved by if THIS hit is the one that kills —
## per call, never remembered, so a kernel a pest survived cannot shove the body a
## Chomp finishes ten seconds later. Callers that know where their hit came from build
## it with `knockback_offset()` (see `Kernel._physics_process`); `Vector2.ZERO`, the
## default, is a corpse that lies where it fell.
func take_damage(amount: float, cause: StringName = &"", knockback: Vector2 = Vector2.ZERO) -> void:
	if not _alive:
		return
	# A zero-damage call is not an engagement. Nothing in the game makes one
	# today, but `amount` is a float off a kernel and a plant level table, and
	# "something shot at it" must mean something landed.
	if amount > 0.0:
		_mark_engaged()
	# The plate. `landed` is what actually reaches the bug; a block is spent on any
	# damaging hit at all, whether it got through or not, which is the Shield Bug's
	# whole small-versus-big axis (see its SPECIES entry). A zero-damage call spends
	# nothing — nothing was fired.
	var landed: float = amount
	_last_hit_blocked = false
	if amount > 0.0 and shell_blocks > 0:
		landed = damage_through_shell(amount, shell_strength, shell_blocks)
		_last_hit_blocked = landed <= 0.0
		shell_blocks -= 1
	health = maxf(0.0, health - landed)
	_refresh_health_bar()
	if health <= 0.0:
		kill(cause, knockback)


## Pure: what `flash_hit` boosts a sprite's current tint towards for the flash's
## rising half — alpha untouched, so a partially transparent state (mid death
## fade, say) stays exactly as transparent while it flashes. Split out so the
## picture is checkable without a live tree, a Tween, or animations turned on.
static func hit_flash_color(base: Color) -> Color:
	return Color(base.r * HIT_FLASH_BOOST, base.g * HIT_FLASH_BOOST, base.b * HIT_FLASH_BOOST, base.a)


## Pure: what a hit the PLATE ATE flashes towards instead.
##
## A Shield Bug's whole difficulty is hits that do nothing, and until this existed a
## blocked hit and a landed one were pixel-for-pixel the same event — `flash_hit()`
## fires on both, because from the caller's side both are "a hit the pest survived".
## A player watching six kernels bounce would have seen six ordinary hits and
## concluded the health bar was broken.
##
## Down rather than up, which is the point: `HIT_FLASH_BOOST` multiplies the
## channels above 1.0 and this multiplies them below it, so the two read as a bright
## flash against a dull thud **on the same channel, in the same direction the
## player already understands** — brighter means it hurt. That survives the colour
## being thrown away (a greyscale screenshot separates them just as well), which is
## `game/OVERLAY_GRAMMAR.md`'s one rule with teeth.
##
## Deliberately not a new drawn cue. The grammar file's table is the vocabulary for
## marks drawn in code, and adding a row to it fails the suite until the notebook's
## cue legend teaches the new shape — the right cost for a shape, and the wrong one
## for what is really just the existing hit flash saying "no". Alpha is left alone
## for the same reason `hit_flash_color` leaves it alone.
const SHELL_FLASH_DIM: float = 0.45


static func shell_flash_color(base: Color) -> Color:
	return Color(base.r * SHELL_FLASH_DIM, base.g * SHELL_FLASH_DIM, base.b * SHELL_FLASH_DIM, base.a)


## The visual tell for a hit this pest survived. Called by Kernel right after a
## connecting take_damage() that did NOT kill — see HIT_FLASH_DURATION's comment
## for why a lethal hit does not also call this (it has its own, bigger cue).
##
## Two peaks now, not one: bright for a hit that landed, dull for one a Shield Bug's
## plate ate. `_last_hit_blocked` is CONSUMED here rather than merely read, because
## the third caller is `StickySundew` (game/sticky_sundew.gd:281), which flashes a
## pest it never damaged — without the reset, a sundew's flash would inherit the
## verdict of whatever kernel happened to hit that pest last.
##
## Gated the same way every cosmetic Tween in this game is: headless pumps no
## frames, so a Tween queued there never runs and this is a silent no-op rather
## than a wasted node. The reset is therefore deliberately BEFORE the gate — a flag
## that outlived an animations-off session would come back stale.
## `glancing` is the caller saying THIS CUE DID NOT FOLLOW DAMAGE
## (plant-tower-defense-zdy2). Default false, so the three damaging callers — Kernel,
## SeedBomb and Nettle — are untouched and say nothing.
func flash_hit(glancing: bool = false) -> void:
	var blocked: bool = _last_hit_blocked
	_last_hit_blocked = false
	# The recoil is armed HERE, beside the flash and before the gate, because the two are
	# one cue: the flash says a hit landed in colour and this says it in motion, and a
	# pest that spoke on only one of the two channels is the thing this pair exists to
	# stop. Before the gate for the same reason the reset above is — a value armed only
	# on animated machines is a value the decay in _gait() can never clear.
	#
	# AND NOW THE TWO CHANNELS READ THE SAME VERDICT, which they did not
	# (plant-tower-defense-zdy2). The colour has always split a hit three ways — 1.9x
	# brighter for one that landed, 0.45x DIMMER for one a Shield Bug's plate ate — and the
	# recoil split it none, so a plate-blocked hit said "that did nothing" in colour and
	# "that hit hard" in motion IN THE SAME FRAME. That is a contradiction rather than a
	# judgement, and it is the half of this the bead did not see.
	_flinch_force = GLANCE_FLINCH_SCALE if (blocked or glancing) else 1.0
	_flinch_left = FLINCH_SECONDS
	if not _alive or _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var base: Color = _sprite.modulate
	var peak: Color = shell_flash_color(base) if blocked else hit_flash_color(base)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", peak, HIT_FLASH_DURATION * 0.35)
	tween.tween_property(_sprite, "modulate", base, HIT_FLASH_DURATION * 0.65)


## Death by any cause — kernels, or a Chomp finishing its meal.
##
## Everything the corpse needs is settled here, before `died` is emitted and long
## before `_play_death()` reaches an animation gate: the cause, the shove, and how long
## the body holds. `died`'s listeners run in between (Game pays the seeds and drops the
## husk), so a value composed later than this is a value the corpse could disagree with.
func kill(cause: StringName = &"", knockback: Vector2 = Vector2.ZERO) -> void:
	if not _alive:
		return
	_alive = false
	_death_cause = cause
	_death_knockback = knockback
	# A hard-won kill lingers longer than an easy one (plant-tower-defense-rowt). Read
	# here rather than in `_play_death()` because `husk_multiplier()` is the price this
	# same death is about to be paid at, and the corpse should outlast the aphid beside
	# it by exactly the ratio the husk does.
	_death_linger = death_linger_for(husk_multiplier())
	if held_by != null and held_by.has_method("release"):
		held_by.call("release")
	died.emit(self)
	_play_death()


## Swaps in the doc's "X-eyed pest" corpse sprite and lingers a beat before
## freeing, rather than the pest just vanishing — a separate sprite, not a tint,
## per the sprite-pass-2 ask. Deferred so a listener of `died` (Game awards
## seeds and drops a compost husk) still sees a valid global_position.
func _play_death() -> void:
	set_physics_process(false)
	if _health_back != null:
		_health_back.visible = false
	if _health_bar != null:
		_health_bar.visible = false
	# set_physics_process(false) above stops the gait but does not undo it, and a
	# corpse frozen at whatever quarter of a stride it died on reads as a bug
	# still leaning into a step. Put the sprite back on its facing and its own
	# scale so the husk lies straight under the fade below. `_facing` is kept,
	# not zeroed: a beetle killed walking left should lie facing left.
	if _sprite != null:
		_sway = 0.0
		_sprite.rotation = corpse_rotation()
		_sprite.scale = corpse_scale()
		# The third corpse channel, and the only one that is a POSITION. Written here
		# unconditionally, above the gate below, for the same reason the rotation and
		# the scale are: with animations off this is the corpse's whole static state,
		# and a shove that only existed inside a Tween would be a cue no headless run
		# and no unit test could ever see.
		#
		# Written on the CHILD, so the Pest node — the thing `Game._on_pest_died`
		# already read a husk position off — never moves. `_sprite.position` lives in
		# this node's space, and a Pest is placed by Board and never rotated or scaled
		# (only `_sprite` is), so the global-space direction the killer measured is the
		# same vector here with no basis change. `_sprite.position` is otherwise
		# unwritten on a Pest: nothing else in this class can fight it for the channel.
		# Plus the carry: a bug killed in a Chomp's mouth is up on the flower, and a
		# corpse that appeared one cell away on the path at the instant of the kill was
		# the whole reason `set_carried(false)` refuses to let go of a dead pest.
		# `_carry_offset` is Vector2.ZERO for every death that is not a Chomp's meal.
		_sprite.position = death_knockback() + _carry_offset
	if _dead_texture != null and _sprite != null:
		_sprite.texture = _dead_texture
		_sprite.modulate = Color.WHITE
	# The corpse drops the tint, so it drops the markers with it — a dead pest
	# still wearing wings would read as a threat the player still has to answer.
	queue_redraw()
	if not is_inside_tree():
		queue_free()
		return
	# Bound to self: Godot kills a node's own tweens when the node frees, so a
	# teardown that frees the tree immediately (free_ui, not queue_free) never
	# fires this callback on a dangling instance.
	var tween := create_tween()
	if GardenTheme.animations_enabled():
		# Full opacity for most of the linger, then fade the tail end — same
		# "hold, then go" shape as the rest of a corpse's beat, just on alpha
		# instead of a callback. Plant.play_exit_and_free() is the reference:
		# a tween on the way off the board, gated the same way.
		#
		# DEATH_FADE stays a fixed tail while the HOLD is what a hard kill lengthens:
		# scaling both would give a queen the same shape of exit as an aphid, only
		# slower, and a fade stretched to 0.45s reads as the game hitching. So the
		# hold is `death_linger() - DEATH_FADE`, which `death_linger_for`'s floor of
		# 1.0 keeps comfortably positive (0.20s at worst) rather than swallowing it.
		tween.tween_interval(death_linger() - DEATH_FADE)
		tween.tween_property(_sprite, "modulate:a", 0.0, DEATH_FADE)
	else:
		tween.tween_interval(death_linger())
	tween.tween_callback(queue_free)
	_play_knockback()


## The shove, as motion. A separate Tween from the one above rather than a parallel
## step inside it: that one is a strict sequence (hold, fade, free) and a
## `set_parallel()` in the middle of it would run the free against the fade.
##
## Gated, and it starts from zero: `_play_death()` has already parked the sprite at its
## final offset, so with animations off the corpse is simply displaced, and with them
## on it slides there over DEATH_KNOCKBACK_TIME. Both are the same picture at rest,
## which is what makes the headless assertion worth anything.
func _play_knockback() -> void:
	if _sprite == null or _death_knockback == Vector2.ZERO:
		return
	if not GardenTheme.animations_enabled():
		return
	# From wherever the body actually is, not from the node's origin: a corpse eaten on
	# top of a flower starts its shove up there.
	_sprite.position = _carry_offset
	var shove := create_tween()
	shove.tween_property(_sprite, "position", _death_knockback + _carry_offset,
		DEATH_KNOCKBACK_TIME)


## How the corpse lies, as a predicate rather than a branch inside `_play_death()`
## — the same reason PlacementPreview.new_cover_cells() is one. A corpse is on
## screen for DEATH_LINGER and then gone, so a rule readable only from a
## screenshot is a rule that gets checked once.
##
## Straight on the pest's own facing for everything except a blast. `_facing` is
## kept rather than zeroed for the reason the corpse code has always kept it: a
## beetle killed walking left should lie facing left.
func corpse_rotation() -> float:
	if _death_cause == DEATH_BLASTED:
		return _facing + BLASTED_TILT
	return _facing


## The corpse's own scale. Squashed along the body axis when something chewed it,
## full size otherwise.
##
## Note this squashes X, not Y: the sprite rests head-up-screen (art_src/STYLE.md)
## and `_sprite.rotation` carries the facing, so the body's long axis is always
## local Y whichever way the pest was walking. Squashing Y would shorten the
## corpse nose-to-tail, which is a pest that shrank; squashing X narrows it, which
## is a pest that was closed on.
func corpse_scale() -> Vector2:
	# The chewed-down factor rides through to the corpse: a bug eaten to a third of
	# itself must not pop back to full size on the frame it dies, which is the exact
	# discontinuity the old single-frame swap had.
	var eaten: float = chewed_scale()
	if _death_cause == DEATH_BITTEN:
		return Vector2(_sprite_scale * BITTEN_SQUASH * eaten, _sprite_scale * eaten)
	return Vector2(_sprite_scale * eaten, _sprite_scale * eaten)


## Where this corpse was shoved to, relative to where the pest fell — the third of the
## three corpse channels, beside `corpse_rotation()` and `corpse_scale()`.
##
## `Vector2.ZERO` until something kills this pest with a direction to give, which is
## every death except a kernel's today. Read by `_play_death()` above the animation
## gate, so it is the corpse's real resting offset and not a description of one.
func death_knockback() -> Vector2:
	return _death_knockback


## How long this corpse holds before it is freed — `DEATH_LINGER` for a plain pest, up
## to DEATH_LINGER_MAX_MULTIPLIER times that for one that cost the player more.
func death_linger() -> float:
	return _death_linger


## How much of the pest is left to draw, as a scale factor. Pure, so the curve is
## assertable with no board, no frame and no open animation gate.
##
## Floors at CHEWED_MIN_SCALE rather than running to zero: a bug that vanishes to a
## point before the flower has finished is a bug that died early, and the kill is the
## chew ending, not the sprite running out.
func chewed_scale() -> float:
	return lerpf(1.0, CHEWED_MIN_SCALE, clampf(_chewed, 0.0, 1.0))


## Record how much of this pest has been eaten. Called by the ChompFlower holding it,
## once per bite, and reset to 0.0 when a pest is released unharmed.
##
## Above every animation gate on purpose: the fraction is game state a test can read,
## and only its rendering is gated. Deleting the call from the chew goes red instead
## of silently doing nothing (test_combat.gd:6331's rule).
func set_chewed(fraction: float) -> void:
	_chewed = clampf(fraction, 0.0, 1.0)


func chewed_fraction() -> float:
	return _chewed


## Taken hold of, or let go. Called by the ChompFlower on either side of a meal.
##
## Turning it OFF puts the body back on the road, but only for a pest that is still
## alive. A pest that died in the mouth keeps its offset: `Pest.kill()` sets `_alive`
## false and only then calls `held_by.release()`, so by the time the flower lets go the
## corpse has already been placed, and zeroing it here would drop the body out of the
## flower and onto the path a frame before it fades.
func set_carried(on: bool) -> void:
	_carried = on
	if on:
		z_index = CARRY_Z_INDEX
		return
	if not _alive:
		return
	z_index = 0
	_carry_offset = Vector2.ZERO
	_apply_carry()


## True while a Chomp has this pest in its vines.
func is_carried() -> bool:
	return _carried


## Where the flower has dragged the body to, relative to where the node still stands.
## `Vector2.ZERO` for every pest that is not in a mouth.
func carry_offset() -> Vector2:
	return _carry_offset


## Move the drawn body. Ignored once the pest is dead — see `_carry_offset`'s header for
## the channel it shares with the death knockback.
##
## Above every animation gate, deliberately, and it is the same rule `set_chewed` states:
## the offset is a value a test can read, and only the vines drawn to it are a picture.
## The flower derives it from its own clock (`ChompFlower.carry_offset_at`), so there is
## no Tween here that headless would leave unplayed.
func set_carry_offset(offset: Vector2) -> void:
	if not _alive:
		return
	_carry_offset = offset
	_apply_carry()


## The three places the offset lands. All of them are drawings; none of them is
## `position`, which is the whole design (see `_carry_offset`).
func _apply_carry() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = _carry_offset
	if _health_back != null and is_instance_valid(_health_back):
		_health_back.position = _bar_origin + _carry_offset
	if _health_bar != null and is_instance_valid(_health_bar):
		_health_bar.position = _bar_origin + _carry_offset
	# The markers and the fought ring are painted on this node's own canvas item, which
	# `_draw()` shifts by the same offset.
	queue_redraw()


func is_alive() -> bool:
	return _alive


## True once anything in the garden has touched this pest — a kernel that landed
## or a Chomp that held it. False for one that walked the whole road unopposed.
##
## Read by Game._note_escape at the instant `escaped` fires, which is the last
## moment it can be: _escape() emits and then queue_frees, so a listener that
## deferred the read would get a freed instance.
func was_engaged() -> bool:
	return _ever_engaged


## Record that the garden has laid a finger on this pest, and put the fought mark on
## it the first time that happens.
##
## The one writer of `_ever_engaged`, which is what makes the mark and the flag the
## same claim: two call sites each setting the bool and only one of them repainting is
## how a pest ends up counted as fought in the summary and drawn as untouched on the
## board. The two callers are `take_damage()` (a hit that landed) and `_physics_process`
## (a Chomp holding it) — the whole list, argued in `_ever_engaged`'s own header.
##
## Idempotent: engagement never comes back off, so the repaint is spent once.
func _mark_engaged() -> void:
	_ever_engaged = true
	if _shows_fought_mark:
		return
	_shows_fought_mark = true
	queue_redraw()


## Is this pest wearing the fought mark right now — "the garden reached this one"?
##
## True from the first hit or hold onward. Read this rather than `was_engaged()` when
## the question is about the picture: they agree today by construction, and the reason
## to keep them apart is that only one of them is allowed to acquire a condition.
func shows_fought_mark() -> bool:
	return _shows_fought_mark


## Pure: the radius the fought ring is drawn at, for a pest drawn at `sprite_scale`.
##
## Strictly outside PLATE_OUTER at the same scale, which is the property that matters
## and the one `test_combat` pins: an armoured pest wears both marks at once, and a
## remark that landed on top of the armour would read as one thicker plate.
static func fought_ring_radius(sprite_scale: float) -> float:
	return SPRITE_HALF * sprite_scale * FOUGHT_RING_RADIUS


## Pure: the fought ring's dashes, as `(from, to)` angle pairs in radians, in order.
##
## The whole geometry of the cue, out where it can be asserted without a frame —
## FOUGHT_RING_DASHES arcs with a gap of the same width after each, so the ring is
## exactly half ink and unmistakably broken. That last part is the two-channel rule
## for this cue: a solid ring here would be a reach, and "half of the turn is bare" is
## the property that survives the colour being thrown away.
static func fought_ring_dashes() -> PackedVector2Array:
	var step: float = TAU / float(FOUGHT_RING_DASHES * 2)
	var out := PackedVector2Array()
	for i: int in range(FOUGHT_RING_DASHES):
		var from: float = float(i) * step * 2.0
		out.append(Vector2(from, from + step))
	return out


## 1.0 for a plain pest; higher for a mutation, so a harder kill leaves a
## better husk. Game._on_pest_died reads this when it drops one.
## What this pest's husk is worth, as a multiple. Multiplies across every mutation it
## carries rather than reading the primary — a pest that is twice as hard to answer should
## pay twice, and reading `mutation` alone would have silently paid a doubly-mutated pest
## the price of one trait from the moment pairs became possible.
func husk_multiplier() -> float:
	var total: float = 1.0
	for each: StringName in mutations:
		total *= float(MUTATION_HUSK_MULTIPLIER.get(each, 1.0))
	return total


func _escape() -> void:
	if not _alive:
		return
	_alive = false
	escaped.emit(self)
	queue_free()


## 0.0 at the entrance, 1.0 at the exit. Targeting uses this to shoot whichever
## pest is furthest along rather than whichever happens to be nearest.
func progress() -> float:
	if _route.size() < 2:
		return 0.0
	return clampf(float(_leg) / float(_route.size() - 1), 0.0, 1.0)
