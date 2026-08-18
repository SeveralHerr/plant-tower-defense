# Bead audit — cycle 109

All 138 open beads read and judged, 2026-08-17, against the code at `f14293c` on `lane3/prune`.

Method: `bd list --status=open --json` for the bodies, then the cited file opened before the
verdict was written. `kanban-staleness-audit`'s bar applies — **a wrong `STALE` deletes an idea
nobody will have again**, so every `STALE` below carries the file:line or `bd show` that killed
it, and anything I could not decide is `NEEDS-DECISION` rather than a guess. Line numbers in
bead bodies drift constantly here; several beads cite lines that have moved 40–500 lines. A
moved line number is *not* grounds for `STALE` and was never used as such.

---

## 1. Summary

| Verdict | Count | Share |
|---|---:|---:|
| `KEEP-PLAYER` | 40 | 29% |
| `WONTFIX` | 66 | 48% |
| `KEEP-DEV` | 17 | 12% |
| `STALE` | 11 | 8% |
| `NEEDS-DECISION` | 4 | 3% |
| **Total** | **138** | |

**The split the owner asked for: `KEEP-PLAYER` 40 vs `KEEP-DEV` 17 — 70/30 in favour of the
player.** That is the surprise of this audit. The queue is not the problem. What gets *picked
out of it* is.

By priority:

| | P1 | P2 | P3 | P4 |
|---|---:|---:|---:|---:|
| KEEP-PLAYER | 2 | 11 | 20 | 7 |
| KEEP-DEV | 1 | 7 | 7 | 2 |
| WONTFIX | 0 | 9 | 52 | 5 |
| STALE | 0 | 1 | 7 | 3 |
| NEEDS-DECISION | 0 | 2 | 2 | 0 |
| **Total** | **3** | **30** | **88** | **17** |

If the 66 `WONTFIX` and 11 `STALE` come out, the queue is 61 items and **two thirds of it is
work a player would notice.**

---

## 2. Every bead, one row

Verdict key: **P** = KEEP-PLAYER, **D** = KEEP-DEV, **W** = WONTFIX, **S** = STALE,
**N** = NEEDS-DECISION.

### P1

| id | title | v | evidence / reason |
|---|---|---|---|
| `6e2e` | Probe a board cue's rendered position | D | Confirmed: every board cue is a `Node2D._draw` with no Control — `OVERLAY_GRAMMAR.md:119-123` lists the cue files, `ui_layout` structurally cannot see any. The 72px sole-cover bug is the only shipped visual defect this project has had. |
| `iqp8` | Give the campaign's back half a real second act | P | Verified: `wave_director.gd:1095-1099` and `:1105-1107` both early-return the flat value for every campaign wave (`over <= 0`). **James already answered it** — `cycle-log.md:329-338`, "no longer a question". The bead's own "DO NOT act without an answer" is the stale part. |
| `qdsi` | The game has no touch input at all | P | `grep -rn "InputEventScreenTouch\|InputEventScreenDrag" game/` → zero. Largest player-visible hole in the queue. |

### P2

| id | title | v | evidence / reason |
|---|---|---|---|
| `5s99` | Should the pause door open the SELECTED plant's page? | P | `page_for_plant` and `selected_placed` both exist; a dev can pick the staleness rule. Low value, real. |
| `81g9` | Give the Chomp an open jaw at the moment of the bite | P | `art_src/` holds `chomp_flower_eating.svg` and `_eating_late.svg` but no open-jaw frame; the swap machinery is built. Direct from a user report. |
| `9afm` | Stop the over-promise simulation asserting the RNG draw | D | The test is a tripwire on any `WaveDirector` RNG change — and `iqp8` is exactly that change. Do it before, not after. |
| `9vq6` | citation_check exits clean over bead citations it never read | W | See WONTFIX §5. |
| `a155` | Check the transform cues by reading properties, not pixels | D | The cheap half of `6e2e`, needs no pixels. `_sway_pivot.rotation` / `_sprite.scale` are readable properties; the canvas half stays open. |
| `ais1` | Warn at startup when rows begin at floor | W | See §5. |
| `b7v5` | Name the coverage-is-not-engagement mechanic on the run summary | P | The mechanic is measured three ways and the player learns it only by losing. |
| `cnn7` | The Nurse Beetle wears the beetle's sprite | P | Verified `game/pest.gd:234-235`: `NURSE.texture = pest_beetle.png`. No `nurse.svg` in `art_src/`, no `pest_nurse.png` in `assets/sprites/`. |
| `d3el` | Point the UI checks at surfaces that actually move | W | See §5. |
| `du7p` | Ask what the board's scarce resource is | W | See §5. |
| `f9zc` | Decide what the message row's one extra clause is for | S | See §4. |
| `fjqp` | Draw the uproot window | P | `_uproot_left`: 10 hits in `game/game.gd`, **0** in `game/hud.gd`. The one countdown with nothing on screen, on a 4-second irreversible decision. |
| `gd27` | Re-measure the message row with player actions | W | See §5. |
| `gfpj` | Screenshot the two remaining cues inside their own sprite | P | Sunflower gauge and Chomp chew ring at 22–26px inside a 64px sprite box; the cob's pips were already measured occluded. Two screenshots. |
| `h4v1` | A pest in a Chomp's mouth is untouched until it dies | P | Verified `chomp_flower.gd:432` (one ring), one `flash_hit()` at the grab; `pest.gd` runs `_gait` while held. The report is exactly right. |
| `h5w6` | Decide whether moving a plant should cost anything | N | See §6. |
| `iqf2` | Screenshot a hover and a selection at once | P | 4px filled disc inside a 9px ring on the same cell, never looked at. Five minutes. |
| `ix76` | Should a 60-seed husk rot faster than a 9-seed one? | N | See §6. |
| `ki5h` | Measure whether a drought is noticed mid-wave | P | Drought doubles firing interval and is the weather demanding a response; it reads as slightly duller grass. |
| `owdi` | Check the notebook with a non-TABLE id in the save | D | Verified: the shelf tests set `earned_milestones = {"hundred_pests": true}` — an id that IS in `TABLE`. No test drives a foreign id. The guard is a comment and a reading. |
| `r722` | Budget the selection panel | D | `budget_entries()` (`game.gd:2433`) prices five couplings; the panel is not one. It is the named blocker for `eupm`, which is player-facing. |
| `rvvt` | A repaint verb for inspecting a drawn cue while paused | D | No `repaint_canvas` in `devtools_ext/commands.gd` (12 verbs, none of them this). Three open beads — `gfpj`, `iqf2`, `ip4n` — all need paused repaint. ~10 lines. |
| `snnp` | Put the reach ring on Plant | W | See §5. |
| `twbt` | Artifacts around the board's page frame | P | A reported visual bug on the surface the player looks at for the whole run. Two named suspects, both confirmable by one cropped screenshot. |
| `txme` | Make the close reason start from the acceptance | W | See §5. |
| `uqeo` | The seed surplus has no sink | P | Verified in the bead's own note: `seed_bank.gd:138` and `:240` are the only two subtractions and both are purchases. `cycle-log.md:339-347` — no longer blocked on James, blocked on a re-measurement. |
| `v9px` | Re-capture the UI findings baseline | D | Still empty (`cycle-log.md:371`). Every `ui_layout` finding gates as NEW, which is a noise cost paid every cycle. Fold `iiyg` into it. |
| `yoc2` | Do the other HUD surfaces deserve corpus-style checking? | W | See §5. |
| `ztue` | Refuse to file a bead from an uncited kanban entry | W | See §5. |
| `zzx3` | launch --snapshot-userstate did not restore, and quit did not say so | D | The standing note at `cycle-log.md:390-392` *recommends this exact flag* for verifying once-per-save behaviour, and it silently failed once and cost a hand-repaired save. Half 1 (establish why) is project-doable; half 2 is upstream. |

