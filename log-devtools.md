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

## 2026-08-15 — Refreshed the self-test harness from 0.18.0 to 0.19.0 (/scaffold-godot-harness)

- Value: **warranted** — the smoke check is the only thing that proved the 0.19.0 core
  actually parses against this project's Godot 4.7.1, and the config merge misbehaved in
  a way only a read-back caught.
  - Expected: a no-op refresh — files bumped, `devtools_config.json` keys preserved,
    lint still green.
  - Got: `lint: godot-selftest-harness 0.19.0 | scan_root res:// … Scripts: 24 compiled
    OK | UIDs: OK | res://game/game.tscn: OK | lint: 0 error(s), 0 warning(s) -> exit 0`,
    and `name_check` `errors: 0 | warnings: 1 | advisory: 4` against
    `engine index: Godot Engine v4.7.1.stable.official (1036 classes, 38 builtins)`.
  - Found: the step 7 config merge silently cleared `godot_bin` and `godot_version`
    (`^ godot_bin: "C:/Users/gotmi/Downloads/Godot_v4.7.1/…_console.exe" -> ""`). Restored
    by hand before continuing; see the gap below. Also surfaced a real pre-existing
    project finding lint does not gate on — `game/board.gd:124` loads
    `res://assets/kenney/png/towerDefense_tile%03d.png`, which does not exist.
  - Cheaper: nothing. `git diff` on the config would have shown the blanking only if I
    had thought to look at a key the command's own step 11 was about to rewrite anyway.

- Gap: **`scaffold_install.py config` treats an empty shipped default as a proposal, so a
  refresh wipes `godot_bin`/`godot_version` before the step that re-detects them.** The
  template ships `"godot_bin": ""`, the key is scaffold-owned, and step 7 runs *before*
  step 11's binary detection — so every refresh transiently destroys a working recorded
  path. Here step 11 put it back, but on a machine where the detection globs miss (binary
  moved, `GODOT_BIN` unset) the refresh would leave the project with no binary at all,
  having deleted the one an earlier run had found. Workaround: re-ran
  `scaffold_install.py config --set godot_bin=… --set godot_version=…` by hand after
  detection.
  - [G-006] status: open | seen: 1 | harness: 0.19.0 | filed: SeveralHerr/godot-selftest-harness#7 (comment - same root cause as the open issue, new manifestation on the refresh path)
  - Improvement: in `cmd_config`, an empty/None shipped default is a placeholder, not a
    proposal — never let it clear a non-empty existing value unless `--set` names the key:

    ```python
            for key, value in proposed.items():
                if key not in merged:
                    ...
                    continue
    +           # An empty shipped default is a placeholder, not a proposal. It must not
    +           # clear a value a previous run detected and recorded (e.g. godot_bin).
    +           if (key not in overrides and value in ("", None)
    +                   and merged.get(key) not in ("", None)):
    +               owned.add(key)
    +               print("  = %s kept as %s (shipped default is empty - not a proposal)"
    +                     % (key, json.dumps(merged[key])))
    +               continue
    ```

## 2026-08-15 — Committed the 0.19.0 refresh and the in-flight range-ring work

- Value: **overkill** — lint and the unit suite were run as a pre-commit gate and both
  passed, confirming what the diff already showed. The one real finding came from a grep.
  - Expected: nothing. The harness diff was a version bump and the game diff added a flag
    and a `_draw()`; neither could plausibly break a compile or an assertion.
  - Got: `lint: 0 error(s), 0 warning(s) -> exit 0` with `Scripts: 24 compiled OK`, and
    `Total: 43 | Passed: 43 | Failed: 0`, `Assertions: 323 executed`,
    `Suite: 6 test script(s)`, `Autoloads: 1 of 1 ready`.
  - Found: `Plant.set_selected()` has no caller anywhere in the project, so `_selected` is
    never true and `CornCobbler._draw()`'s range ring can never appear. Committed as
    explicitly incomplete rather than as a working feature. Found by grepping for the
    method name — **not** by either gate above, both of which were green on a feature that
    cannot fire.
  - Cheaper: `lint --find-orphans`, ~20s. Confirmed after the fact that it does catch it:
    `WARN: res://game/plant.gd: set_selected() has no reference outside its own file -
    heuristic, may be a callback or called by name`.

- Gap: **the check that catches a dead-on-arrival feature is opt-in, so the default gate
  reports green on code that can never execute.** `--find-orphans` found `set_selected` in
  one run, but nothing suggests reaching for it: plain lint does not mention orphans exist,
  and `/verify` does not pass the flag. A method added in the same diff as its only reader,
  with no caller, is the signature of unfinished wiring — and it is invisible to every gate
  that runs by default.
  - [G-007] status: open | seen: 1 | harness: 0.19.0
  - Improvement: run the orphan pass always and print the count as a denominator line
    (`Orphans: 0 of 24 script(s)`), the way `Shaders:` and `UIDs:` already report. Keep it
    non-gating — the heuristic has real false positives on callbacks — but a silent absence
    and a clean result should not look identical. Narrower alternative: gate only on a
    public method that is **new in the diff** and has no reference outside its own file,
    which is the unfinished-wiring case without the callback noise.

## 2026-08-15 — Wired Plant selection (closing G-007) and added the Chomp chew ring

- Value: **warranted** — runtime proved the G-007 wiring gap is actually closed, which no
  static gate can say (both lint and `--find-orphans` were the tools that *found* the gap
  last run; only a live selection click can prove the fix).
  - Expected: `set_selected()` now has a caller, so `CornCobbler`'s range ring renders on
    selection; the new Chomp chew ring shrinks in step with `chew_progress()`.
  - Got: after `place_plant`, `get-state _selected` read `true` immediately (previously
    dead code). `sample-pixels --rect 190,90,36,30` on the ring's edge went from
    `dominant_share 94%` / `brightest 0.196` (unselected baseline) to `dominant_share 47%`
    / `brightest 0.302` while selected, then back to `95%` / `0.180` after switching the
    plant bar selection away — a measurable ring, appearing and disappearing on cue. The
    Chomp's timers were also verified over real time: `_held` null -> beetle object ->
    `_chew_left` 2.6 -> 0.73 (after 2s) -> 0.0 and released (after 1 more second), matching
    `chew_seconds` exactly.
  - Found: confirmed G-007 is fixed — `set_selected` no longer appears in a
    `--find-orphans` run at all. Also hit a real workflow snag: `cmd place_plant` takes
    `x`/`y` args, not `cell`; a `{"cell":[1,1]}` call silently placed at the default (0,0)
    instead of failing, which cost a few minutes of confused `find-nodes` before reading
    `devtools_ext/commands.gd`.
  - Cheaper: nothing for the selection-ring fix — this is exactly the "found by grepping,
    not by a gate" case the prior session flagged, and only the running game can prove a
    click now does the right thing. The Chomp ring's *pixel* isolation was closer to
    overkill: the flower sprite's own orange/yellow palette confounds a small ring, so that
    one check ended `blocked` rather than a clean pass (see gap below) — the state-machine
    check (`_held`/`_chew_left` over real time) is what actually carried the confidence.

- Gap: **`cmd place_plant`'s devtools arg name doesn't match the intuitive `cell` used
  everywhere else in this project's own docs/tests, and a wrong key is silently ignored
  rather than reported.** `_cmd_place_plant` reads `args.get("x", 0)` / `args.get("y", 0)`;
  passing `{"plant":"...", "cell":[1,1]}` doesn't error, it just defaults both to 0 and
  reports success at `(0, 0)` — which reads exactly like "I placed it where I asked."
  - [G-008] status: open | seen: 1 | harness: 0.19.0
  - Improvement: this is a project verb (`devtools_ext/commands.gd`), not harness core, so
    the actual fix belongs there: accept `cell: [x,y]` as an alias, or reject unknown keys
    when `x`/`y` are absent instead of defaulting silently. Noting it here because the
    *pattern* — a project verb accepting an args dict with no key validation — is generic
    enough that the harness's own `list-commands`/`cmd` help text could recommend project
    verbs assert `args.has(...)` rather than `.get(key, default)` for anything spatial.

## 2026-08-15 — Six features in one session: compost meter, pest mutations, seed packet tiers + Seed Sunflower, sprite pass 2, title screen + endless mode, Designer's Notebook

- Value: **warranted** — runtime caught two real, un-Grep-able layout bugs and the headless
  test run caught two silently-vacuous tests before either shipped.
  - Expected: the six new bd issues integrate into the live game without breaking existing
    plant/pest/economy behavior, and findings/lint/tests stay clean.
  - Got: `findings` caught a real `button_text_overflow` on the new side-by-side packet
    buttons and a real `signal_unconnected` on `WaveDirector.wave_spawning_finished`, both
    fixed and re-verified clean. A live screenshot of the Designer's Notebook then showed
    the *entire title screen* — Start/Endless/Notebook buttons, title, subtitle, high-score
    — visible right through the notebook's supposedly-opaque backdrop, plus its two preview
    images blown up to nearly the full screen instead of their 320x320 box.
  - Found: (1) `entry_hook.node_path: "."` in devtools_config.json doesn't resolve via
    `run-method` — needed the literal `/root/TitleScreen`, fixed in config. (2)
    `Control.set_anchors_preset(PRESET_FULL_RECT)` silently resolves to a 0x0 rect for a
    Control added as a bare scene root or via a plain `add_child()` outside a layout pass —
    invisible on the title screen itself (INK is nearly the viewport's own clear colour)
    but fatal for an overlay meant to hide what's under it. Fixed by switching to explicit
    `position`/`size` assignment, matching the pattern `hud.gd` already used everywhere
    else in this project — the working convention was right there and the new screens
    didn't follow it. (3) `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL` outside a Container
    has no real "available width" to fit against and blew a 320x320 box up to most of the
    screen; switched to `EXPAND_IGNORE_SIZE`. (4) GDScript lambda closures capture locals
    **by value**, not by reference — two new unit tests (`grew_seeds`/`destroyed` signal
    listeners assigning to an outer `bool`/`int`) silently verified nothing; both were
    passing for the wrong reason until switched to a boxed single-element `Array`. (5) An
    automatic physics tick during `instantiate_scene()`'s settle frames grabbed a test
    pest before the test's own "idle" baseline was captured, because
    `set_physics_process(false)` called on a node *before* it enters the tree does not
    stick in Godot 4 — the flag is re-derived on enter-tree. Restructured the one test that
    depended on ordering to not need it.
  - Cheaper: nothing for the two layout bugs — pure rendering defects, invisible to lint,
    name_check, and a headless `instantiate_ui` that never asserted on `.size`. The lambda
    and physics-tick bugs needed the actual `run_tests.gd` execution, not a diff read.

- Gap: **`quit` reported the launched process as "STILL ALIVE 10s after quit" three times
  in one session** (pids 19132, 18560, and one earlier), every time requiring a manual
  `Stop-Process -Force` before the next `launch` would proceed. `taskkill /F /PID <n>` run
  through the Bash tool's MSYS path translation mangles `/F` into a phantom `F:/` path
  argument and fails outright — PowerShell's `Stop-Process -Id <n> -Force` is what actually
  worked.
  - [G-009] status: open | seen: 4 | harness: 0.19.0
  - Improvement: on Windows, `devtools.py quit`'s own follow-up guidance
    (`taskkill /F /PID <pid>`) is wrong for an agent shelling out through a POSIX-translating
    bash — either quote/escape the flag in the printed suggestion, or print the
    PowerShell form (`Stop-Process -Id <pid> -Force`) as an alternative on Windows.

- Gap: **`godot --headless --path . --import` must be re-run after adding any new
  `class_name`-declared script, or every script that references it fails with
  `Could not resolve external class member` / `stale class cache` — and the failure mode
  cascades into completely unrelated files**, which reads like a broad regression rather
  than "the cache needs a refresh." Hit twice this session: once after adding
  `compost_meter.gd`/`husk_layer.gd`/`sunflower.gd`/`title_screen.gd`/`notebook_screen.gd`,
  and once more after editing (not even adding) `notebook_screen.gd`/`title_screen.gd` for
  the layout fix, which briefly looked like a *different* bug (`get_viewport_height()` not
  found) before `lint_project.gd`'s own `class_cache_stale` hint pointed at the real cause.
  - [G-010] status: open | seen: 2 | harness: 0.19.0
  - Improvement: `lint_project.gd` already prints the `stale class cache` hint — the CLAUDE.md
    workflow section could say explicitly "after creating a new `class_name` file, run
    `--import` before the next lint/test pass" rather than leaving it to be rediscovered
    from the hint each time.

## 2026-08-15 — Selection marker for plant-tower-defense-42t (second selection cue)

- Value: **warranted** — runtime showed the deselection half of `Game._select()`'s
  exclusivity working across two live plants, which the diff alone only asserts by naming.
  - Expected: Selecting/deselecting a plant flips a separate `SelectionMarker` child's
    visibility, and this works even for `ChompFlower`/`CornCobbler`, which fully override
    `Plant._draw()` and never call `super._draw()` — something only observable by
    inspecting the live scene tree and node state, not by reading the diff.
  - Got: `get-state --property visible` on the first placed Corn Cobbler's marker read
    `true` right after `place_plant` (auto-selects), then `false` after a second
    `place_plant` call — confirming `_select()`'s "exactly one plant selected" invariant
    holds at runtime, not just in the one-plant unit tests. A screenshot showed yellow
    corner brackets on only the newly placed plant, distinct from its green range ring.
  - Found: the marker node really does show up as its own scene-tree entry
    (`res://game/selection_marker.gd`) as a sibling of the sprite/health bars, not folded
    into the plant's own draw calls — confirms the "separate node, not `_draw()`" design
    actually avoids the per-subclass `_draw()`-override trap it was built to avoid.
  - Cheaper: the two unit tests (`test_a_chomp_flowers_selection_marker_shows_even_though_it_owns_draw`,
    `test_a_sunflowers_selection_marker_is_shared_from_the_base_plant_class`) alone would
    have covered the "marker exists and toggles" wiring; only the two-plant exclusivity
    case needed the running game.

- Gap: **`quit` reported "STILL ALIVE 10s after quit" again**, same as G-009 below —
  `taskkill /F /PID <pid>` through the Bash tool's MSYS path translation still mangles
  `/F`; `Stop-Process -Id <pid> -Force` (via the PowerShell tool) is what actually worked,
  same fix as last time. No new gap filed — bumped the existing one.
  - [G-009] status: open | seen: 5 | harness: 0.19.0
  - Improvement: unchanged from the existing entry below.

- Gap: **project verb arg names aren't discoverable from `list-commands` or `--help`** —
  `place_plant`'s actual keys are `plant`/`x`/`y` (read from `devtools_ext/commands.gd`
  source), but a first guess of `id`/`cell` (matching `Game.place_plant(id, cell)`'s own
  signature) was silently accepted and planted the *default* plant at the *default* cell
  instead of erroring on the unknown keys — `args.get("plant", "corn_cobbler")` treats a
  wrong key name identically to an omitted one. Cost two wasted calls before reading the
  handler source.
  - [G-011] status: open | seen: 1 | harness: 0.19.0
  - Improvement: `list-commands` already enumerates registered project verbs by name;
    printing each verb's `args.get(...)` keys (grep-able straight out of the handler, no
    schema needed) alongside the name would remove the guess-then-read-source step for
    every project verb, not just this one.

## 2026-08-15 — Lane pressure readout for plant-tower-defense-4wv

