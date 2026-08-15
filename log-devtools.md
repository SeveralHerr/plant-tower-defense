<!-- BEGIN godot-selftest-harness-format -->
# Devtools / `/verify` Log

Running log of two things per session: whether using the devtools harness was actually
worth it that run, and what was missing from it.

**Why this file exists.** The harness can only be improved from evidence, and the evidence
is perishable — the moment a workaround is found, the friction that forced it is forgotten.
This log is the harness's feedback channel: entries here are what later get upstreamed into
`godot-selftest-harness` itself, so a gap logged in one game becomes a fixed feature for
every game.

**Why it records value and not only gaps.** A log that only asks "what was missing?"
can only ever answer "add more harness." It has no way to say *this task didn't need the
harness at all* — so a tool that is the wrong choice for half the changes it runs on will
generate a tidy stream of feature requests and never once suggest being used less. The
`Value:` block is the half that can say so. Both halves are required.

**Append a new entry at the end of every response** (a `Stop` hook in
`.claude/settings.json` reminds you when a code change lands without one). An honest
"no gaps this turn" line is a real entry — it is what makes the absence of a gap
distinguishable from a forgotten log.

## Format

```markdown
## YYYY-MM-DD — <what the response did>

- Value: **<warranted|overkill|insufficient|inconclusive>** — <one sentence of why>
  - Expected: <what you wrote down *before* the run that runtime would reveal>
  - Got: <what it actually told you — quote the assertion, not "it passed">
  - Found: <what this run caught that reading the diff would not have, or "nothing">
  - Cheaper: <the cheapest thing that would have produced the same confidence>

- Gap: **<what was missing>** — <evidence: the command run, the output it gave, the
  workaround used instead>
  - [G-001] status: open | seen: 1 | harness: 0.7.0
  - Improvement: <the smallest change that would have closed it>
```

### The Value block

**Required on every entry, including "no gaps this turn" ones.** Gaps answer *what was
missing*; this answers *whether any of it was worth doing* — and only the second one can
ever tell you to reach for the harness less often. A log that only records friction can
recommend improvements forever without noticing that the tool was the wrong choice.

| Verdict | Means | What it should change |
|---|---|---|
| `warranted` | Runtime told you something the diff could not. **Name the specific claim**, and record it under `Found:`. | Nothing — this is the harness working. |
| `overkill` | The change was verifiable more cheaply; the run confirmed something never in doubt. This is the verdict when `Found:` is "nothing". | Invoke `/verify` less for this shape of change. |
| `insufficient` | It ran, but couldn't reach or assert the thing that actually mattered; you shipped on something weaker. | File the gap — this is where the harness needs work. |
| `inconclusive` | Aborted, or the change was too small to judge. | Nothing. Don't inflate it to `warranted`. |

`overkill` and `insufficient` are the two verdicts that teach, and they point opposite
ways: one says use it less, the other says fix it. If neither ever appears, the log is
flattering the tool rather than measuring it.

**`Found:` is the half that survives a fix.** Every other line here describes how the run
came out, so a bug the run surfaced and you repaired before writing the entry disappears
completely — the checks end green, the runners end clean, and the entry reads exactly like
one where nothing was ever wrong. That is the single biggest way this log undercounts its
own tool. Write what you fixed *because* of the run, however small; write "nothing" when
that is true and take the `overkill`. `/verify` Phase 5 records the same thing as the
countable `found` field in the ledger, and downgrades a `warranted` that found nothing.

**Write `Expected:` before the run, not after.** One line during Phase 4 Step 1, naming
what runtime should reveal that reading the diff cannot. It costs nothing and it is the
only real defense against retroactive justification — "it was useful" is easy to write
afterwards about any run that passed, and much harder when a prediction is already on the
page and the run merely confirmed what you already believed.

**`Cheaper:` must name a concrete alternative**, not a hedge. Useful answers: "reading
`ore_vein.gd:40-52`", "the existing unit test", "lint alone", "nothing — this needed the
running game". `"probably still worth it"` is not an answer. Over many runs this field is
the actual product of this log: if "reading the file" appears thirty times, that is a
finding about *when to invoke the harness*, which no amount of feature work would have
surfaced.

Honest `overkill` entries are the ones most worth writing and the least likely to get
written. A run that passed feels like a run that helped.

### The status line

Every gap carries one, and it is what makes this file machine-readable — without it an
open gap and one fixed two versions ago look identical, and a recurrence can only be
narrated in a sentence.