### P3

| id | title | v | evidence / reason |
|---|---|---|---|
| `0w8v` | Build screen-content-audit, or record why not | W | One identification, against this project's own two-identification bar. The bead says so. |
| `0y0w` | Price the side panel the way the message row is priced | D | The side panel holds plant names, blurbs and prices — content that grows with every plant, and there are eight now. A clipped blurb is player-visible. |
| `1y2w` | Test whether a computed ceiling keeps a surface uncrowded | W | A five-cycle meta-observation with a named confound. |
| `3iwp` | Decide what bounds a plant's display name | W | One comment, guarding a failure that has happened zero times; `check_budgets` already refuses the build. |
| `4yz6` | Give kanban a top-of-file index | W | A hand-maintained index of a 3948-line file about stale hand-maintained lists. Canonical state is `bd`. |
| `51eo` | Teach settle_read_check about a tree read after a kill | W | A 20th checker rule for a mistake made zero times across ten call sites. |
| `6p1y` | Watch for evidence strings that name a surface, not a corpus | W | Apparatus about apparatus; five budgets, one known ambiguity, already corrected. |
| `6v39` | Give the kernel kill a knockback | P | A Corn Cobbler is the plant most players own most of the time, so most corpses carry no information. |
| `848r` | Never type a node path; and maybe a node_hint verb | S | See §4. |
| `8jog` | Name every node the code keeps a reference to | W | Re-derived: 138 `add_child` vs 104 `.name =` (bead says 123/93). The bead concedes "not every anonymous node is a defect" and offers nothing that separates deliberate from overlooked. |
| `8u01` | Audit the rest of kanban's older sections for Done-lists | W | See §5 (kanban cluster). |
| `8ute` | Audit the design brief against what the game actually does | D | The brief is the only statement of intent and the game has grown three plants and two pest species past it. **Fold `kihy`, `w0wh` and `hwo6` into this** — four beads, one document. |
| `9a2y` | Move set_active onto OverlayScreen | W | Three copies confirmed (`hud.gd:2145`, `pause_screen.gd:854`, `title_screen.gd:935`). The bug that motivated it, `-csrc`, is CLOSED. |
| `a6rf` | Show when a covered cell is covered by a busy plant | P | The over-promise runs measure 65% unanswered on covered ground; only the cue is missing. |
| `ayri` | Point the muzzle fan at the current target | P | Two plants draw where they will act next, and only after they have acted. The cob half is an assignment outside the fire branch. |
| `b3nt` | Write down that the pause card must be read frozen | S | See §4. |
| `b7dd` | Give the message row's slack a name | W | One header sentence; the decision is already made de facto. |
| `bg4i` | Enumerate everything the game silently discards | W | A repo-wide sweep for discard branches plus counters, to instrument questions nobody currently has. The bead's own precedent, `-i366`, is closed. |
| `bia` | Say when a binding is actually saved | P | `_persist()` gives no feedback and a failed write looks identical to a success. Rare path, but player-visible when it fires. |
| `bn2c` | Give the top bar a second row before something needs it | W | **The bead's own citation is wrong**: `BAR_ROWS` does not exist in `game/hud.gd` (only `BAR_HEIGHT: int = 72` at `:22`). Pre-emptive layout for a readout nothing has asked for. |
| `bt4h` | Teach kanban-staleness-audit the derive-vs-taste question | W | Verified absent from the skill. Skill-about-skill. |
| `c6qs` | OVERLAY_GRAMMAR filed a real cue under 'sprites drawing themselves' | S | See §4. |
| `cs2k` | Assert the invariant, not the three instances | D | One sweep test replaces three and catches the screens not yet written; there are five overlay screens now. |
| `d6fe` | Audit the five house checkers that predate the fixture discipline | W | Apparatus about apparatus, squared: documenting that checkers have been watched to fail. |
| `dgu5` | Show a par score for garden efficiency | P | The par number already computes in `test_combat._cover_greedily`. Cheapest replay motivation available. |
| `ei83` | Give a missed hint somewhere to be found again | P | `spend_hint` makes "owed but never seen" a real queryable state (`run_config.gd:432`); there is nowhere to find it. |
| `ejfa` | Assert a flourish reaches its peak | W | A runtime walk per flourish to pin a cosmetic peak, with an unresolved sampling caveat (0.900 vs 0.88) in the way. |
| `eupm` | Show the replant cost beside the uproot refund | P | `Uproot (+%d)` says what you get back and nothing says what putting it back costs — a subtraction left to the player on a four-second timer. |
| `f7y2` | Gate the weather multipliers with assert_margin | W | See §5 — `assert_margin` has **zero callers**. |
| `fdz1` | Audit the six oldest kanban sections | W | See §5 (kanban cluster). |
| `fo96` | Assert GardenTheme.measure agrees with a real Label at every size | D | `measure()` is load-bearing for five budgets and is asserted against a real Label at exactly one font size. If it disagrees at `MESSAGE_FONT_SIZE`, every message-row budget is measuring the wrong thing — the one apparatus bead whose failure would invalidate other apparatus. |
| `frdz` | Count hosted nodes that did not survive the test | W | `run_tests.gd` is harness-owned and regenerated by scaffold. Upstream, not here. |
| `frzz` | Gate the pest gait constants with assert_margin | W | See §5. |
| `g8kc` | Tint ground no plant in the catalogue can use | P | 36 of 94 buildable cells are dead for the Chomp; a player scanning the board sees uniform grass. |
| `hb43` | How often has a heredoc silently damaged a file here? | W | The bead itself says "expect this to find little" and forbids a checker without the count. |
| `hulz` | Give the lane-pressure hatch a row in the grammar table | W | Verified absent from the table (`OVERLAY_GRAMMAR.md:21-32`) while listed as a cue file at `:123`. But `:48` warns that adding a row fails the suite until someone decides whether it is taught — a real cost for a documentation-only gap. |
| `hwo6` | Audit STYLE.md's claims against the art | W | Fold into `8ute`. `svg_style_check.py` already gates the palette half. |
| `hynr` | Sweep kanban for other duplicate section headings | W | Re-derived: **9 prefixes still collide** (`24 of 30`, `23 of 30`, `22 of 30`, `21 of 30`, `20 of 30`, `18 of 30`, `16 of 30`, `15 of 30`, `14 of 30`). Real — but the countermeasure already shipped: `cycle-log.md:381` says "Cut `kanban.md` by line number, never by heading". |
| `i7oi` | Derive the remaining three panel rects | W | Verified still hand-picked (`options_screen.gd:150`, `notebook_screen.gd:31`, `run_summary.gd:51`). None has ever been wrong, and the bead notes each needs its own "derive from what set?" answer. |
| `ifew` | Check whether the wave-cleared line eats the prep note's window | P | A measurement about what the player is being told at the exact moment they decide what to plant. |
| `iiyg` | Give the UI findings baseline something to compare against | W | Same item as `v9px`. Merge. |
| `imme` | Decide what plant death means before there are two causes | D | The cheap branch is one comment at `plant.gd:614` and it forestalls a shipped lie. Enumeration confirmed plausible: one emitter, one caller. |
| `ip4n` | Photograph a chew ring mid-sweep | D | The evidence half of a shipped change, and it blocks `l86t` (player-facing legibility). Needs `rvvt` or the recorded pause/step recipe. |
| `itbj` | Write the animation-testing pattern into a local skill | W | The recipe already lives in `read-a-moving-value` and `cycle-log.md:388-390`. |
| `jk4a` | Give the banner a painter | W | The bead's own words: "It has not bitten yet." Pre-emptive. |
| `kig5` | Give the Chomp's chew ring a shape that is not a range | S | See §4. |
| `kihy` | Audit the design brief's UI claims | W | Fold into `8ute`. |
| `kjcx` | Refuse an equality assertion whose sides are the same object | W | `run_tests.gd` is harness-owned. Upstream. |
| `kmjp` | Decide what rain pays, now that drought pays 150% | P | Rain is the only weather with a downside and no compensation. Downstream of `oo7e` — do not do it first. |
| `ku29` | Check that comments citing a verb or a test are still true | W | A 20th checker for a class with one known instance out of fourteen measured. |
| `l69v` | Ask whether a rich husk should sound rich | P | Player-facing, and the bead's honest alternative ("size and glow already say rich") makes it cheap to close either way. |
| `l86t` | Find out whether a 0.45s chew is long enough to read | P | An aphid chew is shorter than a bus round-trip; the readout may be a flash nobody parses. |
| `lp97` | Tell the player what the run cost | P | Not one summary row is about seeds. `knpc` (the ceiling arithmetic that blocked it) is CLOSED. |
| `m14g` | One table for every glyph the game draws | W | A table plus a derived check for a collision that happened once and was caught by a screenshot. |
| `mthc` | Ask whether the overlays should switch rather than refuse | S | See §4. |
| `n3zm` | Assert the pitch scale's direction | W | One more derived test over a five-entry table. |
| `nuxg` | Do the width budgets want their own rows_that_fit? | W | The bead's own likely answer is "no, and write why". |
| `o2aa` | Is a same-subsystem streak worth checking mechanically? | W | "The likely right answer is NOT YET", n=1, and the bead says do not build the tool to justify the bead. |
| `o9uo` | Make the preview's subject a named predicate | W | Refactor at two modes; the bead says "It is fine at two modes". |
| `ogxu` | Ask whether the budget ratchet should keep a reserve | N | See §6. |
| `om5f` | Rotate the sway about the stem instead of the middle | P | Verified: `plant.gd:305-311` parents `_sprite` to `_sway_pivot` with no offset. Every plant on the board wobbles like a tethered balloon. Two constants, no runtime cost. |
| `oo7e` | Weather needs counter-play, or it is a difficulty modifier | N | See §6. |
| `orcl` | Read the citation checker's landed lines over the whole file | W | 313 citations in a 3948-line file whose canonical state is `bd`; the bead expects a low hit rate and says the value is knowing the rate. |
| `ox1p` | Find the duplicates already in the queue | W | Superseded by this audit — the groups are in §7. Its "124 items" is now 138. |
| `p8k0` | Decide whether pairs belong in the campaign or only in endless | S | See §4. |
| `pa4g` | Audit the notebook against three cycles of new mechanics | D | The notebook is the one surface whose job is to explain the game, and the game has grown a great deal past it. The audit's output is player-facing beads. |
| `pabl` | Cap the wave number's width in next_wave_note | W | A test for a format that cannot be reached (999 waves), or one header sentence. |
| `q1xs` | Check whether moving rules out of CLAUDE.md into a skill held | W | Overtaken by a bigger version of itself: `CLAUDE.md` and `AGENTS.md` now carry **only a pointer** to the whole cycle skill (`cycle-log.md:344`). The experiment being evaluated has been superseded. |
| `r8zc` | Decide whether repeated sounds want a per-play jitter | P | `CORN_FIRED` every 0.62s with several cobs; the machine-gun sameness is audible. Real tension with the twin check, stated. |
| `rd9s` | Report the worst RECURRING string beside the worst possible one | W | One extra field on a dev verb. |
| `rks4` | Derive the seen: count instead of incrementing it by hand | W | Apparatus about the gaps log about the harness. |
| `rowt` | Let a hard-won kill linger longer than an easy one | P | One line (`DEATH_LINGER` scaled by `husk_multiplier()`), and the corpse is where the player actually looks. |
| `ryfi` | Make 'only one line may carry a deadline' fail, not warn | W | Re-derived: still exactly one producer (`game.gd:1630`), constant at `hud.gd:580`. A test asserting a grep count is 1, for a second producer that has not arrived in many cycles. |
| `sleq` | Keep the previous selection's rings while comparing two plants | P | The question a player has is comparative and answering it means holding two pictures in your head. |
| `thoj` | Sweep bd descriptions for absence claims that never said how | W | Superseded: `-g1o4` resolved 16 and reported **139 open beads carry at least one absence claim**; this audit resolves the rest by verdict. |
| `to0d` | Assert a live scenario's precondition where it is consumed | W | A habit, written into a skill. Process. |
| `tzz7` | Surface dead ground before the player is holding a plant | P | A player scanning the board to decide what to *buy* sees uniform grass and learns a corner is useless after committing. |
| `uhno` | Derive message durations from length | W | The bead concedes "the spread is probably RIGHT" — a derivation that reproduces the current values changes nothing a player sees. |
| `vjr1` | Gather the message-corpus waiver reasons into one place | W | One output line on a checker (`message_corpus_check` prints "5 waived" and no reasons). |
| `vvxn` | Trim cycle-log.md's Restarting section | W | Blocked on `q1xs`, which is itself `WONTFIX`. Its numbers drifted 3.4x: the file is 394 lines, not 115, and carries twelve standing notes, not ten. |
| `w0wh` | Read the design brief's combat claims | W | Fold into `8ute`. |
| `wenx` | Does any remaining untaught cue deserve the legend's cost? | P | A question about what the game teaches, whose likely answer ("six is the right number") closes it in three greps. |
| `wf4i` | Give the run summary the corpus pattern | W | The summary's rows are fixed-format numbers, not content-driven text. The corpus pattern earns its place where strings grow. |
| `wlyz` | Show that a pest was fought and survived | P | `_ever_engaged` already distinguishes "you had no answer" from "your answer was not enough" and the player never sees it. |
| `xf0b` | Write down which radii the plant readouts occupy | W | A comment that rots, or a derived test for a collision that has happened zero times. |
| `xi0s` | Look for the seam pattern in the other gated subsystems | W | The bead quotes `extract-a-testable-seam`'s own warning against pre-emptive extraction and then proposes the sweep anyway. |
| `ynai` | Make LEVELS the cob's single source of truth by name | W | Verified eleven statics on `CornCobbler` already read `LEVELS`, none has drifted. A documentation deliverable. |
| `zp0h` | Name the situations the harness's unused verbs are for | S | See §4. |