- Value: **warranted** — the live run found a real bug the diff read did not: a wave lost
  to zero lives never committed its lane pressure, because `_process`'s own
  `if game_over: return` guard skips `_check_wave_cleared` (the only committer) on that
  exact path.
  - Expected: Committing "furthest pest reached" to the board only happens through
    `_check_wave_cleared` today; the live run would need to exercise both a normal wave
    clear *and* a game-over-mid-wave loss to know whether the readout also updates on a
    loss, since reading the diff alone couldn't say what `_process`'s early-return guard
    does to a signal-driven commit still in flight.
  - Got: `board_info` showed wave 1 clear normally at 5 lives, wave 2 auto-start and lose
    the run at 0 lives — then `run-method --method lane_pressure_alpha --args "[[13,7]]"`
    read back `1.0` for the last real path cell before the exit, and a screenshot showed
    the red tile sitting exactly there. Before the fix, the same sequence left it at `0.0`
    after a game-over loss (only a normal clear updated it).
  - Found: losing the last life mid-wave sets `game_over = true`, and `_process`'s early
    return means `_check_wave_cleared` never runs for that wave — the board silently kept
    showing the *previous* wave's pressure forever on any run that ends in a loss (which,
    per the design brief, is most of them). Fixed by committing directly from
    `_on_pest_escaped` when lives hit 0; added
    `test_lane_pressure_is_committed_even_when_the_last_life_is_lost_mid_wave`, which
    fails without the fix and passes with it — the strongest evidence this run's own
    Phase 4 methodology (design the test from the diff, run it live, then promote it) was
    the reason the bug was caught at all rather than shipped.
  - Cheaper: the three pure Board tests (`record_lane_pressure` lighting/ignoring/fading a
    cell) would have been overkill alone — findable by inspection, no engine needed. The
    game-over interaction specifically needed the live game; a careful enough re-read of
    `_process`/`_check_wave_cleared`/`_on_pest_escaped` together might have caught it on
    paper, but a first pass at writing the feature did not, and the live run did.

- Gap: **`quit` reported "STILL ALIVE 10s after quit" a fifth time** this session — same
  as G-009, same `taskkill` mangling, same `Stop-Process -Id <pid> -Force` fix. No new
  gap filed.
  - [G-009] status: open | seen: 5 | harness: 0.19.0
  - Improvement: unchanged from the existing entry.

## 2026-08-15 — Mutated pests drop a better husk for plant-tower-defense-1rh

- Value: **warranted** — the live run confirmed the multiplier reaches an actual
  `compost_state` value through the real signal chain, not just isolated unit math.
  - Expected: `Game._on_pest_died` reads `pest.husk_multiplier()` when computing husk
    value, so a mutated pest killed live should drop a strictly larger husk than an
    identical unmutated pest — the diff shows the formula but not that the live
    `compost_state` actually reflects it end to end (spawn → mutate → kill → drop_husk →
    compost_state).
  - Got: `spawn_pest` + `run-method kill` on a plain aphid dropped a husk worth `2`;
    the same on a `hungry`-mutated aphid dropped `3` — matching
    `maxi(1, ceil(seed_value/2 * multiplier))` exactly for both.
  - Found: the same `Pest.died` → `Game._on_pest_died` → `CompostMeter.drop_husk` chain
    the unit test already exercises headless-and-pumped also holds inside the actual
    live window (real signal delivery through the running tree, real devtools verb
    argument plumbing) — a narrower confirmation than the earlier two runs' actual bugs,
    but a live-only claim rather than a restatement of the unit test.
  - Cheaper: the `GAME_SCENE`-hosted unit test alone gets most of the way there for
    free; the live run's marginal addition was specifically the running-window
    confirmation above, which is real but modest next to the two bugs the prior two
    runs caught.