| Field | Values | Meaning |
|---|---|---|
| `[G-NNN]` | `G-001`, `G-002`, … | **Stable id, never reused.** Allocate the next unused number; ids are per-file, so `G-007` here and `G-007` in another project are different gaps (`tools/upstream_gaps.py` qualifies them with the project name when pooling). |
| `status:` | `open` / `fixed` / `wontfix` | `wontfix` needs a reason on the Improvement line. |
| `fixed-in:` | a harness version | Only on `status: fixed`. Omit otherwise. |
| `seen:` | an integer | How many times this gap has been hit. **Bump this instead of writing a second entry** — a recurrence is a stronger signal than a new gap, and only a counter makes that visible. |
| `harness:` | `X.Y.Z` | The installed harness version it was observed against, from `python tools/devtools.py harness-version` (`python3` outside Windows — probe by executing, the Store alias lies). Without it, a gap logged before an upgrade can't be told from a regression after one. |

Guidelines that make an entry useful later:

- **Quote the evidence.** `devtools.py: error: unrecognized arguments: --property scale`
  is actionable; "get-state was awkward" is not.
- **Say what you did instead.** The workaround is the measure of the gap's cost.
- **Prefer the smallest fix.** "Add `--property` (repeatable) to `get-state`" beats
  "improve state inspection".
- **Note recurrences by bumping `seen:`** on the original entry (and adding the new
  evidence under it) rather than filing a fresh gap that reads as if it were novel.
- **Log closures too.** When a gap gets fixed, set `status: fixed` + `fixed-in:`, and
  record whether the fix actually paid off on the next run. Never delete a gap: a fixed
  entry that comes back is the most valuable thing this file can tell you.

### Two worked entries

The first is what a good `warranted` looks like — the claim is specific enough that
someone could disagree with it:

```markdown
## 2026-07-25 — Animate the HUD orb losing a hit point

- Value: **warranted** — the tween landed at the wrong scale and only the running game said so.
  - Expected: whether `orb.scale` actually returns to 1.0 after the hit animation.
  - Got: `get-state --property scale` read `0.85` at rest; `data.transform` confirmed it.
    The diff looks correct — `scale` is never written back because the tween is `EASE_OUT`
    on a property the parent container overwrites.
  - Found: the orb rests at 0.85 instead of 1.0 after every hit. Fixed in this run by
    tweening the container's own scale; the check that caught it stays recorded `fail`.
  - Cheaper: nothing. Reading the file is what produced the wrong belief in the first place.
```

The second is the one that will not get written unless you make a point of it. Nothing
failed. The run was still not worth its 90 seconds:

```markdown
## 2026-07-26 — Rename `max_health` to `health_max` across three scripts

- Value: **overkill** — a pure rename with no runtime behavior to observe.
  - Expected: nothing specific; ran /verify out of habit because scripts changed.
  - Got: all checks passed, reach 3/3. Confirmed only what lint already proved.
  - Found: nothing.
  - Cheaper: `lint_project.gd` alone, ~4s. The 90s launch + entry hook bought nothing.
```

If your log has no entries of the second kind, that is a fact about the log, not about
the work.

### Sending gaps upstream

Open gaps only help the next project if they reach the harness repo. Pool them with:

```bash
# python3 outside Windows; on Windows the bare `python` is the one that runs
python tools/upstream_gaps.py log-devtools.md --into /path/to/godot-selftest-harness/log-devtools.md
```

It appends every `status: open` gap, deduped by id (re-running is a no-op), and bumps
`seen:` upstream when an id reappears. Nothing is deleted from this file.

---
<!-- END godot-selftest-harness-format -->

<!-- Entries below, newest at the bottom. -->

## 2026-08-15 — Scaffold the harness into plant-tower-defense (fresh install, Godot 4.7.1)

- Value: **warranted** — the smoke check caught two scaffold defects that reading the
  command doc would not have.
  - Expected: that a fresh scaffold on a scene-less Godot 4.7 project would lint clean
    on the first try, since scaffold writes every file it lints.
  - Got: `lint: 0 error(s), 3 warning(s)` naming `devtools_ext/commands.gd`,
    `devtools_ext/commands.example.gd` and `test/unit/test_example.gd` as having
    `no .uid sidecar`. Separately, the two-call `godot_bin` / `godot_version` sequence
    in step 11 printed `^ godot_bin: "<path>" -> ""` — the second call reverted the first.
  - Found: both gaps below. A first-time user following the command verbatim ends with a
    warning-emitting lint and an empty `godot_bin`, which silently breaks `/verify`.
  - Cheaper: nothing — both only appear when the scaffold is actually run end to end.