### P4

| id | title | v | evidence / reason |
|---|---|---|---|
| `22a` | Align the key column across the two screens that show keys | P | "The kind of thing nobody reports and everybody notices" — and that is right. |
| `2khw` | Mark which budget floors have actually been tested | S | See §4. |
| `4kgn` | Make verify_ledger stats show the suite count over time | W | Apparatus about the ledger about the apparatus. |
| `9dzb` | Say in CLAUDE.md that list-commands has an offline mode | S | See §4. |
| `a9pi` | Should the message counters get a devtools verb? | W | The bead makes both arguments against itself, and its stated tiebreaker `-k1` **is not a real bead id** (`bd show` → no issue found). |
| `acj` | Widen the mirror gate to the other prose invariants | S | See §4. |
| `bt5i` | Decide whether a drought should slow the non-shooters | P | A drought slows two plants of five by accident of which read the multiplier. Player-visible balance, and a dev can decide it. |
| `cc55` | Write down what 'armed' looks like, once | W | A comment beside `GardenTheme.DANGER`. |
| `ednt` | Check that every glyph the game draws exists in the font | D | A missing glyph renders as a `.notdef` box with a real width, so `measure()` returns a plausible number and **every width budget passes**. It is the one hole in an otherwise thorough width apparatus, and it is player-visible when it fires. Does not need `m14g` — `Font.has_char()` over the corpus the checker already enumerates. |
| `efjq` | Bisect your own change before auditing the tool | W | n=1, against the two-identification bar. The bead says so. |
| `q8db` | Decide how a FIRST record is celebrated | P | The most significant record a player sets currently gets less than a later, smaller one. |
| `r3e8` | Roll the seeds counter the way the record rolls | P | The readout that moves most often is the one that does not show its movement. |
| `snba` | Give Pest a last_survivable_leg() | D | Three test files re-derive `_route.size() - 2` by eye and getting it wrong by one caused a real bug once. One method. Lowest-ranked keep. |
| `v78` | Show the key hint on the HUD's own buttons | P | A player who rebinds a key sees it only on the two screens that own bindings. |
| `vte` | Widen SHORT_NAMES to the keys the engine names badly | P | Verified `key_bindings.gd:143-152`: 8 of ~100 keys. A rebound `KEY_BRACKETLEFT` renders as something no player calls it. |
| `x5rf` | Give kanban.md entries ids | W | The prerequisite for a tool over a file whose canonical state is `bd`. |
| `xgjw` | Say how much game is left, not just what is next | P | `WAVES.size()` is static and `current_wave` is on every state dict; "3 waves to go" is available everywhere and used nowhere. |

