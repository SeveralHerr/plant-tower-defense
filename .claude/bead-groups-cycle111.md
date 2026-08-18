# The open queue, grouped — plant-tower-defense-ox1p

90 open beads, 14 groups, **every open bead in exactly one group** (proved by set
difference against `bd list --status=open`, not by reading down the list).

## The headline: the base rate was much lower than feared

`ox1p` predicted duplicates: *"The queue is 124 items and grew mostly by filing 3-8 per
cycle for eighty cycles, so the base rate is unlikely to be zero."*

**One true duplicate in 90.** Four other pairs looked like duplicates from their titles
and were not. That is a 1.1% rate, and the reason it is that low is worth more than the
number: **the queue's own anti-duplication rules were already working.** Read the bodies —

- `a155` opens with *"Sharpens -6e2e rather than duplicating it — read that one first,
  and note this halves its scope."*
- `iiyg` cites *"-v9px which this depends on and does not replace"*.
- `kihy` says *"If they turn out to overlap once opened, fold rather than duplicate — per
  step 6, note the open bead instead of filing a second."*

Three beads that each stopped short of being a duplicate, in writing, because whoever
filed them searched first. Step 6's rule and `verify-bd-item`'s search step are not
aspirational; they are visibly load-bearing. **The retrospective sweep `ox1p` asked for
mostly confirms the forward fix already took.**

## The one merge

| Kept | Superseded | Why |
|---|---|---|
| `8u01` *Audit the rest of kanban.md's older sections for Done-lists* | `fdz1` *Audit the six oldest kanban sections against the code they claim about* | Same file, same skill (`kanban-staleness-audit`), same sections, same bar. |

Kept the older (01:50 vs 04:35), per `ox1p`'s own rule that the older usually carries the
measurement — and here it does: `8u01` holds cycle 34's four `file:line` proofs that its
sampled section was 100% stale. **`fdz1`'s two contributions were folded into `8u01`'s
notes before superseding**, because they were the better half of the scoping:

- *the six oldest* sections is a finishable unit; "the rest" is not;
- and the reason those rot is the cycle-31 rule — entries predating it carry no
  `file:line`, which is exactly what makes them unfalsifiable.

## The four that looked like duplicates and were not

| Pair | Verdict |
|---|---|
| `r722` selection panel / `0y0w` side panel | **Distinct panels.** `r722` is the SelectionBox readout for a clicked plant; `0y0w` is `_build_side_panel`, the shop list of names/blurbs/prices. Same defect class, one panel over. |
| `v9px` re-capture baseline / `iiyg` what should the baseline cover | **A dependency, already recorded** — and in the direction opposite to my guess: `v9px` depends on `iiyg`, because a baseline captured in one arbitrary state is worth little. The tracker was right and I was wrong. |
| `9vq6` citation_check never reads beads / `orcl` read the landed lines for support | **Two halves.** `9vq6` is a tool gap (it only reads `kanban.md`); `orcl` is the judgement no tool can do — a citation that still *resolves* onto a line that no longer *supports* it. |
| `8ute` / `kihy` / `w0wh` design brief | **A hierarchy, not a duplication.** See below. |

## The real defect found: missing structure, not duplicate items

Three relationships existed in prose and not in the tracker. Recorded now:

- `kihy` (brief's UI claims) **depends on** `8ute` (whole brief)
- `w0wh` (brief's combat claims) **depends on** `8ute`
- **`w0wh` named the wrong umbrella entirely.** Its description scopes itself as "not the
  whole document, which is `-hwo6`'s larger job" — but `hwo6` audits `STYLE.md`, the *art*
  conventions, a different document. The whole-brief job is `8ute`, which was already open
  when `w0wh` was filed. Corrected in its notes.

This is the failure mode worth carrying forward. Nobody filed a duplicate; somebody
filed a **child that cited the wrong parent**, which is harder to see than a duplicate
and has the same cost — two people audit the same document without knowing it.

## The groups

| n | Group |
|---:|---|
| 15 | **Width budgets & the corpus pattern** — `r722` `0y0w` `yoc2` `wf4i` `vjr1` `rd9s` `6p1y` `nuxg` `gd27` `pabl` `b7dd` `3iwp` `ogxu` `1y2w` `uhno` |
| 9 | **Test-suite discipline** — `9afm` `to0d` `cs2k` `kjcx` `frdz` `51eo` `d6fe` `ejfa` `itbj` |
| 9 | **HUD & screen layout** — `bn2c` `i7oi` `fo96` `9a2y` `o9uo` `22a` `v78` `vte` `bia` |
| 7 | **UI/board checking apparatus** — `6e2e` `a155` `d3el` `0w8v` `v9px` `iiyg` `ip4n` |
| 7 | **Devtools verbs & harness tooling** — `rvvt` `zzx3` `a9pi` `4kgn` `rks4` `efjq` `ryfi` |
| 7 | **Open design questions** — `ix76` `h5w6` `imme` `du7p` `oo7e` `l86t` `xgjw` |
| 7 | **Process & workflow rules** — `txme` `q1xs` `vvxn` `hb43` `ais1` `bg4i` `n3zm` |
| 6 | **Drawing grammar & glyphs** — `snnp` `m14g` `cc55` `xf0b` `jk4a` `ednt` |
| 5 | **kanban.md hygiene** — `8u01` `hynr` `4yz6` `x5rf` `bt4h` |
| 5 | **Document audits** — `8ute` `kihy` `w0wh` `hwo6` `pa4g` |
| 5 | **Citation & claim checking** — `9vq6` `orcl` `ku29` `thoj` `ztue` |
| 5 | **Code structure & naming** — `8jog` `ynai` `snba` `xi0s` `o2aa` |
| 2 | **assert_margin gating** — `f7y2` `frzz` |
| 1 | **Input & platform** — `qdsi` |

## What the grouping shows that the duplicate count does not

**One group is 17% of the whole queue.** Width budgets and the corpus pattern is 15
beads — larger than the next two groups combined, and it is a single technique applied to
a series of surfaces (message row → selection panel → side panel → run summary → …), plus
five meta-beads *about* that technique (`vjr1` gather the waivers, `rd9s` report the worst
recurring string, `6p1y` watch for evidence naming a surface, `nuxg` do the budgets want
`rows_that_fit`, `ogxu` should the ratchet keep a reserve).

That is not duplication and no two of them should be merged. But it is the queue saying
something: **the project has one favourite kind of work, and it is generating beads faster
than it is closing them.** Worth a decision — is every text surface getting a budget, or
is there a point where the pattern has proved itself and the remaining surfaces are
accepted unmeasured? `yoc2` ("decide whether the other HUD surfaces deserve corpus-style
checking") is that decision, sitting inside the group it would resolve. It is the highest-
leverage item in the largest group and it is a P2 nobody has taken.

**Second observation:** `Open design questions` (7) are the only group whose items cannot
be closed by writing code — `ix76`, `h5w6`, `imme`, `du7p`, `oo7e` all need somebody to
*decide* something. Three of them are already blocked on the user. A queue that
accumulates decisions faster than it resolves them will look busy while stalling.
