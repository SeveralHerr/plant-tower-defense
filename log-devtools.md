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