---

## 3. Live findings turned up while reading (not fixed, per the audit brief)

1. **`Dandelion.best_target()` dereferences a pest with no validity guard.**
   `game/dandelion.gd:215-231` reads `pest.global_position` twice, and
   `grep -c is_instance_valid game/dandelion.gd` returns **0** — the file has no such call
   anywhere. Every other targeting path guards: `plant.gd:616`, and `ChompFlower` and
   `StickySundew` both do it themselves. This is recorded in `kanban.md:2048-2055` and **has no
   open bead**. It is the same defect `-or67` was closed for on the other function.

2. **`cycle-log.md:385` says `cmd budgets` prices "the **seven** couplings". It prices five.**
   `Game.budget_entries()` (`game/game.gd:2433-2441`) returns exactly five entries and
   `BUDGET_FLOOR` (`:2363-2377`) declares five keys. Six open beads (`du7p`, `nuxg`, `r722`,
   `yoc2`, `b7dd`, `ogxu`) repeat "seven" from that note. Nobody has recomputed it.

3. **`_T.assert_margin` has zero callers.** It exists at `tools/run_tests.gd:776` and is
   documented in `CLAUDE.md` as the right tool for tuned constants; `grep -rn assert_margin
   test/` returns nothing across 15k assertions. Two open beads (`frzz`, `f7y2`) exist to
   become its first callers.