- Gap: none — `spawn_pest --args '{"mutation": "hungry"}'` worked first try (arg name
  guessed correctly this time, unlike `place_plant`'s `plant`/`x`/`y` in G-011).

## 2026-08-15 — Endless mode mutates faster over time for plant-tower-defense-1qi

- Value: **overkill** — everything passed and confirmed exactly the shape the pure
  function's own math already guaranteed.
  - Expected: `mutation_chance_for` is a pure static function, so its whole curve
    (flat, then a linear climb, then a cap) is knowable from the diff. The live run's
    only job was confirming the *actual live `WaveDirector` instance* — not a fresh
    `WaveDirector.new()` in a unit test — calls it the same way across the same range.
  - Got: `curve --node /root/Game/WaveDirector --method mutation_chance_for --from 1
    --to 40 --step 5` returned `min 0.4 max 0.85`, flat through wave 6, climbing from
    wave 11 on, capped at `0.85` by wave 31 — exactly the shape the four unit tests
    already proved.
  - Found: nothing the unit tests hadn't already shown. Taking the `overkill` honestly
    here, per the log's own note that it is the verdict most likely to go
    under-reported — this session's other three entries were all `warranted`, and one
    of these five items being an honest `overkill` is the expected shape, not a
    surprise.
  - Cheaper: the four unit tests (flat-through-table, climbs, capped, aggregate rate
    above baseline over 200+ sampled pests) already prove the formula and its wiring
    into `_build_schedule` headlessly; `curve` was a nice sanity check but changed no
    conclusion.

- Gap: none this run.

## 2026-08-15 — Second bite frame for plant-tower-defense-rrx

- Value: **warranted** — the live run confirmed the exact crossover frame on a real,
  physics-driven chew, not a hand-picked test delta.
  - Expected: the threshold swap is a one-line condition inside `_chew()`, so the logic
    is knowable from the diff — the live run's value is confirming the actual rendered
    `Sprite2D.texture` on a real, running chew (real `chew_seconds` countdown, real
    grab/release signal timing) crosses at the right moment rather than a moment
    early/late from an off-by-one or a `progress()` rounding edge, which only shows up
    by watching the real timeline.
  - Got: polling `chew_progress()` and the sprite's `texture` resource path together
    across a real, slow-motion (0.1x) beetle chew: still `chomp_flower_eating.png` at
    13%/29%/45% progress, already `chomp_flower_eating_late.png` at 61%, still there at
    93%, back to `chomp_flower.png` the moment the chew released at 0%.
  - Found: no off-by-one in the `> LATE_BITE_THRESHOLD` comparison, and the swap-back to
    idle on release actually fires on a real chew end (not just in `release()` called
    directly, which is all the unit test exercises).
  - Cheaper: the three `ChompFlower` unit tests already assert the same crossover via
    synthetic `_chew(delta)` calls with hand-picked deltas; the live run's real addition
    was narrow but genuine — confirming it against the actual per-frame countdown.

- Gap: **three separate live Godot processes were found still running simultaneously**
  (`Get-Process | Where-Object ProcessName -like "*Godot*"` showed pids started at
  6:02pm, 6:37pm and 6:39pm, all in this one session), after *every* `quit` in this
  session reported "STILL ALIVE" (G-009) and every follow-up `Stop-Process -Id <pid>`
  reported success. The pid `quit`'s warning names and the pid `Stop-Process` killed
  successfully is the **bus-answering engine pid** — but on Windows, `launch`'s own
  console-wrapper process (`..._console.exe`) spawns a separate child process that
  actually owns the window and answers the bus, and `Stop-Process` on the wrapper's own
  reported "Launched pid" does not reliably take the child down with it. Across 5+
  quit/relaunch cycles this session, that left a trail of zombie engines all still
  polling the same `user://` bus directory, which is exactly the "Crossed replies"
  failure mode named in the harness's own gotchas — it presented as newly-spawned pest
  nodes reporting "Node not found" seconds after a `scene-tree` call had just listed
  them (a `spawn_pest`/`scene-tree`/`set-state` triplet hitting three different engine
  instances). Fixed for the rest of this run with
  `Get-Process | Where-Object { $_.ProcessName -like "*Godot*" } | Stop-Process -Force`
  instead of killing one named pid.
  - [G-012] status: open | seen: 1 | harness: 0.19.0
  - Improvement: `quit --wait` already detects "STILL ALIVE" — it could also print
    `Get-Process`-style guidance for Windows specifically (kill every process matching
    the Godot binary's name, not just the one pid it tracked as bus owner), since the
    pid it names is demonstrably not sufficient to guarantee a clean kill on this
    platform. Named it G-012 rather than folding into G-009, since G-009 is about the
    `taskkill`-vs-`Stop-Process` command form and this is about which pid to target at
    all — the two compound (a session hitting G-009 five times in a row is exactly the
    session at risk of also hitting this).

## 2026-08-15 — Husk size/glow scales with value for plant-tower-defense-afd

- Value: **warranted** — the run caught two things the diff could not: a `project.godot`
  the engine had silently truncated, and a HUD collision that only appears once the
  compost count reaches two digits.
  - Expected: runtime should show a live mutated-beetle kill actually dropping a
    max-value husk and `HuskLayer._draw` rendering it without error — the static tests
    assert the sizing function, not that `_draw` survives the lerped arc width on a real
    husk.
  - Got: killing every pest on the board returned
    `values: [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 9]` from `cmd compost_state` — the game's
    real drops land on exactly the two ends the constants are pinned to
    (`value 2 -> radius 8.0`, `value 9 -> radius 15.0`), and the screenshot shows the
    9-seed husk as a visibly larger disc with a brighter, heavier rot ring than the ten
    aphid husks strung along the bottom road. Eleven husks drawn simultaneously, stderr
    empty.
  - Found: (1) the working tree was carrying an earlier `godot --import` rewrite that had
    deleted `window/size/viewport_width=1152` and `viewport_height=648` from
    `project.godot` — the guard step in Phase 1 is what surfaced it; restored. (2) With
    eleven husks down, the HUD reads `Compost 0 (11 ready)` and the `(11 ready)` suffix
    runs underneath the "Grow the next wave" button. `findings` reported
    `0 finding(s) across 5 of 5 checks` over that frame, because the label's own rect is
    fine — it is the *button* that overlaps it, and no check compares two sibling
    Controls' rects for occlusion of text. Filed to kanban.
  - Cheaper: nothing for either. The HUD overlap needs eleven simultaneous husks on a
    live board; the sizing arithmetic was already settled by the four new unit tests in
    `test_selftest.gd`, which is where it belongs.

- Gap: **`find-nodes --class X` does not match a script `class_name`, only engine
  classes, and reports the miss as an empty result rather than as an unknown type.**
  `python tools/devtools.py find-nodes --class Pest` returned `0 node(s) matched:` with
  six live `Pest` nodes in the tree — they report `type: Node2D`, since that is their
  engine class. Worse, combining it with a predicate produces a *misleading* diagnosis:
  `find-nodes --class Pest --where mutation=hungry` printed
  `no candidate exposes 'mutation'`, which reads as "the property is wrong" when the
  truth is "the population was empty". Workaround was `--group pests`, which only works
  because this project happens to add its pests to a group.
  - [G-013] status: open | seen: 1 | harness: 0.19.0
  - Improvement: resolve `--class` against the global class cache
    (`ProjectSettings.get_global_class_list()` / the script's `get_global_name()`) before
    falling back to `is_class()`, and when a `--class` value matches neither an engine
    class nor a registered `class_name`, exit 1 naming it as an unknown type instead of
    returning a clean zero-match. A predicate message must not be emitted for an empty
    candidate set.

## 2026-08-15 — Endless mode scales pest health/speed for plant-tower-defense-nps

- Value: **warranted** — the live wave confirmed the scaled pests still walk the road,
  which is the failure this change could plausibly have introduced and which no headless
  test can see, and it turned up a false gate in `validate-ui`.
  - Expected: a live endless wave past the fixed table should spawn pests that are
    measurably tougher/faster and still traverse the route correctly — the headless tests
    assert the multipliers, not that a 1.6x aphid follows `_advance` legs without
    overshooting a corner.
  - Got: with `current_wave = 38` (over = 30, so 2.8x health / 1.45x speed),
    `find-nodes --group pests --property health --property max_health --property speed`
    returned `health=8.4 max_health=8.4 species=aphid speed=113.1` and
    `health=44.8 max_health=44.8 species=beetle speed=55.1` — exactly 3.0x2.8, 16x2.8,
    78x1.45 and 38x1.45, with `health == max_health` on both, i.e. spawning full rather
    than pre-damaged. Feeding all 18 live pests' positions through
    `Board.world_to_cell` and `Board.is_path` gave `off-road pests: 0`, and letting the
    whole of wave 39 run took `lives` from 10 to 0 with `pests_alive: 0` — every pest
    completed the route at 1.45x speed rather than clipping a corner or sticking.
  - Found: `validate-ui` reported a NEW `ui_layout` finding against the game-over
    banner — `Label 'Banner' text 'The garden is eaten\nSeeds grown: 0  (best 721)'
    exceeds width (text: 1052px, label: 896px)`. A cropped screenshot shows the banner
    rendering perfectly on two centred lines well inside its box: the check measures a
    multiline Label's text as one joined line. Left unbaselined deliberately — baselining
    it would also silence a genuine overflow of that same label later.
  - Cheaper: the multiplier arithmetic needed nothing beyond the six new unit tests in
    `test_selftest.gd`, and that is where it now lives. The route-traversal check at
    1.45x speed and the banner false positive both needed the running game.

- Gap: **`validate-ui`'s overflow check does not account for newlines or autowrap, so any
  multiline `Label` is a permanent false positive.** The game-over banner is a two-line
  Label; the check joined the lines and compared 1052px of text against an 896px box,
  gating a run over UI that a screenshot shows is correct. There is no way to express
  "this Label is multiline" short of baselining the node, which also suppresses real
  overflow findings on it forever.
  - [G-014] status: open | seen: 1 | harness: 0.19.0
  - Improvement: measure per line. Split the Label's `text` on `\n` and compare the
    widest line against the box; when `autowrap_mode != AUTOWRAP_OFF`, compare
    `get_line_count() * get_line_height()` against the box *height* instead and skip the
    width test entirely, since a wrapping Label is supposed to exceed its width.

## 2026-08-15 — Lane pressure records every loss cell for plant-tower-defense-j1h

- Value: **overkill** — the run produced a nice picture and confirmed exactly what the
  eight new unit tests had already settled. Nothing was caught. The ledger downgraded my
  self-reported `warranted` on the empty `found`, and it was right to.
  - Expected: a real wave should now paint several road cells at different strengths —
    the old high-water-mark version could only ever produce exactly one cell at 1.0 per
    wave, so the multi-cell distribution is the thing runtime can show that the diff
    cannot.
  - Got: after wave 1 played out against two Corn Cobblers,
    `Board.lane_pressure_alpha` across all 126 cells returned
    `(3,1)=0.5  (4,1)=0.5  (6,1)=0.5  (9,7)=1.0` — four cells, two strengths, where the
    old code could produce exactly one cell. After wave 2 the earlier ones read
    `0.50 -> 0.275`, i.e. faded by `LANE_PRESSURE_DECAY` exactly once for the whole
    batch rather than once per cell, which was the specific bug the batch API exists to
    avoid. The screenshot shows the graded map.
  - Found: nothing. Every claim above is one a unit test already makes. The one thing
    only runtime could have caught — that deleting the per-frame `_track_lane_pressure`
    scan silently blanked the overlay — did not happen.
  - Cheaper: the eight new unit tests alone, ~9s headless. The honest read is that this
    change was event-plumbing plus pure arithmetic, and both halves are exactly what
    `test_dir` is for. A screenshot for the visual grading would have been the only
    runtime call worth making.

- Gap: no gaps this turn. `find-nodes`, `step-time`, `run-method` on `Board` methods with
  `Vector2i` args passed as `{"x":…,"y":…}`, and region `screenshot` all did what they
  say. [G-013] and [G-014] from earlier this session were not re-hit.

## 2026-08-15 — Placement preview cue for plant-tower-defense-rfh

- Value: **warranted** — `node-bounds` answered the one question the unit tests
  structurally cannot ask, and the run turned up a reach blind spot around subclassing.
  - Expected: runtime should show the preview node landing at the correct *screen*
    position under a given mouse point — the headless tests assert `position` in Entities
    space, and this project has already been bitten once by the 72px HUD-bar offset
    between Entities space and screen space.
  - Got: driving `_update_cursor` with mouse `(200, 300)` put the preview's
    `global_rect` at `(224, 296)` — exactly `cell_to_world(3,3) = (224,224)` plus the
    `Hud.BAR_HEIGHT` 72 offset, so the ring is centred on the cell the player is actually
    pointing at. Hovering road gave `placeable=False` and a screenshot of red brackets
    with no coverage ring; grass gave green brackets and the 176px Corn ring; off-board
    hid it. Switching Corn -> Chomp with **no mouse motion** swapped `reach 176.0 ->
    73.6` and flipped `placeable` to false, because the Chomp is still locked at run
    start — a case I had not thought to write a test for and which the code got right
    for free by routing affordability through `bank.can_afford`.
  - Found: (1) `verify_ledger reach` scored `game/selection_marker.gd` unreached even
    though `PlacementPreview extends SelectionMarker` and its `_draw_brackets()` ran for
    the whole session — a live node reports only the script attached to it, never its
    base class, so *every* base class in a project is structurally invisible to reach
    unless some node instantiates it directly. Added a `reach_aliases` entry; the line
    now reads `+2 by alias ... nothing left unreached`. (2) The first game instance
    stopped polling the bus mid-session and exited with completely empty stdout *and*
    stderr. Relaunched; every check re-passed with identical numbers, so it was not the
    change — but a Godot that vanishes without writing a single line anywhere is worth
    recording.
  - Cheaper: nothing for the screen-space check — `node-bounds` through the live
    CanvasLayer/offset chain is the only thing that answers it. The state machine
    (`placeable` / `reach` / `visible` across road, grass, occupied, unaffordable,
    off-board) was fully covered by the seven new unit tests and needed no game.

- Gap: **reach treats a base class as unreached whenever only subclasses are
  instantiated, which is silent and systematic rather than project-specific.**
  `verify_ledger.py reach` printed `NOT reached: game/selection_marker.gd` for a script
  whose `_draw_brackets()` ran on every frame of the session, because the only live node
  running it was a `PlacementPreview`. `reach_aliases` fixes it per-pair by hand, but
  that is a config declaration — the tool's own docs say an alias is "the project's
  claim, not this run's observation" — being used to paper over something the tool could
  observe on its own.
  - [G-015] status: open | seen: 1 | harness: 0.19.0
  - Improvement: walk the `extends` chain. For every `script` path in the scene-tree
    snapshot, parse its `extends` (a `class_name` or a `res://` path) and credit the
    whole ancestry as reached, in a distinct `reached_base` bucket so it stays
    distinguishable from a directly-observed hit. That is a static read of files the tool
    is already opening, and it would have credited `selection_marker.gd` with no config
    at all.

## 2026-08-15 — Kanban refill, todo refill, and a new local skill for the HUD gap

- Value: **warranted** — building the checker against the live HUD found two staging
  traps that would have made it silently useless, and one measurement it was getting
  wrong.
  - Expected: the new skill's checker should reproduce the HUD overlap that
    `validate-ui` reported 0 findings over, on the real running game.
  - Got: on a fresh board, `0 finding(s) across 14 visible Control(s) under 'HUD'`.
    With eleven husks on the ground, `Label 'Compost  0 (11 ready)' overlaps Button
    'Grow the next wave' by 1484 px (25% of the smaller)`, exit 1 — the exact pair
    `findings` had passed clean over earlier in the session. Reproduced on a second
    independent staging with identical numbers.
  - Found: (1) `set-state` on the Label's `text` is reverted by the next
    `Hud._refresh()`, which every seed/husk/wave signal fires. The write succeeds, the
    read-back confirms it, and the checker then measures the original string and prints
    a clean `0` — the most plausible way to stage this check is also the way to make it
    lie. Documented; the recipe stages game state instead. (2) The finding is transient:
    husks rot at `HUSK_LIFETIME`, the counter shrinks, and a run made ten seconds late
    reports clean over a still-broken HUD. Caught it live — a `--json` re-run right after
    the passing one returned `"findings": []` with `measured: 18`. (3) Rect-only
    comparison is not sufficient in general: a Label whose text exceeds its box paints
    past it rather than growing, so the checker now takes `get_minimum_size().x` as the
    painted extent and flags such a pair as `via_overflow`, with a different fix
    recommendation. (4) `UpgradeButton` and `UprootButton` report *identical* rects while
    hidden and separate ones once visible — the `visible` filter was load-bearing, not
    incidental.
  - Cheaper: nothing. The checker exists precisely because no static read and no
    existing gate asks this question, and all three defects in it only appear against a
    live HUD.

- Gap: **no gaps this turn beyond the three already filed.** [G-013] (`find-nodes
  --class` and script class names), [G-014] (`validate-ui` and multiline Labels) and
  [G-015] (reach vs. base classes) all stand as written; none was re-hit here. The
  sibling-occlusion blind spot that motivated the new skill is [G-014]'s neighbour but a
  distinct thing, and is worth upstreaming as a `validate-ui` sub-check rather than a
  fourth gap entry: `.claude/skills/godot-hud-occlusion-audit/` is a working
  implementation to lift.

## 2026-08-15 — HUD top bar rebuilt as a container for plant-tower-defense-kcj

- Value: **warranted** — two separate defects, one caught by the new unit test and one
  by `findings`, neither visible on the page.
  - Expected: the skill's own checker should now report clean at the husk count that
    produced the collision — that's the check that failed before and is the only
    end-to-end proof the layout fix holds against the real HUD rather than the test's
    synthetic one.
  - Got: `hud-occlusion: 0 finding(s) across 14 visible Control(s)` at 12 husks, the
    exact state that reported the overlap yesterday. Every top-bar rect disjoint —
    row 1 at `20..136`, `162..299`, `325..461`, `487..717`, `916..1132`, row 2 at
    `y 47..70` — and `findings` back to `0 across 5 of 5`. Screenshot shows the
    readouts evenly spaced by the container instead of by four hand-picked offsets.
  - Found: (1) The spacer-only first version did **not** overlap — it shoved the button
    97px off the right edge (`916 -> 1013`). An `HBoxContainer` will not shrink a child
    below its minimum size and a `Label`'s minimum size is its full text, so an
    unbounded counter pushes rather than compresses. Trading a collision for an
    off-screen button is not a fix; the compost label now has a clipped 230px budget
    with ellipsis. Caught by `test_an_absurdly_long_readout_pushes_rather_than_underlaps`
    on its first run, and the assertion I had written ("the button was pushed left") was
    itself wrong — the failure message is what corrected the design. (2) Fitting two
    rows into `BAR_HEIGHT 72` had me trim the button to 34px high; `findings` raised
    `Interactive control 'NextWaveButton' size 216x34 below minimum 40x40`. Rebalanced
    the rows (stats 4..44, message 47..70) and put the 40px back.
  - Cheaper: nothing. One defect came from the suite and one only from `findings`
    against the live HUD, and the whole item was a layout whose failure modes are
    invisible in a diff.

- Gap: no gaps this turn. The sibling-occlusion blind spot that motivated
  `.claude/skills/godot-hud-occlusion-audit/` is still real and still unfiled as a
  numbered gap on purpose — it is written up in the issue linked from the previous
  entry rather than duplicated here. [G-013] / [G-014] / [G-015] not re-hit.

## 2026-08-15 — A richer husk rots faster, for plant-tower-defense-kh9

- Value: **warranted** — the live run proved the per-husk clock survives the real
  pest-death path, and forced a technique change that the next timing check will reuse.
  - Expected: in a real run, a hungry-beetle husk and an aphid husk dropped moments
    apart should show different `max_life`, and the rich one should disappear from the
    live board while the cheap one is still collectible — the unit test proves the
    arithmetic, not that `_process` on the live meter actually races them.
  - Got: `cmd compost_state` after killing one hungry beetle and one aphid returned
    `value=9 max_life=4.50` beside `value=2 max_life=10.00`. Then, with the tree paused
    and `run-method --node /root/Game/CompostMeter --method _process --args "[5.0]"`,
    the board went from `[(9, 4.0), (5, 6.94), (2, 9.7), ...]` to
    `[(5, 1.44), (2, 4.2), ...]` — the 9-seed husk gone, ten 2-seed husks still
    sweepable. That is the acceptance criterion, live. The stray value-5 husk sitting
    between them at `max_life ~7.6` also shows the curve is continuous rather than
    two-valued.
  - Found: (1) `godot --import` stripped `window/size/viewport_width` and
    `viewport_height` out of `project.godot` **again** — second time in two sessions.
    The Phase 1 guard caught it both times; this is recurring, not a one-off, and the
    guard is the only thing standing between it and a silently committed resolution
    change. (2) A race whose window is shorter than a bus round-trip cannot be observed
    by stepping and polling. Four sequential `step-time --seconds 2` + `compost_state`
    cycles blew clean past the entire 4.5s..10s window and reported `0 husk(s)` four
    times in a row — which reads exactly like "the feature does not work". Real
    wall-clock keeps running between round trips, so `step-time` is additive to it, not
    a substitute for it.
  - Cheaper: the lifetime curve and the two-husk race were already covered headlessly
    by the five new tests. The live run's genuine additions were `drop_husk` storing the
    per-husk clock through the actual death path, and the technique below.

- Gap: **`step-time` cannot isolate a short-lived state, because the wall clock keeps
  running between bus round trips — and nothing says so.** Observing a 4.5s husk expire
  while a 10s one survives means sampling inside a 5.5s window, but each
  `step-time` + read pair costs unbounded real game-time on top of the seconds
  requested. The reply is honest about what *it* advanced
  (`process_seconds: 1.008`) and silent about the ~0.5s of ambient time that elapsed
  around it, so the numbers look exact while the experiment is not.
  The workaround that did work is worth writing down:
  `set-state --node /root --property paused --value true`, then
  `run-method --node <the node> --method _process --args "[5.0]"` — the bridge answers
  while paused, so the system under test can be stepped by hand with zero ambient
  drift.
  - [G-016] status: open | seen: 1 | harness: 0.19.0
  - Improvement: give `step-time` a `--paused` flag that pauses the tree, advances by
    calling the loop by hand, and restores the previous pause state — and have the reply
    include `wall_seconds_elapsed` alongside `process_seconds` either way, so the gap
    between "what I advanced" and "what actually passed" is visible instead of inferred.

## 2026-08-15 — Readable threat level for plant-tower-defense-o1p

- Value: **warranted** — three findings, all about rendered text, none of which a rect
  assertion can see. Two of them changed the design rather than just the code.
  - Expected: the threat text should render on the live bar at a deep endless wave
    without reintroducing the collision I just fixed — the budget sum is asserted
    headlessly, but the rendered wave label at its longest is only measurable live.
  - Got: first pass put the raw multiple on the bar and the live readout came back
    `wave 28 -> x140`, `wave 108 -> x897`, `wave 508 -> x4183`. It renders, it fits, and
    it is useless. After switching to a log-scaled level: `1 / 8 / 14 / 19 / 23 / 25`
    across waves `1 / 8 / 28 / 108 / 508 / 999`, with the WaveLabel rect pinned at
    `168..488` regardless of wave number.
  - Found: (1) The raw multiple is unreadable at scale — wave 1 is five aphids, so
    every later wave is measured against a tiny reference. `threat_level()` is now the
    display form and `threat_for()` stays as the precise number underneath. (2) At wave
    509 `validate-ui` reported `Label 'WaveLabel' text 'Wave 509 — endless   threat 23'
    exceeds width (text: 397px, label: 320px)` — the clipped budget was doing its job and
    silently *ellipsising the readout away*. Clipping converts an overflow bug into a
    hidden-text bug, and none of the three rect-based unit tests I wrote last item
    noticed, because the rects were exactly right. Shortened the marker to `∞`; clean at
    wave 999. (3) `get_minimum_size()` returns ~1px on a `clip_text` Label, so the
    technique I used last item to measure whether text fits stops working the moment the
    budgets exist. `validate-ui`'s own `font.get_string_size` measurement is the
    substitute.
  - Cheaper: nothing. All three are about rendered glyph width, and the first is a
    judgement that only surfaces from reading the actual number.

- Gap: **a clipped Label silently hides its own overflow, and only `validate-ui` can
  tell you — but its finding for that case is indistinguishable from the false positive
  in [G-014].** Both arrive as `ui_text_overflow`. One meant "your readout is being
  ellipsised away, fix it" and the other meant "this Label is multiline, ignore me", and
  they were in the same run's output four lines apart. Triage was by eye.
  - [G-017] status: open | seen: 1 | harness: 0.19.0
  - Improvement: split the rule. When `clip_text` is true or
    `text_overrun_behavior != OVERRUN_NO_TRIMMING`, the text is not overflowing its box,
    it is being *trimmed* — report it as `ui_text_trimmed` with the trimmed rendering
    quoted, since the consequence (the player cannot read it) and the fix (make room or
    shorten the string) are both different from an untrimmed overflow. Combined with the
    multiline fix already proposed in [G-014], `ui_text_overflow` would then mean exactly
    one thing.

## 2026-08-15 — Per-run lane pressure post-mortem for plant-tower-defense-dbg

- Value: **warranted** — four findings, and the worst of them was that I had been
  talking to the wrong game.
  - Expected: losing a real run should repaint the board with the whole run's damage —
    cells the live overlay had faded to nothing coming back. The unit tests drive
    `Board` directly; only a live run proves `_end_run` fires the swap after the final
    commit.
  - Got: three waves against one Corn Cobbler took `lives` 10 -> 5 -> 1 -> 0. The
    painted overlay after the loss read
    `{(13,7): 1.0, (2,1): 0.2, (3,5): 0.1, (4,1): 0.2, (5,7): 0.2}` against
    `run_losses = {(13,7): 10, (2,1): 2, (3,5): 1, (4,1): 2, (5,7): 2}` — exactly
    `count / worst` for every cell, including the `(3,5)` the live map had faded from
    0.25 to 0.1 across two waves. `worst_run_cell` = `(13, 7)`, the exit: this run died
    to pests walking the whole road.
  - Found: (1) **A sibling git worktree of this same project had its own Godot running
    and was answering my bus.** `user://` is keyed on project name, so every worktree
    shares it; `launch --isolated` isolates the bus directory but says plainly that
    `user://` is not isolated. The symptom was `no Game in the tree` and
    `Root node not found: /root/Game/Entities/Board` on paths that plainly existed,
    which reads as your own code being broken. Confirmed by a live node whose script
    was `res://game/title_backdrop.gd` — a file that does not exist in this checkout.
    Every measurement in this item before that point is suspect and was re-taken on an
    isolated bus. (2) `SeedsLabel` rendered as `Seeds  4…` — the width budgets I added
    one item earlier were too narrow for a 3-digit seed total. Invisible to all three
    rect-based tests, because the rect was exactly right; clipping is not overflow.
    Caught by looking at a screenshot. Now pinned by
    `test_no_readout_clips_its_own_worst_case`, which measures each readout's declared
    worst-case string in the real theme font. (3) `%r` is not a GDScript format
    specifier — six assertion messages printed their raw format string, so a failing
    test said `%s needs %.0fpx for %r and has %.0fpx: Expected true but got false`. A
    test that fails uninformatively is barely better than one that does not fail.
    (4) Reading the pressure map cell-by-cell is 126 round trips and times out at two
    minutes; the overlay's own `pressure` Dictionary is a single `get-state`.
  - Cheaper: nothing. The swap needed a real lost run, and three of the four findings
    only exist against a live game.

- Gap: **a second Godot from a sibling git worktree silently answers your bus, and
  nothing in the failure says so.** `launch` refuses a second instance *of the same
  checkout* by pid, but a worktree is a different directory with the same project name,
  so the guard does not fire and both processes poll the same
  `%APPDATA%/Godot/app_userdata/plant-tower-defense`. Errors arrive as
  `no Game in the tree` and `Root node not found`, i.e. as bugs in your own scene.
  `launch --isolated` fixes it but you have to already suspect the problem to reach for
  it, and its own banner says `user:// … (SHARED)` without saying what shares it.
  - [G-018] status: open | seen: 1 | harness: 0.19.0
  - Improvement: have `ping` and `launch` compare the answering game's `res://` project
    path against the client's `--path`, and report a mismatch loudly
    (`the game answering this bus is running from <other path>`). The bridge already
    knows both. Failing that, make `launch`'s owner-file check key on project *path*
    rather than pid, so a worktree instance is detected as a second owner.

- Gap: **[G-012] seen again** — zombie Godot processes surviving `quit`. Two were alive
  and `Responding` with neither matching the owner file's pid; only
  `Get-Process Godot* | Stop-Process -Force`, twice, cleared them.
  - [G-012] status: open | seen: 2 | harness: 0.19.0

## 2026-08-15 — Road-adjacency warning for plant-tower-defense-8bb

- Value: **warranted** — the visual judgement needed pixels, and the run caught two
  staging mistakes that would have made a hand-rolled check pass while proving nothing.
  - Expected: the dashed amber ring should be visibly distinguishable from both the
    solid coverage ring and the red blocked state — a warning that reads as "another
    range ring" would be worse than nothing, and that's a judgement only pixels can
    settle.
  - Got: the four-way table came out clean on the live preview —
    `Sunflower BESIDE road -> at_risk True, placeable True -> DASHED WARNING`,
    `Corn BESIDE road -> at_risk False (reach 176)`,
    `Chomp BESIDE road -> at_risk False (reach 73.6)`,
    `Sunflower AWAY -> at_risk False`. The screenshot shows a tight broken amber ring
    just outside the green brackets, which next to a Corn's large faint solid 176px
    circle is unmistakably a different kind of statement.
  - Found: (1) My first probe used screen `(416, 360)` as the "away from the road" cell
    and it was *on* the road — row 4 runs x=3..9. The check reported `at_risk=True` for
    a cell I had labelled safe, which looks exactly like the feature being broken.
    Staging a placement check by reading coordinates off a screenshot does not work;
    asking the board for a cell matching the predicate does. (2) `set-state` on
    `SeedBank.unlocked` — a typed `Array[StringName]` — silently does not take. The
    write reports success and the read-back still shows the old array, with no error
    anywhere. Unlocking had to go through the game's own `buy_packet` path, which is
    the better test anyway.
  - Cheaper: the truth table was already covered by the five new headless tests. The
    live run bought the visual judgement and the two staging corrections.

- Gap: **`set-state` on a typed Array property silently no-ops.**
  `set-state --node /root/Game/SeedBank --property unlocked --value '["corn_cobbler","sunflower"]'`
  reported success; the immediately following `get-state` returned
  `['corn_cobbler']`. No error, no warning, and the printed read-back in the
  `set-state` reply is the thing that is supposed to catch exactly this. A `Variant`
  Array cannot be assigned to an `Array[StringName]` in GDScript, so the write is
  dropped — but the verb reports as though it landed.
  - [G-019] status: open | seen: 1 | harness: 0.19.0
  - Improvement: `set-state` already reads the property back; compare it against what
    was requested and exit 1 with both values when they differ. That is a general fix,
    not an Array-specific one, and it would also catch setters that clamp or ignore.
    Where the type is known (`Array[StringName]` via `get_property_list()`'s hint
    string), converting the parsed JSON array to the typed array before assigning would
    make the common case work rather than merely fail loudly.

## 2026-08-15 — Title screen and Designer's Notebook UX pass (-dau, -6k0)

- Value: **warranted** — the diff could not have told me the notebook was showing the
  same photograph twice, and neither could any check already in the project.
  - Expected: a screenshot to confirm the paper spread reads as a notebook, and the
    occlusion audit to come back clean on two screens built entirely out of
    hand-positioned sibling Controls.
  - Got: neither. The audit reported `13 finding(s)` on the notebook, then `9` after
    the first checker fix, then exactly one real one — `Panel 'DrawingFrame' is drawn
    over Label 'The drawing', hiding 390 px (22% of the smaller)` — a 5px collision
    between a pane label's box and the top of the photo frame. `findings` reported
    `0 finding(s) across 4 of 4 checks` over that same frame, correctly: each of the
    two Controls fits its own box.
  - Found: three defects caught and fixed mid-run. (1) **`image1.jpg` and `image6.jpg`
    are byte-identical** — same SHA, same 500452 bytes — and the PAGES table listed
    both, so the notebook showed one drawing on two pages under two captions that
    described different things. Spotted only because page 6's screenshot looked like
    page 1's; confirmed by hashing all six files. The notebook is now 5 pages and
    `test_no_two_notebook_pages_show_the_same_drawing` compares bytes, because the
    *paths* differ and every path-level check passed. (2) The 5px pane-label overlap
    above, now pinned headlessly by
    `test_no_two_things_on_the_notebook_spread_sit_on_top_of_each_other`, which was
    confirmed to fail on the old constant before the fix went back in. (3)
    `corn_kernel@2x` is 32x32 where every other sprite is 128x128, so
    `STRETCH_KEEP_ASPECT_CENTERED` into a 190px box rendered the kernel page as a
    yellow smear; sprites are now sized to a whole-number multiple of their texture.
  - Cheaper: nothing for (1) or (3) — both are visual facts about loaded assets that no
    amount of reading the table would surface. (2) would have come out of `node-bounds`
    on two nodes if I had already known which two to ask about, which is the whole
    reason the pairwise audit exists.

- Gap: **`press` bypasses the input path, so hover state never clears** — pressing a
  button over the bus fires `pressed` directly, so a tooltip already open stays open and
  renders over the overlay the press just created. A real click cancels the tooltip as
  part of the mouse event; the bridge's press does not, so a screenshot taken after
  `press` can contain a popup a player would never see. Cost roughly fifteen minutes
  chasing a "tooltip bleeding through the notebook" bug that only exists under the
  harness. Workaround: none needed in the end — those tooltips were the wrong design
  anyway and their text moved into the button labels.
  - [G-020] status: open | seen: 1 | harness: 0.19.0
  - Improvement: have `press` push a synthetic `InputEventMouseButton` through
    `Input.parse_input_event` when the target is under the pointer; failing that,
    document on the verb that hover/tooltip state is not cleared and that a screenshot
    taken straight afterwards may contain a stale popup.

- Gap: **orphaned instances fight over the bus, and the error does not say so plainly** —
  four Godot processes accumulated across a session of launch/quit/capture cycles. The
  symptom was not `game not running` but `Foreign instance on the bus: the reply to
  'scene_tree' came from pid 10584, but devtools_owner.json says pid 704 owns this bus`,
  raised part-way through a checker that had already made twenty successful calls, so
  half its measurements were from one process and half from another. Workaround: kill
  every Godot process from PowerShell and relaunch.
  - [G-021] status: open | seen: 1 | harness: 0.19.0
  - Improvement: `launch` already refuses when a live bus answers; it should also
    recognise a *stale* owner whose pid is dead and reclaim it, and grow a
    `launch --reap` that kills instances pointed at this project's `user://` before
    starting. A mid-run owner change should abort loudly rather than surface as one
    failed call among many.

## 2026-08-15 — Checked whether anything still needed merging into main

- Value: **overkill** — no harness involvement was warranted; this was a pure VCS
  question answered by four read-only git commands.
  - Expected: `feat/playable-tower-defense` would carry unmerged commits needing a merge
    into `main`.
  - Got: `git rev-list --count main..feat/playable-tower-defense` returned `0` in both
    directions, and both refs resolve to `80888dc`.
  - Found: nothing — no code changed, so no runtime claim was available to make.
  - Cheaper: nothing cheaper existed; `git rev-list --count` both ways is the minimum.

- Gap: no gaps this turn — the harness was correctly not used, since no gameplay,
  script, or scene file was touched and `/verify` would have had an empty diff to reach.

## 2026-08-15 — Uproot confirm gate (plant-tower-defense-zr4)

- Value: **overkill** — every live probe confirmed what the headless tests already
  said, and the one question the tests could not answer was settled faster by a
  test I wrote mid-run than by the bridge.
  - Expected: the headless tests prove the arm/commit/timeout/reselect state
    machine, but they never render. Runtime should reveal whether
    "Really uproot? (+60)" actually fits the 232px UprootButton at font 18 rather
    than ellipsising, and whether the red override lands and is genuinely removed
    on disarm.
  - Got: `Rect: 908, 592, 232x40` with `Text: "Really uproot? (+6)"` — identical to
    the resting rect, so the longer label does not grow the VBox or push
    `SelectionBox` (`908, 464, 232x168`, foot at 632) past the panel bottom at 648.
    Live `get_theme_color("font_color")` returned
    `{"r": 0.850, "g": 0.25, "b": 0.220}`, exactly `Hud.UPROOT_ARMED`, and after
    `set-game-speed 1.0` plus 5s it returned to `has_theme_color_override == false`
    with the label back to `Uproot (+6)` and `plants = 1`.
  - Found: nothing. No defect surfaced and nothing was fixed mid-run. Three live
    reads of the armed colour returned the resting grey and all three were my
    staging, not the code — see G-022.
  - Cheaper: `test_an_armed_uproot_button_relabels_and_reddens` in
    `test/unit/test_selftest.gd`, ~58ms, which asserts the relabel, the exact
    colour and the revert. I wrote it as a diagnostic *because* the live probes
    kept disagreeing, and it answered in one run what the bridge took six to say.

- Gap: **a confirm window measured in seconds is shorter than a handful of bus
  round-trips, and nothing in the reply says the state expired** — the window is
  `Game.UPROOT_CONFIRM_SECONDS = 4.0`. Arming it with `press` and then reading the
  button took two calls at ~1s each, so `run-method --method has_theme_color_override`
  returned `Result: false` and `get-state --property text` returned `Uproot (+6)`,
  both well-formed answers describing a state that had already lapsed. A second
  attempt read `_uproot_left: 0.0` *after* a press, which looked like the press had
  failed when in fact it had committed an arming left over from the previous block.
  Workaround that worked: `python tools/devtools.py set-game-speed 0.02` (clamped to
  `Game speed: 1.0 -> 0.0`), which freezes the countdown while the bridge keeps
  answering, then `set-game-speed 1.0` to watch the expiry land.
  - [G-022] status: open | seen: 1 | harness: 0.19.0
  - Improvement: a `with-time-frozen` flag on `press`/`run-method` that pins
    `time_scale` to 0 for the duration of the call, or — cheaper — document
    `set-game-speed 0` as the standard technique for observing any state with a
    lifetime shorter than a few seconds. `step-time` already exists for advancing
    time deterministically; the inverse (hold it still while I look) is the missing
    half, and every short-lived cue — a combo window, a hitstop, an i-frame, this
    confirm — hits it.

- Gap: **the installed harness is two minor versions stale, and the workflow text
  handed to the session describes flags it does not have** — the drift check
  reported all 12 files drifted, and `harness_history.json` gave a clean bearing:
  `addons/godot_selftest/dev_tools.gd: matches 0.19.0, current is 0.21.0 -> STALE
  install`, same for `devtools.py`, `verify_ledger.py`, `coverage_check.py`, with no
  file carrying local edits. The concrete bite: Phase 5 instructed
  `python tools/devtools.py quit --kill` after a survivor warning, and the installed
  client answered `error: unrecognized arguments: --kill`. The orphan scan the
  workflow describes as "runs by default (0.21.0+)" also never appeared in lint output.
  - [G-023] status: fixed | fixed-in: 0.21.0 | seen: 1 | harness: 0.19.0
  - Improvement: have `/verify` Phase 0 fail loudly rather than advisorily when the
    bearing is `STALE`, since every later phase is then reading instructions written
    against a client the project does not have. A one-line
    `installed 0.19.0 < documented 0.21.0 - re-run /scaffold-godot-harness` at the
    top of the run would have cost nothing and pre-empted the `--kill` dead end.

## 2026-08-15 — Refreshed the self-test harness from 0.19.0 to 0.21.0 (/scaffold-godot-harness)

- Value: **warranted** — the smoke check is the only thing that distinguishes "13 files
  overwritten" from "13 files overwritten and the project still parses".
  - Expected: a clean overwrite of every shipped file (nothing local had been edited
    since 0.19.0), config keys the project had customized preserved, and lint green.
  - Got: `Scripts: 37 compiled OK | Shaders: none found | UIDs: OK | res://game/game.tscn:
    OK | res://game/title.tscn: OK | lint: 0 error(s), 0 warning(s) -> exit 0`, and the
    installer printed `= main_scene kept as "res://game/title.tscn" (project-owned)` plus
    the same for `entry_hook`, `entry_points` and `reach_aliases`.
  - Found: nothing broken by the refresh, but the installer's own detection line
    (`[full] detected: main_scene=uid://ce2dtga2f08e`) exposed the gap below.
  - Cheaper: nothing — a 337-line `dev_tools.gd` diff and a 570-line `devtools.py` diff
    landing unreviewed is exactly the case where compiling the project is the check.

- Gap: **`scaffold_install.py detect_main_scene()` does not resolve a `uid://` main scene**
  — `project.godot` here holds `run/main_scene="uid://ce2dtga2f08e"` (what the Godot 4.4+
  editor writes by default). The installer's regex returns that string verbatim, so
  `full` printed `[full] detected: main_scene=uid://ce2dtga2f08e` and would have written a
  `uid://` into `devtools_config.json` on a **fresh** install. This project only escaped it
  because `main_scene` was already project-owned as `res://game/title.tscn`. The scaffold
  doc compounds it: step 7 tells the agent to "open the main scene" to detect
  `hud_layer_name`, which cannot be done from a uid without the same resolution step.
  - [G-024] status: open | seen: 1 | harness: 0.21.0
  - Improvement: in `detect_main_scene()`, when the value starts with `uid://`, grep the
    project's `*.tscn` headers (`uid="uid://…"`) and `*.uid` sidecars for the id and return
    the owning `res://` path; fall back to the raw uid only if nothing matches, and say so.

## 2026-08-15 — Plant health in the selection panel (plant-tower-defense-5zc)

- Value: **warranted** — runtime measured a layout the headless test had already
  approved, and the two disagreed because the assertion was too weak.
  - Expected: headless proves the numbers and the box geometry, but HealthFill is
    a manually-sized ColorRect nested inside a ColorRect that a VBoxContainer
    manages. Runtime should reveal whether the fill actually renders at the width
    the test asserts, or whether the container's layout pass flattens it on screen.
  - Got: the fill rendered `Rect: 908, 542, 116x14` against a 232-wide row — exactly
    half at half health, so the container does not touch a non-container's child.
    The colour ramp read `r 0.515 g 0.525 b 0.331` at 20/40 and `r 0.817 g 0.278
    b 0.231` at 2/40. But `SelectionBox` measured `232x184`, foot at **exactly 648**
    on a panel whose own foot is 648.
  - Found: the `Health n/m` line appended to `SelectionLabel` pushed it to a third
    wrapped text row, growing the box 16px and putting the Uproot button flush with
    the bottom edge of the screen with zero margin. `test_the_selection_box_stays_
    inside_the_side_panel_when_damaged` had passed that exact layout, because a foot
    resting on the boundary satisfies `<=`. Moved the numbers onto the bar itself
    (`HealthText`), which returns the box to `232x168` / foot 632, and rewrote the
    assertion to demand `SELECTION_FOOT_MARGIN = 8.0` of real clearance.
  - Cheaper: nothing. The defect is a wrapped label line changing a container's
    height, which only the real font at the real width produces; the headless test
    had the right shape and the wrong operator, and no amount of re-reading the
    diff would have shown the operator was wrong.

- Gap: **`find-nodes --class` did not resolve a script `class_name`** —
  `python tools/devtools.py find-nodes --class CornCobbler --property health`
  answered `0 node(s) matched:` against a board that provably held one
  (`game_state` reported `plants 1`, and the node was sitting at
  `/root/Game/Entities/@Node2D@129` with `script res://game/corn_cobbler.gd`).
  Same for `--class Plant`. Workaround: dump `scene-tree --root /root/Game/Entities`
  and match on the `script` field by hand, which is what `find-nodes` exists to
  avoid. A silent `0 matched` is the bad shape here — it reads as "no such node"
  rather than "that is not a class I can resolve".
  - [G-024] status: fixed | fixed-in: 0.21.0 | seen: 1 | harness: 0.19.0
  - Improvement: already shipped — 0.21.0's `--class` takes a script `class_name`
    including subclasses, and fails on a name that is neither, which turns this
    exact silent zero into an error.

## 2026-08-15 — Threat tint and the project-identity verb (cuk, gqs)

- Value: **overkill** — everything passed and confirmed what the unit tests had
  already settled. The run's real service was being the first compile and first
  execution of code a subagent could not run at all, which is a risk retired
  rather than a defect found.
  - Expected: the verb's git resolution was validated only by a Python port of the
    logic, never by GDScript against a real bus — runtime should show whether it
    reads the sha the repo actually has and whether `list-commands` discovers the
    literal registration. For the tint, whether the override survives on the live
    INK bar.
  - Got: `cmd project_identity` returned
    `plant-tower-defense at C:/Users/gotmi/Documents/GitHub/plant-tower-defense
    (main @ 43bb8434)` with `git_sha 43bb8434a667f3047888b78e40942ee231d10ca6`,
    identical to `git rev-parse HEAD`, and `list-commands --offline` printed
    `project_identity  (reads no args)`. The wave readout measured exactly
    `PAPER (0.925, 0.863, 0.722)` at wave 1 and exactly
    `THREAT_HOT (0.850, 0.25, 0.220)` at wave 200 endless.
  - Found: nothing. No defect surfaced and nothing was fixed.
  - Cheaper: the headless suite alone, 40s — all six new tests pass there, and the
    live sha check is the only assertion the suite structurally cannot make
    (it cannot know what `git rev-parse` says).

- Gap: **a subagent has no parallel-safe way to compile what it writes** — the one
  gate documented as concurrency-safe is `name_check.py`, and it says of itself
  `NOT COVERED: a clean name_check resolves names, it does not compile the file`.
  So the agent implementing `project_identity` shipped a handler and four test
  methods that had never been parsed by the engine and never executed; it reported
  this honestly and worked around it by porting `_git_identity` line-for-line to
  Python and running that against the repo instead. That workaround happened to be
  sound, and is not one the next agent should have to invent.
  - [G-025] status: open | seen: 1 | harness: 0.21.0
  - Improvement: a `--project-copy` mode on `lint_project.gd` / `run_tests.gd` that
    imports into a private `.godot/` under a temp dir, so N agents can type-check
    and run tests concurrently. Failing that, `name_check --require-compile` that
    shells one `godot --check-only` per changed file — slower than a full lint but
    parallel-safe, and it would turn "names resolve" into "this file builds".

## 2026-08-15 — End-of-run summary panel (plant-tower-defense-cw1)

- Value: **overkill** — the three new headless tests had already pinned the rows,
  the persistence and the idempotency; runtime confirmed the layering and found
  nothing wrong with it.
  - Expected: headless proves the numbers, the node names and idempotency, but it
    renders nothing. Runtime should reveal whether the card actually sits above the
    HUD's layer 10 (or the side panel draws over it), whether the translucent
    backdrop really lets the board's damage map read through, and whether the
    entrance tween leaves everything at its final position.
  - Got: `sample-pixels --rect 900,100,240,200` over the side panel read
    `mean #5e5d4d` against the panel's own `PAPER_DARK #d9c9a8` — dimmed from ~0.85
    to ~0.37, so the CanvasLayer at 20 does draw over the HUD at 10. The board under
    the card-free strip read `mean #267045`, still legibly grass, so the run's damage
    map survives the backdrop. `Back to the gate` landed on `root scene now:
    TitleScreen`; `Plant another garden` came back with `lives = 10 game_over =
    False` and no `SummaryLayer`.
  - Found: nothing. Both button paths and the layering worked first time.
  - Cheaper: the headless suite plus one screenshot. Layering was the only claim
    that needed a live renderer, and `sample-pixels` answered it in one call.

- Gap: **the bus cannot pass `null` to a typed Object parameter, so a losing path a
  unit test drives directly is unreachable from the bridge** —
  `run-method --node /root/Game --method _on_pest_escaped --args "[null]"` answered
  `Failed: Argument 0 of /root/Game._on_pest_escaped(): cannot convert Nil (null) to
  Object`. That signature takes `_pest: Pest` and is deliberately called with null by
  both `test_lane_pressure_is_committed_even_when_the_last_life_is_lost_mid_wave` and
  the game's own losing branch, so GDScript accepts it and only the bus does not.
  Workaround: `set-state game_over true` then `run-method _end_run '["..."]'`, which
  reaches the same UI but skips the life-loss bookkeeping the real path performs —
  i.e. the workaround verifies less than the call it replaces, quietly.
  - [G-026] status: fixed | fixed-in: 0.23.0 | seen: 1 | harness: 0.21.0
  - Improvement: marshal a JSON `null` to the parameter's own nil-able default rather
    than to a bare `Nil` Variant — GDScript permits `null` for any Object-typed
    parameter, so the bridge is stricter than the language it drives. Failing that,
    say so in the error: "the bus cannot type a null Object argument; call a wrapper
    or set the state directly" would have saved the guessing.

## 2026-08-15 — Message priority queue, prep strip, packet tier fix (9q8, uk6, ha6)

- Value: **warranted** as run, recorded as **insufficient** — and the ledger is
  right to say so; see the gap below.
  - Expected: the strip is 4px at the very foot of a dark bar — runtime should
    reveal whether it actually renders there or is clipped/invisible against INK,
    and whether the queued-message handoff looks right in a real frame.
  - Got: `Rect: 0, 68, 1152x4  Visible: True  In viewport: True`, draining to
    exactly `288x4` at 4.5 of 18 seconds (1152 x 0.25 = 288), and reading
    `r 0.850 g 0.25 b 0.220` — THREAT_HOT — once the director was pushed to wave
    200 endless. The status row held `IMPORTANT INSTRUCTION` with an ambient line
    posted straight on top of it and `pending_messages` returning 2.
  - Found: two defects, both caught by tests rather than by the live run. (1) The
    message queue drained strictly FIFO, so an important line queued behind
    ambient chatter waited its turn rather than jumping it — the same failure as
    stomping it, only slower; `_advance_message_queue` now selects
    highest-priority-first. (2) `test_a_packet_never_hands_back_something_you_
    already_own` was green *only because of* the ha6 bug: it drains the catalogue
    on the common tier, which terminated solely because common could illegally
    reach the tier-2 Sunflower. With the fallback removed it would spin on a
    refusal forever.
  - Cheaper: nothing for the FIFO defect — it needed a test that queued two
    priorities and pumped. The strip's geometry could have been computed from the
    constants; its visibility against INK could not.

- Gap: **in a fan-out, `reach` grades a run against the whole repo's dirty set, so
  a run that fully verified its own slice is downgraded for someone else's** —
  `verify_ledger record` answered
  `downgraded warranted -> insufficient: no changed file was loaded at runtime
  (game/corn_cobbler.gd, game/pest.gd)`. Both of those belong to two subagents
  still mid-task; my own three items were committed moments earlier, so by record
  time the working tree's changed set was entirely other people's work. The run
  did load and exercise `game/hud.gd` and `game/game.gd` — it simply got no credit,
  because reach is computed from `git status` rather than from what the run
  claimed to be about. The inverse error is the dangerous one and it is equally
  available: had I committed nothing, an agent's untouched files would have been
  silently counted as *my* denominator.
  - [G-027] status: open | seen: 1 | harness: 0.21.0
  - Improvement: let `record` take `--about PATH...` (or read it from the run.json)
    naming the files this run set out to verify, and compute reach against that
    intersected with the changed set. Absent that, `reach` should at least report
    the two numbers separately — "reached 2/2 of the files this run named, 0/2 of
    the rest of the dirty tree" — instead of collapsing them into one verdict that
    is wrong in both directions depending on commit timing.

## 2026-08-15 — Mutation cues, muzzle fan, and the 0.23.0 refresh (5tu, nll)

- Value: **warranted** — both features are drawn *behind* their own sprite, and
  whether that leaves them visible is a question no headless assertion can reach.
  - Expected: Node2D paints its own canvas item before its children, so both the
    mutation markers and the muzzle fan land behind the sprite. Runtime should
    reveal whether they actually protrude past the silhouette or are simply hidden
    under it — a fan or a wing drawn entirely under a 64px sprite is invisible and
    the tests would still pass.
  - Got: the corn cell's grass dominance fell from `#31c56b (64%)` to
    `(60%)` across the two upgrades — about 164 more non-grass pixels, matching
    four extra pips at ~40px² each — while `muzzle_pip_positions()` went from
    `[(20.0, 0.0)]` to five points spanning ±14.9px. Two aphids in identical 64x64
    cells read `(87%)` grass plain against `(76%)` winged: the wings occupy ~450
    more pixels, so they genuinely clear the silhouette.
  - Found: nothing in these two. The defects this iteration surfaced were caught
    by tests earlier — see the previous entry.
  - Cheaper: nothing. The pixel share of a cell is the only measurement that
    answers "is the thing behind the sprite actually visible", and both features
    are drawn rather than positioned, so node-bounds says nothing about them.

- Gap: **no gaps this turn.** 0.23.0 landed clean — every installed file was
  pristine so nothing was backed up, all four project-owned config keys were kept
  and named rather than re-detected, and `find-nodes --class CornCobbler` now
  resolves the script class_name that returned `0 node(s) matched` two iterations
  ago (G-024, confirmed fixed). `list-commands` printing arg keys
  (`spawn_pest  args: species, mutation, count`) removed the guesswork that
  previously cost a round trip per verb.

## 2026-08-15 — Packet button state and HUD motion (vo9, 9xm)

- Value: **warranted** — every new test asserts the headless branch, so the tweens
  in this change had never executed once before the live run.
  - Expected: every new test asserts the headless branch, where
    animations_enabled() is false — so no tween in this change has ever run.
    Runtime should reveal whether the threat tween actually eases (and whether
    reapplying the tint many times a second stacks tweens or thrashes), and
    whether the panel entrance lands back at its resting position rather than
    drifting.
  - Got: the wave readout was caught mid-transition at
    `r 0.872 g 0.432 b 0.369` — genuinely between PAPER and THREAT_HOT, which is
    the one reading that proves a tween ran rather than a value being assigned.
    A second later it read exactly `r 0.850 g 0.25 b 0.220`, and five consecutive
    `_refresh()` calls left it there rather than restarting the fade. The selection
    box settled back on `Rect: 908, 464, 232x152` with `modulate.a = 1.0`. Live
    packet drain: one `buy_packet` returned `packet held chomp_flower`, the next
    three were refused, and the button then read `disabled: true` with
    `Nothing left in a Common Packet` while the rare button stayed lit.
  - Found: two, neither in the feature itself. (1) A doc-comment defect I
    introduced two iterations earlier — inserting the THREAT_* block directly
    above `const HEALTH_ROW_HEIGHT` orphaned the health block's `##` comment 45
    lines from the constants it describes, leaving the threat constants wearing
    the health comment. Repaired. (2) `--filter "packet_button|hud_motion|threat_tint_still"`
    selected `0 of 192` and exited 2 — regex alternation is not supported. The
    harness refusing to call that a pass is the SELECTED NOTHING guard working;
    before it existed this printed `Total: 0 | ALL TESTS PASSED` at exit 0.
  - Cheaper: nothing. The tweens are off headless by construction, so no headless
    gate could have executed them, and a stacking tween looks correct in every
    still frame.

- Gap: **no gaps this turn.** 0.23.0's `--filter` refusal and the orphan scan both
  did exactly what they claim. Recording the ledger *before* committing — the fix
  for G-027's attribution problem — produced `reached 1/1 changed file(s)` and a
  `warranted` that stuck, versus the `insufficient` the same shape of run earned
  two iterations ago.

## 2026-08-15 — The game learns to make a noise (plant-tower-defense-988)

- Value: **warranted** — every headless test in this change asserts `should_play`,
  a pure decision function, so not one voice had ever been created before the run.
  - Expected: every headless test asserts should_play, a pure decision function —
    no voice has ever actually been created. Runtime should reveal whether the
    lazy 8-voice pool really builds under the tree root, whether voices survive
    the pest that triggered them being freed, and whether the repeat gate stops
    five simultaneous deaths stacking into one loud sound.
  - Got: `/root` grew an `SfxPool` holding 8 `AudioStreamPlayer` children on the
    first `play()`, and `find-nodes --class AudioStreamPlayer --where playing=true`
    caught `Voice0` mid-playback with
    `stream=(res://assets/audio/jingles-pizzicato_00.ogg):<AudioStreamOggVorbis#…>`
    — a real decoded stream, not a null that would have degraded to silence and
    passed every test. After pressing the post-mortem's replay button, `/root`
    read `['DevTools', 'RunConfig', 'SfxPool', 'Game']` with all 8 voices intact
    while `Game` had been rebuilt, which is the whole reason the pool is parented
    to root rather than to the node that triggers it.
  - Found: the first `godot --headless --import` after adding 11 `.ogg` files and
    a new `class_name` **crashed** — exit `3221225477`, i.e. `0xC0000005`, an
    access violation — having written only part of its output. `import_check.py`
    refused to read that as success: `no parse/load errors in the output, but
    Godot exited 3221225477 - treat this as an import that did not complete`. A
    bare `--import` judged on exit code alone would have moved straight to lint,
    which would then have failed on a half-built class cache and sent me reading
    GDScript instead of re-running the import. A second run completed and wrote
    all 11 `.import` files.
  - Cheaper: nothing. The headless tests deliberately assert `should_play` rather
    than audibility, so no gate short of a live session could show that a voice
    node is ever created — let alone that it survives the scene reload it exists
    to survive.

- Gap: **a static-only class that demonstrably ran is invisible to `reach`** —
  `record` reported `reached 2/4 changed file(s) … NOT reached: game/sfx.gd`.
  `Sfx` is `class_name Sfx extends RefCounted` with static entry points, so it
  owns no node and can never appear in a `scene-tree` snapshot — even though this
  run *observed the `SfxPool` node that only `sfx.gd` creates*, which is stronger
  evidence than reach normally has for anything. Worked around with a
  `reach_aliases` entry (`game/sfx.gd` vouched for by `game/game.gd` and
  `game/plant.gd`), which the harness correctly buckets as a declaration rather
  than an observation. This is the same shape as G-015 (a base class invisible
  because only a subclass owned the live node).
  - [G-028] status: open | seen: 2 | harness: 0.23.0
  - Second sighting, with a number this time. After a full session — launch, entry
    hook, an endless wave 100 driven to completion with pests spawning and dying —
    `scripts-seen` reported **15 scripts** and `game/` holds 27. Thirteen were
    absent, and three of them provably ran: `sfx.gd` played the sounds,
    `plant_catalog.gd` served every placement, `garden_theme.gd` styled the pause
    card that was open. All three are static-only classes that own no node. The
    other ten are node-owning scripts whose instances simply did not exist in that
    session, which is a fair miss — but it means a project cannot tell the two
    apart from the output, and "13 of 27 unreached" reads as a coverage problem
    when a fifth of it is a measurement problem.
  - Improvement: `scripts-seen` already records every script the engine *loaded*,
    which for a static-only class is exactly the right signal and is an
    observation rather than a declaration. Reach consults it today only as a
    fallback for scripts absent from the tree; crediting a `scripts-seen` hit as
    `reached_loaded` — a third bucket beside `reached` and `reached_alias` —
    would retire the whole class of alias entries projects are currently writing
    for RefCounted helpers.

## 2026-08-15 — Cycle 6: five features, three defects the gates caught (hmy, dlw, 1ci, 6m2, 61k)

- Value: **warranted** — three separate defects surfaced, none of which any static
  read would have shown, and one of which was actively disguised as a pass.
  - Expected: the post-mortem grew from 5 rows to 7, and by my arithmetic the last
    row now ends at y=472 against buttons at 476 — the same flush-boundary shape
    that bit me two cycles ago. Runtime should also show whether the Sunflower
    gauge and the dead-zone bar, both drawn behind their sprites, actually clear
    the silhouette, and whether the two banner labels stay separated on screen.
  - Got: the prediction was right — `Value_Weakestground` measured
    `Rect: 397, 438, 335x34` (foot 472) against `ReplayButton` at
    `Rect: 164, 476, 232x44`. The banner rendered `0, 236, 896x72` and
    `0, 308, 896x28`, abutting exactly. The Sunflower's gauge strip read a dark
    trough `#213129` with a cap at `(0.996, 0.973, 0.792)` where bare grass is
    `#29c56b` at 100%. A dead preview cell rendered 24% non-grass against a live
    cell's 20%.
  - Found: three.
    1. **Two existing tests were silently converted into passes by my own change.**
       Removing `RunConfig.high_score` made
       `test_run_config_high_score_only_ever_goes_up` and
       `test_title_high_score_line_never_reads_as_a_zero_record` raise at runtime —
       and in GDScript that aborts only the method and returns `""`, which for a
       `-> String` test is byte-identical to a pass. The runner caught both as
       `[VACU]`, by noticing they returned pass having executed **zero** of their
       own `_T.assert_*` calls. This is the harness's stated worst failure mode
       being detected instead of shipped, and nothing else in the run would have
       seen it: lint was clean, the suite said 200 passed.
    2. **The wave banner's two labels overlapped by 5px on screen.** The headline
       was declared 62px tall, but a 48px font renders a 67px line box, so it ran
       to y=303 while the note — positioned at `BANNER_Y + BANNER_HEIGHT` —
       started at 298. A Label does not render at its declared size, and only a
       pairwise sibling comparison can see it: every per-Control check passes,
       because each fits its own box.
    3. **The post-mortem's last row cleared its buttons by four pixels.** Nothing
       failed, which is the point. Tightened the row gap and added
       `BUTTON_CLEARANCE = 16` with a test, so the next row added to that card is a
       build failure rather than a rendering accident.
  - Cheaper: nothing. The VACUOUS catch needed the runner's own assertion
    accounting, the overlap needed a pairwise comparison no per-Control check
    makes, and four pixels of clearance is invisible to every gate that passed.

- Gap: **no gaps this turn** — and worth recording *why*, because all three
  findings came from harness features rather than from reading code: the vacuous
  detector, a sibling-occlusion test written in `test_dir`, and `node-bounds`
  against a live CanvasLayer. The one avoidable cost was mine: `place_plant` takes
  `plant`, and I sent `kind`, which is silently ignored — 0.23.0's
  `list-commands` prints `place_plant  args: plant, x, y` precisely so that cannot
  happen, and I had already seen that line two iterations earlier.

## 2026-08-16 — Closing a coverage class while three agents worked elsewhere

- Value: **warranted** — `coverage_check.py` named a defect class this project had
  never asked about, and closing it took one test.
  - Expected: nothing runtime; this was a deliberate gap-filling pass while the
    cycle-7 agents held the game files. The claim to check was
    `coverage_check.py`'s, not the game's.
  - Got: `UNCHECKED scene_validation — nothing loads a res:// scene, so a broken
    .tscn is only found by running the game`, and after the new test,
    `COVERED scene_validation  test/unit/test_selftest.gd:2976
    load("res://game/game.tscn")`, moving the tally from
    `2 covered … 3 UNCHECKED` to `3 covered … 2 UNCHECKED`.
  - Found: the tool would not credit a *stronger* check than the one it asks for.
    See the gap below.
  - Cheaper: nothing — this was already the cheapest form. No engine launch, one
    headless test, and `coverage_check.py` is parallel-safe so it ran while three
    agents held every game file.

- Gap: **`coverage_check.py` credits `scene_validation` only for a `res://….tscn`
  literal inside `load`/`preload`, so a discovery-based scene walk — which is
  strictly stronger — scores as no coverage at all.** The first version of
  `test_every_scene_in_the_project_actually_instantiates` walked `res://` with
  `DirAccess` and instantiated every `.tscn` it found, including any added later
  by anyone. The tool still printed `UNCHECKED scene_validation`, because
  `_scan_scene_loads` requires the path to be a literal (`coverage_check.py:530`:
  "the only strong scene_validation token"). The check that covers *more* scenes
  and cannot rot is the one that scores zero, and the fix is to add a hard-coded
  list beside it — i.e. the tool rewards the weaker pattern. I did add the two
  literals, and they are defensible on their own as "these two scenes must exist",
  but they were written to satisfy the scanner rather than because the walk needed
  them.
  - [G-029] status: open | seen: 1 | harness: 0.23.0
  - Improvement: also credit an instantiation of a path that is not a literal when
    the same file contains a directory walk reaching `.tscn` — or, more simply,
    treat `PackedScene.instantiate()` / `can_instantiate()` in a `test_dir` file as
    a strong token in its own right, since nothing else in a test suite calls it.
    The current rule tests for a spelling, not for the behaviour it stands for.

## 2026-08-16 — A fourth plant (plant-tower-defense-fdm)

- Value: **overkill** — the headless suite had already driven the mechanic and
  asserted the same ratios; the live run's only unique claim was that the physics
  path reaches it at all.
  - Expected: the slow is applied through pest metadata with refcounting, and the
    tests drive `apply_patch` by hand rather than through physics. Runtime should
    reveal whether a pest walking into a real patch actually slows and — the case
    a refcount bug hides — whether it gets its ORIGINAL speed back after crossing,
    rather than being stranded at 55% forever.
  - Got: an aphid read `speed: 78.0` outside the patch and `42.9` inside it
    (78 x 0.55 exactly); a beetle went `38.0 -> 20.9 -> 38.0` across an entry and
    an exit, so the release hands back the recorded original rather than a value
    re-derived from the slowed one. `stuck_count()` read 3 with the wave in the
    patch and fell to 0 when a held pest was freed. Three rare packets returned
    `sunflower`, `chomp_flower`, `sticky_sundew` — the tier now rolls rather than
    dispensing.
  - Found: nothing. Every claim held first time, including the hand-authored SVG
    passing the sprite-style palette and geometry contract on its first render —
    which is the outcome worth noting, since that gate fails the build on a wrong
    size, an off-centre axis, a clipped edge or a colour outside the kit.
  - Cheaper: the headless suite alone. It already exercises `apply_patch`,
    `slowed_speed` and the refcount release; only "the physics path actually calls
    it" needed a live step, and one `step-time --seconds 0.2` settled that.

- Gap: **no gaps this turn.** Worth recording instead that the toolchain caught the
  ordering it is supposed to: rendering the new SVG printed
  `Failed to load script "res://devtools_ext/commands.gd" with error "Compilation
  failed"` because `StickySundew` was not yet in the class cache, and
  `import_check.py` then reported a clean import that fixed it — the documented
  "run --import after adding a class_name" sequence, working as written.

## 2026-08-16 — Plant bar headroom and pause (zij, lzu)

- Value: **warranted** — runtime caught a regression that every one of the three
  new layout tests passed over.
  - Expected: the pause card's whole risk is `PROCESS_MODE_ALWAYS` — get it wrong
    and the card is frozen by the pause it owns and no button works, which
    headless can assert as a property but not as a *press*. Runtime should confirm
    the bridge reports `tree is PAUSED`, that a real press on the card still
    lands, and that the plant bar's new grid puts real buttons where the
    arithmetic says.
  - Got: `ping` answered `tree is PAUSED (bridge still polling:
    PROCESS_MODE_ALWAYS)`, and `_prep_left` read `5.38266633333376` twice across a
    two-second real-time gap — the countdown genuinely stopped rather than being
    hidden. A `press` on `ResumeButton` landed on the frozen tree, the layer was
    freed, and the countdown resumed `3.659 -> 2.351` over one second. Leaving via
    `GateButton` reached `TitleScreen` unfrozen.
  - Found: two.
    1. **Swapping the plant bar's `VBoxContainer` for a `GridContainer` silently
       halved the buttons.** A VBox stretches its children horizontally for free;
       a Grid does not, so they rendered at their icon's natural 128px instead of
       the panel's 232px. All three new layout tests passed over it, because they
       assert heights, rows and positions — and a half-width button is correct on
       every one of those. `node-bounds` reported `232x248` for the bar and
       `128x56` for each button in it, which is the pair that gives it away.
    2. Two tests were caught as `[VACU]` rather than passing, for the third time
       this session. The root cause was a real parse error — assigning a
       `GridContainer` to a var declared `VBoxContainer` — which `name_check`
       passed clean and only the import gate reported, quoting the line and the
       type.
  - Cheaper: nothing. A half-width button satisfies every assertion about height
    and position, and "a press lands on a frozen tree" is not a property a
    headless test can exercise.

- Gap: **no gaps this turn** — the harness caught both defects itself. Worth
  recording that `ping`'s pause line is doing real work: it names
  `PROCESS_MODE_ALWAYS` as the reason the bridge still answers, which is the
  single fact that makes a pause menu verifiable at all, and it is the same
  property the menu itself has to get right.

  A recurring **self**-error, not a harness one: for the second time I inserted a
  block of constants directly above a `const` that already had a `##` doc comment,
  orphaning that comment from its declaration. The fix both times was to insert
  after the complete declaration instead. Worth remembering as a rule rather than
  re-noticing: in a file where every constant carries provenance, "insert before
  the const" is almost always wrong.

## 2026-08-16 — Regrowth in the real physics loop (plant-tower-defense-aoq)

- Value: **warranted**, recorded as **partial** — one check could not be made to
  run, and the ledger is right that a blocked check is not a passed one.
  - Expected: the tests drive `_physics_process` by hand. Runtime should show
    whether the real physics loop actually reaches regrowth on a planted bed, and
    whether the health bar turns green while healing and then hides itself once
    whole — the cue is the mechanic's only visible signal.
  - Got: `seconds_until_regrowth` read `5.1` immediately after a bite with
    `is_regrowing` false, so the delay gate holds. Health then climbed `15.0 ->
    30.475 -> 35.45` under nothing but the real loop, about 1.5 hp/s as specified.
    All three bar states confirmed: `r 0.850 g 0.25 b 0.220` visible when bitten,
    `r 0.360 g 0.700 b 0.340` visible while regrowing, and `visible: false` once
    whole.
  - Found: a **NEW `ui_layout` finding fired once** at the end of a long probing
    session and then could not be reproduced across five targeted attempts — fresh
    scene, damaged plant, mid-regrowth, wave banner up, plant selected. Leading
    hypothesis is a Control sampled mid-entrance-tween: the selection panel starts
    at `modulate.a = 0` and tweens over 0.16s, and `validate-ui` has a
    `ui_transparent` rule. That window is shorter than one bus round-trip, so it
    cannot be caught deliberately. Recorded as `blocked`, not as passed and not as
    fixed.
  - Cheaper: nothing for the regrowth checks. A mechanic that ticks in
    `_physics_process` and whose only cue is a bar colour is exactly what a live
    session is for.

- Gap: **a finding that fires once cannot be re-asked without re-creating the
  frame that produced it.** `validate-ui` reports what is true at the instant it
  samples, which is correct, but leaves nothing to investigate with: there is no
  record of *which* node and rule fired, only a count in a consolidated line I had
  already truncated. The verb re-run seconds later is a different frame and says
  `[OK]`. Everything else in this harness is reproducible by construction — a
  scene, a diff, a seed — and this is the one signal that is not.
  - [G-030] status: open | seen: 1 | harness: 0.23.0
  - Improvement: have `findings` and `validate-ui` write the full finding records
    of the most recent non-clean run to `user://ui_findings_last.json` (node path,
    rule, measured rect, timestamp), and print that path whenever the count is
    non-zero. A transient would then be diagnosable after the fact instead of
    being a number that has already gone. Cheap: the records exist in memory at
    the moment they are counted.

## 2026-08-16 — A source-asset gate the engine is not needed for (plant-tower-defense-9wu)

- Value: **warranted** — a new gate that catches a defect class no existing check
  asks about, verified by injection rather than by assertion.
  - Expected: nothing runtime. This was a tooling pass; the claim to test was the
    checker's own, and the only honest way to test a checker is to break something
    on purpose.
  - Got: clean over all 12 sprites, agreeing with `test_sprite_style.gd` (which is
    also green), and on an injected `#FF00FF` fill it reported
    `ERROR palette sunflower: #FF00FF is off the kit palette by 188.50` **and**
    `ERROR outline sunflower: outline #1F8A4C is not darker than its fill
    #FF00FF` — the second being a consequence the injection was not aiming at,
    which is what a real check looks like. Exit codes verified: `0` clean, `2` on
    a selector matching nothing.
  - Found: the checker's first run reported **10 errors and 5 warnings over a
    corpus known to be clean**, and every one was a bug in the checker. Open
    stroked paths (legs, antennae, X-eyes — half the corpus) enclose no area, so
    their unset fill paints nothing and is not the forbidden black. The two
    foliage palette rows are 0.01 degrees of hue apart and deliberately mixed, so
    the outline rule had to gate on hue distance rather than table membership.
    And stroke-expanded geometric bounds run wider than the opaque-pixel bounds
    the raster gate measures. Separately, the finished tool found a **real drift**:
    the gate's `PALETTE` carries `#5E5E5E` and `#D7C9A8` that `STYLE.md` documents
    nowhere, so an author reading the contract sees 30 colours while the build
    enforces 32.
  - Cheaper: nothing. A checker that has never been run against a known-good
    corpus has not been tested, and that run is what produced every real finding
    here.

- Gap: **the harness has no defect class for source-asset conformance at all.**
  `coverage_check.py` enumerates eight classes — UI layout, UI reachability,
  unconnected signals, orphan growth, input path, scene validation, shader
  compile, name resolution — and every one is about code or a live tree. A project
  whose art is authored to a written contract has no way to ask "does the source
  conform" without rendering, which needs the engine, which is not parallel-safe.
  This whole issue existed because of that hole.
  - [G-031] status: open | seen: 1 | harness: 0.23.0
  - Improvement: an `asset_contract` class in `coverage_check.py`, covered by any
    project-local checker that reads asset sources and is credited the way
    `name_resolution` credits `name_check.py`. The harness need not ship the
    checker — sprite contracts are project-specific — but naming the class is what
    makes its absence visible, which is the tool's whole job.

## 2026-08-16 — Cycle 9: five defects, none of them found by playing

- Value: **warranted** — the decisive check was a pixel comparison no polygon
  assertion could make.
  - Expected: the tests assert polygon vertices and areas. Runtime should reveal
    whether the union actually renders as one even wash — a Geometry2D winding or
    hole bug would produce correct-looking polygon data and a visibly wrong
    picture, and the whole point of the change is what the overlap LOOKS like.
  - Got: the same 16x16 region read `dominant #b57b4a (100%)` with one patch and
    `#b57b4a (100%)` with two — pixel-identical — against bare ground at
    `#b57b42`. The wash is applied exactly once; before the change two discs at
    alpha 0.10 composited to an effective 0.19.
  - Found: nothing in the feature, but two measurement traps of my own worth
    recording. The first before/after comparison was contaminated by a pest
    sitting in the sampled rect — `dominant #e64a3a` is pest red, not ground — and
    then `clear-nodes --group pests` triggered `_check_wave_cleared`, which
    spawned a fresh wave into the same rect. **Clearing a group can advance the
    game's own state machine**; the second reading disagreed with the first for
    that reason and neither was wrong about pixels.
  - Cheaper: nothing. A winding or hole bug yields correct polygon data and a
    wrong picture, so vertex assertions cannot see it.

- Gap: **no gaps this turn.** Worth recording what did the finding instead, since
  none of this cycle's five defects came from playing the game: the scoring
  exploit and both pause regressions came from an idea pass reading code written
  hours earlier, and the palette drift came from a linter built the cycle before.
  The two pause bugs were mine, shipped one iteration earlier, and one of them —
  quitting an endless run filing no score — was a data-loss bug in the feature
  whose whole purpose was to let a player leave.

  The pause-note overlap is the sharpest argument yet for the pairwise check:
  `FIRST_BUTTON_Y` was an absolute `232.0` in a file where every other offset was
  `CARD.position.y + N`, so twenty of the note's twenty-four pixels sat under an
  opaque stylebox. `validate-ui` and `findings` both reported clean over it, and
  correctly — each Control fits its own box, and per-Control measurement is all
  they do.

## 2026-08-16 — The transient that was a real bug all along (cycle 10)

- Value: **warranted** — it found a clipped HUD readout that had been shipping
  since husks were added, and explained two earlier findings I had written off.
  - Expected: the balance change is arithmetic the tests already sweep at 177
    ranges, and the card height is arithmetic too. Runtime should confirm the
    panel's new line renders on two lines rather than three, that the pause card
    actually grew, and that a real volley lands what the dps table promises.
  - Got: the card measured `320x394`, derived, against the hardcoded 380 it
    replaced. The corn panel read `Corn Cobbler — bunch` / `7.0 dmg / 0.62s,
    5 kernel(s)` in a box still `232x152`. And `findings` reported
    `ui_text_trimmed: Label 'CompostLabel' text 'Compost  0 (1 ready)' is trimmed
    by its box (text: 198px, label: 170px; clip_text) - the player sees a cut
    string`.
  - Found: three, the first of which retires **G-030**.
    1. **The "transient" was real.** Twice this session a NEW `ui_layout` finding
       fired and would not reproduce across targeted attempts, and I logged it as
       an unreproducible gap. It reproduces exactly when husks are on the ground:
       `CompostLabel` appends `" (N ready)"`, but `WORST_CASE_TEXT` declared only
       `"Compost  9999"` — so the width test has only ever measured the string
       someone wrote down, never the string the formatter can build. The file's
       own comment cites `"Compost 0 (11 ready)"` as the cause of an *earlier*
       overlap bug, so the suffix was known about and the worst case was never
       updated. My hypothesis in G-030 (a Control caught mid-tween) was wrong.
    2. Measuring all four stats-row budgets showed they were wrong in **both
       directions at once**: Lives had 14px spare while Compost was 18px short.
       They had been picked by eye. All four are now requirement-plus-7px,
       measured in the real theme font — 161 / 302 / 136 / 188.
    3. My own first draft of the corn panel line wrapped to a third row and pushed
       `SelectionBox`'s foot to exactly the panel's 648, caught by the 8px
       clearance test written three cycles ago for that same overflow.
  - Cheaper: nothing. The readout only clips while husks are on the ground, which
    is precisely why two earlier runs saw it and could not reproduce it.

- Gap: **[G-030] status: fixed** — not by the harness, but by finding the cause.
  The improvement I proposed there (write the last non-clean finding records to
  `user://ui_findings_last.json`) is still worth having and stays filed upstream,
  because the reason I chased the wrong hypothesis twice is that the count was all
  I had: `1 NEW` with no node, no rule and no measurement. The third sighting only
  became diagnosable because I happened to run `validate-ui` rather than `findings`
  and it printed the full record. **A consolidated count is a worse signal than a
  named finding, and `findings` gives the count.**
  - [G-030] status: fixed | fixed-in: n/a (root cause was a project bug, not a
    harness one) | seen: 3 | harness: 0.23.0
  - Improvement: unchanged and still wanted — `findings` should print the same
    per-finding detail `validate-ui` does, or name the file it wrote them to.

## 2026-08-16 — Cycle 11: three fixes, and a bug in the harness's own blanker

- Value: **overkill** for both runtime passes — each confirmed a claim the headless
  tests had already made, which is the honest reading and is what the ledger now
  records.
  - Expected: the save logic runs at startup in an autoload before any game
    exists, and the tests drive it with a redirected path. Runtime should confirm
    the real boot path still loads the developer's actual save, and that
    `load_status` reports honestly rather than silently starting at zero.
  - Got: the real `user://highscore.save` (`v2\n140\n0`) read back as
    `load_status: loaded, campaign_high_score: 140`. Truncated mid-number to
    `v2\n14`, it read `load_status: refused` with `0/0` — and **the corrupt bytes
    were still on disk afterwards**, which is the half that matters: the number is
    recoverable rather than destroyed. Restoring returned both. Separately, the
    Sundew patch list held exactly 2 entries while `Entities` held 24 children,
    and held exactly 1 after `reload_current_scene` — the failure a `static var`
    invites and the only one a per-test instantiation cannot produce.
  - Found: nothing in either runtime pass. The three real findings this cycle all
    came from reading: `FileAccess.open(WRITE)` truncating before writing (the
    *producer* of the corrupt saves, so a read-side fix alone would not have been
    one), and the metadata checker correcting its own issue's premise — all five
    keys in this tree are single-file, not cross-script.
  - Cheaper: the headless suites, in both cases. Only "the real `user://` boot
    path behaves like the redirected one" and "a static list survives a scene
    reload empty" needed a live session, and one launch each settled them.

- Gap: **`name_check.py`'s string blanker drops a newline on a backslash
  continuation, so every later finding in that file is reported one line early.**
  At `tools/name_check.py:232-237`, a `\` + newline inside a string literal appends
  `"  "` (two spaces) and increments the tracked `line`, but the blanked text it
  builds `_line_starts` from is now one newline short. `coverage_check.py:213` has
  the same shape. Latent in this project — no `.gd` here uses a continued string
  literal, verified — so it costs nothing today and will silently mis-point
  findings the moment one appears. Found by a checker I had written against this
  blanker as a reference, which is the only reason it surfaced at all.
  - [G-032] status: open | seen: 1 | harness: 0.23.0
  - Improvement: one line —
    `out.append(" \n" if text[i + 1] == "\n" else "  ")` — keeping the blank
    length-preserving while restoring the newline the line index depends on.

## 2026-08-16 — A width assertion that passes unconditionally (cycle 13)

- Value: **inconclusive** so far — this entry records a gap found while reviewing
  an agent's work rather than a run of my own; the cycle's runtime pass is still
  pending on two agents.

- Gap: **`Control.get_minimum_size()` returns ~1px on any Label with
  `clip_text`, so the natural way to ask "does this text fit its column" passes
  unconditionally.** It is the obvious call to reach for — it is what a Container
  uses to size a child — and on a clipping Label it reports the clip stub rather
  than the text. Every value label on the post-mortem card sets `clip_text`, and
  so do three of the four HUD stats readouts, so a width check written the obvious
  way over either of those surfaces is decoration. The project's own
  `test_no_readout_clips_its_own_worst_case` gets this right by measuring through
  `Font.get_string_size` with the label's real theme font — but that is a thing
  someone had to already know, and it is nowhere in the harness docs. This is the
  same family as the vacuous-pass problem the runner already detects: an assertion
  that cannot fail.
  - [G-033] status: open | seen: 1 | harness: 0.23.0
  - Improvement: a `_T.text_width(label) -> float` helper that resolves the
    label's own theme font and measures the string, plus one line in the harness
    CLAUDE.md's gotchas naming `get_minimum_size()` on a clipping Label as a
    false-pass. The helper is four lines and removes the need to know the trap.
    `findings`' `ui_text_trimmed` check already does this measurement internally,
    so the code exists — it is just not reachable from a test.

## 2026-08-16 — Open the Designer's Notebook from a paused run (899)

- Value: **warranted** — the headless suite caught a live 60px overlap regression in a
  file this item never touched, which is the only reason it isn't already committed.
  - Expected: the pause card growing from 390 to 450 tall would push its key rows into
    something, and the notebook would either freeze under the pause or eat Escape wrong.
  - Got: the card geometry was fine — `test_the_pause_card_is_tall_enough_for_whatever_it_holds`
    and both overlap tests passed for free, because height, key-list offset and button
    block are all derived from `BUTTONS.size()`. What failed was elsewhere:
    `Subheading [P: (385.0, 94.0), S: (382.0, 23.0)] and DrawingPaneLabel
    [P: (319.0, 112.0), S: (78.0, 23.0)] do not share pixels (60 overlapping)`.
  - Found: that overlap, in `notebook_screen.gd`, from a *concurrent* agent's in-flight
    edit. Neither agent would have seen it — one was restricted to `name_check`, the
    other never opened the file. Only integrating and gating serially surfaced it.
  - Cheaper: nothing. Both halves of this needed the suite: the pause geometry is
    derived arithmetic that a human would re-derive wrong, and the cross-file regression
    is invisible to any per-agent gate by construction.

- Gap: **no gaps this turn** — the pairwise-overlap test did exactly the job it exists
  for, across a file boundary, during a fan-out. Worth recording as the case *for* the
  sibling-overlap check that G-018 asked the harness to generalize: a per-Control
  measurement (`validate-ui`, `findings`) cannot see this class at all, and this is the
  second time the project's hand-written pairwise version has caught something real.
  - Improvement: none needed here; G-018 already carries the ask.

- Note (not a harness gap): a subagent hit `Viewport.is_input_handled()` being **sticky
  outside `push_input`** — once set by a direct `_input` call in a headless test it
  never resets, silently disabling the guard under it. It redesigned around this. That
  is Godot semantics, not harness behaviour, but it is exactly the kind of thing a
  `godot-input-and-pause-semantics` skill should carry.

## 2026-08-16 — Lawn and notebook from the catalogue (6mv), and the overlap it caused

- Value: **warranted** — the suite caught a regression the authoring agent could not
  have seen, and then caught my own fix being vacuous.
  - Expected: the catalogue rewrite was mostly data plumbing; I predicted the risk was
    a page-count assumption in the pager, not layout.
  - Got: the pager held (all three `% PAGES.size()` assertions passed untouched). What
    broke was the *subheading*: it counts itself from `PAGES`, so two new pages grew
    the sentence from ~336px to the full 382px panel width, reaching 12px into
    `DrawingPaneLabel` against a 5px vertical overlap that was always there.
    `12 x 5 = 60`, exactly the reported intersection.
  - Found: that overlap; and a **vacuous test of my own** — my first fix assumed a
    `res://game/notebook_screen.tscn` that does not exist (the screen is built in code),
    so `instantiate_ui` aborted the method and it returned `""`. `[VACU]` flagged it at
    62ms with zero assertions executed. Without that detector it would have read as a
    pass and I would have committed an assertion that could never fire.
  - Cheaper: nothing. The subheading width is emergent from a runtime string format
    over a table that changed size; no diff shows it.

- Note on the fix: the pairwise-overlap test *caught* this but *described* it badly —
  a 60px intersection between two Controls that each fit their own box reads like a
  positioning bug in the labels, not a sentence that got too long. Added
  `SUBHEAD_MAX_WIDTH` and a test measuring the actual invariant, then mutation-checked
  it (budget 100 -> `the subheading text draws 268px`, naming the sentence). A test I
  did not watch fail is a test I have not written.

- Gap: **[G-033] seen: 2** — `Control.get_minimum_size()` returning ~1px under
  `clip_text` bit again, one item later, in a different file and a different surface.
  First time it was the post-mortem card's value labels; here it was the notebook
  subheading. Both times the obvious assertion would have passed unconditionally, and
  both times it took prior knowledge to avoid.
  - [G-033] status: open | seen: 2 | harness: 0.23.0
  - Improvement: `_T.text_width(label)` measuring through `Font.get_string_size` with
    the label's resolved theme font and size. Two sessions have now independently
    written that same six-line preamble by hand.

- Harness: checked `godot-selftest-harness` for a release — still **0.23.0** (`65103b7`),
  matching the installed version. No refresh.

## 2026-08-16 — Road classification (ch3) and the husk budget (a1k)

- Value: **warranted** — a test I wrote to check my own reasoning refuted it, twice,
  and the second refutation came from a subagent reading the source I had summarised.
  - Expected: ch3 was bookkeeping. I thought I already knew which four numbers were
    road-dependent and only needed to write the classification down.
  - Got: `husk_click_margin() does not mention route( — if it now does, it has become
    road-dependent and the classification block above is wrong: Expected true but got
    false`. My own assertion, failing on my own claim, 2ms in. Then the a1k agent
    corrected the arithmetic underneath it: `COLLECT_RADIUS` is 28 and is the husk
    sweep; the 32 is `Board.CELL / 2`, not a radius. Which flipped the answer BACK,
    for a different reason — the route walk yields CELL/2 for any road.
  - Found: two wrong classifications, in opposite directions, in one cycle. The
    measurement test (32 cells / 2112 px, computed from `route()` at runtime) matched
    the prose in `wave_director.gd` exactly, which is the one thing I guessed right.
  - Cheaper: reading `placement_preview.gd:388-410` properly the first time. I had it
    open and summarised it from its doc comment instead of its body. That is the whole
    lesson of this entry.

- Note: mutation-checked both tests before committing (`cells, 32` -> `33` printed the
  full re-derivation list with the real measured numbers; the earlier subheading test
  at budget 100 printed `draws 268px`). A test I have not watched fail is a test I have
  not written — this is now three cycles running where the mutation check either caught
  a dead assertion or confirmed a live one, and it costs ~30s.

- Gap: **no gaps this turn.** The harness did what it should: `[VACU]` caught a test of
  mine that assumed a `.tscn` which does not exist, and the source-reading test caught a
  claim of mine that the code contradicted. Neither needed a feature the harness lacks.

- Harness: still **0.23.0** upstream (`65103b7`) and installed. No refresh.

## 2026-08-16 — Prep depth readout (842), and the first live pass in several cycles

- Value: **warranted** — the live sweep confirmed a change that had shipped headless-only,
  and the run's real yield was a P1 bug found by reading rather than by any gate.
  - Expected: the prep line was a HUD text change; I expected the risk to be width
    overflow on `MessageLabel`, the failure mode that has bitten three times.
  - Got: width was fine (measured through the resolved theme font against the real
    `size.x`, with an `assert_gt(drawn, 1.0)` guard so the `clip_text` 1px stub cannot
    make it pass unconditionally). `findings` returned **0 across 5 of 5 checks** — all
    five ran, none skipped. Then two live reads confirmed `Plant_0` is
    `corn_cobbler.png` and `Plant_3` is `sticky_sundew.png`, i.e. the duplicate cob is
    really gone from the title lawn.
  - Found: a P1 defect no gate could see — `_note_lane_loss` fires from `_on_pest_died`
    as well as `_on_pest_escaped`, so `_run_losses` counts kills; `run_summary.gd:201`
    then labels the highest-count cell "Weakest ground", reporting the player's best
    chokepoint as their weakest ground every run. Inverted advice, filed as `dwv`.
  - Cheaper: the headless gates alone would have committed this item just as safely.
    The live pass earned its keep on the OTHER items — three cycles of commits had
    landed without one, and `8f4256b` in particular was a visual change verified only
    by measurement until now.

- Note: this is the argument for a live sweep on a CADENCE rather than per-item. Per
  item it is overkill nearly every time; across ten commits it is the only thing that
  looks at the accumulated result. `findings` is one command and ~90s.

- Gap: **no gaps this turn.** `findings` named its denominator without being asked,
  which is exactly what makes a clean result readable.
  - One usability note, not a gap: `find-nodes --class Hud` returned `no node in the
    tree matched class Hud` while sitting on the title screen, which is correct and
    still read as a failure for a moment. `scene-tree --depth 2` disambiguated it in
    one call.

- Harness: still **0.23.0**. No refresh.

## 2026-08-16 — Second warning channel (e0m), closing cycle 14

- Value: **warranted** — two test failures were the vacuity guard firing on a real
  engine trap, not on the feature under test.
  - Expected: a legibility change; I expected to need a screenshot to judge it, and to
    have to argue about whether the hatch "reads".
  - Got: `cell (4, 1) is road, so it can carry pressure: Expected true but got false`
    — twice, on two different tests, 0ms in. (4,1) IS road: it sits on the first
    segment of PATH_CORNERS. The board just had not built its path. `path_cell_count()`
    calls `_build_path()`; `is_path()` did not, so it answered "there is no road
    anywhere" on a Board outside the tree — a confident no, not an error — and
    `is_buildable`, `is_road_adjacent` and `path_index` all inherited it.
  - Found: that trap, fixed at the source rather than in the tests. Any past test that
    built a bare `Board.new()` and asked `is_path` measured an empty board and passed.
  - Cheaper: nothing. No screenshot shows this, and the geometry assertions (441 sample
    points, 57% inked / 43% bare, lattice continuity across neighbouring cells) are
    more precise than my eye would have been anyway — which is the answer to the
    "surely this needs a visual check" instinct I started with.

- Note: the vacuity guard earned its keep twice this cycle in different ways — it
  caught a test of mine that assumed a non-existent `.tscn`, and here it caught a
  production defect while guarding a feature test. Both times the failure was at 0-62ms
  with zero assertions executed, which is a recognisable signature worth knowing:
  **a test that fails instantly on its own precondition is usually telling you about
  the world, not about the test.**

- Gap: **no gaps this turn.**

- Harness: still **0.23.0**. No refresh.

## 2026-08-16 — Placement brackets (dhs), and a false clean from the import gate

- Value: **warranted** — but the run's real product was a harness finding, not the feature.
  - Expected: a two-line colour change. I expected the gates to be a formality.
  - Got: `Assigned value for constant "OK_COLOR" isn't a constant expression` — my own
    edit. `Color.lightened()` is a method call and a GDScript `const` initialiser must
    be constant. It cascaded: `Failed to load script "res://devtools_ext/commands.gd"`,
    and discovery fell from **331 to 164 tests**.
  - Found: my own parse error, and then a gate that hides it (below). Also confirmed by
    mutation that the replacement test has teeth — moving `DANGER` to (0.70, 0.15, 0.30)
    fails with `BLOCKED_COLOR is 0.175 away from DANGER lightened`.
  - Cheaper: nothing cheaper would have caught the const rule. But I had the right
    diagnosis in the first thirty seconds and abandoned it because `import_check` said
    OK — so the cost here was trusting a gate over a symptom.

- Gap: **[G-034] `import_check.py` reports "Import OK" on a hard parse error.** New.
  Reproduced deliberately, all four gates on the identical tree:
  ```
  name_check.py      -> exit 0   (correct; it does not compile)
  import_check.py    -> exit 0   "Import OK: godot --import ran (exit 0) and its 28
                                  line(s) of output contain no SCRIPT ERROR, Parse
                                  Error, Failed to load script or Compilation failed."
  lint_project.gd    -> exit 1   "lint: 2 error(s), 0 warning(s)"
  run_tests.gd       -> exit 2   "Total: 164 | Passed: 149 | Failed: 15"
  ```
  The error text `SCRIPT ERROR: Parse Error: Assigned value for constant "OK_COLOR"
  isn't a constant expression.` appears in `run_tests` output and in lint's findings,
  but never in the import log import_check scans. Severity is bounded: lint catches it,
  and lint runs alongside import in every `/verify` tier that reaches Phase 1, so
  nothing ships broken. But import_check is documented as the gate that catches what
  name_check cannot, and is positioned FIRST specifically so you fix the cause instead
  of reading a cascade — and it was the one gate that missed. It also cost me the
  detour above, because I had the diagnosis and dropped it when the gate disagreed.
  - [G-034] status: open | seen: 1 | harness: 0.23.0
  - Improvement: either `godot --import` does not surface errors for scripts it does
    not re-import (in which case import_check cannot claim "the project parses" and its
    success message should say what it actually verified), or the scan needs to catch
    this error class. The success string is the specific thing to change — it currently
    asserts the absence of four phrases and reads as a compile verdict.

- Harness: checked upstream — still **0.23.0** (`65103b7`). No refresh.

## 2026-08-16 — Closing cycle 15: two P1 bugs, and behaviour tests that drive real input

- Value: **warranted** — one agent's test caught its own bad setup, and the other's
  tests assert what the board DID rather than what a field says.
  - Expected: `ygh` looked like a one-line `MOUSE_FILTER_IGNORE` fix; `dwv` looked like
    a choice between two options I had already framed.
  - Got: `and it is where the escapes are reported, once: Expected 6 of 10 beds but got
    10 of 10 beds` — the dwv agent's own new test, failing because its setup forced
    `game.lives = 6` to end the run early while the beds row computes `LIVES - lives`.
    Driving all ten escapes makes the numbers agree with no forcing.
  - Found: that setup bug; plus the ygh agent proving the input mechanism rather than
    assuming it (a Control under a Node2D is a GUI root, picked in world space, and the
    GUI pass precedes `_unhandled_input` — so the click is deleted, not misrouted), and
    finding the defect was already *documented* in last cycle's notch comment ("the two
    bars beside them predate it and are left as they are") without being fixed.
  - Cheaper: nothing. Both P1s were invisible to every static gate — one is a sentence
    that is false only in certain run shapes, the other is an input path that no test
    exercised until these three did.

- Note: the two behaviour tests drive a real `InputEventMouseButton` through the hosted
  viewport via `_T.dispatch_events` and each opens with a CONTROL click that must
  succeed first, so a dead event pipeline fails loudly instead of passing. That pattern
  is worth copying — it is the difference between asserting a property and asserting the
  behaviour the property is supposed to cause.

- Note on a near-miss of my own: the full suite read `Total: 339 | Assertions: 8211`
  both before and after the ygh work landed, and I briefly took that as "its tests are
  not running". They were — my earlier run had already picked up the agent's file
  mid-flight, and 331 + 5 + 3 = 339 reconciles exactly. **The denominator is only
  evidence if you know when it was taken.**

- Gap: **no gaps this turn.** G-034 was filed upstream earlier in this cycle as
  godot-selftest-harness#23.

- Harness: still **0.23.0**. No refresh.

## 2026-08-16 — Closing cycle 16: a budgets verb, and a test that passed for the wrong reason

- Value: **warranted** — the live run of the new verb surfaced three unknowns, and a
  bisect proved a "regression" was a pre-existing flake.
  - Expected: `cmd budgets` would restate four numbers I already knew, and `2z8` would
    be a small recording change.
  - Got: `6 budget(s): 5 computed, 1 without a number -- 1 spent, 3 tight; tightest
    pest_road_ceiling: peak pests on the road 40 of 40 pests max -- 0 pests left`.
    Three budgets tight and one fully spent, none of which anything had said before.
    The `SubViewport` path measures the notebook subheading at **268 of 358 px** —
    independently reproducing, by a different route, the 268 px my own
    `SUBHEAD_MAX_WIDTH` test arrived at two cycles ago. That cross-check is the reason
    to believe the verb measures rather than transcribes.
  - Found: `test_kernels_launch_from_the_cob_on_an_offset_layer` failing — and it is
    NOT a regression. Reverting each of the three changed game files individually left
    it failing, which ruled out the change; the control I had skipped showed it fails
    **at HEAD when run alone** and passes at HEAD only in a full suite. It read
    `kernels[0]` from a tree-global group that can hold kernels another test fired and
    never freed. It had been passing for its own reasons, not the code's, and only four
    unrelated new tests shifted the order enough to expose it.
  - Cheaper: for `2z8`, the headless suite alone. For `cl6`, nothing — a verb that
    builds a `SubViewport` and loads assets on the frame the bus answers from can only
    be trusted after it has answered the bus once.

- Note, and the lesson I want to keep: **"reverting the change did not fix it" is the
  cheapest possible test for "this is not my change"**, and I ran three file-level
  reverts before running the one control that settled it — the old code, alone, under
  the new conditions. Establish the control before bisecting, not after.

- Note: a test that only passes in company is worse than no test, because it reports
  green from the wrong cause. This one measured a leaked object every time it ran.

- Gap: **no gaps this turn.** The four parallel-safe checkers all ran clean;
  `world_control_check.py` (added this cycle) was exercised by the agent, which reported
  `exit 0, 0 findings` alongside `name_check` — its first use by someone other than me.

- Harness: still **0.23.0**. No refresh.

## 2026-08-16 — Correction: nothing leaks between tests, and I said it did

- Value: **warranted** — a subagent measured the thing I had asserted, and I was wrong.
  - Expected: I briefed the agent that `_T.free_ui` defers through `queue_free`, so tests
    leak nodes into tree-global groups, and asked it to detect that.
  - Got: `_T.free_ui` calls `target.free()` — immediate, synchronous, `run_tests.gd:901`,
    and its own docstring says so ("frees it immediately (not queue_free), so the nodes
    never show up in the orphan count"). A census after **every one of 358 tests**,
    walking `tree.root` and tallying `node.get_groups()` with no frame pumped:
    `tests that grew a group: 0`. Nothing leaks across any boundary.
  - Found: the real mechanism, which is narrower and lives inside a single test.
    `instantiate_scene` pumps settle frames, and a `CornCobbler` enters the tree already
    loaded — so hosting one beside a pest fires a volley before the test body runs, and
    `kernels[0]` was that setup kernel. The agent measured it directly:
    `after instantiate_scene(host): kernels in group = 1`, already at (181, 232) rather
    than the launch point.
  - Cheaper: reading `run_tests.gd:884-901` — nine lines, and its docstring states the
    answer outright. I asserted the opposite from memory and propagated it into a doc
    comment, a skill, two commit messages and two logs before anyone counted.

- **The correction that matters more than the fact.** The fixes I shipped (diff the group
  around the action) are correct and were correct under both stories — which is exactly
  why the wrong reasoning survived. A fix that works does not validate the model behind
  it, and the model is what gets reused on the next bug. I have corrected the doc comment,
  the skill (mechanism, description and intro), and both logs; the two commit messages are
  history and are corrected by the follow-up commit rather than rewritten.

- Also corrected in the skill: "check which your harness uses before theorising — do not
  assume, and do not trust a comment saying which, including one you wrote." That last
  clause is not rhetorical. The comment at `test_selftest.gd:80` asserting `queue_free`
  was mine, written this cycle, and it is precisely what a future session would have
  believed.

- Gap: **no gaps this turn.** `group_leak_check.py` (new, parallel-safe, house style)
  reports `7 test script(s), 13 function(s) read a tree-global group, 4 of those select a
  single node, 0 waived, 2 finding(s)` — a real denominator and a 2-of-4 hit rate rather
  than firing on everything. Its two findings are latent, not currently wrong.

- Harness: still **0.23.0**. No refresh.

## 2026-08-16 — Closing cycle 17: a premise refuted by test, and a warning that arrives

- Value: **warranted** — two of four items ended by disproving the issue that requested
  them, both with runtime evidence rather than argument.
  - Expected: `jrj` would sample `was_engaged()` per road cell and paint a coverage map.
  - Got: `the flag claims the garden reached every one of the 32 road cells` while
    `covered_road_cell_list` says a cob beside the entry touches **4**. `_ever_engaged`
    is monotone, so a per-cell sample is a prefix mask — blind to precisely the two hole
    shapes that cost beds, since both lie after first contact. The test walks distinct
    cells and asserts `visited.size() == road.size()`, so it cannot be N samples of one.
  - Found: two silent bugs avoided in the brief I wrote — `PlantCatalog.reach()` returns
    `SAP_RADIUS` for a Sundew, which engages nothing, so a map built on it would call a
    lane walled in dew defended; and `reach_at_offset` is about which of a volley's
    kernels connect at distance, not coverage, with the on-axis kernel at `INF`.
  - Cheaper: nothing. Both refutations needed the real board and the real catalogue.

- Live check that mattered: `cmd board_info` carries
  `"budgets": "4 of 4 declared budget(s) measured, 0 under floor"` in its `status` block —
  confirming the status provider rides on **every** bus reply, not just the budgets verb.
  That was the load-bearing claim of `8fg`'s design (that `push_warning` reaches nobody,
  because `launch` redirects stderr into `.devtools/`), and it is the half that could
  only be checked against a running game.

- Note: three agents this cycle mutation-checked their own work unprompted — SUNDEW into
  `ENGAGING_PLANTS` (red), forcing the coverage branch to always win (red), a fixture of
  four bad and four good patterns for `group_leak_check` (which caught two bugs in the
  checker itself). The habit has propagated from the briefs into the work.

- Gap: **no gaps this turn.**

- Harness: still **0.23.0**. No refresh.

## 2026-08-16 — Closing cycle 18: three refutations and a test that was wrong about itself

- Value: **warranted** — the cycle's best output was a measurement that stopped a feature.
  - Expected: `4no` would build a per-cell "in reach and did not act" map, since the
    predicate is non-monotone and therefore not blocked the way `_ever_engaged` was.
  - Got: the predicate works and the answer says don't. **0 of 116** pests that spent
    their whole walk on covered ground went untouched, across 439 pests and 14 driven
    waves, including runs losing 34 of 40 beds. At the cell it is 84% and useless — 66%
    in a wave that killed 14 of 14 and lost nothing. 82% of it is a cob firing at a
    different pest; only **3 of 3,909** were the map's geometry.
  - Found: two of my own errors. I broke `suite_reach_baseline.json` with my signal tests
    and did not regenerate — the agent reproduced it with its entire diff stashed to
    prove whose it was. And `test_hosting_a_loaded_cob`, which I accepted two cycles ago,
    asserted a volley had fired by the time `instantiate_scene` returned. That frame
    count is unspecified, so the test was order-dependent: green for two cycles, red the
    moment unrelated tests shifted timing — **the exact accident it was written to
    document**.
  - Cheaper: nothing. Every number here needed the real board, the real schedule and
    frame-by-frame sampling.

- Note: the signature was the inverse of the usual one — passes ALONE, fails in company.
  I have been treating "fails alone, passes in suite" as the tell; both directions mean
  the same thing, that the test depends on state it did not establish.

- Note: `suite_reach_check` caught its own author twice in one cycle — my
  `PlantCatalog.engaging_ids()` wrapper ten minutes after committing it, then my stale
  baseline. A checker that fires on the person who just installed it is measuring
  something real. Its own `NOT COVERED:` line concedes the weakness that matters:
  *"naming is a floor, not exercise"* — a test that writes `WaveDirector.reset()` and
  asserts nothing counts as reach, so the gate can be satisfied without being served.

- Gap: **no gaps this turn.**

- Harness: still **0.23.0**. No refresh.