- Gap: **`scaffold_install.py config` does not record `--set` values as scaffold-owned,
  so a later bare `config` call reverts them to the shipped schema default** — step 11 of
  `scaffold-godot-harness` issues two separate invocations by design:
  `--set godot_bin=<path>` then `--set godot_version=<ver>`. The second printed
  `^ godot_bin: "C:/Users/.../Godot_v4.7.1-stable_win64_console.exe" -> ""`, wiping the
  value the first had just written. Worked around by passing both `--set` flags in one
  invocation, which produced the correct result.
  - [G-001] status: open | seen: 1 | harness: 0.18.0
  - Improvement: in `config`, write each `--set` key's value into `_scaffold_defaults`
    (so the key stays scaffold-owned at its *new* value rather than the schema default).
    Failing that, collapse step 11 into a single `--set godot_bin=… --set godot_version=…`
    call in the command doc.

- Gap: **Steps 5 and 6 copy `.gd` files with plain `cp`, bypassing the installer's `.uid`
  minting, and those paths are outside `uid_check_ignore`** — so the scaffold's own smoke
  check (step 12) reports 3 warnings on a *fresh* install. `uid_check_ignore` defaults to
  `["res://addons/", "res://tools/"]`, but the `cp`-copied files land in `res://devtools_ext/`
  and `res://test/unit/`, which lint does check. Step 4's summary explicitly promises `.uid`
  sidecars are minted for "every `.gd` the installer writes" — these three are not written
  by the installer. Worked around with
  `python tools/devtools.py new-uid --write devtools_ext/commands.gd devtools_ext/commands.example.gd test/unit/test_example.gd`
  (run per-file), after which lint reported `UIDs: OK`, 0 warnings.
  - [G-002] status: open | seen: 1 | harness: 0.18.0
  - Improvement: route steps 5 and 6 through `scaffold_install.py files` (which already
    mints uids and skips existing ones) instead of `cp`, keeping the "never overwrite
    `commands.gd`" rule. `commands.example.gd`, `test_example.gd` and `smoke.json` are
    refreshable and fit the installer's normal path unchanged.

## 2026-08-15 — Measured the Kenney TD style contract and authored the first six sprites

- Value: **warranted** — the test runner caught a hard parse error in a file
  `name_check` had just declared clean, which is the exact case the harness documents
  as NOT COVERED, and the negative run proved the new art gate actually fires.
  - Expected: that `test/unit/test_sprite_style.gd` would pass first try; `name_check
    --only test/` had returned `No findings. errors: 0 | warnings: 0 | advisory: 0`.
  - Got: `godot --headless --script res://tools/run_tests.gd -- --file test_sprite_style.gd`
    exited **2** with seven copies of
    `Parse Error: Cannot infer the type of "err" variable because the value doesn't have a set type`
    — `var err := _T.assert_true(...)` where `_T` is the untyped injected runner.
    After annotating `var err: String`, 7 tests / 49 assertions passed.
  - Found: (a) that parse error — seven occurrences, invisible to `name_check`;
    (b) proof the palette gate is not decorative: repainting the aphid's `#E74C3C`
    body to `#FF00FF` and re-running gave
    `[FAIL] test_every_colour_is_kit_palette_or_a_blend_of_two — pest_aphid stays on
    the kit palette (worst pixel #ff00ff is 188.50 off, tolerance 12.0)`, exit 1,
    restored after; (c) `Image.load_from_file()` emits a
    "will not work on export" WARNING **per call**, 31.8 KB of stderr for six sprites —
    swapped to `load_png_from_buffer`, which also cut the test from 161 ms to 68 ms.
  - Cheaper: nothing for (a) — `name_check` is documented not to reach it and lint
    would have caught it only by also compiling. For (b) nothing: an assertion you have
    not seen fail is a guess.

- Gap: **`run_tests.gd` blames the selector when the cause was a failed compile.** A test
  script that fails to parse is excluded from the discovered count, so a `--file` selector
  naming it "matches nothing" and the run ends on
  `SELECTED NOTHING - file 'test_sprite_style.gd' selected 0 of 3 discovered test(s) (exit 2)`
  followed by three lines of advice about how `--filter` matches method names. The real
  cause — `[ERR] res://test/unit/test_sprite_style.gd: Script failed to compile` — is
  printed above but is not what the verdict points at, and stderr above it was 60 lines
  of backtrace. Worked around by scrolling back to the `[ERR]` line.
  - [G-003] status: open | seen: 1 | harness: 0.18.0 | filed: SeveralHerr/godot-selftest-harness#10
  - Improvement: track the count of scripts that failed to compile during discovery, and
    when it is non-zero prefer that in the final verdict —
    `SELECTED NOTHING - 1 test script failed to compile (see [ERR] above); selector
    'test_sprite_style.gd' cannot match a script that did not load` — before falling back
    to the selector-syntax advice, which is only correct when every script loaded.