---

## 4. STALE — with the citation, ready to paste into `bd close --reason`

**`plant-tower-defense-c6qs` — OVERLAY_GRAMMAR.md filed a real cue under 'sprites drawing
themselves'**
> DONE, and by the cycle after the one that filed it. `game/OVERLAY_GRAMMAR.md:25` now carries
> the row the bead asks for — **Partial arc at a fixed radius, sweeping closed = TIME
> REMAINING** — citing both instances (`husk_layer.gd:69-77`, `chomp_flower.gd:164-165`). The
> exceptions section was re-read in light of it: `:62-70` strikes the Chomp exception through
> and records the resolution, and `:125-130` states the derivation's filter mistake in the
> document itself ("`husk_layer.gd` was in the sprite list until cycle 78 and that was the
> derivation's one real mistake"). All three acceptance clauses satisfied.

**`plant-tower-defense-kig5` — Give the Chomp's chew ring a shape that is not a range**
> ALREADY SHIPPED. The bead's premise — "`chomp_flower.gd:138` shrinks a solid ring" — is false.
> `game/chomp_flower.gd:432` draws `draw_arc(Vector2.ZERO, CHEW_RING_RADIUS, 0.0,
> chew_arc_end(chew_progress()), ...)`: a partial arc at a **fixed** 22px radius
> (`CHEW_RING_RADIUS`, `:89`), sweeping closed. Both acceptance clauses are met — the cue is
> distinguishable from a reach ring with colour discarded (the channel is sweep angle, recorded
> at `OVERLAY_GRAMMAR.md:100`), and the grammar lost the exception in cycle 78
> (`OVERLAY_GRAMMAR.md:62-70`).

**`plant-tower-defense-mthc` — Ask whether the overlays should switch rather than refuse**
> CLOSES ON THE BRANCH THE BEAD NAMED. It says: "Check before choosing: whether the menu buttons
> are even reachable while an overlay is up... in which case the current behaviour is not a
> refusal a player can trigger at all, and this bead is about the entry points rather than about
> the game." Checked. `game/title_screen.gd:935-946` sets **both** `focus_mode = FOCUS_NONE` and
> `mouse_filter = MOUSE_FILTER_IGNORE` on every menu button, and it is called with `false` on
> every overlay open — `:860` (notebook), `:886`, `:913`. A player cannot press a menu button
> while an overlay is up, so the refusal at `_open_notebook`'s `if overlay_open(): return`
> (`:854-855`) is reachable only from `fire-entry-point`. Tooling note, not a UX one.

**`plant-tower-defense-p8k0` — Decide whether pairs belong in the campaign or only in endless**
> PREMISE FALSE. The bead says "the campaign's fixed table ends at 16", so pairs are endless-only.
> `WaveDirector.WAVES` (`game/wave_director.gd:420-621`) contains **22** wave rows, and
> `SECOND_MUTATION_START_WAVE` is still 20 (`:80`). `_build_schedule` gates the second mutation on
> `current_wave >= SECOND_MUTATION_START_WAVE` alone (`:1137-1141`) with no mode flag — so campaign
> waves 20, 21 and 22 already roll paired pests. A player who finishes the campaign meets them.

**`plant-tower-defense-848r` — Never type a node path; and maybe a local node_hint verb**
> THE MANDATORY HALF IS DONE. `cycle-log.md:362-366` carries the standing note verbatim:
> "**NEVER TYPE A NODE PATH** — get it from `find-nodes --class X --where name=Y` or `scene-tree`.
> This project's HUD node is `/root/Game/HUD` while its class is `Hud`, so the wrong guess is the
> natural one, and a path miss reports only the path: fourteen identical `Node not found` replies
> read as fourteen empty reads (gh#53)." The bead's own text supplies the default for the optional
> half: "Decide (b) on whether a second person hits this — one sighting is an observation."
> No second sighting has been logged.

**`plant-tower-defense-b3nt` — Write down that the pause card is the one screen findings must read
frozen**
> PREMISE FALSE. The bead says "the pause card is the documented exception and nothing documents
> it." `cycle-log.md:366` reads: "**`pause` right after `launch`**, but **unpause before
> `findings`** — except the pause card". The exception is stated in the same sentence as the rule
> it contradicts, which is the acceptance's "in the same breath". The only unmet fragment is the
> parenthetical reason (process frames still tick while the tree is paused); worth one clause on
> that line, not a bead.

**`plant-tower-defense-zp0h` — Name the situations the harness's unused verbs are for**
> BUILT, in the place the bead named. `cycle-log.md:379-393` is a situation-first index in this
> project's own words, and it contains all three of the bead's own worked examples: "to verify a
> fix to a once-per-save behaviour, `launch --snapshot-userstate` **before** clearing the flag";
> "To walk a sub-second tween: `pause` **before** creating it, then `step-time --seconds 0.03
> --then-pause`"; "`list-commands --offline` answers 'does this verb exist' with no game running".
> It is in `cycle-log.md`, which the loop reads at the start of every cycle. The unmet fragment is
> "with the cycle it happened" — the entries are not dated.

**`plant-tower-defense-9dzb` — Say in CLAUDE.md that list-commands has an offline mode**
> SAID, in both places. `CLAUDE.md:244` documents it inside the verb table ("`--offline` parses
> the scripts statically with no game running"), and — answering the bead's real worry, that the
> managed block is regenerated by scaffold — `cycle-log.md:388` carries it in the project's own
> unmanaged file: "`list-commands --offline` answers 'does this verb exist' with no game running".

**`plant-tower-defense-acj` — Widen the mirror gate to the other prose invariants**
> THE FIRST HALF IS OBSOLETE BY DESIGN. The bead's case rests on "the parallel-safe gate list in
> CLAUDE.md/AGENTS.md must name every `tools/*_check.py` that exists (it is hand-maintained and a
> new checker can be forgotten)". That hand-maintained list is gone.
> `.claude/skills/cycle/SKILL.md:103-106` records the replacement and the reason: "This used to
> name '`name_check.py` and the eleven project checkers', which was a hand-maintained number in a
> file about not hand-maintaining numbers — it was already fifteen when `check_all.py` replaced
> it." `:419-424` and a live run confirm the derivation: `check_all: ran 18 of 19 discovered
> parallel-safe checker(s) ... CLASSIFIED 28 tools/*.py: 19 checker(s), 1 not parallel-safe, 7
> known non-checker(s), 0 unclassified`. The second half (the verb table vs `list-commands`) is
> inside the scaffold-regenerated harness block and is upstream's to own.

**`plant-tower-defense-2khw` — Mark which budget floors have actually been tested**
> ANSWERED IN THE CONSTANT, which is one of the bead's own two offered acceptances ("or say it in
> the constant's comment"). `game/game.gd:2371-2374` now reads: "The message row, measured against
> every plant name the catalogue can produce (`plant-tower-defense-m1el`). **342px of slack at the
> time it was declared, which is roomy** — and that is the number worth having written down,
> because 'roomy' is what everyone assumed about the wave slot until it had 10px left."
> `hud_readouts` carries the other kind at `:2364-2369` ("Ratcheted up from 7.0 / 8.0 in the same
> commit that..."). The exact case the bead was filed about is now legible. Residual: `husk_click`,
> `hud_stats_row` and `pest_road_ceiling` still carry no comment.

**`plant-tower-defense-f9zc` — Decide what the message row's one extra clause is for**
> PREMISE FALSE. The whole argument is "Three open beads all want that same slot and none of them
> mentions the others: `-fjqp`, `-c3h3` (a flinch), `-qoil` (a second one-shot hint). Roughly 190px,
> three claimants." Two of the three are gone: `bd show plant-tower-defense-c3h3` → CLOSED ("Let a
> plant flinch when something bites it"), `bd show plant-tower-defense-qoil` → CLOSED ("Point a
> second one-shot hint at something else nobody finds"). One claimant is not competition, and the
> bead's conclusion — "Three features arriving at one surface means the ROW is the wrong surface
> for at least one of them" — no longer follows from anything.

---

## 5. WONTFIX — ordered by confidence, highest first

Each of these is a sentence a reasonable person could argue with.

1. **`f7y2` / `frzz` (assert_margin on weather and gait constants).** `_T.assert_margin` exists at
   `tools/run_tests.gd:776` and has **zero callers across 15,298 assertions**. These two beads
   would make it two. Cost: two tests plus the judgement of which corpus each sweeps. Buy:
   protection against a species arriving at speed 61, or a weather multiplier drifting toward 1.0
   — neither of which has happened in 108 cycles, and both of which are one-line constants a
   reader can see. Merge them if either is ever done; they are one item.
2. **`9vq6` (citation_check over bead prose).** Cost: a JSONL-reading mode, an open/closed
   gating split, a per-issue waiver path and a demonstration. Buy: catches drifted line numbers
   inside bead descriptions. This audit is the experiment: I found roughly a dozen drifted
   citations (`r722`'s `game.gd:1921` → `:2433`, `i7oi`'s `options_screen.gd:109` → `:150`,
   `vte`'s `key_bindings.gd:121` → `:143`) and **not one of them changed a verdict.** What kills
   a bead is a false *premise*, and citation_check's own NOT COVERED line says it cannot see
   that. This tool would gate the harmless half of the problem.
3. **`ztue` (refuse to file a bead from an uncited kanban entry).** Cost: a checker that reads
   `bd`, which is a dependency none of the other nineteen have, or a step in a habit. Buy: a
   rule that CLAUDE.md has stated in prose since cycle 72. Process policing an author who is
   also the auditor.
4. **`d6fe` / `51eo` / `ku29` / `6p1y` / `rks4` / `4kgn` / `vjr1` / `rd9s` (checker gardening,
   eight beads).** Collectively: audit five checkers' docstrings, add a rule to a sixth, build a
   twentieth, reword five evidence strings, derive a count in the gaps log, add a stat to the
   ledger, and add two output lines. Cost: most of a cycle. Buy: nothing a player or a bug
   report can see, over an apparatus that just ran **18 of 19 checkers clean**.
5. **`8u01` / `fdz1` / `hynr` / `4yz6` / `x5rf` / `orcl` (kanban hygiene, six beads).** Cost: two
   full-file audits, a heading rename pass, an index, an id scheme, and a 313-citation read.
   Buy: a tidier 3948-line file whose own header says "Canonical task state lives in **beads**;
   this board is the readable view of it". Cycle 108 already audited the sections most likely to
   mislead (`kanban.md:2000-2013`), and the one accident this class caused is prevented by a
   standing note (`cycle-log.md:381`). Keep the file, stop grooming it.
6. **`kihy` / `w0wh` / `hwo6` (three beads to audit one design brief).** Not WONTFIX because the
   audit is worthless — WONTFIX because they are three names for `8ute`. Cost of keeping them
   separate: three cycles doing overlapping reads of the same hand-drawn pages.
7. **`thoj` / `ox1p` (queue hygiene).** Superseded by this document. `-g1o4`'s close already
   reported the denominator (139 open beads carry an absence claim); a second sweep that is not
   also a prune produces a number nobody acts on.
8. **`snnp` (reach ring on Plant).** Cost: a base-class helper, four call-site changes, and
   navigating the trap the bead names itself — `CornCobbler` and `ChompFlower` fully override
   `Plant._draw()` and never call `super`, so the helper must be a function each subclass calls,
   which is four call sites either way. Buy: one implementation of a rule that
   `OVERLAY_GRAMMAR.md:23` already documents and a test already pins numerically.
9. **`bn2c` (second top-bar row).** Cost: a layout change plus new budget declarations plus
   deciding what moves down. Buy: room for a readout nothing has asked for. And its own citation
   is wrong — `BAR_ROWS` does not exist in `hud.gd`.
10. **`jk4a` / `imme`-adjacent pre-emption (`jk4a`, `cc55`, `3iwp`, `pabl`, `b7dd`, `xf0b`,
    `ynai`, `m14g`).** Eight beads whose common shape is "write the rule down before the second
    instance arrives". Each costs a comment or a table; collectively they cost a cycle and buy
    documentation for events that have happened once or zero times. `imme` is the one I kept,
    because its second instance would ship a *lie to the player* rather than a merge conflict.
11. **`q1xs` / `vvxn` / `txme` / `to0d` / `o2aa` / `efjq` / `itbj` / `bt4h` (loop-about-the-loop,
    eight beads).** Cost: reading two cycles of kanban entries against five rules, trimming a
    narrative file, rewriting three skills, and deciding where a `git stash` tip lives. Buy: a
    development loop that describes itself slightly better. `q1xs` in particular has been
    overtaken — `CLAUDE.md` now carries only a pointer to the entire cycle skill, so the
    small move it wants to evaluate has been superseded by a much larger one.
12. **`yoc2` (do other HUD surfaces deserve corpus checking?).** WONTFIX because this audit
    answers it: no. `0y0w` and `r722` are kept because their text is content-driven and grows
    per plant; `wf4i` is dropped because the run summary's rows are fixed-format numbers.
13. **`d3el` / `gd27` (drive the checks harder).** Cost: two driven sessions with pause/step
    discipline. Buy: most likely two more zeroes. Three consecutive sweeps of these surfaces
    have returned 0 findings and no player-visible defect has ever been traced to them. *Lowest
    confidence of the WONTFIX group — if a UI defect does show up on the notebook or the options
    screen, `d3el` was right and I was wrong.*
14. **`ais1` / `du7p` / `1y2w` / `nuxg` / `ogxu`-adjacent budget philosophy.** `ais1` costs a
    persistence mechanism (what was at floor last build?) to warn a developer whose tests
    already fail and who has `cmd budgets`. `du7p` asks what the board's scarce resource is and
    concedes the answer may be "it has none"; the board has carried eleven cues without a
    legibility complaint.
15. **`0w8v` / `hb43` / `xi0s` / `o9uo` / `9a2y` / `i7oi` / `8jog` / `bg4i` / `n3zm` / `uhno` /
    `ryfi` / `ejfa` / `kjcx` / `frdz` / `a9pi` / `iiyg` / `wf4i` / `pabl`.** The tail. Each is
    defensible in isolation; together they are the reason the queue reads as apparatus. Two are
    harness-owned and belong upstream (`kjcx`, `frdz`); one duplicates another bead (`iiyg` into
    `v9px`); one cites a bead id that does not exist (`a9pi`'s `-k1`).

---

## 6. NEEDS-DECISION — the owner's inbox, four questions

These are exactly the four already sitting in `cycle-log.md:301-317` under "Waiting on the user",
which is a good sign: the loop has been honest about what it cannot decide. No fifth is added.

| id | The question, in one sentence |
|---|---|
| `ix76` | Should a 60-seed queen husk rot faster than a 9-seed beetle husk, or is 4.5 seconds a floor on human reaction time that every rich husk should keep? |
| `oo7e` | Should weather get real counter-play, and if so, by water tiles as a third board material (expensive), by a plant or upgrade that ignores drought (cheap), or not at all? |
| `h5w6` | Should moving a plant cost the full replant price, nothing, or the already-computed refund-minus-cost difference? |
| `ogxu` | Should a budget floor be set at the measurement, or at the measurement plus a named reserve? |

One note on the inbox: `iqp8` and `uqeo` used to be on it and **are not any more** —
`cycle-log.md:325-347` records that James answered both on 2026-08-17. Both beads still read as
blocked in their own descriptions. Whoever picks them up should read the cycle log, not the bead.

---

## 7. Duplicate groups (the `ox1p` deliverable, done)

| Group | Beads | Recommendation |
|---|---|---|
| UI findings baseline | `v9px`, `iiyg` | One item. Keep `v9px`; `iiyg`'s "which states?" is its first step. |
| The design brief | `8ute`, `kihy`, `w0wh`, `hwo6` | One audit. Keep `8ute`. |
| Budget bookkeeping | `r722`, `0y0w`, `wf4i`, `yoc2`, `2khw`, `b7dd`, `ogxu`, `nuxg`, `rd9s`, `ais1` | Ten beads about a five-key Dictionary. Keep `r722` and `0y0w`. |
| Kanban hygiene | `8u01`, `fdz1`, `hynr`, `4yz6`, `x5rf`, `orcl` | Drop all six. |
| Board-cue checking | `6e2e`, `a155` | Deliberately split; `a155` is the cheap half and builds the harness `6e2e` reuses. |
| The Chomp bite | `81g9`, `h4v1` | Both edit `ChompFlower._bite()`. **Never work concurrently** — `81g9` first, per its own note. |
| Dead ground | `g8kc`, `tzz7` | `g8kc` is the always-true subset of `tzz7`. Do `tzz7` and `g8kc` falls out. |
| Run-summary coverage | `b7v5`, `dgu5` | Do together or the card grows two lines about one idea. |
| assert_margin | `frzz`, `f7y2` | One item if ever done. |
| Harness-owned | `kjcx`, `frdz` | Both are `run_tests.gd` changes. Upstream, not here. |

---

## 8. The ten I would do next, ranked

The top of the ready list is **not** all apparatus — `bd ready` surfaces three P1s and two of
them (`qdsi`, `iqp8`) are player-facing. But by volume the queue reads as apparatus, and the
selection step has been picking the apparatus. Every item below except one is player-visible.

1. **`qdsi` — real touch input.** P1, and the biggest hole. The game plays on a phone only
   because `emulate_mouse_from_touch` defaults on, which is not even written into
   `project.godot`. A tap places blind: no hover, no preview, no way to abort once the finger is
   down. Start with the reproduce-on-device step the bead already scopes.
2. **`h4v1` — nothing is taken out of the bug.** A verbatim user report, and its twin
   (`n2wd`, "the Nettle's sting reads as a jiggle") shipped at HEAD this cycle. The same player
   is telling you the combat animations do not read. Mechanism 1 (repeat the bite) needs no art.
3. **`81g9` — an open jaw at the moment of the bite.** Same report, and doing it first gives
   `h4v1`'s repeated bite a much better frame. Parent work: it needs a headless import pass a
   lane cannot run.
4. **`cnn7` — the Nurse Beetle needs her own sprite.** A whole boss mechanic — the one pest you
   must *not* shoot — is unplayable because she wears `pest_beetle.png` (`game/pest.gd:234`). It
   shipped that way for a lane-tooling reason, not a design one.
5. **`twbt` — the board's page frame artifacts.** A reported visual bug on the surface the
   player stares at for the entire run, with two named suspects that one cropped screenshot
   distinguishes.
6. **`fjqp` — draw the uproot window.** The only countdown the game hides, on its one
   irreversible four-second decision. The game already draws this shape twice
   (`husk_layer.gd:69-77`, the prep bar).
7. **`iqp8` — the campaign's second act.** Unblocked; James picked (b). Waves 9–22 average +6%
   for thirteen waves and a depth-first run won 22/22 without losing a life. The lever is
   `health_scale_for`, one function.
8. **`gfpj` + `iqf2` — two screenshots, one session.** Are the Sunflower gauge and the chew ring
   hidden under their own art, and do the hover dots and selection rings read as one mark? Both
   are five-minute answers that structural checks cannot give, and the cob pips are already
   known occluded.
9. **`om5f` — rotate the sway about the stem.** Two constants (`_sprite.offset` down 32,
   pivot up 32), no runtime cost, and it changes how every plant on the board moves. Verified
   there is no offset today (`plant.gd:305-311`).
10. **`uqeo` — the seed surplus.** Blocked on a number, not on James. Re-measure one playthrough
    against both ladders, then decide whether a sink is needed. The last measured run finished
    holding 1129 seeds with nothing to buy.

**The one piece of apparatus I would fund:** `a155` (check the transform cues by reading
properties). It is three commands, it needs no pixels, and it covers the class of defect —
a value computed correctly and drawn in the wrong place — that has produced the only shipped
visual bug this project has had. `6e2e` (the pixel half) should wait for it.

---

## 9. Is the apparatus/game imbalance real, and how big?

**Yes, and it is in the picking, not the filing.**

### Counting rule

A bead is **player-visible** if closing it changes what a player sees, hears, or can do in the
running game. Not player-visible: tests, checkers, devtools verbs, docs, skills, backlog files,
instrumentation, and refactors with no behavioural change.

### The number, three ways

**(a) What is filed.** 40 of 138 open beads (29%) are player-visible. Among the 57 I would keep,
40 are player-visible and 17 are not — **70/30 in the player's favour.** The queue is healthy.

**(b) What gets done.** Cycle 107 closed 8 beads (`g1j9`, `dozq`, `xc07`, `ghv1`, `aflo`,
`w71c`, `y1gh`, `kndl`) and cycle 108 closed 8 (`tkdz`, `0x2j`, `nj7w`, `wy2v`, `qewq`, `iljz`,
`i5ny`, `rq94`). **16 beads, 0 player-visible.** A shared source blanker, a mutation harness
verdict, a hand-copied list in two tests, a rename, a road-invariant test, two kanban audits, a
devtools argument guard, a guard sweep, a readout table, and a `WORST_CASE_TEXT` tie-in.

I count 16 rather than the 18 in the brief, and two honest corrections to it:
`54690e8` ("Put the title lawn back on the ground at any viewport height") landed inside the
cycle-108 window and *is* player-visible, though I could not map it to a bead — it reads as
parent wiring; and `n2wd` ("The Nettle's sting is a jiggle") closed at HEAD (`f14293c`), just
outside the window and squarely player-visible. So the true streak is closer to **16 of 17**
than 18 of 18. The shape of the finding is unchanged.

**(c) The apparatus itself.** 19 discovered parallel-safe checkers, 18 ran, **18 clean, 0
findings.** 752 tests, 15,298 assertions. Against that: a P1 saying the game has no touch input,
a boss wearing the wrong sprite, a user report that the Chomp does not look like it is biting,
and a reported artifact on the board's own frame.

### The mechanism

Apparatus beads are *cheap, safe, and lane-parallelisable*. Player-visible beads need an art
pass, a live game, a design call, or a decision that cannot be delegated — `81g9` and `cnn7`
both say in their own bodies that they could not be done in a lane because a worktree has no
`.godot/` and may not run the import pass. **Fan-out selects against player-visible work by
construction.** That is the imbalance's actual cause, and it is a scheduling fact, not a taste
problem: cycles 107 and 108 were both five-lane fan-outs.

### What my rule would miscount

- **A member I would call apparatus that is really player work:** `ednt` (does every glyph exist
  in the font). It is a test, so my rule scores it 0 — but a missing glyph is a `.notdef` box the
  player is looking at *right now*, invisible to every width budget because it has a real width.
  `6e2e` and `gfpj` sit in the same blind spot: they are named as checks, and what they check is
  whether a player can see the thing.
- **A member I would call player work that really is not:** `uhno` (derive message durations from
  length). It changes how long text stays on screen, which sounds player-visible — but the bead
  concedes the current spread is "probably RIGHT", so the derivation would reproduce most of the
  existing numbers and a player would notice nothing. I scored it `WONTFIX` for that reason,
  against my own rule.