- Gap: **the DEVELOPMENT RULE is unsatisfiable on a project with no main scene, and
  nothing says so.** `project.godot` has no `run/main_scene` and
  `devtools_config.json` has `"main_scene": ""`, so `/verify`'s runtime phases have
  nothing to launch; this change (art pipeline + tooling + tests) is real work that
  cannot reach a running game. Ran the three headless gates instead —
  `name_check` (errors 0), `lint_project.gd` (`Scripts: 9 compiled OK | UIDs: OK`,
  exit 0), `run_tests.gd` (`Total: 10 | Passed: 10 | Assertions: 54`, exit 0) — and
  am reporting that as "lint + tests green, runtime unreached", not as "verified".
  - [G-004] status: open | seen: 1 | harness: 0.18.0 | filed: SeveralHerr/godot-selftest-harness#10
  - Improvement: have `/verify` detect an empty `main_scene` up front and exit with an
    explicit *degraded* verdict — run Phases 1–2, skip 3–4, and still write the Phase 5
    ledger row with `reach: 0` and a `skipped: no main_scene` field — rather than leaving
    the caller to decide whether an unlaunchable project counts as a pass.

## 2026-08-15 — built the playable game: board, plants, pests, waves, economy, HUD

- Value: **warranted** — runtime found four defects that lint, 43 green unit tests and
  reading the diff all missed, two of them "the plant does nothing and says nothing".
  - Expected: the board draws 126 tiles with a dirt corridor and no missing edge tile; a
    Corn Cobbler placed next to the road actually kills an aphid before it reaches the
    exit; a Chomp Flower holding a beetle blocks nothing else; and the HUD's seed/wave/
    lives labels update from real game state — none of which the diff shows, because the
    tile lookup, the targeting radius in pixels, and the Control layout are all only true
    once rendered.
  - Got: `{'seeds': 225, 'lives': 10, 'pests_alive': 1, 'plants': 1}` after
    `step-time --seconds 6` with one aphid and one cob — the aphid was still alive and
    seeds had not moved, i.e. the corn had been firing into empty ground for six seconds.
    After the fix, the same sequence returned `{'seeds': 228, ..., 'pests_alive': 0}`.
    For the Chomp, `run-method --method is_busy` returned `Result: true` only after the
    radius fix; before it, `find-nodes --class Pest` came back `0 node(s) matched` with
    the beetle long past and the flower never having closed.
  - Found: (1) `Kernel.setup(global_position, …)` seeded a **sibling** from a global
    coordinate — the entities layer is offset by the 72 px top bar, so every kernel
    launched one bar-height below the cob and hit nothing. (2) `ChompFlower.GRAB_RADIUS`
    was 62 px while a plant and the road lane beside it are exactly `CELL = 64` apart, so
    the flower could never reach anything; "found no prey" and "there is no prey" are the
    same observation. (3) Kenney tiles 038–045 read as grass variants by colour histogram
    but are the kit's overlay markers (plot square, wrench, X, target) and scattered
    obvious UI junk across the field. (4) the seed-packet button used the corn sprite;
    `seed_packet.png`, authored last session, was wired to nothing.
  - Cheaper: nothing. All four needed the running game. The two coordinate/radius bugs
    were invisible to the unit tests *by construction* — every test placed plant and pest
    in the same unoffset space, which is exactly the condition under which both bugs
    disappear. Both now have regression tests that fail when reverted (verified by
    reverting: `[FAIL] test_kernels_launch_from_the_cob_on_an_offset_layer`).

- Gap: **`find-nodes` locates a node but the auto-generated name is the only handle you
  get, and it is not stable across launches.** `find-nodes --class ChompFlower` returned
  `/root/Game/Entities/@Node2D@128`, which is what every follow-up `run-method` and
  `get-state` then has to be typed against; relaunch and it is `@Node2D@131`. Workaround
  was to re-run `find-nodes` before every read and paste the path back in by hand.
  - [G-005] status: open | seen: 1 | harness: 0.18.0
  - Improvement: give `find-nodes` a `--call METHOD` / `--property NAME` pass-through that
    invokes the read on each match and reports it beside the path, so identifying a node
    and reading it are one command. `--property` already exists for properties; the
    missing half is a method call, which is the only way to read anything behind a getter.

- Gap: **[G-004] is now closed for this project — recording the transition rather than a
  new entry.** `main_scene` was empty last session and `/verify` had nothing to launch;
  this session set `run/main_scene` and `devtools_config.json`'s `main_scene` to
  `res://game/game.tscn` and all runtime phases ran. The harness-side improvement
  (an explicit *degraded* verdict when `main_scene` is empty) is still unshipped.
  - [G-004] status: open | seen: 2 | harness: 0.18.0 | filed: SeveralHerr/godot-selftest-harness#10
  - Improvement: unchanged from the original entry.
