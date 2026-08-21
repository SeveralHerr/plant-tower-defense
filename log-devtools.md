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
| `harness:` | `X.Y.Z` | The installed harness version it was observed against, from `python tools/devtools.py harness-version --client` (`python3` outside Windows — probe by executing, the Store alias lies). Without it, a gap logged before an upgrade can't be told from a regression after one. |

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
  - [G-028] status: open | seen: 3 | harness: 0.23.0
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

## 2026-08-16 — Cycle 19, and the loop paused here

- Value: **warranted** — two of three items corrected a claim, and one of the claims was
  an agent's rather than mine.
  - Expected: `zsb` would find a handful of tests reading state straight after
    `instantiate_scene`; `1av` would close a wiring hole.
  - Got: **22 candidates, all 22 hand-checked, zero real exposures.** The first cut
    flagged 106 functions, nearly all Control size reads after `instantiate_ui` — which
    is exactly what `UI_SETTLE_FRAMES` exists to converge, i.e. the harness's contract
    rather than a defect. The distinction is not "physics-dependent" but CONVERGENCE.
  - Found: `--import` had stripped `window/size/viewport_width|height` from
    `project.godot` — the documented hazard, caught only because I diffed the file
    before committing. The HUD's width budgets measure against `ProjectSettings`, so the
    layout would have ridden on an engine default with nothing saying so.
  - Cheaper: for `1av`, nothing. For `zsb`, the count could have come before the tool —
    and to the agent's credit it reported the count first, as asked, and still argued
    the tool earns its place as a regression gate rather than a discovery one.

- **Corrected an agent's headline, which is new this session.** `1av` reported that
  cutting `pest.escaped.connect` would leave the whole suite green and the game
  unlosable. I cut the line: three tests fail, one of them
  `test_every_signal_a_game_script_declares_has_a_listener`, pre-existing, in a file the
  agent never opened. The agent had grepped for `.escaped` and found nothing — but that
  test works by **enumerating declared signals at runtime**, so no grep for a symbol can
  see it. Same blind spot the reach checker has, in the same direction: it credits reach
  by name, so a test that enumerates and asserts over everything credits nothing.

- Gap: **no gaps this turn.** Seven parallel-safe checkers now, all clean:
  `name_check`, `world_control_check`, `meta_key_check`, `group_leak_check`,
  `suite_reach_check`, `svg_style_check`, `settle_read_check`.

- Harness: still **0.23.0**. Checked upstream this cycle; no release since `65103b7`.

## 2026-08-16 — Assert-argument co-occurrence signal for suite_reach_check.py (plant-tower-defense-4p1)

- Value: **overkill** — a stdlib-only static checker change with no engine surface;
  running it against the repo's own tree was the whole verification, and lint/tests
  were run only because the task's own workflow asked for them regardless.
  - Expected: the new NOTE line would print a plausible reached/asserted split (283
    reached gating symbols, some fraction never inside a `_T.assert_*` argument)
    without moving the exit code or the existing findings/baseline counts.
  - Got: exactly that — output grew from 12 to 13 printed lines, one new line:
    `NOTE: of 283 reached gating symbol(s) ... 85 are named only in plain
    statements -- the token never once sits inside a \`_T.assert_*(...)\` call's
    arguments anywhere in the test tree (add_seeds, announce_wave, ...)`. Exit
    code, baseline (`53 pre-existing, 0 NEW, 0 since fixed`), and every existing
    finding were unchanged before/after (diffed the two full runs).
  - Found: nothing. lint (`0 error(s), 0 warning(s) -> exit 0`), tests
    (`Total: 396 | Passed: 396`, `Assertions: 9129 executed`), name_check and
    import_check were all clean and stayed clean — none of them touch a `.py`
    tool under `tools/`, so none of them could plausibly have reacted to this
    change.
  - Cheaper: reading the diff plus one manual run of the checker, which is
    exactly what was done. No running game was needed or used — `suite_reach_check.py`
    opens no project, and nothing under `game/` or `test/*.gd` changed.

- Gap: no gaps this turn. Confirmed by grep that no sibling stdlib checker
  (`world_control_check.py`, `meta_key_check.py`, `svg_style_check.py`,
  `group_leak_check.py`, `settle_read_check.py`) has unit coverage in
  `test/unit/`, so no new test pattern was invented here either — this project's
  standing convention for these tools is dogfooding against its own tree, which
  is what step 8 of the issue asked for and what was done.

- Harness: still **0.24.0** at this run's `harness-version` read (installed
  0.24.0, client 0.24.0; game not launched this run so its side is unknown).

## 2026-08-16 — Corn Cobbler readiness readout (plant-tower-defense-88o)

- Value: **warranted** — the live game was the only way to confirm the fade
  actually paints under real firing traffic with no runtime error, which the
  unit tests (correctly) cannot see.
  - Expected: `readiness()` would drop right after a shot and climb back to 1.0
    over the reload, matching `elapsed/interval`, and `_draw_muzzle_fan`'s new
    per-pip `Color(PIP_COLOR, PIP_COLOR.a * fade)` calls would not throw under
    real placement/upgrade/firing traffic across several plants at once.
  - Got: launched the game, placed 7 CornCobblers, forced fires with `cmd
    spawn_pest`, and polled `run-method ... readiness` — read 0.104, 0.083,
    0.021 immediately after firing (matches the unit test's exact 0.0 at
    `_cooldown == interval`, allowing for the poll round-trip eating into the
    0.8s window before the value could be read) and 1.0 once recovered.
    `.devtools/launch_stderr.log` stayed at 0 lines through the whole session —
    no `SCRIPT ERROR` from any of the ~7 cobblers drawing every frame.
  - Found: the live run didn't surface a code defect, but writing the *test*
    did — `fire_interval()` was sitting in `tools/suite_reach_baseline.json` as
    a pre-existing "no test names this" finding, and the new test now names it.
    `test_the_suite_reach_baseline_lists_only_symbols_no_test_names` caught the
    drift correctly; regenerated the baseline with `--baseline-write` per its
    own error message.
  - Cheaper: the pure-math + real-`_act()`-driven unit test (already written)
    proves the numbers exactly; the live pass only added "and it doesn't throw
    when actually drawn under a real target." Could have skipped it and still
    shipped correctly, but would not have known that for certain.

- Gap: **could not pixel-sample the low-alpha instant** — tried `sample-pixels`
  on the pip's computed screen position immediately after a forced fire, but
  every attempt raced the bus round-trip against the 0.8s reload interval and
  landed after most of the recovery had already happened (readiness read back
  at 0.95-1.0 by the time the sample command reached the game), even after
  slowing `set-game-speed` — because `Engine.time_scale` scales tick *rate*,
  not per-tick delta, so a slow scale does not lengthen the real-time window a
  low value is held at any better than 1.0x does once a command is already
  in flight. `set-game-speed 0` is refused ("use the tree's pause for that");
  there is no bus verb for a real `SceneTree.paused = true` freeze.
  - [G-036] status: open | seen: 1 | harness: 0.24.0
  - Improvement: a `pause`/`unpause` verb (or a `--freeze-on` flag on
    `set-game-speed`) that flips the actual tree pause rather than time_scale,
    so a caller can catch a fast, sub-second state transition and hold it
    indefinitely for a leisurely `sample-pixels`/`screenshot`, independent of
    bus latency.

- Also filed/commented upstream this session: issue #25 (scaffold refresh can
  silently downgrade + branch safety net never fires in a fan-out session) and
  a comment on the open #24 (pid-reuse reproduction: a dead pid was reported
  "STILL ALIVE" because Windows had already reassigned it to an unrelated
  `WmiPrvSE` process).

- Harness: **0.24.0**.

## 2026-08-16 — Three HUD/results-screen feature beads: 9ti (win/loss entrance), d2a (wave-cleared cue), 7mi (prep bar pulse)

- Value: **warranted** — the live game was the only way to see the two new
  Tweens (RunSummary's TRANS_BACK win rise, the prep bar's looping pulse)
  actually settle to the right resting state and actually oscillate, which
  headless (no frames pumped, `animations_enabled() == false`) structurally
  cannot show.
  - Expected: the win/loss RunSummary entrance would land both branches back
    at the same rest position (y=124) despite different offsets/durations;
    the wave-cleared banner would show "Wave N cleared" / "N pests turned
    back." at the same weight as the wave-started banner; the prep bar's
    modulate.a would oscillate once `_prep_left` crossed 2.0s.
  - Got: `node-bounds` on Heading read `128, 124, 640x47` after both the loss
    run (game_over via a bled-out defense) and a forced win
    (`set-state victory true` + `run-method _end_run`) -- same rest position,
    confirmed by screenshot for both. The wave-cleared banner read
    `text: "Wave 1 cleared"` / `"5 pests turned back."`, `visible: true`,
    alongside the still-live status-row sentence, via screenshot. The prep
    bar's modulate.a sampled at 0.998, 0.839, 0.457, 0.514, 0.713, 0.989,
    0.964, 0.831 across 8 polls -- genuinely oscillating, not stuck.
  - Found: nothing broken, but the exercise located a real gap in the OWN
    reasoning process, not the game -- see the two Gaps below.
  - Cheaper: nothing; this is exactly the class of check (Tween lands where
    the code says, over enough real frames) headless cannot answer and the
    unit tests (correctly) do not try to.

- Gap: **the orchestrator-suggested `launch -- --devtools-session X` form
  silently does not wire the session to the game.** Ran exactly
  `python tools/devtools.py launch -- --devtools-session hudwork`; the
  process launched, `ping --session hudwork` never got picked up (`game not
  running` after the 2s grace). Root cause, read from `cmd_launch` in
  `tools/devtools.py`: passthrough args after a bare `--` are appended
  directly to the engine command line (`cmd += passthrough`) with **no**
  Godot-side `--` inserted first, so `--devtools-session hudwork` never
  reaches `OS.get_cmdline_user_args()` (which the addon reads at
  `dev_tools.gd:405`) -- only `--isolated` or the top-level `--session`
  flag correctly append `["--"] + user_args`. This project's own
  AGENTS.md/CLAUDE.md never actually recommends the broken form (it only
  shows `launch` and `launch --isolated`), so the instruction came from
  outside this repo -- but the failure mode (a launch that "succeeds" and a
  ping that then reads as a dead game, indistinguishable from a crash) is
  exactly the kind of silent-wrong-mode this project's other G-entries keep
  naming. Recovered by using `launch --isolated`, which the tool already
  builds correctly.
  - [G-042] status: open | seen: 1 | harness: 0.25.0
  - Improvement: either have `cmd_launch` insert Godot's own `--` before ANY
    passthrough token that starts with `--devtools-` (so the natural-looking
    form works), or have `launch` print a one-line warning when passthrough
    args contain `--devtools-session`/`--devtools-busdir` without a
    preceding bare `--` reaching the engine, naming `--isolated`/`--session`
    as the forms that actually wire it.

- Gap: **CLAUDE.md/AGENTS.md's own words for `--isolated` promise something
  `GODOT_USERDATA` cannot deliver.** The line read this session: "`user://`
  ... stays shared unless you also set `GODOT_USERDATA`" -- phrased as if
  setting it isolates `user://`. `addons/godot_selftest/dev_tools.gd:41`
  says the opposite in its own comment: "Godot has no command line switch
  for `user://` and honours no `GODOT_USERDATA`". Checked directly this
  session: `godot --help` on this project's 4.7.1 build has no
  `--user-data-dir`/`--userdata` engine flag at all, so there is no
  mechanism by which setting the env var could change where the actual
  Godot process's `user://` resolves -- confirmed by the sequence in this
  session (`GODOT_USERDATA=/tmp/... launch` still wrote its owner file etc.
  to the default `%APPDATA%/Godot/app_userdata/plant-tower-defense/`, not
  the temp dir). The sentence in CLAUDE.md is the one a reader acts on; the
  comment naming the true limit is three files away in the addon.
  - [G-043] status: open | seen: 1 | harness: 0.25.0
  - Improvement: reword the harness-generated CLAUDE.md/AGENTS.md line to
    stop implying `GODOT_USERDATA` isolates `user://` -- e.g. "`user://` ...
    stays shared; there is no supported way to isolate it (Godot has no
    `--user-data-dir` flag), so saves/screenshots/baselines from parallel
    `--isolated` instances can still collide" -- so a multi-agent
    orchestrator stops handing out an instruction that cannot work.

## 2026-08-16 — Wired Plant idle sway, per-attack Sfx cues, and a packet reveal beat

- Value: **warranted** — runtime caught a real defect in the packet-reveal code
  that the diff and headless tests alone would not have: the live pass is what
  made `test_a_headless_reveal_names_the_plant_it_actually_unlocked` and its
  two siblings *fail first*, before I understood why.
  - Expected: three straightforward additions (a sin() sway, three Sfx.play()
    call sites, a short flourish before a banner) would verify clean on the
    first pass of each.
  - Got: the packet-flourish tests failed with
    `Expected The packet held a Chomp Flower! but got Plant your free Corn
    Cobbler on the grass, then grow the first wave.` — `_reveal_plant_unlock`'s
    `show_message()` call used the default priority, and `show_message`'s own
    queueing rule (`_message_left > MESSAGE_MIN_READABLE` blocks a same/lower
    priority overwrite) meant the reveal silently queued behind whatever
    ambient message was already on screen instead of showing. Bumped it to
    `Hud.MESSAGE_IMPORTANT`, matching the flourish steps ahead of it.
  - Found: the priority bug above — invisible to code review, since
    `show_message()`'s queueing behaviour is only checkable by actually
    driving two competing messages through it. Also confirmed live (screen
    text over the bus) that a real packet purchase resolves to the correct
    plant name after the flourish, not just headlessly.
  - Cheaper: nothing — the headless test alone is what surfaced the bug; nothing
    short of driving `show_message()` twice with real timing would have.

- Gap: **`launch -- --devtools-session X` silently fails to wire the session** —
  five consecutive launches this way (`python tools/devtools.py launch --
  --devtools-session plantwork`) all reported `launched, but the bus never
  answered a ping within 20s`, with the spawned process stuck at ~6MB RSS and
  ~0.015s total CPU time indefinitely (confirmed via `Get-Process ... | Select
  CPU,WorkingSet`) — a genuine hang, not slow startup, and it reproduced
  identically under both `--rendering-driver opengl3` and the default D3D12,
  ruling out a GPU-contention theory. A sibling agent in a concurrent worktree
  had already diagnosed the same failure and reported that `launch --isolated`
  (which sets `--devtools-session` AND `--devtools-busdir` together) works
  where the bare `-- --devtools-session X` form does not; switching to
  `launch --isolated --kill-survivors` fixed it on the very next attempt, and
  every subsequent launch that session answered a ping within 1-2s. Lost
  roughly 15 minutes and 5 launch/kill cycles chasing GPU-contention and
  windowing-hang theories before the correct fix (a different flag) came from
  outside this session.
  - [G-037] status: open | seen: 1 | harness: 0.25.0
  - Improvement: either make bare `--devtools-session NAME` (without
    `--isolated`) actually wire a working bus the same way `--isolated` does,
    or have `launch` refuse/warn on that combination instead of reporting a
    generic 20s ping timeout that reads identically to a crashed engine — the
    symptom gives no hint that the fix is a different flag.
  - Root cause, found afterward by reading the installed `cmd_launch()`
    (`tools/devtools.py`): `-- --devtools-session X` with no top-level
    `--session` flag leaves `user_args` empty, so the `cmd += ["--"] + user_args`
    line that would add Godot's OWN `--` separator never runs — `cmd +=
    passthrough` alone appends `--devtools-session plantwork` straight onto the
    engine's command line as two unrecognized top-level tokens, which never
    reach `OS.get_cmdline_user_args()` at all. Confirmed against my own printed
    launch line, which shows no `--` before `--devtools-session`. A sibling
    agent had already filed this precisely
    (SeveralHerr/godot-selftest-harness#28, same root cause plus a related
    `GODOT_USERDATA` claim bug) before I got to filing; added a confirming
    comment with the CPU/memory signature above rather than duplicating it.

- Also worth noting: re-running `--import` after an earlier crashed `--import`
  (exit 139, mid-scan) left `.godot/imported/` with 4 files instead of ~690,
  which then surfaced as `Failed loading resource:
  res://assets/kenney/png/towerDefense_tile050.png` and `Unable to open file:
  ...ctex` inside `run_tests.gd` for every scene-instantiating test that
  touched `Board` — looked exactly like a real regression in `board.gd` until
  `ls .godot/imported/ | wc -l` and a from-scratch `--import` (this time
  running to completion, `[ DONE ] reimport`) cleared it. Not filing a
  separate gap for this since it is not a harness defect — a caller's own
  `--import` timing out mid-run under concurrent-agent load and leaving a
  half-built cache is a real failure mode of `--import` itself, worth knowing
  about but not something `/verify`'s own gates could have caught (lint and
  run_tests both ran clean against the broken cache; only the runtime `ERROR:`
  lines gave it away).

- Harness: **0.25.0**.

## 2026-08-16 — Kernel hit cue (plant-tower-defense-7o3) + StickySundew wash-order reset (plant-tower-defense-qij)

- Value: **warranted** — the runtime confirmed two things a diff can't: that the
  flash Tween actually fires with a value above 1.0 in a real windowed process
  (not just that headless takes the gated no-op branch), and that the counter
  genuinely returns to 1 for a second patch rather than climbing to 2, in the
  live game rather than in a unit test that only ever constructs and frees
  StickySundew nodes directly.
  - Expected: for the kernel cue, that a paused-then-stepped `step-time` sample
    would land somewhere between 1.0 and HIT_FLASH_BOOST (1.9) mid-tween. For
    the wash-order fix, that placing a second Sundew after freeing the first
    would report `_wash_order=1` again instead of `2`.
  - Got: `_sprite.modulate: {"r": 1.4286, "g": 1.4286, "b": 1.4286, "a": 1.0}`
    caught via `step-time --seconds 0.02` immediately after forcing the cob's
    `_cooldown` to 0 — a value the pure `hit_flash_color()` unit test alone
    could not have produced, since headless never runs the Tween at all. And,
    separately: `_wash_order=1` on a second live Sundew planted at a fresh
    cell after the first was freed through its own `play_exit_and_free()` —
    before this fix that would have read `2`.
  - Found: nothing broken in either change; the live pass matched what the
    headless tests already predicted. It did surface a testing-methodology
    trap of my own making, not a code defect: calling `play_exit_and_free()`
    directly (bypassing `Game.uproot_selected()`) left `_plants[cell]`
    pointing at a freed node, and the next `place_plant` at that same cell
    (plus `Game.covered_road_cells` / `Hud._refresh_selection`) then threw
    `Trying to cast a freed object` — a reminder that the two-step "erase from
    the dict, then free the node" order in the real uproot path is load-bearing
    and not optional busywork.
  - Cheaper: the headless unit tests alone (`hit_flash_color` pure-function
    test, and the wash-order reset test built entirely from
    `StickySundew.new()`/`.free()`) already prove both mechanisms correctly —
    a reviewer could trust them without the live pass. The live pass bought
    confidence that the *live* Tween and the *live* `_exit_tree` path (real
    scene tree, real GardenTheme.animations_enabled() == true) behave the same
    way the headless-gated tests assume, which is exactly the gap those tests
    cannot close on their own.

- Gap: `godot --headless --path . --import` segfaulted on its first run this
  session (exit 139, mid-reimport of vendored audio) and produced a clean exit
  0 on an immediate retry with no other change. Same signature as the
  already-logged half-built-cache gap above (concurrent-agent load against a
  shared `.godot/` import cache), but this time the crash was a hard segfault
  rather than a truncated cache, and it happened on the FIRST import call of
  the session rather than after `/verify` was already mid-run.
  - [G-044] status: open | seen: 1 | harness: 0.25.0
  - Improvement: `/verify`'s import step retrying once on a non-zero exit
    before surfacing failure would turn "verified nothing, investigate a
    crash" into "verified cleanly, noted a transient" — the same shape as the
    existing G- entry about `--import` racing another worktree's concurrent
    import, just caught one step earlier (segfault vs. truncated cache).

## 2026-08-16 — Title backdrop ambient motion + notebook page-dot easing (plant-tower-defense-yzt, plant-tower-defense-9o6)

- Value: **warranted** — the live bridge caught something a diff/headless-only pass
  could not: whether the eased dot actually trails the page mid-turn, not just whether
  the interpolation math compiles.
  - Expected: with animations enabled and the tween running, `current_page` (the
    target, set synchronously) and `_display_page` (the eased value) would visibly
    diverge for a moment right after a page turn.
  - Got: after `set-game-speed 0.02` then pressing NextButton on the live notebook,
    `get-state --node /root/TitleScreen/Notebook/Paper --property current_page
    --property _display_page` read `current_page: 2` / `_display_page:
    1.14481645822525` in the same round trip — the setter had already advanced the
    target while the marker was still mid-ease. A cropped `screenshot` of the dot row
    at that moment showed the filled dot sitting visibly between two hollow slots,
    matching the number.
  - Found: nothing broken — this was a confirmation run, not a bug hunt. It is the
    only way this specific claim ("it eases, not snaps") could be checked at all: a
    headless test can assert the interpolation formula and the instant-snap fallback
    (added two for exactly that), but headless never runs a live tween to sample
    mid-flight.
  - Cheaper: the two new headless tests (`dot_marker_x` interpolation,
    `current_page`'s instant fallback with animations off) covered most of the
    confidence for a fraction of the cost. The live pass exists only to close the one
    gap they structurally cannot: proving a real tween is actually mid-flight when
    sampled. Also used `screenshot` on the bare title screen to visually confirm the
    new cloud puffs render subtly and don't clash with the wordmark/buttons, and
    `findings --no-scenes` for a clean sweep before quitting.

- Gap: no gaps this turn. `launch --isolated --kill-survivors` worked first try per
  the local skill; the one hiccup was the very first `launch` failing with "Main
  scene's path could not be resolved from UID" because `--import` had not yet run in
  this fresh worktree checkout — expected, already documented, not a new gap.

- Harness: **0.25.0**.

## 2026-08-16 — Give Music its own independent mute, separate from Sfx's (plant-tower-defense-gle)

- Value: **warranted** — the diff is two static-class flags plus an input-handler
  branch; only a live keypress proves KEY_M and KEY_N actually route to two
  different flags instead of one shared one, which was the entire bug.
  - Expected: pressing M in a live run would silence only Sfx (HUD says "Sound
    effects off/on") and leave Music playing, and pressing N would silence only
    the run's music bed (HUD says "Music off/on") and leave Sfx cues untouched —
    the coupling the bead exists to remove.
  - Got: `key M` then `get-state --property text` on `MessageLabel` read
    `Sound effects off. Press M to bring them back.`; `key N` right after read
    `Music off. Press N to bring it back.` — two independent toggles, confirmed
    against the actual HUD copy rather than the source read alone. The grown
    pause card (`Card` at y=140 height=476, bottom 616) still holds `KeyRow3`
    (bottom 592) inside its own paper on a real 1152x648 viewport via
    `node-bounds`, so the fourth key row does not spill past the card the way
    an earlier bug in this same file once let the note sit under a button.
  - Found: nothing broken — confirmation run once the headless suite already
    passed (433/433, including a new
    `test_music_mute_is_independent_of_sfx_mute`).
  - Cheaper: the headless round-trip test covers the flag independence for a
    fraction of the cost; the live pass only closes what it structurally
    cannot — that `_unhandled_input`'s two `if key.keycode == KEY_M/KEY_N`
    branches are actually reachable from a real keypress and that the taller
    card still fits a real window rather than a headless 64x64 one.

- Gap: no gaps this turn. `launch --isolated --kill-survivors` worked first
  try; `key M`/`key N` worked as documented; the one snag was mechanical, not
  a harness gap — `verify_ledger.py record`'s first attempt reported
  `reached 0/2` because the scene-tree/scripts-seen capture was taken from a
  session that never pressed Start, so `game/game.gd`/`game/music.gd` were
  never loaded in that session. Recapturing both files from a session that had
  already entered `game.tscn` and pressed M/N fixed it to `reached 1/2`
  (`game/music.gd` stays unreached because it is a static utility class with
  no script attached to any node the scene-tree walk can see — `MusicHost` is
  a bare `Node.new()`, not a scripted node — which is a structural limit of
  reach-by-script-path, not something this run could have done differently).

## 2026-08-16 — Flash on Chomp/Sundew catches, and a shake+sfx for underfunded upgrades

- Value: **warranted** — runtime caught two things a diff read alone would not have.
  - Expected: ChompFlower._bite() and StickySundew._claim() would call flash_hit()
    without erroring during real gameplay, and the underfunded-upgrade shake would
    rotate the Upgrade button the same way shake_plant_button/shake_packet_button
    already do for their sites.
  - Got: across a real run through wave 5 with only a ChompFlower and a StickySundew
    on the board (34+ pest kills, both call sites exercised repeatedly), stderr held
    only the two pre-existing `press`-on-a-freed-node harness errors from an earlier
    ReplayButton press, nothing from chomp_flower.gd or sticky_sundew.gd. For the
    upgrade shake, `set-game-speed 0.02` then `get-state ... --property transform`
    read `rotation_degrees: -1.037` immediately after calling `upgrade_selected()`
    underfunded, and a second read moments later showed the sign had flipped
    (`+0.798`) — the shake beats actually progressing, not a static value.
  - Found: the live pass caught that `find-nodes --group pests` right after a
    `wait-frames` call kept coming back empty because the wave director auto-starts
    waves on its own prep timer — a pest I was tracking could die or a new wave could
    spawn between two bus calls with no explicit control over it. Reading the diff
    would not have surfaced that the wave clock keeps running independent of any
    single spawn/place call.
  - Cheaper: the unit-test half (flash_hit already had kernel-hit coverage; I added
    an analogous test_an_underfunded_upgrade_shakes_the_upgrade_button) is what
    actually gates regressions cheaply — the live pass mainly confirmed "no runtime
    error under real load" and "the rotation genuinely moves," which headless
    structurally cannot show since it never pumps the tween.

- Gap: no gaps this turn. `--isolated --kill-survivors` launch worked first try per
  the skill; `set-game-speed` needed a positional `scale` arg rather than `--scale`
  (my own mistake reading the flag shape, not a harness gap — `-h` corrected it
  immediately). `suite_reach_check.py` caught that my first draft of the new test
  only named `shake_upgrade_button` inside an assert *message string*, which the tool
  correctly does not count as reach — restructuring to call it directly, matching
  the existing shake_plant_button/shake_packet_button test shape, fixed it.

## 2026-08-16 — Three warning colours in one hue (plant-tower-defense-4lv, closed as duplicate) + seed-fly effect (plant-tower-defense-o2b)

- Value: **warranted** — the live bridge confirmed a claim a diff/headless-only
  pass could not fully make: that SeedGlyph actually opens at the husk's own
  radius on screen and travels toward the Seeds label, not just that the tween
  code compiles and the coordinate math is right in isolation.
  - Expected: at reduced game speed, a husk dropped and swept via
    `run-method drop_husk` / `collect_at` would leave a `SeedGlyph` under
    `Hud._fx_layer`, positioned at the husk's screen coordinates
    (`_entities.to_global(at)`) with `_radius` starting at `HuskLayer.radius_for(9)`.
  - Got: `find-nodes --class SeedGlyph` located it, `get-state --property
    position --property _radius` read `{"x": 499.4, "y": 371.5}` / `14.98` —
    matching the husk's board position (500, 300) plus the 72px Entities
    offset, and radius essentially at HuskLayer.radius_for(9) = 15 a frame in —
    and a cropped screenshot showed the gold disc sitting exactly on the husk.
  - Found: `findings` caught a real defect mid-task: an early `_fx_layer` built
    as a full-rect `Control` passed every headless test but produced a live
    `ui_zero_size`-adjacent-but-opposite finding once the *other* fix (zero-size
    instead) was tried — the two shapes contradicted two different checks
    (`_hud_rects` in test_selftest.gd vs. `findings`' `ui_zero_size`), and only
    running `findings` against the live tree surfaced the second one; grep and
    the unit suite were both silent on it. Landed on `Container` (base class),
    which is full-rect *and* excluded from `_hud_rects` by class the same way
    `ColorRect` already is.
  - Cheaper: nothing — this needed the running game specifically because the
    conflict was between a live UI-layout scan and a headless pixel-rect test,
    and neither alone would have shown both sides.

- Gap: `launch --isolated --kill-survivors` hung at the classic "bus never
  answered a ping within 20s" symptom the local `godot-devtools-concurrent-launch`
  skill describes — but this was a *different* cause than the one that skill
  documents, and the symptom is indistinguishable from the ping side: the process
  was alive, `MainWindowHandle` was 0, one thread, 0.015s CPU, exactly like the
  skill's malformed-cmdline signature. The actual cause was a plain, silent
  Godot OS.alert() dialog titled "ALERT!" blocking the main thread on "Main
  scene's path could not be resolved from UID. Make sure the project is
  imported first." — after a `godot --headless --path . --import` had already
  been run and appeared to finish (printed reimport steps through "[ DONE ]",
  no visible error). `.godot/uid_cache.bin` was in fact absent after that first
  import and present only after a second, identical `--import` call. `ping`'s
  20s timeout gives zero signal that a blocking native dialog is the reason —
  distinguishing "malformed cmdline hang" from "modal alert dialog hang" from
  "still loading" currently requires reading `MainWindowTitle` via PowerShell
  and, since the alert box draws no child controls `EnumChildWindows` can read,
  screen-scraping it with `PrintWindow` into a PNG to read the message at all.
  - [G-045] status: open | seen: 1 | harness: 0.25.0
  - Improvement: two independent fixes would each have closed this faster.
    (1) `--import` exiting non-zero (or printing a distinguishable warning)
    when it does not end up writing `uid_cache.bin`, rather than looking
    identical to a clean run — this is the same shape as the already-logged
    G-044 (`--import` segfault-then-clean-retry) and G-036-ish concurrent-import
    races, but here the first run didn't even error, it just quietly didn't
    finish the one file that matters for the next launch. (2) `ping`'s timeout
    message reading the launched process's own stdout/stderr tail (already
    captured to `.devtools/launch_stdout.log` / `launch_stderr.log` by
    `cmd_launch`) and surfacing a line like "the game already logged: ERROR:
    Main scene's path could not be resolved from UID" instead of a bare
    "never answered a ping" — since that exact diagnostic was sitting in the
    log file the whole time from the FIRST launch attempt, and would have
    named the fix immediately instead of sending the session toward the
    concurrent-launch skill's (correct, but irrelevant here) troubleshooting
    path.

- Harness: **0.25.0**.

## 2026-08-16 — A Sunflower payout gets a cue and a flying glyph (plant-tower-defense-14w)

- Value: **warranted** — the one thing this change is about, where the glyph
  starts, is invisible to every headless gate: `Hud.fly_seed_glyph` returns
  early behind `GardenTheme.animations_enabled()`, so the suite can only assert
  the connection's shape, never the point it flies from.
  - Expected: a real payout should show a glyph leaving the flower's own cell
    rather than the board origin, and should load a voice with the coins stream
    at the new trim — neither of which the diff can show, since fly_seed_glyph
    is gated off headless and volume_db is only read inside `Sfx.play`.
  - Got: with the tree paused and `_act(6.5, [])` driven over the bus,
    `/root/Game/HUD/Root/FxLayer` held one `Control` at `(44.23, 90.69)` — on
    the line from the flower's global `(32, 104)` (cell (0,0), `Entities` at
    y=72) to the Seeds label's centre `(105.5, 24)`. `/root/SfxPool/Voice0`
    read `stream: res://assets/audio/handleCoins.ogg` with `volume_db: -7.0`,
    which is `SEEDS_GROWN`'s trim and not `HUSK_COLLECTED`'s 0.0 — so the cue
    that fired was the new one, not the sweep's.
  - Found: the live start point of the glyph. The headless test can only assert
    that the connection binds the plant; that the bound position actually
    resolves onto the board through `_entities.to_global()` was only observable
    windowed.
  - Cheaper: nothing for the glyph's start point. The bank-credit half was
    settled by `test_a_sunflower_payout_carries_the_flower_it_grew_on` in 31ms.

- Gap: no gaps this turn — `pause` plus `run-method _act --args '[6.5, []]'`
  turned a 0.5s animation into something inspectable at leisure, and the typed
  `Array[Pest]` parameter accepted a JSON `[]` without complaint, which was the
  one thing I expected to have to work around.

- Harness: **0.25.0**.

## 2026-08-16 — A press cue for the wave button and the plant bar (plant-tower-defense-aho)

- Value: **warranted** — the issue's premise was wrong in a way only the running
  game corrects, and the correction is what set the cue's level.
  - Expected: the press cue and WAVE_STARTED's bell should land on two separate
    pool voices in the same frame, with the press at the lower trim — the point
    of the -10 dB choice, and something no headless gate can observe since
    `Sfx.play` returns early there.
  - Got: after `press --node .../NextWaveButton`, `/root/SfxPool/Voice0` read
    `minimize_006.ogg` at `volume_db: -10.0` and `/root/SfxPool/Voice1` read
    `impactBell_heavy_002.ogg` at `0.0` — the eight-voice pool doing exactly
    what it exists for, with `game_state` showing `wave: 1, wave_live: true`
    from the same press. A plant-bar press was proved through state rather than
    sound: `selected_plant` set to `sticky_sundew`, then
    `press .../Button_corn_cobbler`, then `selected_plant: corn_cobbler`.
  - Found: two things. The issue says `Sfx.WAVE_STARTED` "only plays later"; it
    does not — `Game.start_next_wave()` reaches `WaveDirector.wave_started`
    synchronously, so the bell is in the press's own frame. That is why
    `BUTTON_PRESSED` is the quietest row in the table rather than a fourth
    mid-level cue. Also caught mid-run: `run_tests` exited 1 on
    `test_the_suite_reach_baseline_lists_only_symbols_no_test_names` because the
    new test names `next_wave_requested`, which `tools/suite_reach_baseline.json`
    still recorded as un-named debt — re-banked with
    `suite_reach_check.py --baseline-write`.
  - Cheaper: reading `wave_director.gd:175-185` would have shown the synchronous
    emit, but not that the two cues land on separate voices at the levels
    intended. `press --node` is also the only thing here that exercises the
    button's own `pressed` wiring rather than the handler by name.

- Gap: no gaps this turn. Worth recording as a technique instead: an
  `AudioStreamPlayer` pool makes "did the right cue fire" a plain `get-state`
  on `stream` + `volume_db`, which reads a sound in a `--mute`d session — a
  finished sample leaves `playing: false` but the voice still holds what it was
  handed, so the read survives the round-trip latency that would otherwise make
  a 0.2s cue unobservable.

- Harness: **0.25.0**.
## 2026-08-16 — Migrated seven inline scancode checks to a real InputMap, and built the Keys screen over it

- Value: **warranted** — the live game contradicted a diff that read as obviously
  correct, twice, on two different layers.
  - Expected: that `input tap garden_pause` against the running game would open the
    pause card, confirming the migration; and that a screenshot would confirm a
    layout every rect assertion had already passed.
  - Got: neither. `input tap garden_pause` returned `Tapped: garden_pause` and
    `find-nodes --class PauseScreen` came back `0 node(s) matched` — the migrated
    handlers had kept the `var key := event as InputEventKey` narrowing they needed
    while they compared raw keycodes, so every one of the seven verbs was
    unreachable from `Input.action_press`. And on the Keys screen the footer
    rendered flush against the last row while `Rect2.intersects` reported no
    overlap (it is false for two boxes sharing an edge) and `findings` reported
    `0 finding(s) across 4 of 5 checks`.
  - Found: the InputEventAction gap (fixed mid-run, now
    `test_a_verb_arrives_as_an_action_event_as_well_as_a_key_event`) and the
    zero-gap footer (fixed, now a minimum-gap assertion). Also one honest catch by
    a *static* checker: `suite_reach_check` flagged that naming `KeyBindings.reset`
    in a test silently marked `WaveDirector.reset` covered — renamed to
    `reset_action`.
  - Cheaper: nothing for the InputEventAction gap — no static gate in this project
    reads what shape an `_input` handler accepts, and the unit tests were all
    feeding it `InputEventKey`, which is exactly the shape that still worked. The
    footer needed a screenshot specifically; every numeric check passed.

- Gap: **`findings` and the layout gates have no concept of a minimum gap between
  two Controls** — `python tools/devtools.py findings` reported
  `0 finding(s) across 4 of 5 checks` over a Keys screen whose "← Back" button sat
  at y=528 directly under a row button ending at y=528. `ui_layout` measures a
  Control against its own box, and the project's own pair-wise checks
  (`test_the_pause_card_lists_the_keys_and_still_fits_its_paper`, and the helper
  written this session) use `Rect2.intersects`, which is false for boxes sharing an
  edge. So "not overlapping" passes for "touching", and touching is what reads as
  broken. Worked around with an explicit `assert_gte(gap, 16.0)` in the test.
  - [G-046] status: open | seen: 1 | harness: 0.25.0
  - Improvement: give the UI checks a `min_control_gap` threshold in
    `devtools_config.json` (default 0 = today's behaviour) and have the sibling
    comparison report `controls_touching` as its own finding class, so a flush
    edge is named rather than being indistinguishable from a laid-out one.

- Gap: **`--import` crashed twice in a row on the same asset in a fresh worktree,
  and the retry advice does not cover it** — `python tools/import_check.py` exited
  2 with `no parse/load errors in the output, but Godot exited 3221225477`
  (0xC0000005) both times, `.devtools/import.log` ending at
  `[ 0% ] reimport | question_002.ogg` on each run, and `.godot/imported` holding
  only 12 `.tmp` files afterwards. This is G-044's shape (segfaulting `--import`)
  but the documented "run it again" fix did not resolve it — the ogg importer
  crashed at the same file every time. Unblocked by copying `.godot/imported`,
  `uid_cache.bin` and `scene_groups_cache.cfg` from the main checkout, which is
  valid because the import cache is keyed on the `res://` path, identical across
  worktrees.
  - [G-044] status: open | seen: 4 | harness: 0.25.0
  - Improvement: `import_check.py` should notice that `.godot/imported` gained no
    non-`.tmp` file across the run and say so, and — since every worktree of the
    same project imports byte-identical results — offer to seed the cache from a
    sibling checkout's `.godot/` rather than leaving the session to work out that
    that is legal.

- Note, not a harness gap: `user://highscore.save` is shared across worktrees and a
  sibling agent's uncommitted branch is independently writing its own `v3` of that
  file (`v3 / 140 / 0 / m0`, a mute-flags line where this branch writes a
  key-binding count). Both parsers refuse the other's file rather than misreading
  it, which is the designed outcome, but the two `SAVE_VERSION = 3` definitions
  will conflict on merge.
## 2026-08-16 — Persisted milestone flags on the post-mortem card (plant-tower-defense-4qi)

- Value: **warranted** — the live run is what showed `_end_run` actually joins the
  two halves the headless suite asserts separately.
  - Expected: the card would grow a `MilestoneRibbon` listing what the run was the
    first to do, and `RunConfig.earned_milestones` would hold the flag afterwards.
    The suite covers the evaluation table (`Milestones.is_met` at and one under
    every threshold) and the save round trip (a scratch `save_path`) as two
    independent things; nothing in it runs the line between them.
  - Got: staging `pests_defeated=120`, `lives=1` and calling `_on_pest_escaped(null)`
    produced `MilestoneRibbon/Milestone_hundred_pests` reading "A hundred turned
    back", `node-bounds` = `792, 96 336x102` **measured windowed** — exactly
    `RunSummary.ribbon_height(1)` and clear of the card's right edge at 768 — and
    `get-state /root/RunConfig --property earned_milestones` = `{"hundred_pests":
    true}`. `findings --no-scenes` was `0 finding(s) across 4 of 5 checks` with the
    ribbon on screen.
  - Found: nothing broken in the diff, but the run surfaced a real environment fact
    the gates structurally cannot. A sibling agent's game on the **pre-change**
    build shares `user://`, read this build's v3 `highscore.save`, refused it as
    "version 3 and this build reads at most 2", and quarantined it to
    `highscore.save.bak` before writing its own v2 back. That is the version gate
    doing exactly its job — but it means the on-disk half of the round trip is not
    observable live while a second checkout is running, only through the scratch-
    path unit tests. Worth knowing before reading a live save file as evidence of
    anything.
  - Cheaper: nothing for the wiring. Reading `game.gd:764` would have shown the
    call; only the running game shows that the ids it files are the ids the card
    renders, and that the ribbon lands at 792,96 on a real viewport rather than at
    a headless 64x64 window's idea of it.

- Gap: **a static-only class that demonstrably ran is invisible to `reach`** — same
  shape as G-028, third sighting. `record` reported `reached 3/4 changed file(s) …
  NOT reached: game/milestones.gd`. `Milestones` is `class_name Milestones extends
  RefCounted` with only static functions, so it owns no node and cannot appear in a
  `scene-tree` snapshot — even though this run's evidence that it executed is the
  `MilestoneRibbon` sitting on screen, which `Milestones.earned_by` is the only
  producer of. No alias was written this time; the ledger row carries the fact in
  `found` instead, so the miss stays visible rather than being declared away.
  - [G-028] status: open | seen: 3 | harness: 0.25.0
  - Improvement: unchanged from the second sighting — credit a `scripts-seen` hit
    as a third bucket (`reached_loaded`) beside `reached` and `reached_alias`. It
    is an observation rather than a declaration and would retire the whole class of
    alias entries projects write for RefCounted helpers.

## 2026-08-16 — A colourblind-safe ramp for the health and threat bars (plant-tower-defense-xu0)

- Value: **warranted** — a headless test caught a defect that would have shipped
  looking exactly right, and the live pass proved the tween lands on the new stop.
  - Expected: pressing C would swap the wave readout and the health fill onto the
    blue/orange ramp and write the choice down; pressing it again would put both
    back. The suite can assert the ramp *selection* as pure data
    (`threat_color_on` / `health_color_on` take the flag), but not that the key
    reaches the handler, that the easing tint tween ends on the new stop rather
    than somewhere between the two, or that the option lands in the real save.
  - Got: `key C` flipped `RunConfig.colorblind_safe` to true and
    `theme_override_colors/font_color` on `WaveLabel` (threat 22) read back
    `{r: 0.976, g: 0.647, b: 0.196}` — exactly `GardenTheme.SAFE_BAD`. A second
    press returned it to `{0.85, 0.25, 0.22}` = `DANGER`. `user://highscore.save`
    read `v4 / 3 / 3 / m2:campaign_cleared,threat_peak / cb1`, then `cb0` after the
    next press — the real save path, not a scratch one.
  - Found: **the first blue/orange pick was worse than the ramp it replaced.**
    `test_the_safe_ramp_separates_its_ends_in_more_than_the_red_green_channel`
    failed with "the safe ends differ in lightness by 0.157 against the default's
    0.267" — a colourblind-safe pair *harder* to tell apart in greyscale than
    green-against-red, which is the one property the whole option exists to fix. A
    mid blue against a mid orange is the picture everyone has of this fix and it
    reads as obviously correct in a diff; only a test asserting the property rather
    than the colours produces that number. Fixed by pushing both stops apart in
    lightness (0.33 against 0.69, gap 0.36). Also noted in passing, from one
    `find-nodes --class ColorRect` sweep: the in-world plant health bar
    (`Plant.HEALTH_BAR_HURT`) is a THIRD red-lerp bar still on the old ramp — out
    of scope for an issue that names the two hud.gd sites, so filed rather than
    widened.
  - Cheaper: nothing for the tint. The ramp arithmetic is covered headless, but the
    wave readout's colour is a theme *override* reached through an easing tween, so
    "does the bar the player is looking at end up on the new ramp" is only
    answerable by reading `theme_override_colors/font_color` off the live label
    after the tween settles.

- Gap: no gaps this turn. The one thing that needed a workaround —
  `--userdata C:\...` with backslashes silently polling a path with the separators
  eaten (`polling: C:UsersgotmiAppData...`) — is Git Bash mangling the argument
  before Python sees it, not the harness; forward slashes fix it, and the error
  message already prints the mangled path it is polling, which is what named the
  cause.

## 2026-08-16 — Keys screen reachable from the pause card (plant-tower-defense-ac0)

- Value: **warranted** — `node-bounds` answered the one question the whole issue turned
  on, and answered it windowed, where the headless suite could only answer it against a
  constant.
  - Expected: the pause card with a fifth button would foot past 648, since
    `KeyBindingScreen`'s own header says so; deriving `card_top()` as a centred value
    should put the foot at 603 with 45px of slack either side.
  - Got: `Card (Panel)  Rect: 288, 45, 320x558`, tagged `Geometry: measured windowed
    (what a player sees)` rather than `[HEADLESS geometry]`. Foot at 603 in a 648
    viewport. `KeysButton  Rect: 324, 273, 248x44`, inside it. After
    `press --node .../KeysButton`, `KeysScreen/Paper  Rect: 226, 24, 700x600` with
    `process_mode: 3` (ALWAYS) on a tree the card had paused; `find-nodes --class
    KeyBindingScreen` came back `0 node(s) matched` after Back.
  - Found: a stale legend the diff would not have shown. The card builds its key rows
    once from the table Game hands it, and the new button sits directly above those rows
    — so a player could rebind pause and read a row still naming Esc. Added
    `_refresh_key_list()` on close, and a test that drives the rebinding through the
    screen's own `listen_for`/`capture` and asserts the Label text. Also noticed, and NOT
    mine: `KeyRow4` measures `316, 553, 326x26` against a card ending at x=608 — a Label
    whose assigned 264 width loses to its own minimum size, so the longest legend row
    draws ~34px past the paper. Pre-existing (nothing here touches that row's x or
    width); filed rather than widened into this issue.
  - Cheaper: the headless assertion alone would have got the arithmetic right, but it
    asserts against `ProjectSettings`' 648 rather than the window, and the existing
    fits-the-viewport test already had a hardcoded 648 in it. The cheap half that proved
    the new test can fail was a mutation run (`card_top()` → `return 140.0`,
    `--filter pause_card`): `[FAIL] test_the_pause_card_centres_itself_and_fits_a_real_viewport`
    plus `[FAIL] test_the_pause_card_is_tall_enough_for_whatever_it_holds`.

- Gap: no gaps this turn. `launch --isolated --kill-survivors` came up first try,
  `press` / `node-bounds` / `find-nodes --class` / `get-state --property` each answered
  what they claim to, and `findings --no-scenes` reported `0 finding(s) across 4 of 5
  checks (1152x648)` with the skipped one named by reason. The `--import` segfault at
  exit (`exit=139`, `.godot/uid_cache.bin` written anyway) is G-044 and is not re-filed.

## 2026-08-16 — A milestone shelf in the notebook, and the third health bar routed through the colourblind switch (plant-tower-defense-qar, -b6v)

- Value: **warranted** — the shelf is a new hand-positioned page and the plant bar's
  repaint is a *timing* claim, and runtime answered both in a way the diff could not.
  - Expected: the shelf would render inside `DRAWING_BOX` with seven greyed rows, and
    the in-world bar would follow `garden_colorblind` without anything biting the
    plant again.
  - Got: `node-bounds .../Notebook/Shelf` → `Rect: 178, 148, 360x300`, `In viewport:
    True`, `Geometry: measured windowed`. `SourceLabel.text` → `0 of 7 earned`. With
    three ids staged in memory, the screenshot shows three LEAF_DARK rows carrying a
    10px pip against four grey rows with a 4px pip and a `Not yet — ` note. For the
    bar: paused, `take_damage(24)` → `color {0.85, 0.25, 0.22}` (DANGER) at
    `size 12.8x5`; one `input tap garden_colorblind` later, with nothing else
    touching the plant, `color {0.976, 0.647, 0.196}` = `GardenTheme.SAFE_BAD`.
  - Found: **the repaint gap, caught before it shipped rather than after.** The
    obvious version of the fix routes `health_bar_color` through the switch and
    stops there — which is what the issue asked for and is still wrong, because the
    in-world bar is only ever painted from `take_damage()`/`_regrow()`. A chewed bed
    nobody is currently eating would keep the old ramp until something bit it again,
    i.e. the option would look broken on exactly the bar it was added for.
    `Plant.repaint_health_bar()` and the loop in Game's colourblind handler exist
    because of that, and
    `test_toggling_the_option_repaints_the_bars_already_on_the_board` drives it
    through `_unhandled_input` so the loop cannot be deleted silently.
  - Cheaper: for the *arithmetic*, yes — `Plant.health_bar_color_on(false, safe) ==
    Hud.health_color_on(0.0, safe)` is a pure assertion and needs no game, and it is
    in the suite for that reason. For the repaint and for the shelf's layout, nothing
    cheaper: one is about when a paint happens and the other is about where
    hand-typed constants land on screen.

- Gap: **`--isolated` isolates the bus, so a live check that exercises a persisted
  setting has to write through the developer's real save and put it back by hand.**
  Reading staged milestones back was safe (`set-state /root/RunConfig
  earned_milestones` calls no `_save()`), but exercising the colourblind toggle at
  all goes through `set_colorblind_safe()`, which writes `user://highscore.save` on
  every press. The workaround was to read the original values first
  (`colorblind_safe: false`, `earned_milestones: {}`), stage, screenshot, then press
  the key an even number of times and re-read to confirm — a discipline nothing in
  the harness enforces and which a crash mid-check would have skipped, leaving the
  developer's own save altered by a verification run. (The 2026-08-16 entry above
  files the *merge* half of this as "not a harness gap"; this is the other half —
  not two checkouts disagreeing, one checkout mutating state it only meant to read.)
  - [G-047] status: open | seen: 2 | harness: 0.32.0
  - Improvement: a `--snapshot-userstate` flag on `launch` that copies `user://*.save`
    aside and restores it on `quit` (or on the next launch, if the game died) would
    make a live check that touches persisted settings safe by default rather than by
    convention. It needs no `user://` isolation to work.

- Gap: **`import_check.py`'s single retry was not enough** — the same crash signature
  already filed, twice in a row before a third invocation succeeded: `godot --import
  exited 3221225477 with no recognizable parse/load error`, `.devtools/import.log`
  ending at `[ 0% ] reimport | question_002.ogg` both times, `.godot/uid_cache.bin`
  absent after the tool gave up. Calling `import_check.py` a second time (i.e. a
  third `--import` overall) completed and wrote the cache.
  - [G-044] status: open | seen: 5 | harness: 0.32.0
  - Improvement: unchanged in kind but sharper now that there is a count — retry
    until the log's last line stops advancing rather than exactly once, since the
    observed failure needs two retries and the existing cap is one.
## 2026-08-16 — An Options screen for the three flags that only had keystrokes (plant-tower-defense-lgv)

- Value: **warranted** — headless alone produced two claims reading the diff would
  not have, and one of them was a test that was green for the wrong reason.
  - Expected: the new screen would read and write `RunConfig.colorblind_safe`,
    `Sfx._muted` and `Music._muted`; the fifth title button would fit above
    `TitleBackdrop.HORIZON` at the retuned pitch; and the panel's footer would
    stand clear of the last row.
  - Got: `Total: 477 | Passed: 477 | Failed: 0`, `Assertions: 10405 executed`,
    `Suite: 7 test script(s)`, `Errors: 0 emitted during the suite` — and, before
    that, `[FAIL] ... and options cannot open on top of keys either: Expected true
    but got false`, plus lint's `Scripts: 47 compiled OK / UIDs: OK / 0 error(s),
    0 warning(s)`.
  - Found: **two, both mid-run.** (1) The overlay-stacking assertion was written as
    `get_node_or_null("OptionsScreen") == null` after a `_close_options()`.
    `queue_free()` does not take effect until the frame ends and a unit test never
    yields one, so that lookup hands back the corpse of the overlay just closed and
    reads as "the guard failed" — and would have read as a PASS for the wrong
    reason had the guard actually been broken and the node been fresh. Rewritten to
    count children that are not `is_queued_for_deletion()`. (2)
    `suite_reach_check.py` gated two NEW findings on `options_screen.gd` (`set_on`,
    `get_viewport_height`); `set_on` is the absolute setter every button press goes
    through and had only ever been reached through the `toggle()` sitting over it.
  - Cheaper: for the layout, nothing — `test_title_controls_all_clear_the_scenery`
    reads `MENU_BUTTON_NAMES` and the live positions, and five rows at the shipped
    pitch overrun the horizon by 54px, which is not visible in a constants diff.
    For the flags themselves, reading `run_config.gd:280-289`, `sfx.gd:224` and
    `music.gd:136` would have given the same confidence about the setters; the
    tests are worth more as the thing that stops the next screen writing the flags
    directly.

- Gap: **`godot --headless --import` exits having imported only part of the
  project, and the symptom is eleven unrelated-looking test failures.** The first
  `--import` of this session returned normally with `[ 0% ] Executing pre-reimport
  operations... question_002.ogg` as its last line. The full suite then reported
  `Passed: 466 | Failed: 11` with `Errors: 14 emitted during the suite` —
  `SCRIPT ERROR: Cannot call method 'get_height' on a null value at
  TitleScreen._build_scenery` and `Failed loading resource:
  res://.godot/imported/towerDefense_tile050.png-...ctex` — and the named failures
  were `test_every_sound_the_game_can_play_actually_loads`,
  `test_the_title_lawn_shows_every_plant_in_the_catalogue`,
  `test_a_chomps_sprite_swaps_while_its_mouth_is_full` and seven more, none of
  which this change touches. Reading them, the honest first conclusion is "this
  branch broke asset loading". Workaround: re-run `--import` to completion; the
  same suite then reported `Passed: 477 | Failed: 0 | Errors: 0` with no code
  change between the two runs. It also cost ~50MB of `.devtools/tests.log` and
  roughly a 10x slower suite, since every one of those errors printed a full
  GDScript backtrace.
  - [G-044] status: open | seen: 5 | harness: 0.32.0
  - Improvement: unchanged from the earlier sightings, and this one adds the
    cheapest possible version of it — `import_check.py` (or `/verify`'s import
    step) comparing each `.import` file's `dest_files=` against what actually
    exists under `.godot/imported/` and printing `Imported: N of M` as a
    denominator. A partial import is currently indistinguishable from a clean one
    at the point where you could still act on it, and only becomes visible eleven
    failures later in a form that reads like a code regression.

## 2026-08-16 - Extracted OverlayScreen out of the three overlays (plant-tower-defense-q7b)

- Value: **warranted** - the live game answered the one question the headless suite
  structurally cannot: that the extracted chrome still comes up under the *pause
  card*, on a tree that is actually paused, with the node paths the bridge presses
  by name still resolving.
  - Expected: the refactor is pure motion, so the risk is not arithmetic but
    lifecycle - a base-class `_ready()` a subclass silently replaces, an overlay
    that comes up frozen because PROCESS_MODE_ALWAYS moved, or a renamed node path
    only the bridge would notice.
  - Got: `scene-tree --root .../KeysScreen --depth 1` listed `Backdrop, Paper,
    Heading, Note, Row0..Row7, RowKey0..7, RowButton0..7, BackButton, ResetButton`
    in the original order; `node-bounds RowButton7` = `744, 472, 150x40` and
    `BackButton` = `258, 560, 150x40`, so the live footer clearance is 560 - 512 =
    **48px against a FOOTER_GAP of 24** - the same number the headless assertion
    computes, measured windowed. `get-state --property process_mode` returned `3`
    (ALWAYS) on the pause-card copy, and `press BackButton` on the paused tree left
    the pause card with no `KeysScreen` child at all. The notebook came up with all
    18 of its nodes, `PageLabel` reading `1 / 8`, and Next moved it to `2 / 8`.
    `findings --no-scenes` over the open notebook: `0 finding(s) across 4 of 5`.
  - Found: nothing in the game - but the baseline re-run found something about the
    *suite*: with the refactor stashed and `game/overlay_screen.gd` left on disk,
    `test_every_game_class_is_at_least_named_somewhere_in_the_test_suite` failed.
    That is the suite correctly refusing a new `class_name` no test names, and it
    is worth knowing it fires while the class is still unwired rather than after.
  - Cheaper: for the geometry, nothing - the headless test asserts the same 48px,
    but only the live run proves the pause card's copy is the one being measured.
    For the row and label styling, reading the diff was enough.

- Gap: **`node-bounds` crashes on a Button whose text contains a non-cp1252
  character.** `python tools/devtools.py node-bounds .../KeysScreen/BackButton`
  exited with a Python traceback ending `UnicodeEncodeError: 'charmap' codec can't
  encode character '←' in position 17` at `cmd_node_bounds`, devtools.py:3096
  (`print(f"  Text: ...")`). The button's label is the left-arrow + " Back" that
  every overlay in this game uses, so the most obvious verb to point at an
  overlay's Back button is the one that cannot print it on a default Windows
  console. Workaround: `PYTHONIOENCODING=utf-8` in front of the command, which is
  not discoverable from the traceback.
  - [G-048] status: open | seen: 1 | harness: 0.33.0
  - Improvement: reconfigure stdout once in `main()` -
    `sys.stdout.reconfigure(encoding="utf-8", errors="replace")` - so no verb can
    take the whole client down over a character in game text. Failing that,
    `_printable()` should strip unencodable characters, since it is already the
    function every text field is routed through.
## 2026-08-16 — Pause-card legend overflow (neg) and the title menu's sixth slot (w5k)

- Value: **warranted** — the running game produced the number the diff could not,
  twice, and in opposite directions: it confirmed the reported overflow was a
  `set_size` ordering bug rather than a too-long string, and it caught that fixing
  the ordering still left the text 1px over budget.
  - Expected: that `KeyRow4` was simply too long for its box, and that shortening
    the `does` phrase in `KeyBindings.ACTIONS` was the whole fix.
  - Got: `node-bounds` before — `Rect: 316, 553, 326x26`; after the ordering fix —
    `Rect: 296, 553, 304x26`, i.e. the Label finally honoured its assigned width.
    Then the new headless check, measuring through `_T.text_width`: `KeyRow4 draws
    265px, budget is 264`. Two different defects stacked, and only the first was
    the one reported.
  - Found: the ordering trap itself. `_build_key_list` set `size` BEFORE
    `clip_text` / `text_overrun_behavior` / `font_size`, so `Control.set_size`
    clamped to a minimum computed on unclipped text at the theme default font size
    (16, not the 13 the row actually renders at). Reading the diff for the reported
    symptom would have produced a shorter string and left the trap in place — the
    next long row would have overflowed again for a reason nobody had written
    down. Also caught, on w5k: capacity is 8, not the 6 or 7 the issue asked for,
    which only the computed `menu_capacity()` could say.
  - Cheaper: for the *box* half, nothing — `get_minimum_size()` reports the clip
    stub and no static read of `pause_screen.gd` says what `set_size` clamped to.
    For the *text* half, the new `_T.text_width` assertion alone (54ms headless)
    would have done it; the live `node-bounds` was confirmation, not discovery.
    The w5k capture was warranted: the grid's odd-trailing-secondary rule is a
    visual judgement (does a spanning "Options" read as deliberate?) that no
    assertion answers.

- Gap: **[G-033] seen: 3 — now FIXED, and the fix worked exactly as advertised.**
  `_T.text_width(label)` (0.33.0) is the helper this log asked for twice, and it is
  what made the second half of `neg` assertable at all:
  `_T.assert_true(_T.text_width(row) <= PauseScreen.KEY_ROW_MAX_WIDTH, ...)` failed
  at `265 / 264` and passed after the fix. Recorded as fixed rather than bumped
  silently, because a gap that got closed upstream and never says so reads like a
  gap nobody acted on.
  - [G-033] status: fixed | seen: 3 | harness: 0.33.0
  - Improvement: none outstanding. The CLAUDE.md note that ships with it ("Testing
    'does this text fit its box'?") is what pointed at the helper before any time
    was spent on `get_minimum_size()`.

- Gap: **nothing measures a Control's BOX against the panel it is drawn on when
  the two are siblings.** This is the half of `neg` that no gate could see, and it
  is distinct from the text-fitting gap above.
  `python tools/devtools.py findings` reported `0 finding(s) across 5 of 5 checks`
  against a live game whose pause card had 34px of legend hanging off the paper.
  Every check was right to: `ui_layout` measures a Control against its own box and
  its own parent, and `KeyRow4`'s parent is `PauseScreen` (full-viewport), not
  `Card` — the paper it visibly belongs to is a SIBLING, so "inside its parent" is
  trivially true. `validate-ui`'s `ui_text_trimmed` measures text against
  `control.size` and passed too, because after the clamp `size` had *become* 326.
  The project's own pause-card test checked vertical fit and pairwise overlap, and
  a Label sticking out sideways over a backdrop overlaps nothing.
  Workaround: hand-written, per-screen — `right = row.global_position.x +
  row.size.x` asserted against `card.global_position.x + card.size.x`, with the
  card found by node name. That is the third screen in this project to grow its
  own bespoke version of "stays on the paper", after
  `NotebookScreen.SUBHEAD_MAX_WIDTH` and now `PauseScreen.KEY_ROW_MAX_WIDTH`.
  - [G-048] status: open | seen: 1 | harness: 0.33.0
  - Improvement: a `contained-in --node PATH --within PATH` verb, and a
    corresponding `ui_escapes_panel` check driven by an opt-in map in
    `devtools_config.json` (`{"PauseScreen/KeyRow*": "PauseScreen/Card"}`). The
    generic version is guessable without config too: for each visible Panel, flag
    any SIBLING Control that overlaps it and is not fully inside it. A Control half
    on and half off a piece of paper is a defect in every UI, and it is currently
    invisible to every check this harness ships.

- Gap: **`--import` failed again, and this time loudly.**
  `godot --headless --path . --import` exited 139 (`Segmentation fault`) with the
  log ending mid-`loading_editor_layout`; an identical second invocation exited 0
  with zero errors, no code change between them.
  - [G-044] status: open | seen: 6 | harness: 0.33.0
  - Improvement: unchanged — `Imported: N of M` as a printed denominator. This
    sighting adds that the failure mode is not always silent-partial: a hard
    segfault with a clean-looking log tail is the same bug wearing a louder hat,
    and the retry that fixes it is indistinguishable from the retry that papers
    over a real problem unless something states the denominator.
## 2026-08-16 — Save v6 (the two mutes) and a second door to the Options screen

- Value: **warranted** — `node-bounds` at a real 1152x648 settled a card-geometry
  question the diff could only guess at, and the headless suite caught a layout
  invariant a previous session had written down and I would otherwise have broken.
  - Expected: that adding a sixth button to the pause card would fit (the
    arithmetic said 614 of 648) and that the live card would foot around 638.
  - Got: `test_the_pause_card_centres_itself_and_fits_a_real_viewport` failed on two
    assertions — "the card is centred: 24 above, 10 below" and "a sixth button would
    need 670 of 648". Fitting was never the invariant; being centred with room for
    one more row was, and `card_top()`'s `CARD_MIN_TOP` clamp had silently absorbed
    the difference. After pairing Keys and Options on one row, the bridge measured
    `Card 288, 45, 320x558` — byte-identical to the pre-Options measurement in
    70e1f4d — with `KeysButton 324,273 120x44` and `OptionsButton 452,273 120x44`:
    same top edge, 8px apart, right edge at 572 = exactly one full-width button's
    span. `findings`: `0 finding(s) across 5 of 5 checks (1152x648)`.
  - Found: two real defects, both fixed mid-run. (1) The v5->v6 bump would have
    silently eaten a v5 save's milestones AND its rebound keys: all three v5 fields
    were read behind `version >= SAVE_VERSION`, which stops meaning "this file has
    them" the instant SAVE_VERSION moves, and the migration rewrite would then have
    written them back out empty. Caught by reading the parser before editing it, not
    by any gate — no test existed for "a v5 file reads forward" because until this
    change v5 *was* current. (2) The Options screen's colourblind row repainted
    nothing when flipped over a paused board: the C key's handler did the repaint
    inline, so the switch reached from the new door took effect at the next wave.
  - Cheaper: for the geometry, nothing — headless reports the card at a 64x64
    window and the centring claim is about a real viewport. For everything else the
    headless suite alone was enough; the live pass confirmed rather than discovered,
    and its real value was the two numbers in the commit message.

- Gap: **the headless suite rewrites the developer's real `user://highscore.save`,
  and no gate says so.** Four tests in `test_selftest.gd` (`:679`, `:1014`, `:4326`,
  `:4921`) stage low scores in memory and call `RunConfig.record_score()` while
  `RunConfig.save_path` is still the real file; `record_score` calls `_save()`.
  Observed across two full runs: `v5/308/5008` -> `v6/310/5010` -> `v6/2/2`. Both high
  scores destroyed, recovered only from a copy taken into the scratchpad before the
  work started. Every one of those tests stashes and restores the in-memory scores,
  which is exactly what hides it — the FILE keeps the last number written, and the
  suite reports `ALL TESTS PASSED`. Filed as `plant-tower-defense-csl`.
  - [G-048] status: open | seen: 1 | harness: 0.33.0
  - Improvement: the harness knows `test_dir` and it knows `user://`. A `/verify`
    step that snapshots `user://` before the suite and diffs it after — printing
    `user:// writes: N file(s) changed by the suite` as a denominator — would turn
    this from an invisible loss into a line. Advisory is enough; a test suite
    legitimately writes `user://`, but a suite that writes a file NO test named a
    path for is a suite driving production state. Related to gh#33/gh#28: with two
    agents in two worktrees sharing one `user://`, this is not a niche case.

- Gap: **`run_tests.py` silently ignores a `--select` passed after `--`.** `python
  tools/run_tests.py -- --select test_economy` printed `Selected: 491 of 491
  discovered  (no selector)` and ran the whole suite. `run_tests.py --select ...`
  without the `--` errors correctly (`unrecognized arguments: --select`), so the
  passthrough form is the one that fails quietly. Cost here was small (two full
  ~90s runs where one file would have done); the shape is the harness's own
  documented worst failure mode — a denominator that reads fine while describing a
  different run from the one you asked for.
  - [G-049] status: open | seen: 1 | harness: 0.33.0
  - Improvement: `run_tests.py` should forward everything after `--` into
    `run_tests.gd`'s own argument parsing, or, failing that, `run_tests.gd` should
    exit 2 on an argument it does not recognise rather than printing
    `(no selector)` beside a full-suite run. The parenthetical is already the
    evidence; it just isn't fatal.

## 2026-08-16 — Pests got a walk cycle (plant-tower-defense-iue)

- Value: **warranted** — the bridge produced the exact arithmetic identity the whole
  feature rests on, on a live pest, which no headless test and no reading of the diff
  could have produced.
  - Expected: that `_sprite.rotation` would equal `_facing + _sway` on a walking pest,
    that the mutation tint would survive the gait untouched, and that a pest killed
    mid-stride would leave a corpse lying straight.
  - Got: on a paused winged aphid, `_facing=-1.5707963267949`, `_sway=-0.0338831961131744`,
    and the sprite's `rotation: -1.60467946529388` — the sum to the last digit, with
    `modulate: {a 0.88, b 1.0, g 0.94, r 0.82}` still exactly `MUTATION_TINT[winged]`.
    On a beetle stepped 0.1s with `step-time --then-pause`: `rotation: 1.64119553565979`
    against `_facing 1.5707963267949 + _sway 0.0703991653428545`, `scale {x 0.945, y 1.055}`
    (narrowed across the body, lengthened along it, |stretch| 0.0546 under GAIT_STRETCH
    0.06). `run-method kill` on that same beetle then read back `rotation: 1.57079637050629`
    and `scale {1.0, 1.0}` — the lean undone, the facing kept. Nine aphids spawned in one
    burst reported nine distinct `_gait_phase` values (0.0, 2.400, 4.800, 0.917, 3.317,
    5.717, 1.833, 4.233, 0.350) and nine different `_sway` values at the same instant.
  - Found: nothing — the headless suite (507/507) had already pinned the composition
    rule, and the live run agreed with it. `settle_read_check.py` did catch a real defect
    in the new test mid-work: a `_gait_time` read after `instantiate_scene` with nothing
    guarding the baseline, fixed by zeroing the clock in the test and asserting an exact
    value instead of `> 0.0`.
  - Cheaper: the headless tests alone would have carried the arithmetic. What they could
    not carry is that a real pest on a real route, turning a real corner, keeps a live
    sway across the turn — `_facing` moving PI -> -PI/2 between two reads while `_sway`
    kept oscillating is the one claim that needed the running game.

- Gap: no gaps this turn. `step-time --then-pause` plus `find-nodes --class Pest
  --property _sway --property _gait_phase` was exactly the right pair of verbs for
  reading a per-frame animation without a screenshot, and `quit` confirming
  `user://: no file changed during this run` closed out the save-file worry from
  [G-048] without a manual diff.
## 2026-08-16 — More waves, and a boss pest (plant-tower-defense-74a)

- Value: **warranted** — the live run produced the one claim no diff and no headless
  test could: what a boss fight actually looks like over 40 seconds of real time
  against a real garden, and it separated "killable" from "kills the run" in the
  same session.
  - Expected: an 80 HP queen at 30 px/s would be ground down somewhere in the
    first half of the road against six-to-seven maxed Corn Cobblers, and would be
    effectively unkillable against a thin level-1 garden. Both guessed off
    `single_target_dps` arithmetic before running anything.
  - Got: wave 16 driven end to end — each queen entered at 80 and was tracked
    `79 -> 51 -> 27 -> 10 -> 0` while walking from 6% to ~36% of the road, roughly
    30-40 s per queen, and the aphid count on the board jumped `0 -> 6 -> 15` in
    the two samples after the first deaths. The run cleared wave 16 with 10/10
    beds. The same wave 12 against four level-1 cobs held the queen at `72/80` for
    25 consecutive seconds — three hits in half a minute — and the run lost all ten
    beds at t=34.8s. That is the balance band as a measurement rather than as an
    estimate.
  - Found: two things reading the diff would not have. (1) The endless road stopped
    filling. Raising `ENDLESS_BEETLE_BASE` to 20 puts the column past its road
    share from the first endless wave, so `_paced_gap` spreads it and the swarm and
    column no longer peak together — endless fell from 40 of 40 pests to 29, which
    would have silently turned `pest_road_ceiling` from `spent_by_design` into
    `tight` and deleted a documented invariant. Caught by
    `test_the_pest_road_ceiling_reports_spent_by_design_not_a_plain_spent` failing
    on `headroom == 0.0`, and fixed by sizing wave 16's swarm to 22 so the campaign
    finale lands on the ceiling exactly. (2) `test_the_coverage_map_keeps_its_promise…`
    drove "wave 14", which stopped being an endless wave when the table grew, so
    its stated premise ("the garden is LOSING it") quietly evaporated — 7 of 29
    escaped where it needs a third. Now written as `WAVES.size() + 6` and
    re-measured at 24 of 48.
  - Cheaper: nothing for the fight itself. The road-budget half was caught headless
    by `run_tests.py` in 90 s and needed no game at all — the Python model in the
    scratchpad (a 60-line re-implementation of `peak_simultaneous_pests` and
    `threat_for`) was what made sixteen waves tunable in four iterations instead of
    four Godot runs each, and that is the cheapest thing here by a wide margin.

- Gap: **`launch --snapshot-userstate` is opt-in, and the warning that you needed it
  arrives at `quit`, after the file is already unrecoverable.** The flag added for
  G-047 works exactly as advertised — the second launch restored cleanly. The first
  launch did not use it, and `quit` then printed:

  ```
  user://: this run wrote the developer's REAL user data in
  C:\Users\gotmi\AppData\Roaming\Godot\app_userdata\plant-tower-defense
  -- changed: highscore.save.
  ```

  By then the developer's campaign best had been overwritten with 36074 from a run
  driven on 35,000 injected seeds, and the pre-existing value exists nowhere — no
  snapshot, no history, nothing to restore from. The warning names the damage at the
  one moment nothing can be done about it. Note the damage is not test pollution: it
  is the *game* saving normally, which is why no test-side rule catches it.
  - [G-050] status: open | seen: 1 | harness: 0.36.0
  - Improvement: take the snapshot on **every** `launch` (it is a file copy of
    `user://*.save`, cost is microseconds) and make `--snapshot-userstate` control
    only whether `quit` restores it. Then a run that turns out to have written the
    real save is recoverable after the fact instead of only before it. Failing that,
    `launch` should print the "this session shares your real `user://`" line it
    already prints *with* the names of the files that exist there and would be
    overwritten, so the decision is offered at the moment it can still be made.
## 2026-08-16 — The Bomb Dandelion: a fifth plant, arcing seed bombs, and an epic packet tier

- Value: **warranted** — `findings` refused a HUD layout that every headless gate,
  including the bar's own arithmetic sweep test, had just called correct.
  - Expected: the runtime pass would confirm what the unit tests already asserted —
    that a fifth plant button and a third packet button both fit the side panel,
    since `plant_bar_layout()` reported a legal column count and every button
    cleared the 40px touch floor.
  - Got: `7 finding(s) ... ui_overflow: GridContainer 'PlantBar' extends past
    viewport (rect: 908,116 -> 1194,320, viewport: 1152x648)` plus four
    `button_text_overflow`. The two-column bar the layout function had chosen is
    not renderable at all: `get_combined_minimum_size()` on a plant button reads
    `{"x": 158.0}`, so two of them need 324px in a 232px bar and the GridContainer
    GROWS rather than shrinking, pushing the whole side panel 42px off screen.
  - Found: that, and the fix it forced — the plant buttons' two-line text has 54px
    of intrinsic height against one line's 31px, which is the only slack in the
    panel and is what a fifth plant plus a third packet tier had to be paid for
    with. Also that "Blowball Dandelion — locked" measured 225px against a 233px
    button and had to become "Bomb Dandelion".
  - Cheaper: nothing. The bar's vertical arithmetic is unit-tested and was right;
    the failure is a Container's minimum-size behaviour against a label width, and
    no static read of `hud.gd` produces the number 158.

- Value (second half): **warranted** — the bridge is how "the seeds arc" stopped
  being a claim about a tween and became a measurement.
  - Expected: `find-nodes --class SeedBomb` mid-wave would show a projectile
    somewhere between the plant and a pest.
  - Got: two at once, `flight_fraction()=0.876 sprite_lift()=19.1` and
    `flight_fraction()=0.027 sprite_lift()=4.67`, with `position` landing exactly on
    `from.lerp(to, t)` and each `sprite_lift()` matching `SeedBomb.lift_at(t)` to
    three decimals — i.e. the arc is the sprite lifting off an honest ground track,
    which is the only shape that works on a top-down board.
  - Found: nothing new here; it confirmed the unit tests against a live wave.
  - Cheaper: the headless tests already pin the arithmetic. What runtime added was
    `performance --by-type` reporting `Orphan growth: +0` after a wave of bombs,
    which says the linger-then-free path actually frees.

- **[G-047] again (seen bumped to 2, not re-filed).** A live pass ended a run and
  `quit` reported `changed: highscore.save; created: highscore.save.damaged-36074` —
  the campaign record went from 36074 with three milestones to 308 with none, on a
  `launch --isolated` that isolates only the bus. Two things worth adding to that
  entry's evidence: the loss happened without any test running, purely from playing
  the game through the bridge, and the `.damaged-NNNNN` quarantine file is written by
  nothing in this repository (`grep -rn 'damaged-' tools/ addons/ game/` is empty), so
  a concurrent worktree's build produced it. The old content survives inside it and
  was left untouched. `--snapshot-userstate` was not passed and should have been.

- Gap: **`set_physics_process(false)` before `add_child()` does not stick, and the
  harness's own test guidance does not say so.** A `Dandelion` built with physics
  disabled and then hosted had already fired a seed by the first assertion
  (`a fresh head is full: Expected 3 but got 2`), because Godot re-enables physics
  processing at `NOTIFICATION_READY` for any script declaring `_physics_process`.
  `test_combat.gd` already works around it by calling the setter AFTER
  `instantiate_scene` and resetting `_cooldown` by hand, but nothing says why, so the
  next test writer rediscovers it. Cost: one full suite round trip.
  - [G-050] status: open | seen: 1 | harness: 0.36.0
  - Improvement: one paragraph in the harness's "Where the checks you write live"
    section, beside the existing `instantiate_ui` note — headless pumps no frames for
    Controls, but it DOES pump the settle frames for a hosted Node2D, and a node
    quiesced before hosting is not quiesced. Better still, a `_T.quiesce(node)`
    helper that sets the flag after the host is live, so the ordering is not
    something each test has to know.


## 2026-08-16 - tests for the OverlayScreen builder surface and the title menu grid (plant-tower-defense-fvv)

- Value: **warranted** - the headless suite produced a number the diff could not: an
  assigned `size` that the engine clamped up underneath the builder.
  - Expected: five appended tests would go green first try; `suite_reach_check`'s 8 NEW
    findings would fall to 0 because the six `add_*`/`footer_y` and the two static
    title-grid functions are now called and asserted on.
  - Got: `Total: 524 | Passed: 523 | Failed: 1` on the first run -
    `and spans this paper at the y it was given: Expected [P: (200.0, 140.0), S: (720.0, 40.0)]
    but got [P: (200.0, 140.0), S: (720.0, 42.0)]`. `add_heading` sets a 40px box and a
    30px font's combined minimum size is 42, so the box the builder asks for is not the
    box that lands. Second run: `Total: 524 | Passed: 524 | Failed: 0`,
    `Assertions: 11406 executed`, `Suite: 7 test script(s)`.
  - Found: that clamp. The assertion was rewritten as exact position + exact width +
    `assert_gte` on the height, which is the claim that is actually true of every
    text-bearing Control the base builds - and is the assertion that will not go red the
    next time the theme's heading font moves.
  - Cheaper: nothing cheaper reaches it. `name_check` (0 errors), `import_check` (OK) and
    lint (`Scripts: 48 compiled OK`) all passed on the version that failed - a clamped
    `size` is neither a name nor a compile error. No game was launched: everything here is
    layout `instantiate_ui` resolves, plus two static functions, so a live pass would have
    cost a windowed Godot and told me nothing the suite did not.

- Gap: **`instantiate_ui`'s contract says a Control's `size` stays `(0, 0)` without it, and
  stops there - it never says the size that lands can be LARGER than the one the code
  assigned.** Every doc line about this helper is about the value being too small
  (`headless pumps no frames, so without it size stays (0,0)`), so the trap it actually
  set was the opposite one. `probe.heading.size` came back `(720.0, 42.0)` against an
  `add_heading` that had just executed `heading.size = Vector2(panel.size.x, 40.0)`,
  because `Control.size` is clamped up to `get_combined_minimum_size()` and a Label's
  minimum is its font. Workaround: assert position exactly, width exactly, and height
  with `assert_gte`. This repo's own history has hit the same clamp before from the
  other side (a Label whose "assigned 264 width loses to its own minimum size" draws
  past its paper) without it ever being filed.
  - [G-051] status: open | seen: 1 | harness: 0.38.0
  - Improvement: one sentence beside the existing `(0, 0)` warning - "and after the
    settle frames a Control's `size` is clamped UP to `get_combined_minimum_size()`, so
    an exact-equality assertion on a text-bearing Control's size is asserting the theme's
    font metrics as much as the code's layout; assert position exactly and size with
    `assert_gte`." Better still, a `_T.assert_box(control, rect)` helper that does exactly
    that split, so the right assertion is the shortest one to write.

## 2026-08-16 — Pin the 'game' group at zero instead of asking which node is first (plant-tower-defense-uay)

- Value: **warranted** — a temporarily inverted precondition made the full suite state a
  fact about tree state that no amount of reading the diff could have established.
  - Expected: that `test_the_budgets_verb_degrades_per_entry_with_no_game_in_the_tree`
    was green for the wrong reason — the `godot-test-isolation` skill's whole thesis is
    that a tree-global group read gets a node the test never made, and
    `group_leak_check.py` had flagged this line on three prior agent runs.
  - Got: the opposite, and stated numerically. With the guard flipped to
    `assert_eq(in_group.size(), 99)`, the 519-test suite printed
    `Expected 99 but got 0 ... Found: []`. The `"game"` group is genuinely empty at that
    point in suite order, so the verb really was being driven down its no-Game path. The
    old `get_first_node_in_group(...) == null` guard was correct; what it could not do is
    *say* so, because "whichever the engine lists first" carries no cardinality.
  - Found: nothing broken in the game. The finding was about what the test could
    *express*, not what it measured — worth separating, because "the checker fired" and
    "the code is wrong" got conflated three times before this.
  - Cheaper: nothing cheaper would have done. `group_leak_check.py` (0.2s) names the
    line but is a source scanner and cannot say whether the group is populated at
    runtime; only running the suite with the count inverted answers that. Reading
    `commands.gd:41-42` established that `_game()` is tree-global, which is why the
    guard matters — but not whether it was currently being satisfied by luck.

- Gap: **a stopped background test run keeps writing to the results file, and a results
  file containing two runs looks like one run with a contradiction in it.** A suite run
  was moved to the background on timeout and stopped via `TaskStop`; the shell died, the
  `godot` child did not, and it kept appending to the same redirect target a later
  foreground run had truncated. The result was one file with two `Total:` lines —
  `519/519 | 11310 assertions` and `516/519 | Failed: 3` — with per-test times inflated
  from 154ms to 5610ms by the CPU contention. The house doctrine is "read the
  denominators, not the exit code", and here there were two sets of denominators
  disagreeing with each other in one file. Diagnosing it needed
  `Get-CimInstance Win32_Process` to prove the surviving pids were a *sibling agent's*
  bridge session on another checkout and not mine.
  - [G-051] status: open | seen: 1 | harness: 0.38.0
  - Improvement: have `run_tests.gd` stamp a per-run nonce on both its opening and its
    `Total:` line (`run 7f3a1c pid 12345`), and have `run_tests.py` exit `2` when its
    captured output contains more than one distinct run nonce — "this file is two runs,
    you are reading a mixture" rather than leaving a human to notice the duplicate
    `Total:`. Cheap, and it turns an invisible misread into a refusal.

- Gap: **`godot --headless --path . --import` segfaulted mid-import again** (exit 139,
  died on `question_002.ogg`), leaving a half-populated `.godot/` whose next test run
  emitted 400,548 lines of `Failed loading resource:` and never finished. Known shape.
  `python tools/import_check.py` afterwards rebuilt it and reported
  `Import OK: the class cache regenerated ... 1134 line(s)`, so the recovery path works —
  the cost is that the bare `--import` gives no signal that its own crash invalidated the
  run that follows, and it leaves `.import*.tmp` debris behind (two files here).
  - [G-044] status: open | seen: 7 | harness: 0.38.0
  - Improvement: as previously filed — `--import` should be wrapped so a non-zero exit is
    surfaced and retried rather than silently handing on a truncated cache. Additionally:
    sweep the `assets/**/*.import*.tmp` / `.TMP` leftovers on the retry, since they
    otherwise show up as untracked files in `git status` and invite being committed.

## 2026-08-16 — cycle 30: found and fixed the suite writing the player's real save

- Value: **warranted** — the writers were two chains through the game's own code, and
  no amount of reading the tests would have named them; the run is what named them.
  - Expected: that `RunConfig._load()`'s migration branch was rewriting the file on
    startup, since the bytes came back identical and a v5→v6 migration would explain a
    same-content write.
  - Got: the opposite. A `get_stack()` on `_save()` printed three real-path writes and
    none of them was `_load`: `test_quitting_a_run_through_pause_still_files_the_score
    -> Game.bank_score() -> record_score() -> _save()`, and two from
    `test_toggling_the_option_repaints_the_bars_already_on_the_board ->
    Game._unhandled_input() -> toggle_colorblind_safe() -> _save()`.
  - Found: a live data-loss bug, not the mtime nuisance the issue described. The first
    test stages both records at 0, so its write is unconditional — it filed 320 over
    this machine's real campaign record (308). The developer's numbers came back only
    because the colourblind test ran LATER and saved the restored in-memory values on
    top. The save survived by suite order. Also found, in passing, that the existing
    guard test had been reporting clean over both of them since it was written.
  - Cheaper: nothing. `run_tests.py`'s reporter said WHICH file changed and that is
    where its knowledge ends; the diff shows two tests that look exactly like the
    forty others that host `game.tscn`. Six lines of `get_stack()` in `_save()`, one
    suite run, and the answer was unambiguous.

- Gap: **the user:// reporter names the file the suite wrote and cannot name the test
  that wrote it.** `user:// writes: 1 file(s) changed by the suite ... changed:
  highscore.save` is exactly one bit more than "something happened", and recovering the
  rest cost a hand-instrumented `_save()` and a full 535-test run. The machinery to do
  better is already in `devtools.py` and already called by the wrapper —
  `userstate_stat_take` / `userstate_stat_diff` are a snapshot and a diff, and
  `run_tests.gd` already brackets every test method with setup/teardown.
  - [G-052] status: open | seen: 1 | harness: 0.38.0 | filed upstream: gh#39
  - Improvement: take the snapshot per test method rather than per run (it is a `stat`
    of one directory, cheap next to a scene instantiation), and print
    `user:// writes: highscore.save <- test_quitting_a_run_through_pause_still_files_the_score
    (test_selftest.gd)`. Same check, same cost class, and it turns a cycle of
    instrumentation into a line of output. Gate it behind a flag if the per-test stat is
    unwelcome by default — the information is worth a `--trace-user-writes`.

- Gap: **`_T` has no `assert_ne`.** Asserting "this path is NOT the player's save" — the
  runtime half of this cycle's fix — has to be written
  `_T.assert_false(a == b, "...%s...%s" % [a, b])`, and the message has to carry both
  values by hand, because `assert_false` reports only `Expected false but got true`.
  The helper set has `assert_eq`, `assert_true`, `assert_false`, `assert_float_eq`,
  `assert_gt`, `assert_gte` and `assert_margin`; inequality is the obvious missing one,
  and it is the shape every "did the guard actually move this" check wants.
  - [G-053] status: open | seen: 1 | harness: 0.38.0 | filed upstream: gh#39
  - Improvement: add `static func assert_ne(actual, unexpected, context := "") -> String`
    beside `assert_eq` in `run_tests.gd`, reporting `Expected anything but <value>` and
    printing the actual — six lines, and it removes the hand-formatted message that is
    the only reason the failure above is readable.

## 2026-08-16 — cycle 31: the second direction on a derived lookup table

- Value: **overkill** — triaged to tier (c) at Phase 0.5 and it was the right call; the
  gates confirmed what two planted failures had already proved.
  - Expected: tier (c) headless-only. `board.gd` gains one `const` with no runtime
    behaviour, so a launch could load the file and have nothing observable to assert;
    `test_every_grass_cell_has_a_tile_the_kit_actually_ships` stands in for runtime, and
    both of its directions were planted and watched fail before being restored.
  - Got: exactly that. `lint: 0 error(s), 0 warning(s)`, `Total: 535 | Passed: 535`,
    `Assertions: 11707 executed`, `Suite: 7 test script(s)`, `user:// writes: 0 file(s)`.
    The two plants are the real evidence: adding `0b0111: 999` to the table failed the
    new direction with `Expected [] but got [7]`, and removing the produced mask `0b0011`
    failed the old one with `cell (8, 2) needs edge mask 3`. Different messages, different
    causes, which is what "both directions" has to mean.
  - Found: nothing. The table had no dead entries — the assertion that would have caught
    one simply did not exist until now, which is a gap in the *checks*, not a defect the
    run surfaced. `found: []` is the honest answer and `overkill` follows from it.
  - Cheaper: nothing cheaper than what ran. The full runtime pass was skipped on purpose;
    the two filtered suite runs that planted the failures were the whole cost.

- Gap: **no gaps this turn.** Phase 0.5's triage table answered the question directly —
  tier (c), name the tests that stand in for runtime — and the ledger accepted the row
  with `--no-reach` without pretending a number it did not have. The one thing worth
  noting is not a gap: `record` downgraded nothing, because the run reported `overkill`
  itself rather than claiming `warranted` over an empty `found`.

## 2026-08-16 — cycle 31: the reset button asks before it undoes anything

- Value: **warranted** — three defects, none of which the diff or the headless test
  could show, and one of them was the harness catching me doing the thing I spent the
  previous cycle fixing.
  - Expected: the button wiring and the two-press state machine need the live game — a
    headless test can call `reset_all()` directly, but only a real press proves
    `_reset_button.pressed` is connected to the handler that now asks rather than the
    one that undid.
  - Got: more than that. `get-state --node .../Note --property text` came back
    `hold the garden still will go back to its shipped key.` — `KeyBindings.describe()`
    returns a legend cell, not a noun phrase, which is the trap this very file already
    documents thirty lines further down at the refusal message. My headless assertion
    was `note.text.contains(describe(...))`, which is true of a garbled sentence.
  - Found: three.
    1. The garbled sentence above.
    2. The reworded version measured **962px of text in a 700px `clip_text` Label** —
       `findings` reported `ui_text_trimmed: the player sees a cut string`. A
       confirmation that names what it is about to destroy was naming it off the
       visible edge. Fixed by naming the KEYS (`F1 · F2`) rather than the verb
       phrases, and promoted into `test_dir` as a `_T.text_width(note) <= note.size.x`
       assertion — planted and watched fail at `1006px of text in a 700px label`.
    3. **The live session wrote the developer's real save.** `capture()` persists, so
       driving the screen through the bridge put `garden_pause 4194332` /
       `garden_restart 4194333` into `user://highscore.save`; the next full suite run
       loaded them at startup and five byte-exact save assertions failed against a
       binding block no test wrote. Restored byte-identical (md5 `75aab726…`, the
       value recorded in cycle 30). This is exactly the hazard the harness's own
       token-aware section states — `--isolated` does not isolate `user://` — arriving
       from the bridge rather than from the suite, one cycle after the suite half was
       fixed and gated.
  - Cheaper: nothing. The headless test passed on the garbled sentence and is
    structurally unable to see a trimmed label; the save pollution was only visible in
    a full-suite run.

- Gap: **nothing stops a live bridge session persisting into the developer's `user://`,
  and nothing tells you afterwards that it did.** `quit` names what the run changed —
  and I did not read it, because the write happened many verbs earlier and the failure
  surfaced twenty minutes later as five unrelated-looking test failures. The suite now
  has `tools/save_persist_check.py` and per-script `setup()` redirects; the bridge has
  neither and cannot have the second one.
  - [G-054] status: open | seen: 2 | harness: 0.38.0 | filed upstream: gh#40
  - Improvement: `launch --snapshot-userstate` already exists and makes `quit` restore
    what the run changed. Make it **the default for `launch`**, with
    `--no-snapshot-userstate` to opt out — a verification session that silently mutates
    the developer's save is never what was wanted, and the flag only helps the people
    who already know to look for it. Failing that, have `launch` print one line naming
    the `user://` files it is prepared to see change, so the hazard is stated at the
    moment the risk is taken rather than at `quit`, after the damage.

## 2026-08-16 — cycle 32: the pause legend against a key the player picked

- Value: **warranted** — a real spill, found by the new test on its first run, in a
  place a pre-existing test had been measuring for cycles.
  - Expected: the derived worst-case key is only a claim about text width until a real
    card is built with it; and `CARD_WIDTH` feeds `CARD_X` and `card_rect()`, so
    widening it moves the card's placement and every layout test that derives from it.
    Runtime is where "still looks like a card" gets decided.
  - Got: the headless half fired first and harder —
    `KeyRow4 draws 384px against a 304 budget ... (On-screen keyboard   colourblind-safe
    health and threat bars)`. 80px of legend onto the dimmed backdrop over the live
    board. Runtime then confirmed the fix as geometry rather than as an impression:
    `KeyRow4 ... control: 256,553 384x26 within: 228,45 440x558`, `findings` clean, and
    a screenshot showing the card still proportioned.
  - Found: the spill. The existing `test_no_pause_card_legend_row_draws_past_the_paper`
    has measured this exact budget for cycles and could not see it, because it measures
    the legend **as built** and every row it has ever measured carried a shipped key.
    A legend row is `"%s   %s" % [keys, does]`; the card was sized against the `does`
    phrases, and the moment the Keys screen landed the other half became the player's
    choice. The old test was not wrong, it was *complete for a game that no longer
    exists* — which is a failure mode worth naming, since nothing about it looks stale.
  - Cheaper: the headless test alone would have done it, and did. The runtime half was
    confirmation — but `CARD_WIDTH` feeds `CARD_X`, and "a 440px card still looks right
    over the board" is not a thing any assertion in this project states.

- Gap: **no gaps this turn**, and one closed by using it. Last cycle's [G-054] was that
  a live session silently writes the developer's `user://`; this run used
  `launch --snapshot-userstate 'highscore.save'` and `quit` reported
  `userstate: restored 1 file(s) and removed 0 created during the run` with the md5
  unchanged. The flag works exactly as documented — which is the argument for gh#40
  (make it the default), not against it: it only helped here because the previous cycle
  had already paid for the knowledge that it exists.

## 2026-08-16 — cycle 33: the pause card sizes itself to its own legend

- Value: **warranted** — the runtime half found a defect the headless suite was green
  over, and it was a defect introduced by the fix it was verifying.
  - Expected: the column split is arithmetic until a real card is built from it.
    `card_width()` derives from measurements taken by a DETACHED Label, and whether
    that resolves the same font as the in-tree rows is a fact about this project's
    theme rather than about Godot. Runtime is also the only place "the card got
    narrower" is observable at all.
  - Got: the card measured `266, 45, 365x558` against a hand-picked 440 the day
    before, with `KeyRow0` a 46px right-aligned column and `KeyRowDoes0` a 247px
    left-aligned one. Then, rebinding `garden_pause` to `On-screen keyboard` through
    the bridge with the card already open: `KeyRow0 size 127`, `KeyRowDoes0` pushed to
    x+143 — **52px off a 365px card**.
  - Found: two.
    1. `_refresh_key_list()` measured against `key_row_max_width()`, which re-derives
       from the NEW bindings — so it laid the columns out for the card the rebinding
       *would* produce, while the card on screen was still the one built for the old
       keys. The fix for a legend running off the card had reintroduced a legend
       running off the card, one code path over. Now measured off the `Card` node,
       and gated by a test planted and watched fail at `684 against paper ending at
       631`.
    2. The live session wrote the real save **again**, despite
       `launch --snapshot-userstate 'highscore.save'`.
  - Cheaper: nothing. No test drove a rebinding against an already-built card until
    this run made one, so the suite had nothing to say.

- Gap: **`--snapshot-userstate` did not restore on the `quit` that ended the session.**
  Second sighting of [G-054] and a sharper one than the first, because this time the
  mitigation was in use. Sequence: `launch --snapshot-userstate 'highscore.save'`,
  drive the game (which rebinds and therefore persists), `quit`. Afterwards
  `user://highscore.save` still carried `garden_pause 4194417`, and five byte-exact
  save tests failed against it. The snapshot itself was **correct** —
  `.devtools/userstate_snapshot/highscore.save` held the right pre-run bytes — and a
  second, bare `python tools/devtools.py quit` (no game running at all) printed
  `userstate: restored 1 file(s) and removed 0 created during the run` and put them
  back. So the machinery works and something about the ending quit skipped it; I did
  not establish what, because that quit's output was redirected to /dev/null and the
  session is gone. Worth saying plainly rather than guessing.
  - [G-054] status: open | seen: 2 | harness: 0.38.0 | filed upstream: gh#40
  - Improvement: unchanged (make it the default), plus one that this sighting argues
    for on its own — **`quit` should say what it did with the snapshot every time,
    including "no snapshot to restore"**, and a `quit` that was asked to restore and
    could not should exit non-zero. A restore that silently does not happen is worse
    than no restore, because the flag was the reason to stop checking the file by hand.

## 2026-08-16 — cycle 34: the Keys screen shows the key in full

- Value: **warranted** — two defects, one live and one latent, in a class the suite had
  no test for at all.
  - Expected: the derived column and the widened panel are arithmetic until a real
    screen is built from them; and this screen's rows are built through a SHARED
    helper whose ordering bug was fixed at one call site and left in place here, so
    whether the box holds is a fact about the helper rather than about the column.
  - Got: the live half was the *headless* half this time — a test driving `refresh()`
    with the longest engine key bound failed at `the key is shown IN FULL: 157px of
    name in a 140px column`. Runtime then confirmed the fix as a picture rather than a
    number: `On-screen keyboard` rendered whole at `590,144 157x24` inside a
    `218,24 717x600` paper, clear of the Change button, `findings` clean.
  - Found: two.
    1. **The Keys screen truncated the key the player had just chosen.** The one
       surface whose entire job is saying which key a verb is on showed
       "On-screen keybo...". It also invalidated the argument used to accept the same
       truncation on the pause card one cycle earlier — "if something must be cut it
       is the key, which the player can read in full one screen up". They could not.
    2. **`OverlayScreen.add_row_label` set `size` before `clip_text`** — the exact
       ordering bug `PauseScreen._build_key_list` documents at length having been
       bitten by, fixed there at the call site and left in the shared helper that two
       screens build every row through. Latent today, and measured rather than
       assumed: size-first gives a **373px box for an assigned 140**, clip-first holds.
  - Cheaper: nothing. There was no test anywhere that drove a rebinding through
    `refresh()` on this screen — the whole "state changed while the screen was open"
    class was untested, which is what the bead was about.

- Gap: **no new gap, and [G-054] behaved this time.** `launch --snapshot-userstate` was
  passed, `quit` printed `userstate: restored 1 file(s)` and the save's md5 came back
  identical. Reading that line rather than redirecting it is the whole of the lesson
  from last cycle.
  - One wording note, not worth its own id: `quit` prints the "this run wrote the
    developer's REAL user data … `launch --snapshot-userstate` restores such files on
    quit" warning **even when that flag was used and the restore is about to happen on
    the very next line.** It reads as "you should have done X" at the moment X is
    working. Added as a comment on gh#40 rather than filed separately, since it is the
    same function and the same conversation.

## 2026-08-16 — cycle 35: weather rounds

- Value: **warranted**, but narrowly, and the honest split is worth recording.
  - Expected: the derivation and the multiplier are arithmetic until a real cob reads
    them; and the banner is the only thing that makes weather a rule the PLAYER knows
    about rather than a number the code applies, so "the words reached the screen" is
    not assertable headlessly through anything but the pure headline/note functions.
  - Got: the plant side confirmed exactly as predicted —
    `fire_interval_scale=1.0` on a cob planted clear, `2.0` after
    `_apply_weather("drought")`, and the banner reading `Drought` /
    `Dry ground. Everything you planted shoots half as often.` with rain correctly
    replacing it.
  - Found: one, and not the one I was looking for. **The selection panel's readout
    ignores the weather.** It prints `1.0 dmg / 0.80s, 1 kernel(s)` straight from
    `CornCobbler.LEVELS`, so under a drought it tells the player 0.80s while the cob
    fires every 1.60s. Seen in a screenshot, caught by no assertion — the rule reached
    the plants and not the surface that describes the plants. Filed rather than fixed.
  - Cheaper: **most of this was cheaper headless and I should say so.** The
    derivation, the multiplier and the heal are pure enough to assert without a game,
    and the two new tests carry them. The runtime half earned its place on exactly two
    things: words arriving on a screen, and the readout defect above.

- Gap: **no gaps this turn.** `launch --snapshot-userstate` behaved again —
  `user://: no file changed during this run`, `restored 1 file(s)`, md5 unchanged.
  Two clean sessions in a row now against one miss, which is the ratio worth having
  on the record at gh#40.

- Note, not a gap: a screenshot taken 0.3s after a banner fires can miss it — the
  banner fades on a timer, and the capture caught the game after it had gone. Reading
  the two Label texts directly was both more reliable and cheaper, and is what the
  harness's own token-aware section already recommends over a screenshot. Recording it
  because the instinct to "take a picture to check the words" is exactly the instinct
  that guidance is arguing against, and I had it anyway.

## 2026-08-16 — cycle 36: the cob quotes the rate it will actually fire at

- Value: **warranted**, and the interesting part is that a *headless* gate I did not
  write did the work.
  - Expected: a readout fix and a bar addition, both small; the risk was the bar's
    width, which the project already gates twice.
  - Got: the width gates did far more than confirm a number. Adding a weather tag to
    the wave slot failed `test_no_readout_clips_its_own_worst_case` at
    `WaveLabel needs 424px, has 312`, then again at 366 after I shortened the tag,
    and when I widened the slot to fit, `test_a_clean_launch_warns_about_no_budget_at_all`
    reported `hud_stats_row ... down to -35 px` — the whole stats row overflowing,
    which "shoves the wave button off the bar rather than overlapping it, which is
    not a fix". Measured, the base string is 302px in a 312px slot: **every**
    candidate tag overflowed, including a bare `*` at 317.
  - Found: two, and neither was the one I set out to fix.
    1. **A second instance of the drought bug.** `readiness()` divided a cooldown
       armed at `interval x scale` by the *base* interval, so the cob's arming glow
       sat empty for the whole first half of every reload under a drought. Same
       cause as the selection panel: the surfaces that DESCRIBE a value are a
       separate population from the code that USES it. Both read `fire_interval()`
       now, and the planted version fails at `got 0.00` where it should read 0.50.
    2. **The top bar cannot afford weather at all**, which is a design answer rather
       than a bug. Reverted in the same cycle, with the measurement written into
       `Hud.WORST_CASE_TEXT` so the next attempt reads it before spending an hour.
  - Cheaper: nothing, and this is the cycle where that is least arguable — the whole
    finding came from gates that ran in seconds and refused to let a guess through.

- Gap: **no gaps this turn.** The run never needed the bridge: every claim here was
  settled headlessly, including the one about pixel widths, because this project
  measures text through the real theme font rather than by eye. Worth recording as
  the counter-example to the last two cycles, where runtime earned its place.

## 2026-08-16 — cycle 37: reconciling the gap ledger (plant-tower-defense-ye1)

- Value: **warranted** — the reconciliation the workflow has asked for since cycle 4,
  and every number in the request turned out to be wrong.
  - Expected: 61 open gaps to walk, most of them probably fixed by eight harness
    releases, and a long boring pass.
  - Got: the count was the first finding. `grep -c "status: open"` returns 65, which is
    a count of LINES; the file holds **69 status lines over 49 distinct ids, 44 of them
    currently open**. The bead said 61. Three ids (G-024, G-030, G-033) carry an
    earlier `open` line *and* a later `fixed` one, so the file states both at once —
    the format records status per ENTRY, which is right for the entry and leaves the
    FILE unable to answer "what is open".
  - Found: three things, none of which was on the list.
    1. **`tools/gap_ledger.py`** now derives each gap's status from its LAST mention,
       which turns an unanswerable question into a derived one. Old entries are left
       alone deliberately: rewriting them would falsify what was true the day they
       were written.
    2. **A citation is not a fix, and the split matters.** 43 of this project's ids
       appear somewhere in the installed 0.38.0 — but 29 of those are only in the
       harness's own copy of this log, put there by `upstream_gaps.py`. Just **14 are
       cited in harness CODE**, and those citations read in the past tense
       ("used to cost", "used to pass for", "used to be"), which is what a fix looks
       like. Counting the 43 would have closed 29 gaps nothing had acted on.
    3. **G-044 is cited in code and is still open**, which is why the split above is
       not sufficient either: `import_check.py` carries a
       `plant-tower-defense:G-044` comment describing the `--import` segfault
       mitigation, and this log records the gap at `seen: 7` against 0.38.0 because
       the mitigation was not enough.
  - Cheaper: nothing, and the cheap version is what produced the wrong numbers — the
    grep that said 61 was the cheap version.

**Reconciliation.** These ten are cited by name in `templates/` code in the installed
0.38.0, each describing the old behaviour in the past tense. Marked fixed on that
evidence; not re-run individually, and this line is the record of which claim is being
made. G-019 was re-verified in full (`dev_tools.gd` rebuilds a JSON array as the
property's typed Array, citing the id).

  - [G-014] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-016] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-018] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-019] status: fixed | shipped in 0.38.0 | evidence: dev_tools.gd rebuilds typed arrays, read in full
  - [G-025] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-026] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-029] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-046] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-047] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-048] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code
  - [G-049] status: fixed | shipped in 0.38.0 | evidence: cited in templates/ code

**Still open and re-confirmed:** [G-044] status: open | seen: 7 | harness: 0.38.0 —
cited in code, and the citation is a mitigation this project has watched fail.

- Gap: **no gaps this turn.** The harness was not the subject; its log was.

## 2026-08-16 — cycle 38: the record rolls up from the one it beat

- Value: **warranted** — an animation is the one class the suite structurally cannot
  reach, and the run also caught me muting the tool that was answering me.
  - Expected: `GardenTheme.animations_enabled()` is false headless, so the suite can
    assert the renderer, the origin and the final text, and cannot assert that
    anything MOVES. That is the whole reason to launch.
  - Got: exactly that, once I stopped breaking my own procedure. At
    `set_game_speed 0.05` the label read
    `Campaign 301` → `302` → `303` on successive polls, climbing from the 300 it beat
    toward 308, and settled on `Campaign 308`. At 1.0 the roll finishes inside a
    single bridge round-trip, which is why the first four attempts saw only the
    final value.
  - Found: **nothing in the code, and something about how I drive it.** Four attempts
    showed a static label and I began doubting the feature. The cause was
    `press --node /root/TitleScreen/PlayButton` — the button is named `StartButton`,
    and the verb had been answering `Node not found: ...` with **exit 1** the entire
    time. I had written `> /dev/null 2>&1` on it and never read the code. The harness
    was correct and immediate; I had muted the one thing that would have told me.
  - Cheaper: nothing cheaper can run a Tween. But the run cost four round-trips to a
    mistake already printed on the first.

- Gap: **no gaps this turn**, and one non-gap worth writing down because it looked
  like one. I was about to file "`press` reports success on a node that does not
  exist" — it does not: `Node not found: /root/TitleScreen/PlayButton`, exit 1,
  verified explicitly before writing this. The bug was mine. **Check that the tool is
  actually silent before filing a gap about its silence**, especially after
  redirecting its output.

## 2026-08-16 — cycle 39: the prep gap says what is coming

- Value: **warranted** — two defects, both about a Label's lifetime across two
  systems' timing, and the headless suite was green over both.
  - Expected: the wording is pure and already asserted headlessly; what runtime adds
    is whether the note ever actually reaches the row, since it shares that row with
    a message queue whose timing no test drives.
  - Got: it did not reach the row, and then it would not leave it.
    `get-state --node .../MessageLabel --property text` read empty in the prep gap;
    after the fix it read `Wave 1 next — 5 pests.`, and after the second fix it
    correctly went blank when the wave started and came back as
    `Wave 14 next — 29 pests · a queen.` ahead of a boss wave.
  - Found: two halves of one omission.
    1. **The note never survived.** `refresh()` is driven by state CHANGES and a
       message expiring is not one, so `_advance_message_queue` blanked the row
       seconds after the note was written and nothing put it back.
    2. **And it never came down.** Clearing the cached string when the wave starts is
       not enough, because nothing else rewrites that Label — so the note announcing
       a wave stayed on screen for the whole wave it was announcing.
    Together: the note needed writing AND unwriting, and only the writing existed.
    A test that asserts a pure formatter cannot see either.
  - Cheaper: nothing. The suite had no test that drove a message to expiry. It does
    now, written from what the running game showed rather than from what I imagined
    the failure would be.

- Gap: **no gaps this turn.** Worth recording what the runner did right: a parse error
  in the test file (a `var` declared inside one `if` block and read in the next, which
  GDScript scopes per-block) came back as `run_tests.gd itself reported exit 2` with
  `SCRIPT ERROR: Parse Error: Identifier "live" not declared` quoted and located. That
  is the failure mode `--filter` used to blame on the selector; the fix for [G-003] is
  visibly working, and this is the first time this project has hit it since.

## 2026-08-16 — cycle 40: one owner for the message row, and a last wave that says so

- Value: **overkill**, and worth writing down as such because the last three entries
  were `warranted` and a run of them is what makes this verdict go unwritten.
  - Expected: a refactor with no behaviour change, so the suite is the real check and
    runtime is confirmation. The new last-wave branch is the only thing with a claim
    runtime could settle, and only because the flag is derived from the table.
  - Got: exactly that. `547/547` before the refactor and `547/547` after was the whole
    proof that three writers collapsed into one painter without moving anything, and
    the launch confirmed one string:
    `Wave 16 next — the last one · 36 pests · a queen.`
  - Found: nothing. The suite caught nothing because there was nothing to catch, and
    the launch caught nothing because the headless assertions had already covered the
    branch against the real table.
  - Cheaper: the headless suite alone. It held the refactor to no behaviour change and
    asserted the new branch; the launch verified one sentence I could have read out of
    the test's own expectation.

- Gap: **no gaps this turn.** Two notes on things that worked rather than things that
  did not. `--snapshot-userstate` restored cleanly for the fourth consecutive session
  (md5 unchanged), and the suite's own before/after count is what made a pure refactor
  safe to do at all — `Total: 547` on both sides is a stronger statement than any
  assertion I could have written about the refactor specifically.

## 2026-08-16 — cycle 41: the message row joins the budget system

- Value: **warranted**, narrowly and for a reason worth naming — the finding is a
  measurement rather than a defect.
  - Expected: the budget is a claim about a running HUD (`Label.size.x` only exists
    once the bar has been laid out), so `cmd budgets` reporting it at all is the thing
    headless cannot settle.
  - Got: `hud_message_row: widest catalogue message 534 of 876 px max -- 342 px left`,
    `state: ok`, naming the exact string that would clip first — the Bomb Dandelion
    uproot line. And `"count": 7`, which the hand-written tripwire in
    `test_the_budgets_verb_reports_every_declared_coupling` had already caught at
    `Expected 6 but got 7`.
  - Found: **342px of slack, where I had assumed it was tight.** Two cycles of the top
    bar being full had me expecting the same here; a 55-character plant name did not
    clip, and it took roughly 85. The number is the finding — "roomy" is exactly what
    everyone assumed about the wave slot until it had 10px left, and the difference
    between the two is now written down rather than re-guessed.
  - Cheaper: the headless test carries the assertion and was planted and watched fail
    at `998px of 876`. The launch proves the budget is WIRED, which is a different
    claim: a budget declared and never reported is invisible everywhere, and that is
    precisely what the count tripwire exists to catch.

- Gap: **no gaps this turn.** One note on a test that behaved well: the budgets-count
  assertion is a hand-written list of seven names and adding a budget is SUPPOSED to
  break it. I nearly "fixed" that by deriving the list from the same table the verb
  reads — which would have made it tautological, the verb reporting what the verb
  reports. It is a tripwire in the other direction: a budget declared and never wired
  in is invisible, and one wired in that nobody meant to add shows up here as a number
  that moved.

## 2026-08-16 — cycle 42: the armed reset marks the rows it will take back

- Value: **warranted** — two findings, both invisible to a green suite, and the second
  one is a defect that predates this change by many cycles.
  - Expected: a colour-plus-mark cue is a visual claim. Whether the glyph renders at
    all, and whether it reads as distinct from the key names beside it, are both
    things only a picture settles.
  - Got: a picture settled both, and the first one against me.
  - Found: two.
    1. **The revert mark collided with a key NAME.** I chose "←" because it is proven
       in this font (`OverlayScreen.BACK_TEXT` is "← Back") and reads as "going back".
       `KeyBindings.SHORT_NAMES` renders `KEY_LEFT` as the same glyph — so the pager's
       own row is a key literally named "←", and a moved one would have read "← ←".
       Visible in the screenshot and in nothing else: the headless test asserts
       `KEY_REVERT_MARK` generically and passes whatever it is. Changed to a bullet,
       which is not a keycode string in any build, and confirmed by a second
       screenshot that it renders as a glyph rather than a `.notdef` box.
    2. **`findings` reported 12 `interactive_overlap` pairs**, and the overlap is a
       symptom rather than the defect. Measured with the Keys screen open:
       `Button_corn_cobbler` reads `focus_mode: 2`, `mouse_filter: 0`,
       `disabled: false`. The overlay's backdrop is a full-viewport
       MOUSE_FILTER_STOP ColorRect, so the mouse is blocked — and focus is a separate
       channel, which is exactly what `OverlayScreen`'s own header says
       `PauseScreen._set_card_active` exists for. That covers the pause card's own
       buttons; nothing covers the HUD, which is on a different CanvasLayer. **The
       defect did not change this cycle — only its visibility did.** At the previous
       panel width the overlap was ~6px and went unreported; widening it by 14px
       pushed it over. Filed as `plant-tower-defense-csrc` and deliberately NOT
       baselined, so it keeps gating until it is fixed.
  - Cheaper: nothing. The suite asserted the mark's presence and its width budget and
    was green through a glyph collision and a focus hole.

- Gap: **no gaps this turn.** Worth recording that `findings` earned its keep in the
  way it is designed to: I did not ask it about focus, or about overlays, or about the
  HUD. It reported a geometric fact I had made slightly worse, and the geometric fact
  turned out to be a symptom of something else entirely. That is the argument for a
  zero-config sweep that asserts things the project never asked it to.

## 2026-08-16 — cycle 43: the HUD goes inert behind an overlay

- Value: **warranted** — the fix is two properties on a live tree behind a live
  overlay, and the question that mattered could only be asked of the tool that
  raised it.
  - Expected: `findings` surfaced this defect, so the run's real question is whether
    `findings` goes clean once it is fixed.
  - Got: **it did not.** `Button_corn_cobbler` reads `focus_mode: 0`,
    `mouse_filter: 2` — genuinely unreachable — and all twelve `interactive_overlap`
    pairs still reported. The check treats a `Button` as interactive by CLASS; a
    control that cannot be focused and cannot be clicked is still counted.
  - Found: two.
    1. **The gap above.** The defect is fixed and proven; what remains is geometry
       that cannot matter. Baselined after reading all twelve — they are one class,
       every pair a now-inert HUD side-panel button against a Keys screen row button —
       and filed as [G-055] rather than left to gate forever on something correct.
    2. **This machine's plugin cache is 0.42.0 and this project runs 0.38.0.** It
       updated partway through the session. Four releases unused — and cycle 37's
       entire gap reconciliation was judged against 0.38.0, so every still-open
       `[G-NNN]` was assessed against a harness that is now stale. Filed as
       `plant-tower-defense-ny3h`, to be done as its own cycle.
  - Cheaper: nothing. Headless cannot produce a live overlay over a live HUD, and
    "does the sweep go clean" is not a question anything else can answer.

- Gap: **`interactive_overlap` counts controls that cannot be interacted with.** Two
  Buttons overlapping is only a defect if a player can reach both; one at
  `FOCUS_NONE` with `MOUSE_FILTER_IGNORE` can be reached by neither channel, and
  making a covered layer inert is the standard fix for exactly the hazard this check
  exists to find. So the check currently fires hardest at projects that have already
  fixed the problem, and the only way to quiet it is a baseline — which then also
  hides a REAL overlap arriving later at the same node pair.
  - [G-055] status: open | seen: 1 | harness: 0.38.0 | filed upstream: gh#42
  - Improvement: skip a Control whose `focus_mode == FOCUS_NONE` **and** whose
    `mouse_filter == MOUSE_FILTER_IGNORE` when pairing for `interactive_overlap`, and
    say so in the finding's own text for the ones it does report ("both reachable").
    That turns "these overlap" into "these overlap and both can be used", which is
    the claim the check is actually making. Cheap: both properties are already read
    by `reachable-ui`.

## 2026-08-16 — cycle 44: the 0.42.0 refresh, attempted and reverted

- Value: **warranted**, and by the cheapest possible mechanism — a number taken before
  the change and the same number taken after.
  - Expected: a routine version bump. Four releases of fixes, three of them mine, and
    the refresh is documented as idempotent.
  - Got: the install was flawless — `[version] upgrade 0.38.0 -> 0.42.0`, no `.bak`
    (nothing was locally edited), every `.uid` already present, every project-owned
    config key kept, and all nine project-authored tools under `tools/` untouched.
    Then the suite **segfaulted**: exit `3221225477` (`0xC0000005`), three runs out of
    three, always at `test_corn_shoots_the_pest_closest_to_escaping`, preceded by
    `Attempted to set an invalid (previously freed?) object instance into a
    'TypedArray'`.
  - Found: **a harness regression, proven rather than suspected.** `git stash` the
    refresh → `552/552`; pop it → segfault; `git checkout -- .` → `552/552` again.
    Identical project code on both sides. Filed as gh#43 with the bisect. Reverted to
    0.38.0, because a harness that crashes the suite cannot be the thing gating the
    work.
  - Cheaper: nothing, and this is the strongest case for the before-measurement I
    have hit. Without `552/552, 12142 assertions` written down *before* the install,
    the crash reads as "the refresh broke my game" and the next hour goes into
    `plant.gd`. It took two commands to prove it was the harness.

- Gap: **no new gap in this project's usage**, and one filed upstream. Worth recording
  what the refresh got RIGHT, because it is easy to remember only the crash: the
  version guard, the pristine-file detection, the `.uid` handling and the config
  ownership tracking all did exactly what their documentation says, on a real project
  with four releases of drift and nine foreign files in `tools/`. The failure is in
  the shipped runner, not in the installer.
  - Also worth noting: **the skill loaded from a plugin cache pinned at 0.33.0** while
    the project runs 0.38.0 and the newest cache is 0.42.0. Running `full` from the
    skill's own interpolated paths would have DOWNGRADED five versions. The installer
    refuses that (exit 2) and the skill documents `--plugin-root` for exactly this, so
    the guard held — but the skill's every path still points at whatever version the
    cache happens to be pinned to, which is the same trap logged long ago and is why
    this ran `0.42.0/tools/scaffold_install.py` explicitly.

## 2026-08-16 — cycle 45: a test that had never checked its own rule

- Value: **warranted**, and by a headless assertion rather than by the bridge — the
  finding came from adding one liveness check to a test that had been green for many
  cycles.
  - Expected: guard `_furthest_along_in_range` against a stale pest (the reference the
    0.42.0 crash dereferenced), and audit the tests that name nodes after an `await`.
    A tidy-up.
  - Got: the guard is right and small. The audit found the real thing, and it was not
    about 0.42.0 at all: the same test **fails its new liveness assertion on 0.38.0**,
    where the whole suite is green. `far._leg = 4` on a five-point route is the last
    leg, so the pest escaped and freed itself during the settle frames
    `instantiate_scene` pumps. `assert_true(target == far)` then compared two
    references to the same freed object and passed.
  - Found: **a test that had never once checked the rule it is named for.**
    `test_corn_shoots_the_pest_closest_to_escaping` measured a candidate set with one
    live member in it. Fixed by putting the pest on the last leg it can survive on
    (`_leg = 3`), and proven by planting a nearest-target implementation and watching
    it fail with real numbers — `targets the pest at progress 0.75, not the closer one
    at 0.25`. That failure was unreachable before.
  - Cheaper: nothing cheaper, and nothing else would have found it. `settle_read_check.py`
    reports 0 findings here — its vocabulary is settle-volatile *values*, and this is a
    settle-volatile *reference*, which is a different class.

- Gap: **no gaps this turn.** One decision recorded instead. Nine tests in this project
  create a self-freeing mover and name it after an `await`; exactly one put its mover
  near the end of its life, and the other eight start at leg 0 where two settle frames
  cannot reach the end. **A checker for this would fire nine times for one real
  defect**, which is the ratio that teaches people to waive a gate — so the rule went
  into `.claude/skills/godot-test-isolation` as a question to ask ("does this test put
  its mover near the end of its life?") rather than into `tools/` as a check. Deciding
  *not* to build a checker is a legitimate outcome of an audit and is worth writing
  down, because the alternative leaves the same audit to be re-run later by someone who
  assumes it was never done.

## 2026-08-16 — cycle 46: the bed an armed uproot will remove says so

- Value: **warranted**, on one question the suite structurally cannot ask.
  - Expected: a two-channel visual cue is a claim about pixels — whether heavier
    brackets read as heavier at 64px, and whether the RIGHT marker changed, since a
    running tree holds two `SelectionMarker`s (the bed's and the placement preview's).
  - Got: `find-nodes --class SelectionMarker --property marker_color --property
    line_width` answered both at once — the bed's went
    `(1.0, 0.95, 0.35) @ 2.0` → `(0.85, 0.25, 0.22) @ 4.0` and the preview's did not
    move. The screenshot then showed heavy red brackets with `_uproot_left: 3.97`.
  - Found: nothing in the code, and **the same procedural mistake as cycle 38**. The
    first screenshot showed a yellow marker and I was a step from filing it: the
    four-second confirm window had **lapsed** between the arm call and the capture
    (`_uproot_left: 0.0`), and `_disarm_uproot` had correctly restored both channels.
    The picture was right and the capture was late. `set_game_speed 0.05` and
    re-capture showed it properly.
  - Cheaper: the headless test carries both channels and the restore. The launch
    earned its place on the two-markers question — an assertion in a hosted test sees
    one marker and cannot tell you the other one stayed put.

- Gap: **no gaps this turn.** Worth recording what `find-nodes` did well, because it is
  the verb that made this cheap: `--class SelectionMarker --property marker_color
  --property line_width` returned both instances with both values in one call, which
  is exactly the "did the right one change" question. The obvious alternative — a
  `get-state` on a path — would have required knowing the auto-generated node name
  `@Node2D@129/SelectionMarker`, and would have answered about one marker only.
  - Related, and fixed rather than filed: the marker was auto-named, so it had no
    addressable path at all. It is `SelectionMarker.NODE_NAME` now, for the reason this
    project already states about `Backdrop`/`RowButton%d` — node paths are a contract,
    and `@SelectionMarker@31` is not one.

## 2026-08-16 — cycle 47: arm_uproot and commit_uproot

- Value: **overkill**, and that is the honest verdict after three `warranted` cycles.
  - Expected: a pure rename, so the suite count on both sides is the real proof.
    Runtime would only confirm that the two names do what they say.
  - Got: exactly that. `553/553` before and `553/553` after, and live —
    `arm_uproot` → `confirm needed` with `"plants": 1`, `commit_uproot` → `""` with
    `"plants": 0`.
  - Found: **a stale doc claim, twice, and I re-committed it before checking.** Both
    headers said the unguarded mutator is called by "the devtools verbs and the
    placement tests". There is no devtools verb — `list-commands` has nothing matching
    `uproot`, and `devtools_ext/commands.gd` never mentions it. I rewrote one of those
    headers during the rename and preserved the false half. Corrected in both places;
    the file's other three "devtools verbs" claims were checked and are true
    (`collect_husk`, `place_plant`, `start_wave` all exist).
  - Cheaper: the suite alone. The launch confirmed two return values that the tests
    already assert.

- Gap: **no gaps this turn.** One note on `list-commands --offline`, which is what made
  the stale claim cheap to disprove: it parses the registration sites statically with no
  game running, so "does a verb by this name exist" costs nothing and needs no launch.
  That is the right tool for auditing a comment that claims a verb, and it is not
  obvious from the verb table in `CLAUDE.md`, which describes `list-commands` as a
  discovery aid for a running session.

## 2026-08-16 — Drought pays 150% on seeds, and the prep note says so

- Value: **warranted** — runtime produced two claims the diff could not, and one of them
  corrected a budget I wrote myself seven cycles ago.
  - Expected: `weather_seed_value(4)` returns 6 under drought and 4 under clear, and the
    prep note carries the new clause. I expected the suite to cover both.
  - Got: both, live — and `cmd budgets` reported `widest catalogue message 570 of 876 px
    max -- 306 px left`. That 570 is the **prep note**, not a plant name. My cycle-41
    budget `_budget_hud_message_row` measured only the four plant-name messages (534px)
    and never the note, which is now the widest thing that row ever holds. A budget with
    the wrong corpus is a budget that reports green while the real widest string grows
    unwatched.
  - Found: **that gap in my own budget, and very nearly a defect filed against working
    code.** Reading `MessageLabel.text` returned empty three times running while
    `_idle_message` held the correct note. That is not a bug: `_paint_message_row` gives
    a transient message precedence over the standing note, and `_message_left` was
    `0.43`. `pause` first, then `_advance_message_queue`, and the row reads
    `Wave 7 next — 19 pests · drought · pests pay 150%.` deterministically. Third time
    this session a state variable told the truth a screen read did not.
  - Cheaper: nothing. The suite asserts the multiplier and the note's text, but the
    budget corpus error only surfaces from `cmd budgets` against a running HUD, and the
    precedence question needed the live message queue.

- Gap: **nothing documents `pause` as the tool for a deterministic property read.** The
  verb table sells it as "sets `SceneTree.paused` directly, bus keeps answering — catch a
  sub-second effect", and `ping`'s note frames the answering-while-paused property as
  *pause menus are verifiable*. Both are true and neither says the thing that cost me
  three reads: **a property a `_process` timer mutates cannot be read reliably without
  freezing the tree first.** I read an empty Label three times and had no way to tell "the
  row is blank" from "something else is holding the row right now", because a single read
  of a moving value carries no evidence that it was moving.
  - [G-056] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#44 (finding 2)
  - Note: re-checked against 0.42.0 before filing and NARROWED. 0.42.0 does state
    the idea for `step-time --then-pause` ("so the read that follows carries no
    ambient drift") -- attached to stepping, not stated as a general rule about
    reading. Filing the un-narrowed version would have been a false alarm.

- Gap: **`verify_ledger.py record` reports a post-commit row as "a real zero".**
  Recorded this cycle's row after committing and got `reached 0/0 changed file(s) -
  a real zero: every changed file is excused from the denominator`. reach is the
  diff intersected against what the game loaded, so after a commit it is empty by
  construction -- and the tool asserts the benign reading of an ambiguity it cannot
  resolve. "Nothing was in scope" and "the evidence was committed away" are opposite
  claims and the row cannot be told apart afterwards.
  - [G-057] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#44 (finding 1)
  - Improvement: when the reach denominator is 0, check whether the working tree is
    clean while HEAD just touched the run's files, and say so instead of glossing it.
    Failing that, write `reach: null` with a reason -- honest beats reassuring.
  - Improvement: one line in the Gotchas list — `**A single read of a timer-driven
    property is not a measurement.** Anything a `_process`/`_physics_process` timer
    mutates should be read after `pause` (the bus answers while paused), or with
    `step-time --then-pause`. An unexpected value read live is ambiguous between "wrong"
    and "mid-transition", and the read itself cannot tell you which.` It belongs beside
    the existing "A run that never changes is broken, not passing" entry, which is the
    same lesson pointing the other way.

## 2026-08-16 — Cycle 49: verify-bd-item skill, and mirror_check --fix

- Value: **overkill — avoided.** Triaged out at Phase 0.5 tier (a): the whole cycle
  touched `.claude/skills/`, `tools/mirror_check.py`, `CLAUDE.md`, `AGENTS.md` and
  `kanban.md`. Nothing Godot loads, so no game was launched and no ledger row was
  written. Recording this because a cycle with no harness entry is indistinguishable
  from a cycle where the entry was forgotten, and that ambiguity is the reason this
  log requires an entry either way.
  - Expected: nothing from runtime. A static checker is verified by its fixture and by
    mutating the checker, not by a running game.
  - Got: exactly that. The fixture went green, then six mutations of `mirror_check.py`
    each went red for the right reason, and two of them only went red after two more
    fixture cases were added — which is the finding, see below.
  - Found: **a defect in `mirror_check.py` that predates this change and had nothing to
    do with it.** `ENDS` carried `\n---\n`, and a horizontal rule is ordinary markdown,
    so a `---` inside the Workflow block ended the block early in BOTH files: two
    21-character stubs compared identical and the tool reported clean over a comparison
    covering a fraction of the text. That is the empty-denominator failure the house
    checker contract exists to prevent, sitting inside the checker that enforces it.
    The fixture case that found it was written expecting to test something else.
  - Cheaper: nothing cheaper would have found it. Reading the diff shows `--fix` working;
    only feeding the tool a block containing `---` shows the tool measuring a stub.

- Gap: **no gaps this turn** — the harness was not run, so it had no opportunity to have
  one. One note that belongs in the project log rather than here: two of the four
  mutations in the first sweep reported `MUTATION TEXT NOT FOUND` because a shell
  heredoc ate a backslash level, which reads exactly like "this code is not present" and
  would have been recorded as "the mutation survived" by a less suspicious sweep. A
  mutation harness needs to distinguish *did not apply* from *applied and survived*;
  mine printed them differently only because I happened to assert the needle was found.

## 2026-08-17 — Cycle 50: checker audit, and proving the facing request already shipped

- Value: **warranted** — the runtime pass produced a claim about the LEVEL that no
  amount of reading `pest.gd` could have produced.
  - Expected: to confirm or refute "enemy facing is broken" — a direct user request —
    and I expected to find the code correct and the art wrong, since that is where a
    facing bug usually lives when the rotation maths reads fine.
  - Got: both correct. All four cardinals read back live off a running game (`+X` →
    1.5707963267949, `+Y` → 3.14159265358979, `-X` → -1.5707963267949, `-Y` → 0.0), and
    all three pest SVGs rest head-up-screen, matching `art_src/STYLE.md:14`.
  - Found: **the road never travels -Y.** Reading a pest's `_route` off the live tree
    gave thirty-four points running right, down, left, down, right — not one -Y step. So
    `_update_facing`'s `_facing = 0.0` branch has never executed in a real game, and
    `Vector2.UP` appeared in no test either. Three of the four cardinals were covered by
    accident (`+X` in the gait test, `-X` via the corpse test, `+Y` used without its
    value being asserted) and the fourth by nothing at all. That is a property of the
    shipped level, not of the diff, and only the running game holds it.
    Also found, and worse: **my first mutation sweep was vacuous.** `run_tests.py` takes
    `--filter` only after `--`; without it argparse exits 2 and all three mutations read
    as "RED" having never run a test. Caught only because the RESTORE run also came back
    non-zero, which it had no business doing.
  - Cheaper: nothing. `--offline` static reads answer "does this verb exist"; they cannot
    answer "does any leg of this road point up".

- Gap: **no gaps this turn** — and one note worth recording in the harness's favour,
  because the thing that saved me was the harness's own contract. Exit codes here are
  `0` pass / `1` findings / `2` the runner could not run, and my sweep's bug was
  collapsing 1 and 2 into "non-zero, therefore killed". Redone as a three-way verdict —
  `RED (killed)` on 1, `SURVIVED` on 0, `BROKEN RUN - proves nothing` on 2 — every
  mutation came back exit 1 with a real `Failed: 2 / 1 / 2` and `Selected: 3 of 555`
  beside it. **A mutation harness that reads only truthiness cannot tell a killed test
  from a test that never ran**, which is the same shape as `[G-056]`: an unexpected
  result that is ambiguous between two opposite meanings, where the result itself
  carries no way to tell. The denominator (`Selected: 3 of 555`) is what settles it, and
  it was printed all along.

## 2026-08-17 — Cycle 51: scope-vs-claim, and the budget it immediately caught

- Value: **warranted** — the runtime run produced the one claim the diff could not: that
  the widened sweep actually reaches its new producers.
  - Expected: `cmd budgets` to report a LARGER `hud_message_row` number once three more
    `show_message()` producers were swept.
  - Got: **the number did not move.** 570 of 876 px, unchanged, because the prep note is
    still the widest thing on that row. Which means the diff alone could not distinguish
    "the new producers are swept and are narrower" from "the new producers are silently
    not swept at all" — the whole point of the change, invisible in its own result.
    Settled by mutating `wave_cleared_note` to an enormous string and re-reading:
    `spent 570 -> 1065`, `state ok -> spent`. Restored: 570, `ok`.
  - Found: the budget was still missing **five of eight** `show_message()` producers a
    full cycle after I "fixed" it — last cycle's fix added exactly the one I happened to
    be looking at. Also that `WORST_CASE_TEXT` was asserted in one direction only, and
    that `stats_row_budget()` holds a *second* hand-list of the same four readouts.
  - Cheaper: nothing for the reach question. The enumeration of call sites was static and
    cheap; proving the sweep reaches them needed the running game.

- Gap: **`verify_ledger record` silently discards unrecognised keys in `run.json`, then
  reports the discarded evidence as missing.** I passed Phase 4 evidence under `phase4`
  (with `check`/`result` entries). `record` accepted it without a word, wrote the row with
  `checks: []`, and printed:

  ```
  verify_ledger: warranted with no Phase 4 checks recorded - the claim that earned it is
  not in the row
  ```

  Both halves of the information were present in the same invocation and never met. `tier`,
  `phases` and `notes` were dropped the same way. The warning is good and it is what made
  me look; what it cannot do is say *you supplied this under the wrong name*.
  - [G-058] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#46
  - Process note, recorded because it nearly cost something: I wrote the issue's
    Environment line claiming the code was unchanged at 0.42.0 BEFORE checking it,
    then checked. It holds (`checks = run.get("checks") or []` at 0.42.0:1031, and
    no unknown-key handling anywhere in that file). But the order was wrong, and
    the whole reason skill-feedback-issue demands a re-check is that a stale claim
    in a public issue is the most common way this loop wastes a maintainer's time.
  - Improvement: on unknown top-level keys, name them and suggest the nearest known one —
    `run.json: ignoring unknown key 'phase4' (did you mean 'checks'?)`. The known-key set
    is already in the code that normalises the row; this is a set difference and a
    `difflib.get_close_matches` call. Silent key-dropping in a file whose entire purpose
    is to be a record is the same class as the `reach 0/0` gloss in gh#44: the tool has
    the information needed to be unambiguous and states the convenient reading instead.

## 2026-08-17 — Cycle 52: one corpus for the message row, and a checker to keep it

- Value: **warranted** — and the reason is worth stating precisely, because the headline
  number did not move.
  - Expected: `cmd budgets` to report a larger `hud_message_row` once five previously
    unswept literals joined the corpus.
  - Got: **570 of 876 px, unchanged.** The prep note still wins at 79 characters against
    the opening hint's 68. That result is *identical* to what a completely broken sweep
    produces, which is the second cycle running that a budget fix has been unfalsifiable
    from its own output. Settled by mutating a corpus literal to an enormous string:
    `spent 570 -> 1068`, `state ok -> spent`, restored to 570/`ok`.
  - Found: four things, three of them in my own work.
    * There are **fourteen** `show_message()` call sites; my cycle-51 comment said eight.
    * `message_corpus_check.py` shipped two bugs the fixture caught in minutes — corpus
      literals read from the blanked source (`1 literal(s)` for a corpus of five), and an
      argument span taken from raw text so a comma *inside* a literal split it.
    * The new corpus test caught my own miscount on its first run: 8 non-catalogue
      entries, not 7.
    * `test_no_message_clips_for_any_plant_in_the_catalogue`'s header claimed "every other
      line the row shows is a fixed literal". False, and precisely the sentence that made
      three cycles of budget work look finished.
  - Cheaper: for the enumeration, yes — and that is now the checker's job rather than a
    person's. For "is the corpus actually swept", nothing cheaper than the mutated build.

- Gap: **`[G-058]` again, from the other side — `verify_ledger record` DOES validate some
  fields and not others, and the inconsistency is the surprise.** Passing
  `found[].phase: "static"` produced:

  ```
  verify_ledger: `found` phase 'static' is not one of import, lint, tests, runtime,
  other - recorded as null
  ```

  which is exactly the right behaviour: it names the field, lists the legal values, and
  says what it did. Last cycle the same tool dropped four unknown *top-level* keys in
  silence. So the machinery for saying "I did not understand this" already exists in the
  file — it is applied to enum values and not to key names.
  - [G-058] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#46
  - Improvement: unchanged, and now cheaper to argue for — reuse the `found[].phase`
    warning's own shape for unknown top-level keys. The `checks` key worked this cycle
    and the row carries its four Phase 4 entries, so the fix is narrow.

## 2026-08-17 — Cycle 53: the road climbs

- Value: **warranted** — and unusually, the static work and the runtime work each caught
  something the other could not.
  - Expected: the reshape to hold its two invariants (32 cells, 2112 px) and break only
    shape-dependent tests. Predicted before touching the file, by scripting the route.
  - Got: exactly that. `test_the_road_is_still_the_road_the_constants_were_measured_against`
    passed untouched — the guard that exists to fire on a road change did not fire, because
    the change was designed around it. Five shape-dependent tests failed, which is the set
    the same file's header predicts by name.
  - Found: three things the diff could not have shown.
    * `_mixed_garden`'s `Vector2i(10, 3)` sits on the NEW road, so that placement would
      have failed and quietly made a six-plant garden into five.
    * Six cobs cover all 32 road cells and still let one escape in thirty-four cross
      unfought — **coverage is not engagement**, because a cob shoots only the
      furthest-along pest in range. The seventh cob is for overlap, not reach.
    * `(2, 3)` stopped being a cell that is dead for a Chomp and good for a Corn: the new
      route runs up column 2, putting road at `(2, 4)` directly under it.
  - Cheaper: for the invariants, a 20-line script, and that is what was used — the numbers
    were checked before the file was edited rather than after the suite complained. For
    "does a pest render upright while climbing", nothing. That is the whole change.

- Gap: **no gaps this turn.** One note in the harness's favour: polling `find-nodes
  --class Pest --property _facing` for a `0.0` and then calling `pause` the moment it
  appeared is what caught a pest mid-climb — a sub-second state on a four-cell leg. The
  verb table advertises exactly this ("catch a sub-second effect, poll for the moment,
  pause, then inspect at no rush") and it worked first try, three polls in.

## 2026-08-17 — Cycle 54: derive the rules, record the taste calls

- Value: **warranted**, on the strength of one finding that reversed the design.
  - Expected: to derive all three garden lists and both counts, making a road change a
    pure data change. That was the plan written into the bead.
  - Got: the derivation works and is *better* — greedy set cover finds five cobs reaching
    all 32 road cells where seven are recorded — and it **broke two tests**. Those gardens
    encode calibrated FIREPOWER, not coverage: a cob shoots only the furthest-along pest
    in range, so a minimal cover is a weaker garden than a redundant one over the same
    cells. `derive-the-list` says stop when membership is a taste call, and seven cobs is
    one.
  - Found: **a heredoc ate the leading `#` from four comment lines**, `test_placement.gd`
    failed to compile, and the suite printed
    `Total: 490 | Passed: 490 | Failed: 0 | ALL TESTS PASSED`. Sixty-seven tests silently
    absent, reported as a clean run. Caught by the two things the harness prints for
    exactly this: the denominator (490 against 557) and exit `2`.
  - Cheaper: reading the diff would have shown the derivation. It would not have shown
    that the derived garden is a better cover and a weaker garden, which is the whole
    finding — that needed the suite.

- Gap: **no gaps this turn**, and a note in the harness's favour that is worth writing
  down properly, because it is the second time this session the same pair has saved a
  run. `Total: N | Passed: N | Failed: 0` is not a pass on its own. The `Total:` is a
  **denominator** and exit `2` means *the runner could not run*, not *the code is clean* —
  and a script that fails to compile takes its whole file out of the count while leaving
  the surviving tests reporting green. The docs say both of these plainly ("Read the
  denominators, not just the exit code"; "a `2` means you verified nothing"). They were
  right and they were what caught it.

## 2026-08-17 — Cycle 55: dots for the road a purchase newly defends

- Value: **warranted**, and specifically for the screenshot rather than the numbers.
  - Expected: the predicate to work (it is unit-tested and three mutations kill it) and
    the dots to appear over the road inside the ring.
  - Got: **an empty screenshot, for a correct reason.** My first live hover was `(6, 2)`,
    which is road — `_draw()` returns before the dots on an unplaceable cell. Nothing was
    wrong with the drawing; the check was aimed at a cell the cue deliberately says
    nothing about.
  - Found: that near-miss surfaced a real inconsistency worth fixing. `new_cover_cells()`
    answered with cells for an unplaceable hover while `_draw()` skipped it, so the
    predicate and the picture disagreed. It now checks `placeable` exactly as
    `shows_dead_zone()` does, with a test. Also found the same file's header still
    quoting the pre-reshape dead-ground figures (15 and 34, against 11 and 36 since
    cycle 53).
  - Cheaper: nothing. The unit test passes on a buildable cell and would never have
    exercised the road-hover case, because the test picks the cell.

- Gap: **no gaps this turn.** One workflow note that is mine rather than the harness's:
  the game kept playing while I read code between commands, and by the time I took the
  second screenshot the run had ended and the board was replaced by the summary screen.
  `pause` immediately after `launch` — which `read-a-moving-value` already says — is what
  fixed it, and it is worth remembering that the rule applies to *the session*, not just
  to individual reads. A game left running is a moving value the size of the whole board.

## 2026-08-17 — Cycle 56: rings for what a selected plant alone holds

- Value: **warranted** — the runtime run carried the claim the unit test structurally
  cannot.
  - Expected: the rings to appear on the cells `sole_cover_cells()` returns, and to thin
    when a second plant overlaps.
  - Got: both, and the second one sharply. A lone cob at `(8, 5)` rings eight cells;
    planting a second at `(8, 6)` drops the first to **zero** with nothing clicked. The
    unit test proves the set arithmetic; only the running game proves the push path in
    `_refresh()` reaches the node, and "the rings thin without the player touching
    anything" is the entire feature.
  - Found: nothing broken — the suite caught the one thing that was missing before I
    could, refusing the new `SoleCoverMarks` class until a test named it. That is
    `test_every_game_class_is_at_least_named_somewhere_in_the_test_suite` doing precisely
    its job, and it fired within seconds of the class existing.
  - Cheaper: for the arithmetic, yes, and it is unit-tested. For the push path, nothing.

- Gap: **no gaps this turn.** Worth recording what went right instead, because it is the
  second cycle running that the same habit paid: `pause` immediately after `launch`, then
  `place_plant`, then read — the cue was inspected on a board that was not moving, and the
  8-to-0 result is trustworthy because nothing else could have changed between the two
  reads. Cycle 55 lost a screenshot to a run that ended while I read code; this cycle cost
  one extra command and lost nothing.

## 2026-08-17 — Cycle 57: an empty answer that looks like an answer

- Value: **warranted**, and the run's most useful output was a measurement that killed the
  planned design before it was written.
  - Expected: to add a line to the selection panel saying "nothing depends on this one".
  - Got: the panel cannot take one. `_selection_label` autowraps with a 56 px minimum
    inside a 152 px box, `hud.gd` records that a third line once pushed SelectionBox's foot
    to exactly the panel's own 648 and was caught by the clearance gate, and its VBox
    comment says the stack already runs to within 16 px of the panel foot. The cob's second
    line measures ~190 px of a 232 px box, so any suffix wraps. **The bead's design would
    have reproduced a failure the file already documents.**
  - Found: nothing broken; the finding was the constraint itself, and it was found by
    reading the file the change would touch rather than by running into the clearance gate
    afterwards. The cue moved into the world instead — a dashed ring on the plant — which
    costs no layout at all.
  - Cheaper: for the constraint, reading `hud.gd` was the cheap path and it worked. For
    "does a dashed ring at 31 px read as a separate statement or as a fatter bracket",
    nothing but a screenshot.

- Gap: **no gaps this turn.** Worth noting what carried the cycle instead: two comments in
  `hud.gd` — the third-line failure and the 16 px VBox remark — were written by whoever hit
  those limits, at the line they constrain, and between them they settled the design in
  about two minutes. That is the same property `scope-vs-claim` argues for from the other
  direction, and it is the second cycle running that the codebase's own prose has been the
  decisive input rather than any tool.

## 2026-08-17 — Cycle 58: the rings change tense when an uproot is armed

- Value: **warranted** — though the sharpest thing this run produced came from the suite,
  not the bridge.
  - Expected: `arm_uproot` to flip the rings red, and the screenshot to show the cells that
    go bare.
  - Got: both. `arm_uproot` returns `confirm needed`, `SoleCoverMarks.warning` reads true,
    and eight thick red rings sit on the road the cob alone holds.
  - Found: **the suite refused to pass and was right twice over.** The new test covers two
    symbols that were sitting on the reach debt baseline, so `suite_reach` demanded a
    re-bank — and in the same breath reported **1 NEW** uncovered symbol. Re-banking
    blindly, which is the obvious response to "PROGRESS: re-run --baseline-write", would
    have buried a regression under an improvement. The NEW one was
    `SoleCoverMarks.set_warning`, reached only indirectly through `set_uproot_armed`; it
    now has a direct test, which also covers the idempotence its header claims and the
    indirect route never exercises.
  - Cheaper: for the predicates, yes — they are unit-tested and five mutations kill them.
    For "do eight thick red rings read as the consequence of a pending action", nothing.

- Gap: **no gaps this turn**, and a note about a good tool behaviour worth not losing.
  `suite_reach_check`'s PROGRESS line and its NEW count are printed *together*, which is
  what made the trap visible. A tool that had only said "you improved, re-bank" would have
  been actively harmful here. That is the same shape as the denominator rule this project
  keeps relearning: **an improvement and a regression reported in the same breath are
  legible; either one alone is not.**

## 2026-08-17 — Cycle 59: the armed window becomes a move preview

- Value: **warranted** — and the finding came from the mutation sweep rather than from
  either the suite or the bridge.
  - Expected: hovering during an armed uproot to preview the moved plant, and the
    screenshot to show cost and gain together.
  - Got: both. `reach: 176.0`, `plant_id: corn_cobbler` while armed, and one screenshot
    carrying red rings on what the move costs and green dots on what it buys.
  - Found: **a mutation SURVIVED, and that was the result.** The arming guard read
    `_uproot_armed if _uproot_left > 0.0`, and nothing could kill the second half —
    `_disarm_uproot()` nulls the first on every exit path there is. A condition that can
    never disagree is dead code wearing a safety belt, which this repo has paid for before
    in `mirror_check`'s CRLF normalisation. Removed; the invariant it stood in for is a
    test now, driving expiry directly rather than sleeping four seconds. Re-run: five
    mutations, no survivors.
    Also found by writing that test: **an expired uproot window CANCELS rather than
    uprooting**, which I had assumed the other way and which failed loudly on
    "something is already growing there".
  - Cheaper: for the values, the suite. For "can the player see the cost and the gain at
    once", nothing but the screenshot — that is one claim about one screen.

- Gap: **no gaps this turn**, and `settle_read_check` earned a specific mention. It caught
  the new test reading `_uproot_left` as an accumulator after `instantiate_scene`. The read
  is genuinely deterministic — the test writes the value via `arm_uproot()` and spends it
  via a tick it drives itself — so the right answer was a waiver with that reason rather
  than a restructure. Writing the waiver was worth more than the check: it made me state
  *why* the assertion is separate from the `_uproot_armed` one, which is that
  `_disarm_uproot` clears the reference AND the clock, and a version clearing only the
  reference would leave a dead timer running under the next selection. **A waiver that has
  to explain itself is a second chance to notice what the assertion is for.**

## 2026-08-17 — Cycle 60: pointing the armed prompt at the move preview

- Value: **warranted**, and specifically for the budget verb — the code change was one
  line and the interesting output was a number.
  - Expected: to append a tip to the armed message and confirm it does not clip.
  - Got: it does not clip, and `cmd budgets` said what the suite could not — the message
    row went **570 → 784 px of 876** and flipped to state `tight`. The first wording spent
    214 of the 306 px available. Shortening the tip brought it to 755, leaving 121 against
    a declared floor of 40.
  - Found: that measurement, which changed the shape of the work. It passes, so shipping it
    was right — but 185 px of permanent headroom spent on a lesson taught once is a poor
    trade, and it is now the argument for a one-shot hint rather than a vague "would be
    nicer". `RunConfig`'s milestone set is already a persisted seen-once mechanism, so that
    follow-up needs no save-version bump.
  - Cheaper: for "does it clip", the suite already answers. For "what did it cost",
    nothing — that number exists only against a running HUD.

- Gap: **no gaps this turn**, and one self-inflicted false alarm worth writing down because
  the skill had already called it. `findings` reported **4 NEW `ui_transparent`** findings
  at alpha 0.00 on the selection panel and exited 1. Cause: my own `pause`, freezing the
  panel's entrance tween mid-fade. `read-a-moving-value` says exactly this — *"a paused
  tree … here the freeze is the CAUSE of the bad read, not the fix"* — and I still spent a
  check confirming it rather than recognising it. That is the correct order and I would do
  it again; the note is that **`pause` is a tool and a hazard in the same command**, and a
  gating check run against a frozen tree needs the same suspicion as any other single read.

## 2026-08-17 — Cycle 61: the move tip, shown once

- Value: **warranted** — the runtime reading corrected a criterion I had written myself.
  - Expected: `cmd budgets` to fall from 755 px back to roughly 570 once the tip stopped
    appearing on every uproot. That was the bead's acceptance, in my own words.
  - Got: **755, state `tight`, unchanged — and correctly so.** The corpus now prices BOTH
    forms of the prompt, and the tip form is still the widest thing the row can ever hold.
    A budget measures the worst case the FORMAT allows, not the common case. The one-shot
    changes frequency, not the ceiling.
  - Found: that, which is the whole entry. The change is still right, for a better-stated
    reason — a hint shown once is more likely to be read than one that has become
    wallpaper — but "we get 185 px back" was never true, and shipping that claim would have
    made the next budget reading confusing for whoever took it.
    Also found: a **surviving mutation where the test was at fault**. Replacing the warning
    with the tip rather than joining them went unnoticed, because I asserted the warning
    only on the second arm — where `with_tip` is false and it is present however the tip is
    composed. It proved nothing about the case my own docstring claimed to guard.
  - Cheaper: for the one-shot logic, the suite. For the budget correction, nothing — that
    number exists only against a running HUD.

- Gap: **no gaps this turn**, and cycle 60's new workflow rule paid immediately: `findings`
  ran before quitting, came back **0 across 4 of 5 checks with 0 NEW**, and confirmed the
  UI baseline is genuinely empty rather than merely absent this run. One cycle after adding
  "run the broad check", it is already the thing that turns "I did not see a problem" into
  "the checklist found none".

## 2026-08-17 — Cycle 62: pricing a producer's variants

- Value: **overkill**, by the ledger's own definition, and recorded as such because that is
  the entry that goes unwritten.
  - Expected: nothing from runtime. This was a static checker; no game was launched.
  - Got: nothing from runtime, correctly. The whole verification was a 7-case fixture and
    a 5-mutation sweep, which is what `house-static-checker` says a checker's verification
    IS.
  - Found: the new rule found a live instance on its first run — `next_wave_note` takes two
    bools and the corpus priced one of four combinations. Waived after **reading the body**
    rather than assuming: both flags only ever `parts.append()`, so `(true, true)` strictly
    dominates. Also found that my own waiver was not detected, because I wrote the reason in
    the comment block above the call and the checker only read the call's own line.
  - Cheaper: nothing cheaper than the fixture, and the fixture was the method.

- Gap: **no gaps this turn.** One observation about the harness's *contract* rather than a
  hole in it: the `overkill` verdict exists precisely for a cycle like this, and it took a
  deliberate decision not to launch the game "just to have a runtime row". A run that adds
  nothing is not evidence, and the ledger is more useful for containing the honest zero.
  Sixty-two cycles in, the `value` field's four options have all been used and the one that
  keeps the record trustworthy is this one.

## 2026-08-17 — Cycle 63: the third direction on the corpus

- Value: **overkill**, deliberately and for the second cycle running. No game was launched
  and none was needed; a static checker's verification is its fixture and its mutation
  sweep.
  - Expected: the new rule to be clean on this repo, because a quick `grep -c` comparison
    of corpus producers against their callers said all seven were live before I wrote a
    line.
  - Got: exactly that — `0 dead producer(s)`. A rule that finds nothing on the day it is
    written is the normal case for a drift guard, and saying so is more useful than
    hunting for an instance to justify it.
  - Found: **two defects, both in my own work, both from the fixture.** The rule printed a
    `waive:` hint and ignored waivers entirely, because the lookup lived inside the other
    rule's loop — caught by fixture case 4. And adding the rule broke the two OLDER
    fixtures, correctly: their stub HUDs declare producers with no callers, so the new rule
    fired on them. Isolated by giving each stub an internal caller.
  - Cheaper: nothing. The fixture was the method and it earned its cost twice over.

- Gap: **no gaps this turn.** A note on fixture hygiene that this cycle paid for: **adding
  a rule to an existing checker can break that checker's older fixtures without either
  being wrong.** The old fixtures were minimal stubs, and minimal stubs violate new rules
  by construction. Running all three every time is what caught it — running only the new
  one would have shipped a checker whose own test suite was two-thirds red. That is the
  denominator rule again, applied to fixtures rather than to findings.

## 2026-08-17 — Cycle 64: auditing the oldest backlog sections

- Value: **overkill — avoided.** Triaged out at Phase 0.5 tier (a): the entire cycle
  touched `kanban.md` and nothing else. No game, no ledger row beyond this note, and the
  verification was `grep` and `Read` against the code each entry claimed something about.
  - Expected: some mix of shipped, stale and still-real across eight entries.
  - Got: **six SHIPPED, two STALE, zero still wanted.** The three oldest sections were
    entirely obsolete — every idea in them had either been built or overtaken.
  - Found: two things about auditing, both of which the harness was irrelevant to.
    The title-screen entry quoted four constants that **all still reproduce exactly**, and
    its conclusion is false — the code that disproves it also records that both shapes the
    entry proposed were considered and rejected. And an entry cited the *button* whose
    click was silent, while the fix had landed in the *handler*: checking only the cited
    line would have produced a confident, wrong "still real".
  - Cheaper: nothing. Reading eight entries against the code is the work.

- Gap: **no gaps this turn**, and one near-miss worth recording because it was mine and it
  was caught by process rather than luck. My first cut used `s.index()` on a section
  heading. `### New this cycle (25 of 30)` appears **twice** — two independent numbering
  runs with different subtitles, so `uniq -d` on the headings reports nothing — and the
  match landed on the earlier one, deleting 1937 lines instead of 85. `git diff --stat`
  before committing is what showed it, which is exactly why
  `kanban-staleness-audit` says to separate the finding pass from the rewrite pass. The
  rewrite now cuts by line number with three asserts on the boundary lines.

## 2026-08-17 — Cycle 65: corpses that say what killed them

- Value: **warranted**, twice over, and the second run is the interesting one.
  - Expected: the predicates to work (unit-tested, five mutations red) and the corpses to
    read back distinct.
  - Got: distinct — default `rot 1.5708 / x 0.72`, bitten `rot 1.5708 / x 0.4464`, blasted
    `rot 2.1208 / x 0.72`. And **reach 1/3**: every kill in that run went through `kill()`
    directly, so *neither edited call site was ever loaded*. The ledger naming them is what
    sent me back to drive a real Chomp bite, which took reach to 2/3.
  - Found: **`_T.assert_lt` does not exist, and my test called it.** The call aborted the
    method and `run_tests.gd` reported `[PASS]` — an aborted coroutine returns `""`, which
    is identical to a genuine pass. `run_tests.py` caught the `SCRIPT ERROR` the return
    value cannot carry, exactly as its docs describe. **The tell in the numbers is worth
    keeping: same test count, assertions 12279 → 12287 after the fix.** A test that adds
    zero assertions while adding a test is the shape to watch for.
  - Cheaper: nothing. The corpses land off-board at the route's entry bracket, so a
    screenshot would have shown an empty road — checked before shooting, not after.

- Gap: **no gaps this turn**, and two notes in the harness's favour, both about it being
  right when I was not. `run_tests.py` versus `run_tests.gd` is documented precisely for
  the abort-reads-as-pass case and it earned that paragraph today. And `findings` reported
  a `container_layout_drift` on `SeedsLabel` against a **paused** tree that vanished on
  unpause — the second frozen-tree false alarm this session, the first being a tween
  mid-fade. The pattern is now firm enough to state plainly: **run `findings` unpaused**,
  because pause freezes containers mid-layout as readily as it freezes a tween mid-fade.

## 2026-08-17 — Cycle 66: a bead built on my own false claim, and a budget audit

- Value: **warranted**, and for the first item the harness's contribution was to prove the
  work unnecessary before I wrote any of it.
  - Expected: to add a cue marking an escaped pest, on the strength of a kanban entry
    saying an escape has "no sound, no corpse, no linger".
  - Got: every part of that false. An escape plays `Sfx.PEST_ESCAPED` (`game.gd:911`),
    tints the exit cell (`:910`), and punches the Garden readout (`hud.gd:1072-1073`).
    Reading three call sites cost less than the feature would have and produced a better
    result: a correction plus a workflow rule.
  - Found: **`cmd budgets` reports SEVEN budgets, not the five my own standing note
    claimed**, and three of them sit exactly at their declared floor — `husk_click` 4 of 4,
    `hud_readouts` 10 of 10, `hud_stats_row` 19 of 19. The floors are ratcheted down to the
    measurement on purpose here, so that is the system working, but it means the HUD has no
    room on three rows out of four and the only slack left is the row I spent 185 px of
    last cycle.
    Also found by applying `scope-vs-claim`: `hud_readouts`' evidence string said "over
    each live readout", which reads as measuring the CURRENT text — a budget that passes
    because the counter happens to say "Seeds 25". It sweeps `WORST_CASE_TEXT` against the
    live slot. **I misread my own project's string before opening the line**, which is the
    argument for fixing it rather than shrugging.
  - Cheaper: for the escape, reading three call sites — which is what happened, just one
    step later than it should have. For the budgets, nothing: seven live measurements
    against a running HUD exist nowhere else.

- Gap: **no gaps this turn.** Cycle 65's rule (run `findings` unpaused) held on its first
  outing — 0 findings across 4 of 5, no frozen-tree false alarm, because the tree was
  stepping.

## 2026-08-17 — Cycle 67: reporting which budgets are resting on their floor

- Value: **warranted**, and the runtime pass earned it by disagreeing with arithmetic that
  was perfectly correct.
  - Expected: the verb to report the three budgets cycle 66 found at their floor by hand.
  - Got: **"4 of 7"** on the first live read. `pest_road_ceiling` declares a floor of `0.0`
    and sits on it by construction, so it qualified honestly — and could never be anything
    else, making every future reading carry one permanent entry while burying the three
    that are at floor because somebody *spent* them. The headline already counts
    `spent_by_design` separately, so it was reporting one budget twice. Excluded, with a
    test.
  - Found: also **a surviving mutation that was a real gap** — removing the `computed`
    guard changed nothing, because the test never staged an unmeasured budget.
    `budget_regressions` calls that case "a hole in the check, not a pass", so counting it
    at-floor would report the HUD as fuller than anyone has established. Five mutations red
    now.
  - Cheaper: the unit test pins the three-way split against staged entries and would have
    shipped happily. Only the live verb showed the count was wrong in a way no staged
    entry would have revealed, because the offending budget's floor is a real declared
    `0.0` rather than a test fixture.

- Gap: **no gaps this turn.** Worth noting what the harness's own design did here: the
  reply is built from `all` rather than the `--id`-filtered `entries`, and the existing
  comment says why — "grading only the shown entry would report every floor whose budget
  was filtered out as a floor guarding nothing". I added the new count to the same list
  without thinking about it, and it was right for free. **A previous cycle's reasoning,
  written at the line it constrains, made a later addition correct by default** — the
  fourth cycle running that this codebase's own prose has done the deciding.

## 2026-08-17 — Cycle 68: writing down a grammar, and finding it had exceptions

- Value: **overkill**, deliberately — no game launched and none needed for a document plus
  a constants test. The verification was `grep` and the suite, which is what a grammar
  derived from source deserves.
  - Expected: to write down the four-cue vocabulary I had described in last cycle's kanban
    entry: dashed = a remark, solid = a range, filled = a gain, doubled width = armed.
  - Got: **three of four hold and "solid ring = a range" is violated twice**, once by a cue
    I wrote myself two cycles ago. `SoleCoverMarks` draws small SOLID rings on road cells —
    a mark, not a radius — and `ChompFlower` draws a solid ring whose radius *shrinks* as a
    chew completes. Deriving from the 55 draw calls rather than from memory is the whole
    reason the document is worth anything.
  - Found: also that **the document's own pointers shifted eight of the line numbers it
    cites**, before it was committed — adding a five-line header to three cue files moved
    every `draw_` call below it. Re-derived, then verified programmatically that all twelve
    citations land on a `draw_` call rather than trusting the fix.
  - Cheaper: nothing cheaper than the grep, and the grep *was* the method.

- Gap: **no gaps this turn.** One note on the shape of the deliverable, since this project
  has sixty-eight cycles of evidence that prose rots: the document's mechanical half is a
  test (six mutations, all red) and its prose half says explicitly that it will rot unless
  re-derived, with the derivation command in the file. **A document that names the command
  that would falsify it is the closest a prose artefact gets to being checked** — which is
  the same argument `house-static-checker` makes for a printed denominator, applied to
  writing instead of to output.

## 2026-08-17 — Cycle 69: a message with a clock behind it, driven from a real click

- Value: **warranted** — the running game answered a question the headless test could not:
  whether the path that arms an uproot is reachable the way a player reaches it.
  - Expected: to confirm what the headless test had already proved — that the armed-uproot
    prompt now pre-empts a five-second packet reveal instead of waiting behind it.
  - Got: that, and the thing worth the launch. `arm_uproot` returned **`nothing is
    selected`** on the first live attempt: the test sets `selected_placed` by planting,
    and a player sets it by clicking the plant. Driving the real path — `touch_press` /
    `touch_release` at the plant's `global_position`, which Godot's touch-to-mouse
    emulation turns into the click the game actually handles — put a real `Plant` in
    `selected_placed`, and only then did `arm_uproot` return `confirm needed` with
    `MessageLabel` reading `Click Uproot again to dig up your Corn Cobbler — it will not
    grow back.` and `pending_messages()` reading 1.
  - Found: the defect itself, before the fix — the test was written first and failed
    reading `The packet held a Chomp Flower!`, which is what turned the bead's design
    question into a defect. Also that the test's first draft asserted
    `pending_messages() == 1` and got 2, because planting posts its own line: the setup
    was inside the number.
  - Cheaper: the headless test alone would have proved the FIX. It would not have proved
    the selection path, and `--filter` on one test is 50 ms against a ~40 s launch, so the
    honest split is: fix verified cheap, reachability verified expensive and worth it once.

- Gap: **`[G-058]` a third time, and this time it cost a wrong row rather than a warning.**
  I passed `lint_exit`, `tests_exit`, `tests_total`, `tests_failed` and `assertions` as
  top-level keys. `record` accepted all five silently and wrote:

  ```
  'verdict': 'unknown', 'lint': None, 'tests': None, 'runtime': None
  ```

  The real key names are nested objects (`lint: {new: ...}`, `tests: {failed: ...}`) plus a
  top-level `verdict`. The previous two sightings produced a *warning* that made me look;
  this one produced a **well-formed row that under-reports a clean run as
  `verdict: unknown`** — the exact failure mode `.devtools/verify-runs.jsonl` exists to
  prevent, in the file that exists to prevent it. I corrected the row in place and said so
  in the commit.
  - **[G-058] status: fixed upstream, still open here | seen: 3 | harness: 0.38.0 |
    upstream: gh#46 (CLOSED)** — and the reconciliation is the interesting half. I went to
    comment a third data point on gh#46 and found it closed and the fix shipped:
    `difflib.get_close_matches` against `RUN_JSON_KEYS`, printing
    `run.json: ignoring unknown key %r%s - it is NOT in the row`, at
    `<marketplace-clone>/templates/tools/verify_ledger.py`, lines 1101-1107 (0.47.0) — not
    a path in this repo, and written as one until cycle 77's citation sweep said so. On
    0.47.0 this cycle's `lint_exit` would have been named at me instead of vanishing.
    **This project runs 0.38.0 on purpose** (gh#43's segfault, bead `-ny3h`), so the gap is
    real here and fixed there, and that pair is a status the ledger has no word for. Do not
    file it again; do not mark it plainly `fixed` either, because the next cycle on 0.38.0
    will hit it.
  - Improvement, and it is additive to the shipped fix rather than a substitute:
    **`record` should print the schema it accepted on every run**, one line, the way every
    gate in this project prints a denominator — `run.json: read 8 of 8 keys (checks, found,
    value, cheaper_alternative, harness, duration_s, tier, expected); verdict defaulted to
    unknown`. `difflib` catches a key that is *near* a real one; a denominator catches the
    rest, including the silent `verdict` default that is what actually made this row wrong.
    Not filed: the defect gh#46 describes is closed, and a second issue asking for a
    stylistic denominator on top of a landed fix is the kind of noise that skill-feedback's
    own guardrails exist to stop. It lives in `log.md`.

## 2026-08-17 — Cycle 70: honouring a twelve-cycle-old "a screenshot proves it"

- Value: **warranted** — and for the claim I made in a comment rather than for the one in
  the bead.
  - Expected: to satisfy `-6cqi`'s acceptance ("two cobs at different levels are
    distinguishable without selecting either; a screenshot proves it") and close it. The
    geometry shipped in cycle 58; only the evidence was outstanding.
  - Got: the evidence — a level 1 cob reading as one pip and a level 3 as five pips plus an
    arc, confirmed by sampling rather than by squinting (`#ffc500` against `#2ecc71` grass)
    — **and a verification of the change I made mid-run.** Having removed the `if
    offsets.size() > 1` branch on the argument that a degenerate `draw_arc` draws nothing, I
    sampled three points on the circle that arc would have traced around the level 1 cob:
    `mean #2ecc71, dominant #29c56b (100%)` at two of them, road at the third. That claim
    was an assumption about an engine API until the game answered it, and it is exactly the
    kind that ships as a visible regression.
  - Found: two things the diff could not show. **A mutation that survived** — my first test
    asserted `kernel_angle_offsets` and breaking the draw site's own `if` left it green,
    because the test restated a function the arc did not depend on. That survivor is the
    whole reason `spread_arc_span` exists. And **a pip landing over the cob's own leaves is
    drawn behind them**: `Node2D._draw()` renders before its children and `_sprite` is a
    child (`game/plant.gd:172`), so the same pip reads `#ffc500` at one aim and leaf green
    at another. Recorded in `kanban.md` with the radii of every plant's cues enumerated
    against the 64x64 sprite box, not fixed — four of five pips visible is legible, and a
    fix made blind is how the next entry gets written wrongly.
  - Cheaper: nothing. The acceptance criterion is literally a rendered frame, and the
    degenerate-arc question needs the renderer too. The mutation finding came from the
    headless suite at ~40 s.

- Gap: **`sample-pixels` can describe a region but cannot answer "is this colour present in
  it", which is the only question a drawn-cue check ever has.** The verb takes `--rect
  X,Y,W,H` and nothing else (`--points` is not a flag; it exits with the argparse usage
  block), and it reports `mean`, `dominant` with a percentage, `brightest` and `darkest`.
  Real output from this run, on a 5x5 box centred where a pip should be:

  ```
  25 px in (178, 230, 5, 5): mean #24894a, dominant #19844a (36%)
  ```

  That is enough to conclude "not obviously the pip" and not enough to assert anything. The
  workaround was to shrink the rect until `dominant` became the cue's own colour and read
  the percentage — which works, is a squint with extra steps, and cannot be written into a
  test. A cue drawn at 5% coverage of a 5x5 box is drawn; `dominant` will never say so.
  - [G-059] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#49
  - Improvement: `sample-pixels --expect RRGGBB[,RRGGBB...] [--tolerance N]`, reporting the
    matched pixel COUNT and fraction per expected colour, and exiting 1 when a named colour
    appears zero times. That turns "did this cue get drawn" from a description into an
    assertion, and it is the one visual question the rest of the harness cannot reach:
    `node-bounds` is for Controls, `findings` is for layout, and a PNG costs a token budget
    and an eyeball. `--points X,Y[;X,Y...]` as an alternative to `--rect` would close the
    smaller half — a cue is a point, and expressing a point as a 1x1 rect works but reads
    like a workaround because it is one.

## 2026-08-17 — Cycle 71: a second animation channel, and two mutations that survived

- Value: **warranted** — the claim the whole change rests on ("these two animations no
  longer fight over one property") exists only while both are running, and only the live
  game has both running.
  - Expected: that the new `Sway` pivot would carry the idle motion while the five event
    flourishes kept their own hold on `_sprite.scale`, and that nine plants breathing every
    frame would not show in the frame budget.
  - Got: both, and the first one needed three polls to catch. A recoil is a 0.15 s tween and
    the bus round-trip outruns it — the first two reads returned `_sprite.scale = (1.0, 1.0)`
    with the tween already landed, which is indistinguishable from a tween that never ran.
    The third caught it: `_sprite.scale (0.980, 1.023)` and `_sway_pivot.scale (1.022, 0.978)`
    **in the same frame**, neither touching the other. Frame budget: FPS mean 124, min 98.8
    over 60 frames with nine plants, orphan growth +0.
  - Found: four things, and only the first is about the game. **The bead was already
    shipped** — `Plant._wobble` has swayed every plant since the first playable build and
    `Pest._gait` animates every pest. Cycle 70 filed it "verified unbuilt" after enumerating
    `create_tween()` call sites, which is the wrong set: both animations are `_process`-driven
    sinusoids and a tween census cannot see them. Then **two mutations survived**: pointing
    the breathe straight at `_sprite.scale` passed (past its `animations_enabled()` gate
    `_wobble` does nothing headless, so pumping it and reading what moved is a test of an
    unreached branch), and setting `BREATHE_AMOUNT = 0.0` passed (every assertion was
    expressed *relative to* `BREATHE_AMOUNT`, so zeroing it left them all true). And I
    asserted "the breathe never gets wider than its own sprite", which is false of the shape
    I had just written — it alternates.
  - Cheaper: nothing for the collision claim. The two survivors came out of the headless
    suite at ~40 s each, which is the cheapest finding of the cycle by a wide margin.

- Gap: **no gaps this turn** — but one correction to a note in this file's own history, and
  one small flag error worth writing down so the next cycle does not repeat it.
  `set-game-speed` takes the scale as a **positional** argument, not `--scale`; passing
  `--scale 0.05` exits 2 with the argparse usage block. The verb is the right tool for
  exactly this problem (catching a sub-second tween mid-flight) and I reached for it and
  then fell back to polling, which worked by luck on the third try. `pause` cannot substitute
  here: pausing is a second command and the tween lands during the round-trip, which is the
  same race. The one that would actually be deterministic is `step-time --then-pause`, and
  it is the verb this project has never once used in seventy-one cycles.

## 2026-08-17 — Cycle 72: walking a tween that polling cannot see

- Value: **warranted**, and the run WAS the deliverable rather than a check on one — see the
  gap below, because the triage table has no name for that.
  - Expected: that `step-time --then-pause` would work on a Tween, since every prior use in
    this log was on `_process`-driven state and the docs promise only "the step lands".
  - Got: it does, and the contrast is sharper than the question. `CornCobbler._recoil` is
    0.05 s out and 0.10 s back. Four consecutive `get-state` reads straight after firing it:

    ```
    _sprite.scale: {"x": 1.0, "y": 1.0}   x4
    ```

    Four well-formed reads, every one the landed value, **which is exactly what a tween that
    never ran looks like**. Paused first and stepped 0.03 s at a time it walks cleanly —
    0.920 → 0.900 → 0.940 → 0.980 — and two independent runs agree to six decimals on
    samples two through four.
  - Found: the reason, which is not in any flag description. `_cmd_step_time` waits on
    **both** clocks — the physics one and the process one, "so idle tweens do too" — which
    is why it works here and why `set-game-speed` carries no equivalent promise. And the
    non-obvious operational half: **pause BEFORE creating the tween.** `--then-pause` lifts a
    pre-existing pause for its own step and re-freezes after, so a tween born frozen is
    advanced only by the steps you ask for; skip that first `pause` and it runs in wall clock
    between every command, which is the polling case above.
  - Cheaper: nothing. The previous cycle tried polling, got lucky on the third attempt, and
    that luck is worse than a clean failure — a technique that works one time in four teaches
    you it works.

- Gap: **Phase 0.5's triage table classifies a run by its diff, and an experiment inverts
  that — the diff is the run's OUTPUT.** This cycle's diff was one Markdown file, which is
  tier (a): "print 'nothing to verify', write **no** ledger row, log `Value: overkill —
  avoided: triaged out', and STOP the run here." Every clause is wrong for what happened. The
  run was not overkill; it was not avoidable; and the ledger — whose stated job is to be the
  denominator of runs — would carry no record that a full session happened.

  ```
  commands/verify.md:127
  | (a) Nothing Godot loads: only docs/`.md` outside code ... | **Nothing** | ... STOP the run here. |
  ```

  Following it literally would have discarded the finding that polling a short tween fails
  *silently*. And the case is one the harness's own workflow encourages: `log-devtools.md`
  asks every turn what was missing from the harness, and finding out usually means driving it.
  - [G-060] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#50
  - Improvement: a fifth row — tier (e) **Experiment**, reach not expected, ledger row written
    with `--no-reach` and `skipped: "experiment; the session produced the diff"`, verdict
    judged on what the session ESTABLISHED. Plus one line above the table: *classify by what
    the run is for, not only by what changed.* The distinguishing test is mechanical:
    **tier (a) if the diff existed before the run was considered; tier (e) if the run came
    first.**

## 2026-08-17 — Cycle 73: eighteen frames, and a census that lied by one line

- Value: **warranted** — the runner answered a question the source is genuinely ambiguous
  about, and no game was launched to do it.
  - Expected: that a pest killed headless might never free. `Plant.play_exit_and_free` takes
    an early return when animations are gated off, and two tests exist because that bug
    shipped twice; `Pest._play_death` instead routes **both** branches through
    `tween_interval(DEATH_LINGER)` + `tween_callback(queue_free)`, and the suite's own
    comments say headless "pumps no frames".
  - Got: it frees, in **18 process frames**. The worry was unfounded and the number is the
    finding — 18 against the **2** that `UI_SETTLE_FRAMES` pumps, so any test that kills a
    pest and reads the tree a frame or two later sees a corpse still present, and would
    reasonably read that as a leak or as the kill not landing. Ten `.kill()` call sites
    across `test/unit/` sit inside that window.
  - Found: the harness caught my own aborted test. The first draft called
    `is_queued_for_deletion()` on an instance that had already been freed;
    `run_tests.gd` reported `[PASS]` with 2 assertions, and `run_tests.py` failed the run
    with `SCRIPT ERROR: Cannot call method ... on a previously freed instance` and the
    standing note that an aborted coroutine returns `""` identically to a pass. **That
    wrapper is documented as existing for gh#27 and this is the first time in this log it
    has actually fired on my own code.**
  - Cheaper: reading `Pest._play_death` — which is what produced the wrong expectation.
    Runtime was correctly skipped; the question is entirely headless.

- Gap: **no gaps this turn.** One methodological note instead, because it is the second
  cycle running that an enumeration of mine was quietly incomplete, and this time in a new
  way. I enumerated sound call sites with
  `grep -o 'Sfx.play(Sfx\.' | sed 's/.*Sfx\.\([A-Z_]*\).*/\1/'`, concluded `RUN_LOST` was
  declared and never played, and was about to write it down. It **is** played —
  `game/game.gd:941` is `Sfx.play(Sfx.RUN_WON if victory else Sfx.RUN_LOST)`, and a
  line-oriented extraction that captures one match per line cannot see the second constant.
  Cycle 71's failure was enumerating the wrong *mechanism*; this one was enumerating the
  right mechanism with a tool that silently returns at most one hit per line.
  **`grep -o` per token, never `sed` per line, when the thing you are counting can appear
  twice in one statement** — and re-running it properly is what turned up the finding that
  actually shipped: 22 named sounds over 11 files, two pairs identical in file *and* volume.

## 2026-08-17 — Cycle 74: a derived check found five collisions where I had found two

- Value: **warranted**, though almost all of it came from the headless suite — the launch
  was insurance rather than evidence, and saying so is the point of this field.
  - Expected: that the new derived check would name the two colliding sound pairs I had
    already found by hand last cycle, and that fixing those two would make it green.
  - Got: **five.** The check named `PLANT_UPGRADED` / `WAVE_STARTED` after the first two
    were fixed, and re-deriving every `(file, volume, pitch)` triple at once turned up
    `PLANT_PLACED` / `PLANT_UPROOTED` and `UPROOT_ARMED` / `SUNDEW_CLAIM` as well. My
    hand-read had enumerated all ten shared files correctly and then compared volumes for
    only a *sample* of them — the third distinct way a census of mine has come up short in
    five cycles (wrong mechanism, wrong match granularity, and now a complete enumeration
    followed by an incomplete second pass over it).
  - Found: a mutation that survived and changed the design. Deleting the pitch line from
    `play()` left `PITCH` perfectly unique and the player hearing twins again — **the table
    check asserts the tables, not that anything reads them.** And `play()` is gated off
    headless (`should_play` → false), so a headless suite cannot observe it at all. So
    `Sfx.tune_voice` was split out as the one place every voice property is written, and it
    is callable on a bare `AudioStreamPlayer` with no audio server, no pool and no gate. The
    mutation is red now.
  - Cheaper: the headless suite did the real work at ~40 s a run. The launch checked one
    thing it alone could: that writing a new property on a pooled `AudioStreamPlayer` does
    not error in a real audio server, which a muted headless suite cannot speak to.

- Gap: **no gaps this turn.** One observation about the harness's own shape, recorded
  because it recurs: this is the second cycle in three where the useful assertion had to be
  moved to a **seam** rather than strengthened in place, and both times for the same reason
  — the behaviour lives past a `*_enabled()` gate that is false for the entire headless
  suite (`GardenTheme.animations_enabled()` in cycle 71, `Sfx.should_play` here). The
  pattern is now explicit enough to state: **when a property is set past a headless gate,
  extract the setting into a function that takes its target as an argument.** The gate stays
  where it belongs, and the composition becomes assertable without a display or an audio
  server. Both `Plant.breathe_scale` and `Sfx.tune_voice` exist for exactly this and neither
  was designed that way first — each was retrofitted after watching a mutation survive.

## 2026-08-17 — Cycle 75: a checker for the file that records the checkers

- Value: **overkill** — and deliberately written that way, because the cycle was useful and
  the *harness* was not the reason. No game launched, and the harness gates
  (`name_check`, the suite) confirmed exactly what was already known: a new Python file that
  no GDScript imports cannot break GDScript. The finding came from a project-owned tool
  built this cycle.
  - Expected: that a checker deriving `verify_ledger`'s accepted key set from its own source
    would confirm the two key names I already knew were wrong, and otherwise sit quiet.
  - Got: `tier`. I have written that key into **every** `run.json` this session and
    `verify_ledger` reads it nowhere, so every one of those rows lost it silently. Also
    measured: **26 of 86 historical rows carry `verdict: "unknown"`** — 30% of the evidence
    file — and since only one has a null `lint` and none a null `tests`, most of those are an
    omitted `verdict` the tool defaults quietly rather than a misnamed key.
  - Found: the above, plus the confirmation that the bead's own remedy would not have worked.
    It asked for the schema "written down where /verify can see it"; **reading
    `verify_ledger.py` is what I did, and it is exactly how `tier` survived** — scanning 1400
    lines for lookups that are ABSENT is the task a regex is better at than a person.
  - Cheaper: nothing cheaper produced the finding. The harness half of the run was ~40 s and
    told me nothing, which is what `overkill` is for.

- Gap: **the Phase 0.5 triage table has no row for project-owned tooling that is not
  `res://` code**, which is a second instance of the shape gh#50 already describes.
  This cycle's diff was `tools/run_json_check.py` plus two Markdown files. Tier (a) covers
  "only docs/`.md` outside code, `.beads/`, `log-devtools.md`, CI/git files" — a `.py` gate
  the project ships and runs is none of those, and it is not `.gd`, so tiers (b) and (c) do
  not reach it either. The table's implicit assumption is that everything worth verifying is
  loaded by Godot, and a project with ten stdlib checkers is a standing counterexample.
  - [G-060] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#50
  - Improvement: the same fifth row gh#50 proposes, widened — classify by **what verifies
    this change**, not by what loads it. A Python checker's verification is its own fixture
    and its mutation pass, and those belong in the ledger row's `checks` exactly like a
    Phase 4 bridge check does. Recorded here with `--no-reach` and five `checks` entries
    naming the fixture and the three mutations, which is what the table should have told me
    to do rather than to stop.

## 2026-08-17 — Cycle 76: auditing the user's own request list

- Value: **overkill** — avoided: triaged out at Phase 0.5, no `res://` change. The cycle was
  four `grep`s and a rewrite, no game launched, no gate beyond the citation-verifier script,
  and no ledger row. Writing this entry anyway is the point: a cycle that correctly did not
  use the harness is data about when the harness is needed, and it is the entry that goes
  unwritten.
  - Expected: to check three unaudited bullets and find one or two drifted.
  - Got: three of the four bullets in that section were substantially wrong, and the two
    that were "unbuilt asks" are shipped in every clause — an epic packet tier, four
    authored fluff frames indexed off the ammunition count, a real parabola, a blast radius,
    and a facing function that maps all four cardinals.
  - Found: something about my own workflow rather than the game. **Four candidate kanban
    entries died this cycle because I opened the code before writing them** — "endless never
    tells the player what got harder" (there is a `_what_got_harder` feeding the wave-start
    message, `game/wave_director.gd:623`), "the boss has no mechanic" (it does), "the
    dandelion is unbuilt" (it is not), "facing is broken" (it is not). The rule that says
    open the code first has now saved four entries in one cycle, which is more than it has
    caught in any previous one.
  - Cheaper: nothing — `grep` *was* the method, and the whole finding is that reading is
    cheaper than remembering.

- Gap: **no gaps this turn.** One note on the audit skill instead. `kanban-staleness-audit`
  says to separate the finding pass from the rewrite pass so a wrong verdict is not applied
  before anyone reads it, and I did both in one pass. The mitigation was mechanical rather
  than careful — a script that opens every `file:line` in the rewritten section and prints
  the cited line, which has caught two bad citations in earlier cycles and is strictly
  better than a second reading by the same eyes. Worth folding into the skill as the
  sanctioned way to compress the two passes, rather than leaving the rule stated and
  routinely broken.

## 2026-08-17 — Cycle 77: a checker whose denominator was the finding

- Value: **overkill** for the harness proper — no game, and `name_check` plus the suite
  confirmed what a new stdlib file that no GDScript imports could not have broken. The
  cycle's findings all came from a tool built and then USED in the same cycle, which is
  the project's own rule and the reason it exists.
  - Expected: to stop retyping a six-line script, and for the first full run to surface a
    handful of stale citations in a file that says at its own top that half of it is stale.
  - Got: **130 citations in `kanban.md` and all 130 resolving**, which reads as a clean bill
    and is not one. Only **74 of the file's 323 entries carry a citation at all**; 249 make
    claims about the code with no coordinates whatsoever. So the number that mattered was
    the denominator, and the tool was one line away from shipping without it — a checker
    reporting "0 findings" over a quarter of its subject is exactly the clean-result-over-an-
    empty-input-set failure the house contract exists to name.
  - Found: four things, and only the first came from the exit code.
    1. One bad citation across all 23 markdown files — a `log-devtools` entry citing
       `templates/tools/verify_ledger.py` as though it were a path in this repo.
    2. Reading the *landed lines* rather than the exit code: `kanban.md` cited
       `game/plant.gd:172` as `add_child(_sprite)`, and cycle 71's Sway pivot pushed that 34
       lines down, so `:172` now lands on a health-bar comment. **A citation that resolves
       and no longer supports its claim** — the precise case the tool's own `NOT COVERED`
       line says it cannot see, demonstrated on the first pass.
    3. The continuation form (`` `game/sfx.gd:86`, `:91` ``) was invisible: 44 of them in
       `kanban.md`, a third again on top of the 130. Binding them found a reference written
       as a bare `:331` in a sentence whose preceding citation was a 183-line file.
    4. Two bugs in the tool, both from using it rather than reading it — mutating the
       missing-file branch made the next line traceback instead of exiting 2, and running it
       WITHOUT `--quiet` (the mode that prints source, and therefore the mode the first three
       runs never used) died with a `UnicodeEncodeError` on an em-dash.
  - Cheaper: nothing. Every one of those needed the tool to exist and then to be pointed at
    the whole file rather than the paragraph being edited.

- Gap: **no gaps this turn.** One observation worth keeping: findings 2 and 4 both came from
  running the tool in its *verbose* mode, which nothing in the workflow asks for. A checker's
  quiet mode is the one that gets wired into a loop and therefore the one that gets exercised;
  its verbose mode is where the output nobody reads lives, and both a crash and a real
  finding were sitting there. **Run a new checker once in the mode you do not intend to use.**

## 2026-08-17 — Cycle 78: a swept chew ring, and a check I could not catch

- Value: **warranted**, and the ledger said so more precisely than I would have. One live
  frame carried the half of the change that cannot be argued from constants; a second
  check could not be run at all, and `verify_ledger` downgraded the row `pass -> partial`
  on its own for exactly that reason.
  - Expected: that a fixed-radius swept arc would sit outside the flower's own sprite,
    where the old shrinking ring vanished behind it, and that a mid-chew frame would show
    the sweep.
  - Got: the first, clearly — a full ring at 22 px reads outside the head in a rendered
    frame. Not the second.
  - Found: **I could not photograph a partial arc, after four different attempts, and the
    reason is a genuine three-way squeeze.** An aphid chew is 0.45 s against a bus
    round-trip of roughly 200 ms, so plain polling gets one or two samples by luck (it got
    zero). `pause` makes each step deterministic and stops the wave that has to deliver a
    pest. `set-game-speed 0.08` keeps the chew open long enough and stops the pest arriving
    at all. Fine `step-time --then-pause` slices work but only advance game time inside the
    slice, so 14 × 0.3 s bought 4.2 s of world and no pest walked that far. Each tool
    individually solves the problem and each one breaks a precondition of the others.
  - Cheaper: the headless suite proves the sweep's shape in 25 assertions at ~40 s,
    including monotonicity across 20 samples. It cannot speak to occlusion, which is the
    entire reason the radius moved from 16 to 22.

- Gap: **no gaps this turn** — the squeeze above is a fact about the game's timings, not a
  missing verb, and the combination that should work (clear the board of Corn Cobblers so
  a pest survives to reach the Chomp, then step in slices) is filed as `-ip4n` rather than
  logged as a harness complaint. Two notes worth keeping instead:
  - **`blocked` is the right result and I nearly wrote `fail`.** A check that could not run
    is not a check that failed, and the ledger's own downgrade rule turns one `blocked`
    into `partial` for the whole run, which is a more honest headline than a `pass` with a
    footnote nobody reads.
  - **A mutation that does not change behaviour is not a survivor.** Mutating a resolver to
    `matches = [] or [...]` left the right-hand side evaluated, and the finding count did
    not move at all — which is the tell. A real survivor changes the code and not the
    result; a no-op changes neither, and the two look identical if you only read the verdict.

## 2026-08-17 — Cycle 79: the budget made the design decision

- Value: **warranted**, and the decisive work was headless. The launch confirmed one thing
  the suite structurally cannot, which is the honest shape of this run rather than a
  complaint about it.
  - Expected: that a forfeit clause would fit on the armed-uproot prompt, since
    `hud_message_row` was the one HUD budget with real slack (121 px against a floor of 40,
    measured in cycle 66).
  - Got: **it did not fit, by 188 px.** `check_budgets` refused the build — 1064 px against
    an 876 px row — and named the exact worst-case string: the move tip and the forfeit
    clause together on the longest plant name. So the design answer came from a
    measurement. The two extras are mutually exclusive and the one about money wins.
  - Found: also a `container_layout_drift` on the first `findings` run, immediately after a
    message-row text change. Relaunched, settled 90 frames, re-ran — zero; changed the row
    text again, settled 30 frames, re-ran — zero. The known mid-sort transient, **checked
    rather than assumed**, because the UI baseline is empty (`-v9px`) so every `ui_layout`
    finding gates as NEW and there is nothing to compare against.
  - Cheaper: the budget check is headless and did the deciding in ~40 s. What the launch
    added was the live string quoting **20** seeds after one upgrade — the corpus test
    cannot say that, because it prices the ladder's *maximum* rather than a real plant's
    level, which is correct for a budget and useless as a behavioural check.

- Gap: **no gaps this turn.** One note about a good outcome, since those go unwritten as
  often as `overkill` does: this is the first cycle where a **budget refusal changed the
  feature rather than the number.** The system's own documentation warns that ratcheting a
  floor down in the commit that spends it is how a HUD ends up with no slack nobody chose
  (`-ogxu`, still open on the user). Here the refusal was taken as information — the row
  cannot hold both clauses, so it holds one — and `Game.BUDGET_FLOOR` was not touched at
  all. Worth recording as the shape of a budget working, not just failing.

## 2026-08-17 — Cycle 80: the developer's own save made the live check meaningless

- Value: **warranted**, narrowly and for a reason worth naming: the headless test is
  decisive and runs in 50 ms, and what the live pass added is that the milestone
  `RunConfig` actually *persists* behaves like the one a test erases in memory.
  - Expected: to confirm end to end that a first-ever uproot on an upgraded plant no longer
    burns the move-tip one-shot.
  - Got: on the first attempt, **nothing at all** — the developer's real save already had
    `seen_move_tip` earned, so the milestone read `true` before the arm and `true` after,
    and the check could not distinguish the fix from the bug. That is the well-formed-zeros
    failure with a different face: a real answer to the wrong question.
  - Found: the fix. Relaunched with **`--snapshot-userstate`** — the first use of that flag
    in eighty cycles — cleared `earned_milestones` in the running game, drove an upgraded
    first arm (money clause, hint NOT spent) and then a fresh arm (tip shown, hint spent).
    `quit` reported `userstate: restored 1 file(s)`. Without the flag this run would have
    left the developer's save cleared, which the harness warns shows up later as unrelated
    headless test failures.
  - Cheaper: the headless test, for the logic. Nothing cheaper for the persistence question,
    and the persistence question is the only reason to launch at all here.

- Gap: **no gaps this turn.** Two notes:
  - **`suite_reach_check` caught the seam the test did not name.** The new predicate was
    driven only through `arm_uproot`, so it was exercised and unnamed — the checker flagged
    it as NEW against its baseline, and naming it directly turned one behavioural example
    into all four combinations of a two-input predicate. Three of the four say no, so the
    example had been proving almost nothing. A reach checker paying for itself on a
    two-line function is a better argument for it than any of its own denominators.
  - **A live check against persisted state needs its precondition asserted, not assumed.**
    The failure above was silent and would have read as a pass. The habit to keep: before
    driving a one-shot, read it and assert it is in the state the check requires. That is
    `read-a-moving-value`'s "read the clock alongside the value" applied to a flag rather
    than a timer.

## 2026-08-17 — Cycle 81: the check the bead demanded turned the design around

- Value: **warranted**, though the split is unusual: the headless suite did nearly all of
  it, and the one thing the launch added was worth the launch.
  - Expected: to find out whether an armoured **and** winged pest is unkillable, which is
    what `-1d07` said to check before building rather than after.
  - Got: the opposite. `MUTATION_ARMOURED`'s only effect on play is doubling a Chomp's chew
    time (`apply_mutation`; every other reader of `is_armoured` is cosmetic gait), and a
    winged pest cannot be grabbed by a Chomp at all (`game/chomp_flower.gd:85`). **The pair
    is redundant, not lethal** — it would have paid 1.5 × 1.5 for a trait it cannot use,
    which is a payout bug wearing a difficulty costume.
  - Found: two things beyond the feature.
    1. **A seeded assertion that was a coincidence.** Adding one `randf()` per mutated pest
       past wave 20 moved the over-promise run's `escaped_engaged` from 34-of-34 to
       20-of-34. Isolated properly rather than guessed: with the draws still consumed and
       the second mutation *never applied*, the failure is byte-identical — so it is the
       stream, not the feature. The equality had never been derivable; the claim beside it
       (`pests_all_covered_untouched == 0`) is, and still passes.
    2. Three test call sites set `pest.mutation` directly to stage a payout check. Making
       the payout a product over `mutations` broke them **loudly** rather than quietly
       paying for one trait — the good failure mode, and only because the field's meaning
       narrowed rather than widening.
  - Cheaper: the suite, for everything except the live check that the excluded pair is
    refused at the **pest** and not only at the roll — two enforcement points, and only a
    running game exercises the devtools verb that reaches the second one.

- Gap: **no gaps this turn.** One technique worth keeping, since it is the reason finding 1
  is a finding rather than a shrug: **when a seeded simulation changes, separate the stream
  from the behaviour by consuming the draws without applying the effect.** One mutation of
  the form `if false and <condition>:` — carefully, since `[] or [...]` taught me last cycle
  that a no-op mutation proves nothing — and if the failure is identical, the RNG moved and
  nothing else did. That converts "my change broke a test" into "my change reshuffled a
  draw and the test was asserting the draw", which are different problems with different
  fixes, and the second one is invisible without the experiment.

## 2026-08-17 — Cycle 82: reach said the launch verified nothing, and it was right

- Value: **overkill**, and the ledger's own `reach` field is what makes that verdict
  evidence rather than an impression.
  - Expected: to confirm three hand-derived row ceilings by computing them, and to check
    the three screens still build.
  - Got: the ceilings confirmed exactly — options 3 of 3, shelf 7 of 7, summary 7 of 7 —
    and **`reached 0/4 changed file(s)`**. The session sat on the board and never opened
    the options screen, the notebook or the summary card, so the launch touched none of the
    code in the diff. `findings` returned 0 across all five checks, which is true and says
    nothing about this change.
  - Found: the title screen — the one surface that already **computed** its ceiling — has
    three spare rows, while all three that wrote the sums into a comment are exactly full.
    One data point, and a suggestive one: a limit nobody has to re-derive may be a limit
    people stop crowding.
  - Cheaper: the suite alone, at ~40 s. These are pure static computations over constants
    and nothing in the diff could plausibly break a scene.

- Gap: **no gaps this turn**, and one note in the harness's favour. This is the first row in
  the ledger where I would have written `warranted` from impression — the run was clean, the
  screens built, `findings` was 0 across five checks — and `reach 0/4` refused it. The field
  is documented as answering "did this run load the code it claims to verify", and this is
  the case it was built for: **a clean runtime pass on an unreached diff is a statement
  about the game, not about the change.** Worth recording because the pattern is easy to
  repeat: any diff confined to screens the entry hook does not open will reach nothing
  unless the session navigates there, and nothing in `/verify` navigates.

## 2026-08-17 — Cycle 83: four screens checked at runtime for the first time in 83 cycles

- Value: **warranted**, and unusually clearly: the whole cycle existed to reach code that no
  headless test and no previous runtime pass could touch.
  - Expected: that naming the overlay screens as `entry_points` would make them drivable,
    and that a first-ever UI pass over three never-checked surfaces would find something.
  - Got: drivable, yes — `fire-entry-point notebook|keys|options|pause` each lands where it
    should, with `first-frame` confirming the topmost Control is inside the opened screen.
    **And nothing was wrong.** 0 findings each across `ui_layout`, `ui_reachable`,
    `signal_unconnected` and `performance`. A clean first sweep of three surfaces that had
    never been checked is a result, not a non-event — it is the answer to a question this
    project could not previously ask.
  - Found: **entry points do not compose.** Firing `keys` while the notebook is still open
    silently does nothing, because `_open_keys` returns early on `overlay_open()`. Caught by
    `first-frame` reporting the same topmost Control three times in a row rather than by any
    error — the verb reported success each time, because the method *was* called and *did*
    return. The fix is the real user path (press the current overlay's `BackButton` first),
    not a new "open, replacing" method that would have been a seam with no other caller.
  - Cheaper: nothing. These four screens were unreachable until this cycle's config existed.

- Gap: **no gaps this turn.** One note on the shape of the fix, because it is the second
  time a config edit has bought more than a code change would have. `entry_points` needed
  the `scene` field on every entry — the automatic `entry_hook` fires `skip_to_game`, so by
  the time anything wants the title screen's overlays the tree is already on the game scene.
  That is documented (`fire-entry-point` "switches scene first if one is configured") and it
  is the kind of detail that reads as boilerplate until the entry silently resolves no node.
  Worth stating plainly for the next project: **if your entry hook navigates, every entry
  point that wants the pre-hook scene must say so.**

## 2026-08-17 — Cycle 84: the readout had already been measured and refused

- Value: **warranted**, and the decisive part was a screenshot rather than an assertion.
  - Expected: to add a standing weather readout to the top bar, on the strength of a bead I
    filed in cycle 77 saying no readout carries it.
  - Got: **it had been asked for in cycle 17 and refused on a measurement.** `-saaw`'s notes
    record every candidate tag overflowing the 312 px wave slot — `"  rain"` 366, `"  dry"`
    357, `" ~"` 324, a bare `"*"` 317 — and widening the slot putting `hud_stats_row` 35 px
    over budget. My `-t0vy` was a duplicate: I had verified only that `fire_interval_scale`
    reaches no HUD file, never that the question was already open **and already answered**.
  - Found: the refusal contained the answer. The top bar was never weather's home — weather
    is a property of the garden, not of the run's bookkeeping — so it went on the board,
    which has the room the bar does not. Photographed all three states in one region: clear
    saturated green, drought duller with flat dashes, rain cooler with slanted streaks. And
    the frame cost, which the suite cannot speak to: FPS mean 123.6, min 113.4, because it
    is one `_draw` on a weather CHANGE rather than per frame.
  - Cheaper: the suite proves the scatter and the angle difference in 40 s. It cannot say
    whether a 20%-alpha tint and a 7 px dash are **visible**, which is the entire question
    for a cue whose job is to be noticed peripherally.

- Gap: **no gaps this turn.** One process note, and it is the more useful half of the cycle.
  Cycle 77 filed a duplicate because it checked whether the CODE lacked the feature and not
  whether the QUEUE already held the question. Step 6 already says to note an open bead
  rather than file a second one; what it does not say is how to find the open bead, and
  `bd search` over a phrase from the entry ("weather readout", "top bar") would have found
  `-saaw` in seconds. **`verify-bd-item`'s `confirm` step should search the queue, not only
  the code** — the code tells you the feature is absent, and the queue tells you whether
  that absence is an oversight or a decision. Here it was a decision, recorded, with the
  measurement attached, and the measurement is what made the right answer obvious.

## 2026-08-17 — Cycle 85: a user's screenshot found what 587 tests could not

- Value: **warranted**, and it is the clearest case in this log: the defect is invisible to
  every headless test **by construction**.
  - Expected: nothing. This began as the user asking what some circles on the ground were.
  - Got: a real bug. Sole-cover rings drew 72 px (`Hud.BAR_HEIGHT`) high — more than a full
    64 px row — because `Board.cell_to_world` is board-local despite the name and
    `SoleCoverMarks._draw` hands it to `to_local()`, which measures from the viewport.
  - Found: **a second instance in the same shape**, by enumerating `cell_to_world`'s callers
    rather than fixing the reported one. `placement_preview.gd:268` draws the gained-cell
    dots through `to_local()` too. One symptom, two members. The other nine callers are
    correct and each was checked rather than assumed.
  - Cheaper: nothing. The data is right and only the rendered position is wrong, so no
    assertion over `points` can see it. It took a screenshot to notice and pixel samples to
    confirm — before: the cell centre 100% road brown at every sample, the point 72 px above
    64% green with 36% other; after: the centre 44-67% brown with a warm mean, the point
    above 100% pure green.

- Gap: **no gaps in the harness — the gap is in what this project tests.** Three cycles now
  have hit the same seam from different sides: cycle 71 (an idle animation aimed at the
  wrong property, caught by mutation), cycle 74 (a table asserted while nothing read it,
  caught by mutation), and this one (points asserted while their rendered position was
  wrong, caught by a **person looking at the screen**). The pattern is sharper than
  `extract-a-testable-seam` currently states it: **asserting the input to a draw call is not
  asserting the drawing**, and the distance between them is a coordinate space — the one
  thing a pure test cannot hold, because it needs a parented node to exist.
  - Improvement: `findings`' `ui_layout` check reads Control rects and would never have seen
    this, since these are `Node2D` draw calls with no Control anywhere. The check that WOULD
    have caught it is a pixel probe at an expected position, which `sample-pixels` can do and
    nothing automates. gh#49 (assert a colour is present in a region) is the missing half —
    filed for a different reason and this is the case that makes it a gate rather than a
    convenience.

## 2026-08-17 — Cycle 86: the same seam, twice in a row, closed by hand again

- Value: **warranted** — and for the second consecutive cycle the reason is the same seam.
  - Expected: that the flinch would reach the sway pivot, which no headless test can assert.
  - Got: numbers. Sway alone holds the pivot within ±0.014 rad across four stepped samples;
    a bite swings it to **+0.130 and −0.024** — more than twice the entire idle amplitude —
    and `_flinch_left` reads 0.12 of 0.32 as it decays. A screenshot mid-flinch shows the
    plant leaning at −0.074 rad. FPS mean 122.3 against 122–124 in cycles 71 and 84.
  - Found: **the third mutation survived, and it is the same class as cycle 85's bug.**
    Replacing the flinch term at the draw site with `0.0` passes every headless test,
    because they assert `flinch_amount` — the pure function — and not the rotation it feeds.
    `extract-a-testable-seam` predicts exactly this and says a live session is the answer, so
    it got one.
  - Cheaper: the suite pins the decay curve and the arming rule in 40 s and cannot see
    whether any of it reaches the screen.

- Gap: **no gaps in the harness. The gap is `-6e2e`, and this is the second cycle running to
  pay its cost by hand.** Cycle 85: a coordinate-space bug shipped because tests assert the
  points and not where they land. Cycle 86: a surviving mutation on the same seam, closed with
  four `step-time --then-pause` samples and a `get-state` read. Both took ten minutes of
  driving that a probe would do in one call.
  - The pattern is now specific enough to state as a rule for whoever builds `-6e2e`: the
    check is **not** "does the cue appear" but "does the value the game computed reach the
    property that draws it". Cycle 86's version is three lines — pause, step, read
    `_sway_pivot.rotation`, assert it exceeds `WOBBLE_RADIANS` — and it needs no pixels at
    all. **A property read beats a pixel probe wherever the drawn thing is a transform**, and
    only the cues drawn with `draw_*` into a canvas need sampling. That halves the surface
    `-6e2e` has to cover and makes the easy half genuinely easy.

## 2026-08-17 — Cycle 87: the audible path turned out to be readable after all

- Value: **warranted**, and it overturned the prediction that produced the runtime pass.
  - Expected: that the audible half would be **unverifiable**. `Sfx.play` is gated, the
    harness launches with `mute: true`, and there is no audio capture — so I expected to
    record the runtime portion as thin and say so.
  - Got: the whole path reads back. The voice pool is **real nodes** under `/root/SfxPool`,
    so a kill can be inspected: a 3.0× pest tuned `Voice0` to `pitch_scale 1.12` at
    `-1.5 dB`, exactly `PEST_KILLED_HARD`'s row. Pest → `husk_multiplier` →
    `kill_event_for` → `play` → `tune_voice` → an `AudioStreamPlayer`, every hop observed.
  - Found: a bonus the suite could not reach. A plain kill afterwards **reused `Voice0`** and
    retuned it to 1.0 at −3.0 dB. That is the pooled-voice staleness hazard `tune_voice`
    writes every property unconditionally to prevent — cycle 74 argued it from the code and
    nothing had ever watched it happen.
  - Cheaper: nothing for that half. The suite asserts `tune_voice` composes correctly and
    structurally cannot say that `play()` reaches it.

- Gap: **no gaps this turn**, and one correction to my own instinct worth recording. I nearly
  skipped the runtime pass on the reasoning that a muted session cannot verify a sound. That
  reasoning was about the OUTPUT — nobody can hear it — and the thing worth checking was the
  **state that produces the output**, which is a node property like any other. **"This is
  unobservable" is usually a claim about the final medium, and the pipeline feeding it is
  almost always made of readable values.** The same move applies to anything the harness
  cannot sense directly: don't ask whether you can perceive the effect, ask what the last
  readable value before it is. Here it was three hops from the top and one `find-nodes` away.

## 2026-08-17 — Cycle 88: the husk cue that had run out of range (-532j), and -beq1 closed unbuilt-because-already-built

- Value: **warranted** — the frame answered a question the numbers structurally cannot, and
  then answered a second one I had not thought to ask.
  - Expected: the unit tests already pinned the whole drop table, so I predicted runtime
    would only confirm that three pips fit legibly on a 30px husk — a taste check.
  - Got: that, plus the comparison itself made visible. The capture puts a 9-seed husk
    beside a 14-seed one and they are the same circle, the same brightness and the same
    ring weight, differing by exactly one pip. The derived table *said* six of ten values
    collide; the screenshot is what makes that a thing you can see rather than a claim
    about `clampf`.
  - Found: two, both on the way to the picture. The five test husks **rotted before the
    first screenshot** — `lifetime_for` at value ≥ 9 is `MIN_HUSK_LIFETIME` 4.5s, and I
    spent longer than that reading `global_position` — so the check had to be re-run
    paused with `queue_redraw` forced by hand. And the first two captures were empty
    because `drop_husk` takes an **Entities-local** position while `screenshot --region`
    takes screen space, and `Entities.global_position` is `(0, 72)`. That is cycle 85's
    coordinate-space class, hit by me, while verifying a fix in the same subsystem, one
    cycle after writing the bead that says board cues need a position probe.
  - Cheaper: nothing. The numbers needed no game and did not get one; what needed the game
    was whether a count of three is countable, and whether the collision the table derived
    is the collision a player sees.

- Gap: **`pause` freezes the mechanism that repaints, so a state change made while paused
  is invisible until you know which node redraws from `_process`** — the workaround is
  three commands and requires reading the node's source first.
  `pause`, then `run-method drop_husk` ×5, then `screenshot`: an unchanged frame. Nothing
  in the reply says why. `HuskLayer` repaints from `_process` (`game/husk_layer.gd:87`),
  which a paused tree does not call, so the canvas still held the pre-drop frame — while
  `ping` cheerfully answers, because the bridge is process-mode ALWAYS and the game under
  it is not. The fix was
  `run-method --node /root/Game/Entities/HuskLayer --method queue_redraw`, which only
  works if you already know that node is the one drawing and that it draws from
  `_process`.
  This is not a niche shape: every `_draw`-based cue in a Godot game repaints from either
  `_process` or an explicit `queue_redraw`, and pausing to inspect a transient is exactly
  the case `pause` is documented for ("catch a sub-second effect, poll for the moment,
  pause, then inspect at no rush"). The husks here were transient *because* they rot in
  4.5s, so unpausing to get a repaint races the thing being inspected.
  - [G-061] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a `repaint [--node PATH]` verb that calls `queue_redraw()` on the node and
    its `CanvasItem` descendants (whole tree by default) and returns how many it touched —
    one command, no source-reading, and it composes with `pause`. Failing that, have
    `pause`'s own reply carry a `canvas_repaint: frozen` note naming the consequence, so an
    unchanged frame is diagnosable from the output instead of from a guess.

- Gap: **the verify ledger detected that a `warranted` row carried no Phase 4 checks, said
  so, and wrote the row anyway.** `verify_ledger.py record` printed
  `warranted with no Phase 4 checks recorded - the claim that earned it is not in the row`
  and then `recorded unknown run, value=warranted - reached 3/3 changed file(s)`. Both
  lines are true and the warning is the useful one, but it is advisory text on stderr that
  nothing reads back: `verify_ledger.py stats` does not count rows in that state, so the
  ledger's own headline metric treats a row whose verdict has no recorded evidence
  identically to one that does. My row is exactly such a row — the runtime work was real
  and driven by hand, so the verdict is earned, but the row does not carry it.
  - [G-061] see above for the pause gap; this one is its own:
  - [G-062] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `stats` should print the count of `warranted`/`insufficient` rows with an
    empty or absent `checks` array as its own line — "N of M verdicts carry no check
    evidence". The warning already knows how to detect the state; the gap is that nobody
    ever sees it again after the run that produced it scrolls past.

### Cycle 88 gap reconciliation — the first run of the new `gap-reconcile` skill

Built `.claude/skills/gap-reconcile/SKILL.md` this cycle because `log.md` had named it twice
and `.claude/skills/` did not have it — a step-0 obligation I had reported as satisfied
without checking, which is its own finding. Applied immediately to the two open gaps carrying
an `upstream:` field, both of whose issues are now CLOSED. Both are **fixed in the installed
0.54.0 and unavailable here**, because this project is pinned at 0.38.0 on purpose (gh#43).

- [G-059] status: fixed | seen: 1 | harness: 0.54.0 | upstream: gh#49 | note: shipped in full
  and then some. `sample-pixels --expect RRGGBB[,RRGGBB...]` with `--tolerance` (default 8)
  at `templates/tools/devtools.py:5191`, the assertion path at `:4716-4723` reporting per
  colour count and fraction and `sys.exit(1)` on absent — and `--points X,Y` shipped too,
  which was the smaller half of the ask. Read the code rather than the flag's presence, per
  the skill's own step 3: it also exits **2**, not 0, when `--expect` is sent to a game whose
  harness predates 0.49.0 (`:4711-4715`), so an unassertable run is not reported as a clean
  one. That is better than what was asked for.
- [G-060] status: fixed | seen: 2 | harness: 0.54.0 | upstream: gh#50 | note: `commands/verify.md:134`
  is a sixth Phase 0.5 row, `(f) Only project-owned tooling outside res://` → **Tooling-only**,
  and it cites `plant G-060, 2nd sighting` with the exact scenario logged here — a
  `tools/run_json_check.py` plus two `.md`s fitting no row. Row `(e)` covers the adjacent
  case (the diff IS the run's output) with a `"kind": "experiment"` that `stats` counts
  separately.

**What reconciliation changed in-project, which is the point of doing it:** `-6e2e` was filed
as blocked on gh#49. It is not any more — the tool exists, one pin away. That moves the bead
from "waiting on upstream" to "waiting on `-ny3h`", which is a different and much more
tractable kind of blocked, and nothing in the gap ledger's count would ever have said so.
Noted on the bead.

## 2026-08-17 — Cycle 89: two doors for two contracts (-0q3q), no launch and saying so

- Value: **warranted** — and every claim it produced came from the headless half, which is
  worth naming because the runtime half was skipped on purpose.
  - Expected: `spend_hint` is twenty lines of guard on an autoload, covered by three new unit
    tests plus an existing one that hosts `game.tscn`. I predicted the gates would confirm
    and nothing more.
  - Got: three separate findings, none of which reading the diff would have produced.
    `suite_reach_check` fired on `is_hint` as **public with no test naming it** — my three
    tests drove it through both guards and never asserted the deciding function, which is
    precisely the seam the whole change exists to create. And `run_tests.py` caught two
    failures that `run_tests.gd` reported as clean runs.
  - Found: the worst was a test of mine that **passed over nothing**. A derived disjointness
    check asserted `Milestones.TABLE.has(id)` for each hint id; `TABLE` is an
    `Array[Dictionary]` keyed by `"id"` (`game/milestones.gd:54`), so a String compared
    against Dictionaries is false for every id in the game. Green, vacuous, and `[VACUOUS]`
    could not catch it because the method executed real assertions. It surfaced only because
    `String(dict)` crashed two lines later — i.e. **by luck**. The correct idiom was already
    in the codebase at `notebook_screen.gd:505`.
  - Cheaper: for the runtime half, yes, and it was taken — see the gap below. For what was
    actually caught, nothing: the vacuous assertion needed the engine's own type error, and
    `suite_reach_check`'s finding needed the tool.

- Gap: **`run_tests.gd` reported `Total: 531 | Passed: 531 | Failed: 0 | Skipped: 0` on a run
  that had silently lost 64 tests to a parse error.** This is a second sighting of the class
  the `run_tests.py` wrapper exists for, in a new shape worth recording: not a test that
  aborted mid-method, but a whole SCRIPT that failed to load.
  ```
  SCRIPT ERROR: Parse Error: There is already a variable named "err" declared in this scope.
  ERROR: Failed to load script "res://test/unit/test_economy.gd" with error "Parse error".
    Total: 531  |  Passed: 531  |  Failed: 0  |  Skipped: 0
  ```
  The wrapper exited 2 and quoted it, so the safety net held — and that is the point: the
  denominator moved 596 → 531 and **`Passed == Total` the whole way**, so the headline line
  is indistinguishable from a clean run of a smaller suite. `Suite: 7 test script(s)` was
  still 7, because discovery counts files and this file was discovered and then failed to
  load. Nothing in the summary block says a script is missing from the run.
  - [G-063] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `run_tests.gd` should carry its own load-failure count into the summary —
    `Scripts: 6 of 7 loaded` beside the existing `Suite:` line, and a non-zero shortfall as
    exit 1 in its own right. It already knows: it iterates the discovered files and the load
    returns null. The wrapper catching this is the correct backstop, but a runner whose
    headline says `ALL TESTS PASSED` over a suite missing 11% of itself is a runner that
    cannot be run directly, and `run_tests.gd` is what a fresh session reaches for first.

- Gap: **the triage table has no row for "the changed call site is already driven by a hosted
  scene in the headless suite", so a correctly-skipped runtime pass has nowhere honest to
  live.** This cycle's diff is an autoload guard plus one call site in `Game.arm_uproot`. That
  site is already exercised by `test_the_move_tip_is_spent_only_when_it_is_actually_shown`
  (`test/unit/test_economy.gd:2571`), which instantiates `game.tscn`, places two cobs,
  upgrades one and drives the real arm path. Launching would have re-driven the same code with
  a renderer attached. Tier (c) is `static func`s and `const` tables only; this is instance
  methods, so the table says full run.
  I recorded the row with `"runtime": "skipped"` and a `skipped:` string arguing the case,
  which the ledger accepted — but that is prose in a field, not a tier, so `stats` counts this
  as a run that simply had no runtime rather than one that reasoned about not needing it.
  - [G-064] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a tier for **"headless integration covers the changed path"** — the test that
    stands in must be NAMED (tier (c) already sets that precedent) and must be one that hosts
    a scene, which is a mechanical property a reader can check. Without it the honest choice
    is between an overkill launch and a row that looks like a gap.
  - Note: no gaps beyond these two this turn.

  - [G-063] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#52 | note: reconciled
    against the INSTALLED 0.54.0 the same cycle it was filed, per `gap-reconcile`, and it
    survives — in a sharper form worth the re-check. 0.54.0 already collects the list
    (`_selected_load_failures`, declared `templates/tools/run_tests.gd:127`, appended
    unconditionally at `:552`) and already exports it in `--json` at `:715`. It is printed at
    exactly one place, `:799`, guarded by `_selection_error != ""` — the selector-matched-
    nothing case gh#10 added it for. On a full run `_selection_error` is empty, so the branch
    is skipped and a populated list never reaches the summary. **The data is one `elif` away
    from being visible**, which is a much better issue than the one I would have filed from
    the 0.38.0 observation alone.

## 2026-08-17 — Cycle 90: the flight hint (-2ker), and two observation errors that looked like a defect

- Value: **warranted**, and the clearest case in several cycles — three of the run's four
  claims are ones no headless gate can make.
  - Expected: the unit suite covers the predicate, the edge and the spend contract. I
    predicted runtime would add only the row's WIDTH, which `message_corpus_check` says
    outright it cannot know.
  - Got: that, plus two things I had not predicted. `cmd budgets` priced the row at
    **818 of 876 px, 58 left** with the new tip in the corpus. A screenshot showed the
    sentence unclipped using under half the row — worth a picture rather than an assertion
    because the label has `clip_text = true`, which is precisely the case where
    `get_minimum_size()` returns ~1 px and the width test the unit suite *could* have
    written passes unconditionally. And a real winged aphid walked past a real Chomp and
    the tip appeared, reproduced twice.
  - Found: three, none of them a defect in the shipped feature.
    **`message_corpus_check` refused a `const`.** I wrote `const FLIGHT_TIP` and appended
    it to the corpus; the checker reported the call site as calling none of the corpus's
    producers. The corpus mechanism resolves producer CALLS and literals, so a const
    reference is invisible to the row's budget — the thing four cycles went into
    measuring. Six producers already sat beside it; the const was the outlier, and the
    checker knew.
    **The end-to-end unit test's first draft saw zero emissions and looked like a broken
    signal.** `Plant._physics_process` calls `_act(delta, _live_pests())` every frame
    (`game/plant.gd:368`), so whether a headless settle spends the rising edge before the
    listener exists is a question about the settle, not the feature. Rewritten to clear
    both sides explicitly rather than encode a frame count.
    **And the live run appeared to show the hint never firing, through two compounding
    observation errors and no defect at all.** I polled
    `/root/Game/Hud/Root/TopBar/MessageLabel`; the node is `/root/Game/HUD/...`. Every
    read returned `Failed: Node not found` and I read fourteen of those as an empty row.
    By the time `find-nodes --class Label --where name=MessageLabel` gave me the real
    path, the hint had already been spent on the first attempt and was correctly doing
    nothing — `earned_milestones` read `{"seen_flight_tip": true}`. That is cycle 80's
    trap exactly, and `launch --snapshot-userstate` had been passed at launch for it and
    restored the save on quit.
  - Cheaper: nothing. The budget is a running-game number by construction, and `clip_text`
    makes the cheap assertion a false one.

- Gap: **`get-state` reports a missing node identically whether the path is wrong or the
  game is broken, and nothing suggests the verb that would resolve it.**
  ```
  Failed: Node not found: /root/Game/Hud/Root/TopBar/MessageLabel
  ```
  That is the entire reply, fourteen times, for a path whose only error is the case of one
  segment. The tree contains `/root/Game/HUD/Root/TopBar/MessageLabel`; the reply knows the
  path it was given and has the tree in hand, and says neither "the deepest segment that
  DID resolve was `/root/Game`" nor "a node named `MessageLabel` exists at
  `/root/Game/HUD/...`". The fix I eventually used —
  `find-nodes --class Label --where name=MessageLabel` — is in `REFERENCE.md` and is the
  right verb; nothing in the failure points at it.
  This is worse in a polling loop than in a single call, which is how it cost fourteen
  batches: each read "failed" identically to the previous one, so the shape of the output
  was stable and looked like a stable *result*.
  - [G-065] status: open | seen: 1 | harness: 0.38.0
  - Improvement: on a node-path miss, report the longest prefix that resolved and the
    children available at that point — `resolved as far as /root/Game, which has children
    [HUD, Entities, CompostMeter, ...]`. That alone names a case error instantly. Better
    still, when the leaf name exists elsewhere in the tree, say where: the walk is already
    happening and a single `find_children(leaf, "", true, false)` is one call.
  - Note: no other gaps this turn.

  - [G-065] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#53 | note: reconciled
    against the installed 0.54.0 before filing, per `gap-reconcile`. All four
    `"Node not found: %s"` sites are unchanged (`dev_tools.gd:1254`, `:1741`, `:1872`,
    `:3843`); `:1872` alone adds "(also tried under /root)", which shows the intent already
    exists at one site and nowhere else.

## 2026-08-17 — Cycle 91: the cue legend (-bxhg), and two mutations that survived their guards

- Value: **warranted** — the one claim that mattered is one no assertion this project can
  write.
  - Expected: five drawn swatches at 15 px either read as five distinct shapes or they do
    not. I predicted runtime would answer exactly that and nothing else.
  - Got: that — the screenshot shows brackets, a full ring, a three-quarter arc, a dashed
    ring and a filled dot, all distinguishable, with the provenance line reading "5 of the
    board's 10 marks". Plus the four-kind exclusivity holding in a live tree rather than in
    a unit assertion: `fire-entry-point notebook`, page 10/10, `CueLegend visible=true` and
    `Shelf visible=false` in the same query.
  - Found: **both mutations survived their first guard, and each survival was a finding
    about the test rather than the code.**
    Inlining `Color(1.0, 0.95, 0.35, 0.9)` into ONE of `_draw_subject`'s two `draw_line`
    calls passed, because the guard was `source.contains("SelectionMarker.MARKER_COLOR")`
    and the *other* call kept the token alive. `contains` proves a token appears somewhere;
    it says nothing about every use. Replaced with the property actually wanted — **no
    swatch painter builds a `Color` literal at all** — which goes red.
    Deleting `KIND_LEGEND`'s `PANE_LABELS` row passed too. `pane_label_for` returns `""`
    for an unknown kind *by design* (better a blank heading than the neighbouring kind's,
    which is what the `if/elif/else` chain it replaced would have given), but blank is only
    better than wrong if something notices, and nothing did.
    And the existing `test_the_notebook_plant_pages_fit_their_card` carried the **same
    latent defect as the production code I had just fixed** — its dispatch is
    `if DRAWING / if SHELF / else PLANT`, so the new kind fell through and was asserted to
    name a real plant.
  - Cheaper: for the drawing, nothing. For the two mutation findings, also nothing — a
    guard that has not been watched failing is the thing this project keeps re-learning.

- Gap: **`fire-entry-point` puts you on a screen but says nothing about what state it is
  in, and the state it landed in was not the documented one.**
  ```
  python tools/devtools.py fire-entry-point notebook
  entry_points.notebook fired /root/TitleScreen._open_notebook()
    scene changed to reach /root/TitleScreen
  ```
  The notebook's build ends with `go_to(0)` (`game/notebook_screen.gd:370`), so page 1 of
  10 is what a reader of the source expects. The live screen was on **page 10 of 10**. That
  was convenient — it is the page I wanted — and I nearly recorded "the legend renders"
  without noticing I had not navigated to it. Whether the entry point, the pager's wrap
  (`go_to` normalises `-1` to the last page) or a stray input put it there, the reply is the
  only thing that could have said so and it reports only that the method was called.
  The reason this matters beyond one screen: an entry point exists to reach a state, and a
  run that verifies the WRONG state passes exactly like one that verifies the right one.
  `reach` catches an unloaded file; nothing catches an unexpected page.
  - [G-066] status: open | seen: 1 | harness: 0.38.0
  - Improvement: have `fire-entry-point` return the same summary `first-frame` already
    computes — topmost on-screen Control, visible CanvasLayers, paused state — so the reply
    says what is on screen rather than only what was called. The verb exists and the data is
    one call away; the entry point is precisely the moment a caller has no idea yet.
  - Note: no other gaps this turn.

  - [G-066] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#54 | note: reconciled
    against the installed 0.54.0 before filing. `_cmd_fire_entry_point`'s success return
    (`dev_tools.gd:5181`) carries `name`, `node_path`, `method`, `result` and
    `scene_changed` — every field describes the CALL and none the resulting screen. The
    fix is a merge rather than new code: `first_frame` is registered at `:602` and already
    computes "what IS the screen showing".

## 2026-08-17 — Cycle 92: the notebook opens where the door was (-czz4)

- Value: **warranted** — the entire feature is which page each of two doors opens on, and
  no headless test can drive `PauseScreen`'s real button through to a `NotebookScreen` it
  constructs itself.
  - Expected: two reads. Pause door → the legend, title door → the drawings.
  - Got: exactly that. `fire-entry-point pause`, `press NotebookButton`, and
    `PageLabel` reads `10 / 10` with `CueLegend visible=true` in the same query; a fresh
    session's `fire-entry-point notebook` reads `1 / 10`. **Both doors driven on purpose** —
    asserting only the legend case cannot distinguish "`open_at` works" from "`open_at` is
    ignored and 0 happens to be right", and that is a real failure mode for a property whose
    default equals one of its two expected values.
  - Found: **cycle 91's gh#54 observation does not reproduce.** `fire-entry-point notebook`
    lands on `1 / 10` today, matching `go_to(0)`. Last cycle it landed on `10 / 10` and I
    could not say why; I still cannot, and I can no longer make it happen. The issue's claim
    — that the reply never says what is on screen — is unaffected and if anything better
    supported: a cycle went by unable to tell whether the entry point, the pager's wrap or a
    stray input caused it, and the only reply that could have narrowed it names just the
    method. A comment saying so is owed and GitHub returned **HTTP 503 twice**, so the text
    is parked at `.devtools/pending-gh54-comment.md` to post next cycle.
  - Cheaper: nothing for the two-door check. The rest of the cycle's findings came from
    reading, not running.

- Gap: **`press` reports the button it pressed and nothing about what the press did**, which
  is the same shape as [G-066] one verb over. The sequence that verifies this feature is
  `press NotebookButton` then a separate `find-nodes` to discover a notebook now exists and
  a third call to read its page. The press is the interesting moment and its reply is
  `Pressed /root/Game/PauseLayer/PauseScreen/NotebookButton` — true, and silent about the
  overlay that appeared as a direct result.
  Filing it separately from G-066 rather than bumping that one's `seen:`, because the fix is
  different: `fire-entry-point` wants the screen summary because it is *supposed* to change
  the screen, whereas most presses change nothing visible and a full `first_frame` on every
  one would be noise. What `press` wants is narrower — **did the tree gain or lose any
  node** as a result, reported as a count and the topmost added path.
  - [G-067] status: open | seen: 1 | harness: 0.38.0
  - Improvement: snapshot `get_tree().get_node_count()` either side of the emit and report
    the delta, plus the deepest new node's path when the delta is positive. That turns
    "pressed a button" into "pressed a button and a `Notebook` appeared", which is the claim
    a caller is actually making when they press a menu item. Cheap, and it degrades to
    `+0 nodes` for the presses where nothing happens — which is itself worth seeing, because
    a button wired to nothing currently reports success.
  - Note: no other gaps this turn.

  - [G-067] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#55 | note: reconciled
    against the installed 0.54.0 before filing. `_cmd_press`'s success return
    (`dev_tools.gd:5444`) carries `node_path`, `type`, `disabled` and `button_pressed` —
    every field about the button, none about the world after the press. Filed cycle 93
    after GitHub's GraphQL API recovered; the gh#54 comment owed from cycle 92 went up at
    the same time. **Both needed `gh api -X POST repos/...` rather than `gh issue`**, which
    goes through GraphQL and was still 503-ing while REST was fine — worth knowing as a
    fallback rather than as a reason to give up on filing.

## 2026-08-17 — Cycle 93: measuring a drop rate that turned out to be zero (-i366, -he1l)

- Value: **warranted** — the question was about a real run by construction, and before this
  cycle it could not be answered even in principle.
  - Expected: I thought the row probably did drop lines in a busy wave, and that the
    measurement would tell me which ones.
  - Got: **zero**, across waves 1-6 to a full loss — 54 pests defeated, ten lives lost, a
    weather change to rain and back, every wave transition. And the threshold, driven live:
    six `show_message` calls in one frame gives one on the row, `pending_messages()` 3, and
    `messages_refused` 2. The row holds four; the fifth inside a 2-4 s window is the first
    line lost, and ordinary play never produces four events that close together. A worry
    three cycles old, closed with a number.
  - Found: three, and the third is the one that nearly cost the measurement.
    `_queue_message` has **two** drop sites, not the one the bead and cycle 90's kanban
    entry both described — `return` loses the arriving line, `remove_at` loses a waiting
    one. And a higher-rung message does **not** evict a queued line: it pre-empts, pushing
    the line it interrupted into the queue, where a full queue of equals refuses it. I had
    asserted the opposite and the test caught me.
    Then: **the run hit `game_over` at wave 6 while I was still driving waves**, and
    `set-state --property lives --value 99` did not revive it. Two subsequent polling loops
    returned `messages_refused: 0` — and identical `run_seconds` — which I nearly recorded
    as a deeper measurement than the one I actually had. A frozen tree answers with
    well-formed numbers, which is the harness's own standing warning ("a run that never
    changes is broken, not passing") arriving in a shape I did not recognise: I was watching
    a counter that was legitimately 0, not a value that had stopped moving.
  - Cheaper: nothing. The instrument had to be built before the question could be asked.

- Gap: **a `.devtools/` path is not a durable place to park anything, and cycle 92 recorded
  that it was.** `.gitignore:8` is `.devtools/*` with a single exception for
  `verify-runs.jsonl` at `:9`, so the gh#54 comment text cycle 92 wrote to
  `.devtools/pending-gh54-comment.md` was **never committed**. It survived only because this
  session kept the same working tree; a fresh clone, a worktree, or another machine would
  have lost it, and that cycle's commit message says it was "parked at" a repo path as
  though it were.
  Not a harness defect — it is mine — but it is logged here because the harness's own
  conventions point at `.devtools/` for scratch state (`.devtools/tree.json`,
  `.devtools/import.log`, `.devtools/lint.log` are all in the loop's instructions), so
  "write it under `.devtools/`" is the reflex the surrounding tooling teaches, and exactly
  the wrong one for anything that must outlive the session.
  - [G-068] status: open | seen: 1 | harness: 0.38.0
  - Improvement: nothing upstream to change. The in-project fix is a habit —
    **durable means tracked**, so anything owed to a future cycle goes in a bead's body or a
    committed file, and `git check-ignore -v PATH` answers it in one command. Recorded as a
    gap rather than a note because the reflex it corrects comes from the harness's own
    layout, so the next person will make the same move for the same reason.
  - Note: no other gaps this turn. `gh issue comment` / `gh issue create` go through
    GraphQL and were still 503-ing while REST was healthy — `gh api -X POST
    repos/OWNER/REPO/issues[/N/comments] --input FILE.json` worked first try, which is worth
    trying before parking anything.

## 2026-08-17 — Cycle 94: the collision that turned out not to be one (-trn1)

- Value: **warranted** — but narrowly, and the honest version is that the headless test
  answered the mechanism and runtime answered a different question.
  - Expected: the headless test had already shown the pre-empted line is deferred rather
    than erased. I predicted runtime would confirm it against the real paths and nothing
    more.
  - Got: that, and it was worth having. `take_damage(999)` on a real plant, `arm_uproot` on
    a real selection, both inside one frozen instant — `pending_messages()` 1,
    `messages_refused` 0 — then `step-time --seconds 4.05 --then-pause` and the row reads
    "A hungry pest ate your Corn Cobbler!" again. The test stages that collision by hand;
    only the run shows the two real producers doing it.
  - Found: three, all mine, and the first is the reason the cycle existed.
    **Cycle 93's kanban claim was false and I wrote it.** "Arming an uproot destroys the line
    the player is reading" was reasoned from the queue's drop rule instead of from the branch
    that actually runs — and both branches are in `show_message`, eight lines apart. The
    entry even cited `game/hud.gd:1462` for the pre-empt and then described the behaviour of
    the *other* one: **a citation that resolves, on the right line, supporting the opposite
    of the sentence around it.** That is exactly what `citation_check`'s own `NOT COVERED`
    line says it cannot detect, and this is the first time I have watched it happen to me.
    **The first live attempt read an empty row and proved nothing.** 17 seconds of game time
    passed inside `wait-frames 120`, so both messages had expired before I looked. The
    standing note for this exists ("to walk a sub-second tween: pause, then `step-time
    --seconds 0.03 --then-pause`") and I did not reach for it, because four seconds does not
    feel sub-second — but the row's contents are a sub-second-resolution question whatever
    the durations are.
  - Cheaper: for the mechanism, yes — the headless test, which I had already written. For
    "do the two real producers actually collide this way", nothing.

- Gap: **`cmd touch_press` silently accepts an argument shape it ignores.** The verb takes
  `{index, position:[x,y]}`; I sent `{x, y}`, and it reported success and did nothing:
  ```
  cmd touch_press --args '{"x":288,"y":296}'   -> success
  run-method --method arm_uproot                -> "nothing is selected"
  ```
  So a malformed click reads as a broken uproot, one verb downstream. The harness's own
  reference warns about this class in general — `list-commands` prints each verb's arg keys
  and says "a key not listed is silently ignored" — which makes it a documented property
  rather than a surprise, and it is still the wrong default for a verb whose entire effect
  is positional.
  Filing it against the project's own extension rather than upstream: `touch_press` is
  registered in `devtools_ext/commands.gd`, so the fix is ours. The generic case (unknown
  keys ignored) is the harness's and is deliberate.
  - [G-069] status: open | seen: 1 | harness: 0.38.0
  - Improvement: have the project's `touch_press` / `touch_release` / `touch_drag` **refuse**
    a call with no `position` (or `to`) rather than defaulting to zero, and name the key they
    wanted. Three verbs, one guard each, and it converts a silent no-op into a message. A
    positional verb with no position is never a call anyone meant.
  - Note: no other gaps this turn.

## 2026-08-17 — Cycle 95: the sixth legend row (-1wx0)

- Value: **warranted** — one question, and it is the entire design of the row.
  - Expected: whether a heavier bracket reads as *the same mark with a warning on it* rather
    than as a different symbol. No assertion answers that.
  - Got: it does. Through the pause door, the armed row's red brackets are visibly heavier
    than row one's yellow ones and the two read as a pair. All six rows sit inside the 300 px
    matte with room below. And the provenance line updated itself to "6 of the board's 10
    marks" with no second edit, because cycle 91 wrote it against `CueLegend.row_count()` —
    a seam taken up front, paying four cycles later.
  - Found: **the bead's constraint was wrong in the direction that makes work cheaper.** It
    said the five rows sit at the edge of the matte, so a sixth needs `ROW_PITCH` cut or a
    second page. Derived from `CueLegend`'s own constants rather than eyeballed: five end at
    248 of 300, six at 294, seven at 340. It fit at the existing pitch. "At the edge" was an
    impression written into a bead, and acting on it would have bought a second page nobody
    needed — the mirror image of the last three cycles, where a wrong premise made work look
    *necessary*. Also: cycle 91 closed `-bxhg` without meeting one clause of its own
    acceptance, which nothing noticed until I went looking for a place to record what is
    taught.
  - Cheaper: nothing for the drawing. Everything else this cycle came from arithmetic over
    constants, which is the cheap half and was the half the bead skipped.

- Gap: **`verify_ledger record` has no way to say a check was about a PICTURE.** Four cycles
  running the decisive runtime evidence has been a screenshot judged by eye — the husk pips
  (88), the flight tip's width (90), the legend's five swatches (91), the armed bracket's
  weight (95). Each is recorded as a `checks` entry with `"result": "pass"` and a prose note,
  which is indistinguishable in the row from an assertion that ran.
  That matters for the ledger's own purpose. `stats` counts passes; it cannot separate "a
  gate returned 0" from "a person looked at a PNG and was satisfied", and the second is the
  one that does not survive being wrong. It is also the only kind of check this project
  cannot re-run — the artefact is in `user://screenshots/` and the row does not name it.
  - [G-070] status: open | seen: 1 | harness: 0.38.0
  - Improvement: an optional `"evidence"` field on a `checks` entry carrying the artefact
    path, plus a `"judged": "eye"` marker distinguishing a human verdict from a mechanical
    one. Then `stats` can report "N of M runs rest on a judged check", which is a number
    worth watching in a project whose most player-facing work is exactly the work no
    assertion covers. The screenshots already have stable paths; nothing is being asked to
    exist that does not.
  - Note: no other gaps this turn.

  - [G-070] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#56 | note: reconciled
    against the installed 0.54.0 before filing. `evidence` exists at
    `templates/tools/verify_ledger.py:170` but only as an ALIAS for the whole `checks`
    array (`RUN_JSON_ALIASES`), not as a per-check artefact path, and there is no `judged`
    concept anywhere in the file. Filed with the four-cycle table (88, 90, 91, 95) as the
    evidence, since one screenshot-judged check is a habit and four in a row is a ratio.

## 2026-08-17 — Cycle 96: retiring a line the player has read (-gtne)

- Value: **warranted**, and the run's most useful output was a number that would have closed
  the bead wrongly if I had stopped reading it.
  - Expected: the bead said measure first, and I expected a small non-zero — some rate of
    resumption per wave.
  - Got: **zero**, across six waves, 54 kills, eight lives lost, 257 seconds, with
    `run_seconds` moving as a witness (cycle 93's rule, applied deliberately). And that zero
    is honest and useless: every pre-empting call site is a **player action** — arming an
    uproot, opening a seed packet — and six waves of driving the wave director contain
    neither. One `arm_uproot` over a live message gave `messages_preempted` 1 first try.
  - Found: two, and the second is about a test of mine that was green while asserting
    nothing.
    **"Measured in a real run" measures the game, not the player.** A run driven by starting
    waves exercises what the game does to itself. If the behaviour under test is triggered by
    something the player does, that run measures zero and the zero looks like an answer. This
    also retroactively weakens cycle 93's `-i366` result, which was the same shape of run with
    the same absence of player actions — noted in `kanban.md` and filed, because the counters
    still exist and the re-measurement is cheap.
    **A boundary assertion computed by subtraction does not test the boundary.**
    `line_was_read(4.0, 4.0 - MESSAGE_MIN_READABLE)` computes `4.0 - 2.8 = 1.2000000000000002`,
    strictly greater than `1.2`, so it passed under both `>=` and `>`. A mutation flipping the
    comparison survived, which is the only reason I know. Rewritten as
    `line_was_read(MESSAGE_MIN_READABLE, 0.0)`, which subtracts exactly.
  - Cheaper: nothing. The counter had to exist before the question could be asked — the same
    shape as `-i366` three cycles ago, and this time the instrument outlived the question.

- Gap: **the ledger's `blocked` result works exactly as designed and I had never seen it, which
  is worth logging as a success rather than a defect.** The unread-then-displaced scenario lost
  its selection live and was never driven, so I recorded that check as `"result": "blocked"`:
  ```
  verify_ledger: verdict downgraded pass -> partial: blocked check(s) unread-then-displaced,
  live - a check that could not run is not a check that passed
  ```
  Nine cycles of recording rows and this is the first `partial` I have produced. The downgrade
  is right, the message says why in one line, and the row now carries a verdict I cannot read
  later as a clean pass. **No gap here** — recorded because the harness's own logging rule asks
  for what was missing, and "nothing was missing, and here is the mechanism that caught me
  being sloppy" is the more useful entry when it is true.
  - Note: no gaps this turn. The one thing I would change is mine, not the harness's: I drove
    the scenario without re-checking the selection had survived the previous step, which is
    the same class as cycle 94's "I killed the plant I was clicking".

## 2026-08-17 — Cycle 97: the two-channel enumeration (-vxq6), and a heredoc that ate a backslash

- Value: **warranted**, and entirely from Phase 1 — no runtime, correctly (Phase 0.5 tier (b):
  one `.md`, one GDScript comment, one test change).
  - Expected: a docs cycle. Write a verdict per cue, add a comment, done.
  - Got: `suite_reach_check` reporting four symbols as unnamed by any test while all four
    were plainly named in real code at lines I could point at. I spent several minutes
    treating that as a checker bug — probing `strip_comments`, checking line endings, reading
    `STRING_RE` — before bisecting with `git stash push <one file>` and finding it was mine.
  - Found: **I wrote GDScript through a shell heredoc and it ate a backslash.**
    `section.find("\n## ", 1)` landed in the file as a literal newline inside the string:
    ```
    	var stop: int = section.find("
    ## ", 1)
    ```
    Godot accepts it, the behaviour is identical, **613/613 passed and lint reported 0/0**.
    `blank_strings` correctly treated the remaining 1018 characters as one string body, so
    every symbol after that point was genuinely invisible to the scan. The checker was right
    and looked wrong, which is the hardest shape for a finding to arrive in.
    `CLAUDE.md` step 2 forbids exactly this, in those words, and names four prior occurrences
    where a heredoc stripped leading `#` from comment blocks. This is the same mechanism
    reaching a different target, so the standing count understates it.
  - Cheaper: nothing. Every cheaper gate agreed with me — that is the point. The suite passed,
    lint passed, the code ran and produced the right answer.

- Gap: **nothing missing from the harness this turn, and one thing worth recording as working.**
  The bisect that found this was `git stash push -q <one file>` then re-run, then `stash pop`
  — ten seconds, and it converted "the checker is broken" into "my edit did this" with no
  reasoning at all. That is not a harness feature and needs no harness feature; it is worth
  writing down because I reached for source-reading first and the bisect second, in that
  order, and the order was wrong.
  The one thing I would ask of `suite_reach_check` is smaller than a gap: when a symbol is
  reported unreached **and the raw text of a test file contains its token**, say so —
  "`row_count` appears in `test_placement.gd` but only inside a blanked region" would have
  named the cause in the first line of output instead of the twentieth minute. The data is
  already in hand; both the raw and the blanked source are held at that point.
  - [G-071] status: open | seen: 1 | harness: n/a (project checker, tools/suite_reach_check.py)
  - Improvement: as above — compare against `raw` when reporting, and add one clause when the
    token is present there but absent from `blanked`. It is the difference between a finding
    that accuses the test suite and one that accuses the file's syntax.

## 2026-08-17 — Cycle 98: a sixth plant, and the panel that cannot sell it (-zhq9)

- Value: **warranted**, and this is the clearest case in twenty cycles — three of the run's
  findings could only come from a running game, and two of them decided the cycle.
  - Expected: build a plant, place it, watch a neighbouring Corn fire faster. A feature cycle.
  - Got: that, and then `findings` reporting **7 gating findings** — `ui_overflow` on the
    plant bar and three of its buttons, the side panel 167px past the right edge of the
    viewport. Nothing in Phase 1 saw it: 617/617 passed, lint 0/0, eleven checkers clean.
  - Found: three, and I would not have believed any of them from reading.
    **The sprite was drawn in the lawn's own colour.** First cut used `#2ECC71` for the
    leaves; `GardenTheme.LEAF` is `Color(0.180, 0.800, 0.443)` — the same hex. The plant
    vanished into the grass. A screenshot caught it, and **no gate compares a sprite against
    the ground it stands on** — `svg_style_check` passed it, because the palette is legal.
    **The panel is full and said so in advance.** `hud.gd`'s `PLANT_BAR_BOTTOM` comment
    prices it exactly and ends "the next plant runs into it". Five plant buttons sit at
    exactly the 40px touch floor.
    **The ScrollContainer rescue does not work, and the measurement is the point.** I assumed
    `interactive_overlap` between a scrolled-out button and the packet button was an artefact
    — the harness compares rects and cannot model scrolling. So I tested it: a real
    `cmd touch_press` at (1020,356), inside both rects, was answered by **neither** button.
    Seeds unchanged, selection unchanged. The packet button was genuinely unclickable where
    the clipped button covered it. That turned an opinion into a revert.
  - Cheaper: nothing. The colour needed a frame, the overflow needed a live layout, and the
    click needed a click.

- Gap: **`findings` reports `ui_overflow` against the VIEWPORT, and the thing that actually
  overflowed was a panel.** The message reads
  `GridContainer 'PlantBar' extends past viewport (rect: 908,116 -> 1319,332, viewport:
  1152x648)`. True, and it names the outermost boundary rather than the nearest one. The bar
  is a child of a 256px-wide `SidePanel`; it broke that first, by 167px, and the viewport
  only afterwards. A reader chasing "past the viewport" looks at screen size and anchors; the
  actual fix was in a container three levels in.
  The harness already ships the verb that answers this — `contained-in --node PATH --within
  PATH` reports per-side overhang, and `findings` surfaces the same idea as
  `ui_escapes_panel` for a **sibling** panel. What it does not do is check a Control against
  its own ANCESTOR, which is the containment a layout bug most often breaks.
  - [G-072] status: open | seen: 1 | harness: 0.38.0
  - Improvement: when a Control overflows the viewport, walk up its ancestors and report the
    NEAREST Control it also escapes — `extends past its parent 'SidePanel' by 167px (and the
    viewport)`. The walk is a few lines, the rects are already in hand, and it changes the
    finding from a symptom into a location. The current message is not wrong; it is just the
    least useful true thing available.
  - Note: no other gaps this turn.

## 2026-08-17 — Cycle 99: the bar was a content problem (-wb3r, and -zhq9 released)

- Value: **warranted**. Two numbers decided the cycle and both are properties of a live layout.
  - Expected: a hard UI problem needing a redesign — the bead priced four options and refused
    the cheap ones.
  - Got: `get_minimum_size()` on a plant button, **195x31**, against the 114px a two-column
    bar can give. That one read reframed the whole thing: the fix was in the button, not the
    bar. After taking the name off, **8x8** — and `findings` 0 across 5 of 5, exit 0, on the
    board that reported seven gating findings last cycle.
  - Found: **`screenshot --region` takes OUTPUT pixels while `node-bounds` reports VIEWPORT
    coordinates.** This window renders 2880x1779 for a 1152x648 viewport — a 2.5x scale — so
    three captures came back showing grass at coordinates `node-bounds` had just handed me. I
    only noticed by taking a full-frame shot and reading its size. Same coordinate-space class
    as cycle 85's board bug and cycle 90's Entities offset, in a third place.
  - Cheaper: nothing. Whether six icons read apart is a screenshot question by construction,
    and the minimum-width number does not exist until the theme has resolved a font.

- Gap: **`screenshot --region` and `node-bounds` speak different coordinate systems and
  neither says so.** `node-bounds` prints "Size from: get_global_transform_with_canvas() x
  Control.size (screen space)" — which reads as though it matches what a screenshot would
  capture, and on a 1:1 window it does. Here it does not, and the failure is silent: you get a
  valid image of the wrong place.
  The harness knows the scale — `canvas-scale --node` exists and reports it — so the data is
  in hand at the moment of the capture.
  - [G-073] status: open | seen: 1 | harness: 0.38.0
  - Improvement: have `screenshot --region` report the scale it applied when the window is not
    1:1 — `Cropped to: 2270,290 580x545 (viewport 908,116 232x216 at 2.5x)` — or accept the
    region in viewport coordinates with a `--pixels` flag for the raw form. Either ends the
    class. The one-line version is cheapest: print the scale whenever it is not 1.0, so the
    mismatch is visible in the reply that produced the wrong image.
  - Note: no other gaps this turn.

  - [G-072] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#57 | note: reconciled
    against the installed 0.54.0 before filing — `dev_tools.gd:3915` still formats
    `"%s '%s' extends past viewport"` with no ancestor walk.
  - [G-073] status: open | seen: 1 | harness: 0.54.0 | upstream: gh#57 | note: same issue,
    filed first because it is the worse of the two: `devtools.py:1144` prints
    `Cropped to: x,y wxh` with no scale, so a region taken from `node-bounds` produces a
    valid PNG of the wrong place and no error. Filed together because they share a shape —
    a reply that is true, is the most general true statement available, and sends the reader
    to the outermost cause when the specific one was already computed.

## 2026-08-17 — Cycle 100: three lanes in parallel (-eeaq, -4du6, -l4ke)

- Value: **warranted**, and the runtime pass answered a question three agents each said
  outright they could not: whether their sprites read on the surfaces they stand on.
  - Expected: a merge, a suite run, and two screenshots.
  - Got: **five integration failures**, none visible to the agent that caused it, each a fact
    about a file that agent was correctly forbidden to touch. Then a single frame settling
    three separate open questions at once — `wave_count 22`, the Nettle's orange unmistakable
    on a green lawn, the Shield Bug's blue-grey plate unmistakable beside two plain red
    aphids on a tan road, and the plant bar holding **seven** at two columns of four.
  - Found: the two sprite-colour choices were both reasoned and unseen — one agent wrote "my
    colour choice is reasoned, not seen" and the other said the same in different words. Both
    were right, and that is the argument for the parent keeping the runtime pass rather than
    delegating it: an agent that cannot launch the game cannot check the one thing about a
    sprite that matters.
  - Cheaper: nothing. All eleven parallel-safe checkers were clean in all three lanes; the
    failures live exactly where those checkers cannot look.

- Gap: **`screenshot --region` is not a uniform scale of the viewport, and gh#57 asked for
  the wrong fix.** Cycle 99 filed [G-073] proposing that the verb print the scale it applied.
  This window is 2880x1779 for a 1152x648 viewport: 2880/1152 is 2.5 but 1779/648 is 2.745,
  so it is **letterboxed** and there is no single scale to print. Two region captures came
  back showing road at coordinates `node-bounds` had just given me, and I fell back to a
  full-frame capture — which is what actually worked, twice, in two different cycles now.
  - [G-073] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#57 | note: **the proposed
    fix in gh#57 is insufficient and I should say so on the issue.** Printing "2.5x" would
    have been wrong here. The honest fix is either to accept the region in VIEWPORT
    coordinates (every other spatial verb does) or to print the full mapping including the
    letterbox offset. Second sighting bumps the count rather than opening a new id.
  - Improvement: comment on gh#57 with the non-uniform case before a maintainer implements
    the simpler thing. Filed as a bead so it is not lost.
  - Note: no other gaps this turn.

## 2026-08-17 — Cycle 101: the campaign played end to end, three parallel lanes merged

- Value: **warranted** — runtime produced two claims the diff could not, and one of them was a
  defect that every headless gate passed.
  - Expected: that driving a full campaign would tell me whether the 22 waves are balanced,
    and that the merge of three lanes would need the usual integration repairs.
  - Got: two complete playthroughs whose only policy difference was where surplus seeds went.
    Breadth-first (eleven level-1 plants, never upgraded) died at wave 10. Depth-first
    (upgrade what is already down) won all 22 waves and **never lost a life** — 591 pests,
    ending on 1129 spare seeds. Same unlocks in both: all seven plants by wave 7.
  - Found: **`devtools_ext/commands.gd`'s `_cmd_upgrade_plant` answered `success: false` with an
    EMPTY message after successfully upgrading a Chomp Flower.** It cast the result to
    `CornCobbler` and read `corn.level` off a null, so the handler died *inside the reply* —
    which is indistinguishable from the game refusing the upgrade. `find-nodes --class
    ChompFlower --property level` said `level=2`: the upgrade had landed. Nothing headless can
    see this. The cast resolves, so `name_check` passes; it compiles, so lint passes; no test
    drives a debug verb, so the suite passes. It was reachable only once a second plant became
    upgradable, and only from a running game. Fixed in this run.
    Also found: the wave-8 tuning below, confirmed against a live campaign rather than against
    the table — the breadth policy that died at wave 10 reached wave 17 after the change.
  - Cheaper: nothing. The verb defect is a null cast on a branch only a running game with a
    non-corn upgradable plant reaches, and "is the campaign balanced" is a question about a
    played campaign. Reading the diff would have shown the cast and read it as correct, because
    it was correct for the whole time corn was the only plant with a ladder.

- Gap: **`run_json_check.py` is only useful strictly BEFORE `verify_ledger record`, and running
  both in one shell command is functionally "after".** I piped them together; the checker
  correctly reported `FINDING: 'verdict' is absent -- record defaults it silently, so the row
  will read as an unknown/blank run rather than as the clean one it was`, and the row had
  already been appended by the time I read it. The ledger is append-only, so the row now says
  `recorded unknown run, value=warranted` and re-recording would double-count a single run.
  `verify_ledger` also warned `warranted with no Phase 4 checks recorded - the claim that
  earned it is not in the row`, which is the same shape of loss: the defect above is in `found`
  but the check that caught it is not a recorded phase-4 entry.
  - [G-074] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `verify_ledger record` should run the same key check itself and refuse to
    write a row that fails it, rather than defaulting the field and reporting the loss after
    the append. A checker whose whole value is "run me first" is one an operator can only
    fail once per row, permanently. Failing that, `record` could accept `--dry-run` so the
    validate-then-write pair is a single safe operation.

- Gap: **a parallel-safe checker in a SHARED checkout reports the other lanes' in-flight edits
  as its own findings.** The Nettle lane reported `suite_reach_check exit=1` with 12 NEW
  findings in `game/board.gd`, `game/garden_theme.gd` and `game/plant.gd` — none of which it
  had touched; all three were siblings' uncommitted work. It correctly diagnosed this itself
  ("which `git status` shows are other lanes' in-flight edits in this shared checkout"), but
  only because it thought to check. A lane that trusted the exit code would have reported a
  false failure, and a lane that saw exit 0 by luck of timing would have reported a pass it
  had not earned.
  - [G-075] status: open | seen: 1 | harness: 0.38.0
  - Improvement: this is mine to fix in the workflow, not the harness's — either fan out into
    git worktrees (`isolation: "worktree"`), or tell each lane that a finding in a file it does
    not own is not its finding. The cheaper half is the instruction; the correct half is the
    worktree. Filed as a bead.

## 2026-08-17 — Moved the loop out of CLAUDE.md into /cycle (docs-only, no game launched)

- Value: **inconclusive** — the harness was not used; the change moved 411 lines of prose
  from `CLAUDE.md` (and its `AGENTS.md` mirror) into `.claude/skills/cycle/SKILL.md`. No
  script, scene or gameplay changed, so nothing was there for a runtime pass to reach.
  - Expected: nothing to verify at runtime; the only gates with a category for this are
    `mirror_check.py` (the pointer block in both files) and `citation_check.py` (the one
    `file:line` inside the moved text).
  - Got: `mirror_check: CLAUDE.md 9 line(s)/639 chars, AGENTS.md 9 line(s)/639 chars,
    identical` after `--fix` regenerated AGENTS.md's copy; `citation_check: 1 citation(s)
    ... 1 resolved, 0 finding(s)`. `git diff --numstat` read `7 409` for each of the two
    instruction files and `425 0` for the skill — the shape of a move, not a rewrite.
  - Found: nothing.
  - Cheaper: this was already the cheapest path — two stdlib checkers and a diff-stat read.

- Gap: no gaps this turn. (`mirror_check`'s "block is only N characters" stub note is
  sized at 200 and the pointer is 639, so the smaller mirrored block does not trip it;
  worth knowing if the pointer is ever trimmed.)

## 2026-08-17 — Renamed the title screen to "Pest Control" (headless-only tier)

- Value: **overkill** — a one-word Label text change; the headless suite already hosts `title.tscn` six times, so a seventh test pinning the name and `_T.text_width` < band width answered the only real question without a launch.
  - Expected: nothing runtime-only: a one-word Label text change; the only question is whether it fits, which text_width answers headlessly
  - Got: `[PASS] test_title_screen_is_named_pest_control` — text reads "Pest Control", width < 1152; capture.gd (windowed, 4 frames) shows it centred at 54px. 655/655, 13569 assertions, Suite: 7.
  - Found: nothing (the `:=` on `_T.text_width(...)` parse error was my own new test, caught by lint as name_check's NOT COVERED line predicted)
  - Cheaper: `run_tests.py --filter pest_control` alone plus the capture, ~50s vs the full ~4 min gate set.

- Gap: no gaps this turn.

## 2026-08-17 — Extracted Gather's itch.io deploy workflow into the `itch-ci-deploy` skill; installed it here

- Value: **overkill** — no runtime, no bridge; nothing here touches the game tree.
  - Expected: nothing from the harness — this is a CI/workflow + skill-authoring change.
  - Got: `scaffold_itch_deploy.py . --target severalherr/plant-tower-defense:html5` wrote `export_presets.cfg` (preset.0 Web, thread_support=false) and `.github/workflows/deploy-to-itchio.yml`; diff against Gather's proven file shows only the parameterisation.
  - Found: nothing (no local 4.7 web templates, so the export itself is unproven until CI runs).
  - Cheaper: this was already the cheapest path.

- Gap: no gaps this turn — the harness has no CI/export role and was not asked to have one.
  - [G-000] status: n/a | seen: 0 | harness: (not consulted)

## 2026-08-17 — Five lanes in worktrees: rain, attacks, top bar, packets, speed (+2 parent items)

- Value: **warranted** — the merge produced five claims the diff could not, and every one of them was a fact about a file some lane was correctly forbidden to open.
  - Expected: that the lanes would come back green and mean little, because a fresh worktree has no `.godot/` and so a lane compiles nothing; and that the top bar would not fit the speed button, which lane E measured at -48px before the merge existed.
  - Got: `685/685, 14374 assertions, Suite: 7`; `lint: 0 error(s), 0 warning(s)`; `findings: 0 finding(s) across 5 of 5 checks` **twice** (bare board, then with plants and pests live); live `hud_stats_row` reads `1074 of 1112 px -- 38 px left`; `_rain_phase` 0 -> 115.5 -> 465.6 under a forced rain wave; Chomp `_bite_lunge` (-3.45,-6.09) then (0.15,-7.00), both length 7 = LUNGE_DISTANCE; Nettle `_sting_lean` 0.154 -> 0.083 -> -0.135.
  - Found: **five, all fixed in-run.** (1) Two of lane v104's direction tests were green-by-construction impossible — the prey sat in range during `instantiate_scene`'s settle frames, so the Chomp had already eaten (lunge (-6.615,-2.290), which is that exact aphid at full LUNGE_DISTANCE) and the Nettle had already stung (lean 0.1703) before the "has not attacked yet" precondition was read. (2) The stats row had 1160px of contents in a 1112px row. (3) Three public surfaces were NEW in `suite_reach_check` after the merge — `hud.speed_requested`, `plant_button_tint`, `plant_button_tooltip` — each a lane's API whose only caller lived in a parent-owned file. (4) `citation_check` reported every bare citation in `kanban.md` ambiguous, because the five lane worktrees live INSIDE the repo and `rglob` found six copies of every file. (5) `game_speed.gd` ran provably — the button cycled `Engine.time_scale` three times under my hand — and `reach` still recorded it NOT reached.
  - Cheaper: nothing. Three of the five are invisible without the compiler or a running game, and the two a lane could in principle have caught are the two it was forbidden to look for.

- Gap: **`name_check.py --require-compile` is unusable in a fan-out worktree, and fails LOUDLY rather than saying it could not run.** Two lanes hit it independently and neither was told anything true. Lane A: `python tools/name_check.py --require-compile game/weather_overlay.gd` -> exit 1, `does not compile: SCRIPT ERROR: Parse Error: Identifier "WaveDirector" not declared in the current scope ... at res://game/weather_overlay.gd:56` — a line unchanged from `main`. Lane B on its three files: `Could not find base class "Plant"`. Both are the documented "needs the project imported once already" case: a fresh worktree has no `.godot/global_script_class_cache.cfg`, so every cross-file `class_name` false-positives. Workaround: none — the lanes reported "names resolve, this is not a compile" and the parent ran `import_check.py` + `lint_project.gd` + `run_tests.py` once after merging. **The cost is that five lanes each shipped green having never parsed a line.**
  - [G-076] status: open | seen: 2 | harness: 0.38.0
  - Improvement: `name_check.py` ALREADY reads `.godot/global_script_class_cache.cfg` and returns `None` when it is absent (0.60.0, line ~782-790, `"""class names in .godot/global_script_class_cache.cfg, or None when absent."""`). `--require-compile` just does not consult it. So: when the cache is absent and `--require-compile` was asked for, exit **2 "could not run — this project has never been imported, so every cross-file class_name will report as undeclared"** instead of exit 1 with fabricated `compile_error` findings. That is the harness's own exit-code contract (`2` = nothing was verified) applied to the one case where it currently lies. Confirmed still open in 0.60.0, not just in the 0.38.0 this project pins.

- Gap: **`reach` cannot see a static-utility script, and this is now costing a wrong verdict rather than a missing one.** `game/game_speed.gd` is `class_name GameSpeed extends RefCounted`; no node carries it, so `scripts-seen` cannot see it however much of it ran. I pressed the button, watched the label go 1x -> 2x -> ½x -> 1x and `Engine.time_scale` follow each time, and the ledger still recorded `NOT reached: game/game_speed.gd`. CLAUDE.md documents the fix (`DevTools.mark_script_reached`) and I applied it — but that is a per-file manual opt-in, so the ledger's honesty scales with how many static utilities somebody remembered to annotate.
  - [G-077] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `reach` already knows a file is in the diff and already knows it is not in the tree. When a changed `.gd` declares `class_name` and `extends RefCounted`/`Object` (statically visible, no engine needed), report it as **`unreachable-by-construction`** rather than folding it into `NOT reached` — the same three-way split the harness uses everywhere else (`reached` / `not reached` / `could not be reached`). A file that CANNOT be seen and a file that WAS NOT loaded are opposite results, and today they print identically.

- Gap: **a tree-walking checker sees N+1 copies of the repo during a worktree fan-out, and only the PARENT sees them.** `citation_check.py` resolves a bare filename by unique basename anywhere under the root; `rglob` does not read `.gitignore`; `.claude/worktrees/` is gitignored but very much on disk. Result: `FINDING: kanban.md:3713 cites plant.gd:187-190 -- that bare name matches .claude\worktrees\agent-a287093c5954505ba\game\plant.gd and ... and game\plant.gd.` for every bare citation in the file. A lane running the same checker inside its own worktree sees nothing wrong. Fixed in-project by excluding `worktrees` from the walk: `296 citation(s) across 1 file(s), 296 resolved, 0 finding(s)`.
  - [G-078] status: open | seen: 1 | harness: 0.38.0
  - Improvement: this is a project-owned checker so the fix landed here, but the shape is the harness's problem too — anything that walks the repo root during a fan-out inherits it. The harness should either ship a shared "repo files, excluding nested worktrees and `.godot/` and `.git/`" walker for its checkers to use, or `scaffold-godot-harness` should warn when it detects `.claude/worktrees/` inside `scan_root`. A findings count that changes depending on whether sibling agents happen to be running is worse than no count.

## 2026-08-17 — Deployed Pest Control to itch.io (severalherr/pest-control), built the store page, caught the entry_hook firing for players

- Value: **warranted** — the bridge set up a 20-plant, 15-pest board for store screenshots in a clean worktree (`launch --isolated`, `place_plant`/`spawn_pest`/`add_seeds`, `screenshot --hide /root/Game/HUD`) while the main checkout was mid-merge and unrunnable; and running the *exported* build on itch.io produced a claim no diff or gate could — `entry_hook` (`skip_to_game`) fires in template builds, so players never saw the title screen.
  - Expected: screenshots; the export to "just work" once butler had a key.
  - Got: `entry_hook: fired` on ping (correct, editor launch); on itch the embed opened straight on the board with `Seeds 25 Wave 0/22`; after gating `_passive` on `OS.has_feature("template")` the embed opens on the title screen (`Pest Control · Start · 8 waves`). Patched autoload: `--check-only` clean, `run_tests.py` 658/658, `Assertions: 13945`, ping still `entry_hook: fired` on an editor launch.
  - Found: the shipped-build defect above (fixed in 91b24eb; upstream godot-selftest-harness#58).
  - Cheaper: nothing — only running the exported build shows what a template build does with the autoload.

- Gap: **the harness has no notion of "exported build"** — `dev_tools.gd` gates only on `--script`; an itch/web export polls the bus and fires `entry_hook` for players. Workaround: local patch gating `_passive` on `OS.has_feature("template")` with `-- --devtools-force` opt-in.
  - [G-120] status: open (upstream #58) | seen: 1 | harness: 0.60.0
  - Improvement: the diff in #58; plus a lint line "entry_hook configured AND an export preset exists — confirm the template build stays passive".
- Gap: **`launch --isolated` prints no client-side follow-up that works** — subsequent verbs needed `--session <id> --userdata <bus_dir>` read out of `.devtools/launch.json`; `GODOT_DEVTOOLS_BUSDIR` is honoured by the game, not by the client, and `--session` alone still polls the default `user://`.
  - [G-121] status: open | seen: 1 | harness: 0.60.0
  - Improvement: `launch --isolated` should print the exact `python tools/devtools.py --session X --userdata <bus_dir> ping` line, and the client should read `GODOT_DEVTOOLS_BUSDIR` (or `.devtools/launch.json`) as its bus dir when `--session` is given.

## 2026-08-17 — Replaced the itch banner and cover with the game's own title screen

- Value: **warranted** — the bridge turned the live title scene into store art: hid the five menu Controls and two labels via `set-state visible`, moved `TitleLabel`/`SubtitleLabel` down and re-spaced the seven `Plant_N` sprites with `set-state position` (whole Vector2), `screenshot`, then cropped 960x400 / 630x500 with Pillow. No composited text, no pixel font — the page now reads as the game.
  - Expected: a usable frame in one or two captures.
  - Got: `banner_src2.png 1152x648`; new banner id 29345385, cover id 29345415 (og:image confirms).
  - Found: nothing.
  - Cheaper: nothing — the art had to come from the running scene.

- Gap: no gaps this turn. (`set-state --property position.x` correctly refuses on a Vector2 and names the fix; that message is what made it one retry, not three.)

## 2026-08-17 — Cycle 103: the game finally says that upgrading exists (-gz53)

- Value: **warranted** — two defects, neither visible in the diff, and one of them found by a static gate before a single test ran.
  - Expected: that the tests would pin the milestone and say nothing about whether a player ever sees the sentence, and that the interesting failure would be in WHEN the hint fires rather than whether.
  - Got: `687/687, Assertions: 14393, Suite: 7`; `lint: 0 error(s), 0 warning(s)`; `findings: 0 finding(s) across 5 of 5 checks` unpaused after `wait-frames 60`; and at runtime `has_milestone("seen_upgrade_tip")` **false at 19 seeds, true at 20** — that cob's exact `upgrade_cost()` — with the row reading `Your Corn Cobbler can be upgraded. Click it on the board — 20 seeds.`
  - Found: **three.** (1) `save_persist_check` printed `chain: place_plant() -> _refresh() -> _maybe_teach_upgrading() -> spend_hint() -> _save()` and named two tests in `test_board.gd` that walk it — a file that had never written to `RunConfig`, had not changed by one line, and had just become a writer of the developer's real `user://highscore.save`. (2) The hint would have been shown up to `MESSAGE_QUEUE_MAX` times rather than once: `show_message` returns `false` on a busy row but **queues** the arriving text instead of dropping it, which is right for the edge-triggered `_on_flight_ignored` and wrong for a level-triggered caller on the `_refresh` funnel, where affordability stays true and every later refresh stacks another copy. Fixed with `Hud.row_is_quiet()`. (3) The corpus tripwire caught the per-plant entry count moving 5 → 6.
  - Cheaper: for the save chain, nothing beats the one second `save_persist_check` took. The double-post needed reading `show_message`'s return contract against a level-triggered caller — no gate has that — and only the live row proved the sentence renders at all.

- Gap: **`launch --snapshot-userstate` did not restore the file it snapshotted.** Launched with it precisely because this cycle's feature writes `user://` (a one-shot hint calls `RunConfig._save()`), drove the hint, and after `quit` the developer's real `highscore.save` still read `m1:seen_upgrade_tip` where it had been `m0`. `quit` reported the pids and printed no restore line at all. I put it back by hand — the milestone line is length-prefixed (`m0` is the documented empty form, `run_config.gd:84-90`) and the scores either side of it, `3454` and `5008`, are the player's real ones, so a wrong restore here would have been silent data loss rather than a broken save.
  - [G-122] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `quit` already prints `user://: no file changed during this run` when nothing moved — that line is the natural place for the other outcome, and it printed the *clean* wording on a run that had in fact changed a file, which is worse than silence. So: when `--snapshot-userstate` is in force, `quit` must say per file whether it was unchanged, restored, or **failed to restore**, and exit non-zero on the third. As it stands the flag's failure mode is indistinguishable from its success, and the whole reason to reach for it is that you already know the run will write.

- Gap: **no gap for the double-post, and that is worth saying rather than leaving blank.** The defect was in this project's own code, not the harness, and no zero-config check could have had an opinion — it is a contract between two of our functions. `save_persist_check`, a project checker written to `house-static-checker`, is what caught the other one. That is the harness's own argument working: the generic checks cover the generic failures, and the project grows its own for the rest.

## 2026-08-17 — Filed four beads from a user bug report; no code changed

- Value: **inconclusive** — the harness was not run, because nothing was built or changed.
  - Expected: nothing; this turn was static reading (grep/sed over `game/hud.gd`,
    `game/board.gd`, `game/game.gd`, `project.godot`) to ground four bug reports in
    `file:line` citations. No gameplay, script, or scene change, so the DEVELOPMENT RULE's
    `/verify` trigger did not fire.
  - Got: nothing from runtime. Every claim in the four beads is a static one and is
    labelled as such — `twbt` explicitly makes "confirm which suspect with a cropped
    `screenshot` before fixing" its first acceptance criterion rather than asserting the
    cause, precisely because reading the code cannot distinguish a corner-normal
    discontinuity from a non-integer-scale tile seam.
  - Found: nothing — but reading found something a run would not have: `game.gd:1678`
    handles no `InputEventScreenTouch`/`ScreenDrag` at all, so the reported "click and drag
    is awkward" describes an interaction that does not exist. A live session would have
    shown mouse emulation working and hidden the absence.
  - Cheaper: nothing cheaper than what was done. `grep -n` over four files was the whole
    cost and produced every citation in the beads.

- Gap: **no gaps this turn** — the harness was not exercised, so it had no opportunity to
  fall short. Nothing to file.

## 2026-08-17 — Filed two animation beads (Chomp meal, Nettle sting); no code changed

- Value: **inconclusive** — the harness was not run, because nothing was built or changed.
  - Expected: nothing from runtime. This was intake, not implementation: a static read of
    `game/chomp_flower.gd`, `game/pest.gd`, `game/nettle.gd`, `test/unit/test_combat.gd` and
    `art_src/*.svg` to ground a two-sentence user report. No gameplay, script or scene edit,
    so the DEVELOPMENT RULE's `/verify` trigger never fired.
  - Got: nothing from the bus. Two NON-devtools gates did run and both matter:
    `bead_prose_check.py` -> "0 finding(s) gating", confirming no shell-eaten prose in the
    new beads; `citation_check.py` -> "298 citation(s) across 1 file(s), 298 resolved".
  - Found: **yes, two things a clean read would have missed.** (1) `citation_check.py`
    reports clean while checking only `kanban.md` — it does not read beads at all, so it
    offered no protection over the 20-odd citations I had just written. Hand-checking with
    `sed -n 'Np'` then caught three genuinely wrong line numbers (`nettle.gd:309`->308,
    `:319`->326, `chomp_flower.gd:436`->438), all fixed before the beads were finalised.
    (2) The Chomp's victim keeps running `_gait()` while held (`pest.gd:845`) — the bug
    walks on the spot inside the jaws. That is the actual content of the user's complaint
    and no screenshot would have named the cause.
  - Cheaper: nothing. `grep`/`sed` over five files was the whole cost. A live session would
    have been strictly worse here — it would have shown the animations playing and hidden
    the absence of any victim-side change, which is the finding.

- Gap: **`citation_check.py` reads only `kanban.md`, so bead citations are ungated** — ran
  `python tools/citation_check.py`, got `298 citation(s) across 1 file(s), 298 resolved,
  0 finding(s)` immediately after writing ~20 fresh `file:line` citations into three beads,
  three of which were wrong. The exit-clean is honest about its scope only in the tool's own
  `NOT COVERED:` line, which does not mention which files it read. Workaround: hand-checked
  every load-bearing citation with `sed -n 'Np' FILE`.
  - [G-123] status: open | seen: 1 | harness: (client version not queried; no bus opened
    this turn — `harness-version --client` not run because no harness command was used)
  - Improvement: have `citation_check.py` print the files it scanned (`scanned: kanban.md`)
    so a clean exit cannot be mistaken for coverage it does not have, and add a `--beads`
    mode reading `.beads/issues.jsonl` description/design/notes fields with the same
    resolver. The scan is textual and the resolver already exists; this is a source-list
    change, not new machinery.

## 2026-08-17 — Cycle 104: four lanes, and the merge found a bug in my own previous fix

- Value: **warranted** — three defects, none visible in any lane's diff, and one of them in code I wrote two cycles ago and had already called fixed.
  - Expected: that the merge would find what the lanes structurally cannot — a lane compiles nothing and runs nothing, and two of these four changed PROCESS-GLOBAL state (`Engine.time_scale`, the save format) whose failures surface nowhere near where they are caused.
  - Got: `705/705, Assertions: 14585, Suite: 7`; `lint: 0 error(s), 0 warning(s)`; `check_all: ran 15 of 15 ... 15 clean`, `CLASSIFIED 23 tools/*.py ... 0 unclassified`; `findings: 0 finding(s) across 5 of 5 checks` unpaused; and at runtime the speed toggle filed `spd1`, survived a quit, and read back `2x` on a fresh launch.
  - Found: **three, all fixed in-run.** (1) Two tests failed on the `-zgzc` merge and **both were right** — the game had genuinely stopped starting at 1x, which is the feature; `GameSpeed._step` is a static var and `RunConfig.game_speed_step` is autoload state loaded from the real save before any `setup()` runs, so the chosen speed is process-global twice over and a `GameSpeed.reset()` at the top of a test is no longer enough. (2) The first suite run after the v6→v7 bump **rewrote the developer's real `highscore.save`** before any redirect could apply, because `RunConfig` is an autoload and `_ready()` beats `setup()` — nothing lost, but `save_persist_check` structurally cannot see it since there is no test function in the chain (`-58u7`). (3) **My own cycle-102 `citation_check` fix was wrong in the opposite direction**: it excluded on an ABSOLUTE path, so run from inside a lane — whose own path *is* `.claude/worktrees/…` — it discarded the entire repo. The parent read `298 resolved`; a lane read `260` and 38 bogus advisories.
  - Cheaper: nothing for any of the three. The isolation failure needed the whole suite in one process, which no lane may run. The save migration needed reading a file no gate reads. And the `citation_check` asymmetry needed the checker executed from inside a worktree AND from the parent — a comparison only the fan-out itself produces, which is why two cycles of running it one way each never saw it.

- Gap: **no NEW harness gap this turn, and that is worth writing rather than leaving blank.** All three defects were in this project's own code and its own checkers, not in the harness — and two of them were caught BY project checkers written to `house-static-checker` (`save_persist_check` printed a call chain last cycle; `check_all`'s classified denominator is what made "14 of 15 ran" legible this cycle). The one harness-shaped observation is that `check_all`'s **denominators** did all the work while its **exit code** stayed 0 through the entire `citation_check` defect: every run was clean before and after, and the only thing that moved was `19 world-space script(s)` → `38` and `298 resolved` → `260`. A gate whose number is the signal and whose verdict is not is exactly what `house-static-checker`'s denominator rule is about, and it held.
  - [G-123] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `check_all --compare-to FILE` — capture the classified denominators to a file, and diff a later run against it. Every check in this cycle's tree-walk audit was "run it twice under different filesystem conditions and see whether the numbers moved", done by hand with `diff` on two captured outputs. One flag would make that a standing check instead of a one-off, and it is the only thing that would have caught the absolute-path regression automatically.

## 2026-08-17 — Cycle 105: the eighth plant, the live viewport, and a checker for rotting claims

- Value: **warranted** — the suite's DENOMINATOR caught a whole script aborting, and the bridge answered the one question no headless test in this project can.
  - Expected: a new plant is mostly bookkeeping — join the hand-lists — so I predicted the gates would find the lists I missed rather than anything about the plant, and that the real question was whether the heal is wired into the frame at all rather than sitting in a class nothing calls.
  - Got: `713/713, Assertions: 14752, Suite: 7`; `lint: 0 error(s), 0 warning(s)`; `check_all: ran 16 of 16 ... 16 clean` (the new checker joined by itself via the contract marker, 15 → 16, with no registration edit); `findings: 0 finding(s) across 5 of 5 checks` at BOTH 1152x648 and 1548x648; and live, a cob set to 10 health beside an Aloe read **20.4 then 35.4** as the game ran, which is `HEAL_PER_SECOND` 3.0 per game second.
  - Found: **three.** (1) A FIFTH hand-list a new plant must join that `-ibvb` does not name — `TitleScreen.PLANT_X` — caught as `Expected 7 >= 8`. Its own header had already done the arithmetic and named the fix in advance: "That is the day to drop PLANT_SCALE or go to two rows." (2) My first Aloe tests used `GAME_SCENE`, which `test_combat.gd` does not declare; the parse error took the whole script down and the suite reported **`Total: 564` against 705** — 141 tests silently absent. The exit code alone would have read as an ordinary failure. (3) Two more copies of `get_viewport_width()` still reading `ProjectSettings`, in `title_screen.gd` and `overlay_screen.gd`, found by the lane that fixed the third and correctly left alone (`-nrup`).
  - Cheaper: nothing. The suite found three of the five list omissions in one run, and only a windowed game could show the side panel staying pinned at 1548 wide.

- Gap: **no new harness gap, and the reason is worth recording.** Everything that went wrong this cycle was caught by something already installed — the suite's `Total:` denominator, `svg_style_check`'s content-box measurement, `suite_reach_check` naming an unreached public symbol in each of two lanes, and `check_all`'s `CLASSIFIED` line moving by exactly one when a checker was added. The one thing a lane still cannot do is compile, and that is `[G-076]`, not a new finding.
  - [G-076] status: open | seen: 3 | harness: 0.38.0
  - Improvement: unchanged — `--require-compile` should exit 2 "could not run" when `.godot/` has no class cache, instead of exit 1 with fabricated `Identifier not declared` findings. Third cycle running that three lanes each reported green having never parsed a line; this cycle it cost a parse error that reached the parent instead of the lane, exactly as predicted.

- Note, not a gap: **`set_resolution` earned its place and I had not used it before.** Lane 0jye's report said plainly that headless cannot answer whether the root window's content-scale override produces the canvas `expand` documents, and handed it over as a named check. Three `cmd set_resolution` calls and three `node-bounds` reads settled it: 1720x720 gives a 1548-wide canvas with the side panel at x 1292 (1292 + 256 = 1548, pinned), and 1024x768 gives 1152x792 — the width floor the whole stats-row budget rests on, confirmed rather than reasoned about.

- Addendum (cycle 105, the audio lane landing later): **`quit`'s `user://` warning fired correctly and named the file**, which is worth recording because last cycle's `[G-122]` is about the flag it then recommends. The run's dial press persisted to the developer's real `highscore.save`; `quit` printed `this run wrote the developer's REAL user data ... changed: highscore.save` and suggested `launch --snapshot-userstate` — the flag that does not restore. So the DETECTION half is good and only the REPAIR half is broken, which narrows `-zzx3` usefully: whatever fixes it can rely on quit already knowing which files moved.

## 2026-08-17 — Cycle 106 gap reconciliation (no run; a status pass over two open ids)

Not a harness run, so no `Value:` block — this is step 4's reconcile bullet, appending
status rather than rewriting the entries that recorded these as open.

- Gap: **`reach` cannot distinguish a static utility from a file the run did not load.**
  - [G-077] status: fixed | seen: 1 | harness: 0.38.0
  - Fixed in cycle 104 by `plant-tower-defense-v3ji`. `verify_ledger.py` splits three ways
    now, and it proved itself on its own cycle's row: `1 UNREACHABLE BY CONSTRUCTION (no
    node can carry these, so no snapshot could ever report them - not a gap in this run):
    game/game_speed.gd (extends RefCounted)`, printed separately from `NOT reached
    (loadable, and this run did not load them)`. Cycle 102's row went from four
    genuinely-unreached files to one with no `mark_script_reached` added. **Caveat that
    keeps this worth reading:** `verify_ledger.py` IS harness-managed — it is in
    `.harness_manifest.json` and its sha matched before the edit — so
    `/scaffold-godot-harness` will revert it. The fix was written stdlib-only and
    self-contained specifically so the diff is portable upstream.

- Gap: **a tree-walking checker sees N+1 copies of the repo during a worktree fan-out.**
  - [G-078] status: fixed | seen: 1 | harness: 0.38.0
  - Fixed in cycle 104 by `plant-tower-defense-tfnv`. `tools/repo_walk.py` is the single
    exclusion rule and the rooted checkers import it rather than each carrying a copy. It
    was PLANTED rather than asserted: two fake lanes plus a third checkout detectable only
    by `.git`, 98 planted `.gd` files, and `check_all` output byte-identical with and
    without them (`diff` returned 0 lines). Before the fix `world_control_check` went 19 →
    38 scripts. The sweep also enumerated every tree-walking tool rather than fixing only
    the one that complained, and found the reverse defect in cycle 102's own fix — an
    ABSOLUTE-path exclusion discards the whole repo when the checker runs from inside a
    lane, which is why the rule is now computed relative to each tool's own root.

## 2026-08-17 — Cycle 106: a second boss, one ScreenMetrics, and a screenshot from James

- Value: **warranted** — the bridge answered two claims no headless test in this project can reach, and a screenshot from the user found a defect the whole suite was blind to.
  - Expected: two lanes with no compile between them, one rewriting the difficulty arithmetic and one touching every full-screen surface. I predicted the merge would find prose and fixtures that had become FALSE rather than code that was broken.
  - Got: `741/741, Assertions: 15134, Suite: 7`; `lint: 0 error(s), 0 warning(s)`; `check_all: ran 16 of 16 ... 16 clean`, `CLASSIFIED 24 tools/*.py ... 0 unclassified`; `findings: 0 finding(s) across 5 of 5 checks` at 1548x648; the pause Backdrop reading `0, 0, 1548x648` where it used to stop 396px short; and wave 17 spawning `15 beetle / 17 aphid / 1 nurse`.
  - Found: **four.** (1) James's screenshot: the playfield sat hard left with every extra canvas pixel in one grey gutter. (2) Moving it exposed `_click_at` comparing an absolute `screen_pos.x` against a board-LOCAL width — a centred board silently ate every click on its rightmost 117px **while drawing them perfectly**. (3) `PauseScreen`'s Backdrop is `MOUSE_FILTER_STOP` precisely so the board cannot be played through a pause, and at 1152 on a 1548 canvas it left 396px of live clickable board over a held run — a correctness bug wearing a layout bug's clothes. (4) `Hud.next_wave_note` appended the literal `"a queen"` for any boss wave, false on two waves the moment `wave_carries_boss` stopped meaning the Queen.
  - Cheaper: nothing. The gutter needed a windowed game at a non-16:9 shape, the backdrop needed the same, the boss needed a live wave-17 census, and the click guard needed READING — no picture of it could ever have been wrong.

- Gap: **no new harness gap, and the two that bit are already filed.** `[G-076]` (a lane cannot compile) bit for the fourth cycle running: two lanes shipped 919 and 873 lines with zero engine execution between them. What is new is only the size — lane gsai's answer was to build an offline replica of the wave table, validate it against six known-good facts BEFORE trusting it, and then re-run it against the source **parsed back out of its own edited files**. That is a lane inventing its own compile substitute because the harness cannot give it one.
  - [G-076] status: open | seen: 4 | harness: 0.38.0
  - Improvement: unchanged in substance, sharpened by this cycle's evidence — a `check_all` mode that imports once into a LANE-LOCAL `.godot/` (a `--cache-dir` shim, or `GODOT_PROJECT_CACHE`) so N lanes each compile their own diff without colliding. Both lanes independently named the same fix. It would turn "not a compile" into "compiled, not run", which is most of the distance.

- Note, not a gap: **a user screenshot outperformed every gate this project owns.** `findings`, `lint`, 741 tests and 16 checkers were all green over a playfield sitting in the wrong half of the window, because every one of them measures the design size and every test hosts the board at the origin. That is `godot-2d-placement-audit`'s central claim arriving here for the second time, and it is worth writing down that the cheapest detector in the toolkit remains a person looking at the game.

## 2026-08-18 — Cycle 107: five parallel lanes, eight beads, and a seam neither lane could see

- Value: **warranted** — the runtime pass produced one claim no gate in this project can
  produce, and the merge produced two the gates were green over.
  - Expected: runtime should show the road_shape budget verb printing the new test name
    (a runtime string no gate reads), and the renamed predicate firing on a live preview
    (a rename nothing compiled)
  - Got: both, plus the one that mattered — `CornCobbler._recoil` sampled frozen read
    `(0.920, 1.09333)` at t=0.0333 and `(0.89999, 1.11667)` at t=0.0666, which is linear
    interpolation over `TWITCH_OUT_SECONDS=0.05` then `TWITCH_BACK_SECONDS=0.10` to five
    decimals on both axes. `shows_redundant_patch_coverage` answered `false` on the live
    preview and `shows_redundant_coverage` came back `has no method` — the rename proved
    in both directions, which is what a rename actually needs.
  - Found: the cross-lane seam. `sfx_call_check` (lane E) called
    `gdsource.strip_comments` (lane A) bare, taking the `KEEP` default where it was
    written and mutation-tested against `message_corpus_check`'s `BLANK` semantics; the
    two modes differ on 40 of 44 `game/*.gd` files. Planting a `Sfx.play(Sfx.GHOST_CUE)`
    inside a string literal gave 26 call sites and 1 false finding against the correct
    25 and 0. `check_all.py` was **18 of 18 clean with the bug present.** Second half of
    the same seam: `BLANK` blanks the `&` of `&"..."`, which `CONST_DECL` needs to tell a
    StringName event id from a String const — lane A flagged that `&` as safe "since no
    caller reads it", and lane E's checker, which did not exist in lane A's worktree,
    reads exactly it.
  - Cheaper: nothing for the tween arithmetic — no static gate here can observe a
    duration, which is lane D's own argument for refusing to rescale the timings. The
    rename and the budget string would have fallen to grep.

- Gap: **a fan-out lane cannot type-check the file it just wrote** — `name_check.py` is
  the only parallel-safe gate, and it resolves names without compiling; a fresh worktree
  has no `.godot/`, so `--require-compile` false-positives every cross-file `class_name`.
  Five lanes reported green this cycle having parsed nothing. Lane D worked around it by
  porting its GDScript scanner to Python and running that against the pre- and
  post-change trees — real proof of the logic, no proof of the GDScript.
  - [G-124] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a read-only shared-import mode — one `godot --check-only` per named
    file against a `.godot/` the lane may read but not write, which is what
    `--require-compile` already almost is. Needs the parent to have imported once and
    the lane to be told it may read that cache.

- Gap: **nothing gates a call-site's ARGUMENTS against the callee's default when a
  shared helper gains a mode parameter.** The seam above is one function growing a
  keyword argument whose default is not the behaviour its existing callers were written
  against. Both sides were individually correct and every checker stayed green.
  - [G-125] status: open | seen: 1 | harness: 0.38.0
  - Improvement: probably not a harness feature but a fan-out rule — when a lane
    collapses N copies of a function into one shared implementation, the merge owes a
    per-caller check that the chosen default matches what each caller previously had.
    Worth adding to `merge-the-fanout` as a named failure class; it is currently absent
    and it is the one that bit hardest this cycle.

- Note: this project runs harness 0.38.0 while 0.60.0 is on the machine
  (`plant-tower-defense-ny3h` is the open bead for that refresh). Gaps above are filed
  against 0.38.0 and may already be closed upstream.

- Gap: **the `/verify` skill shipped with the plugin describes a `run.json` the installed
  ledger does not read.** The skill (from plugin 0.60.0) says the row carries
  `"tier": "<full|headless-only|...>"` and that `stats` counts by it; this project runs
  harness 0.38.0, whose `verify_ledger.record` reads eleven keys and `tier` is not one of
  them. Caught by this project's own `tools/run_json_check.py`, not by the ledger:
  `FINDING: unknown key 'tier' -- verify_ledger reads it nowhere, so it will be dropped
  without a word and the row will not carry it.` Verified after the fact — the recorded
  row has no `tier`. Removed the key; the row stands without it.
  - [G-126] status: open | seen: 1 | harness: 0.38.0
  - Improvement: the skill's Phase 5 should say which harness version introduced each
    `run.json` key, or `record` should warn on an unread key the way `run_json_check`
    does rather than dropping it silently. Note the shape of this one: the guidance was
    newer than the tool, so following the instructions correctly produced a row that
    quietly lost a field. `plant-tower-defense-ny3h` (refresh 0.38.0 -> current) is the
    standing fix.

## 2026-08-18 — closed uqeo/hulz by measurement, merged two lanes, verified both live

- Value: **warranted** — the bridge settled the "written or obvious" condition on both
  lanes in four calls, which no headless gate could have.
  - Expected: the rain prep-note clause renders and the pause tooltip matches its
    destination; both plausible from the diff and neither provable from it.
  - Got: `Wave 5 next — 16 pests · rain · beds mend 35%.` off the live `Hud`, and
    `tooltip_text=Opens at page 13 of 14 — What the marks on the board mean.` against
    `open_at=12` and `PageLabel text=13 / 14` — the promise and the destination read
    back from the same running tree.
  - Found: `node-bounds` confirmed `NotebookButton` is still `248x44`, i.e. the tooltip
    did not widen the button past the rect `button_rects()` placed it in — the specific
    failure that file's header warns about, and the reason the lane chose a tooltip over
    a longer label. Nothing else; both lanes' work was correct as handed back.
  - Cheaper: nothing. Three of the four reads are of live node state after a real press.

- Gap: **no gap this turn.** `find-nodes --class Hud` recovered the node path in one
  call after `/root/Game/HudLayer/Hud` (from a lane's report) turned out not to exist —
  which is the verb working as documented rather than a gap.

- Note, not a gap: the `uqeo` measurement was answered *without* the bridge. A 22-wave
  live run would have produced one point on a curve whose shape `Plant.upgrade_ladder`,
  `Sunflower.INTERVAL` and `can_start_wave` already decide. Worth recording because the
  instinct was to launch the game, and the cheaper answer was strictly stronger: it
  covers every playthrough rather than the one that got played.

## 2026-08-18 — round 11: owdi driven, ox1p grouped, hb43 swept (no bridge this round)

- Value: **warranted**, but for the headless suite rather than the bridge — the game
  was never launched and did not need to be.
  - Expected: `owdi`'s claim ("a foreign id cannot reach the shelf") was already true by
    reading, so I expected a green test and nothing else.
  - Got: green, 6 assertions — and then the part that mattered: patching
    `shelf_progress_text` to count off `earned_milestones.size()` turned it **red**, and
    restoring turned it green. That is the only evidence that a test about a protection
    is asserting anything at all.
  - Found: nothing in the game. The defects this round were both in **my own
    measurements**: a history sweep that reported 554 false hits, then 144, before
    asking `gdsource` instead of a regex.
  - Cheaper: nothing for `owdi` — the bead's whole point was that reading had already
    been done once and was not enough. For `hb43`, no engine at all was needed.

- Gap: **`isolation: "worktree"` branched both lanes from the session's ORIGINAL HEAD,
  not from current main.** `git worktree list` showed both agent worktrees at `bd9d332`
  — the commit in this session's opening git status — while main was 17 commits ahead at
  `d3e2c30`. Both lanes were therefore editing files that had moved underneath them, and
  Lane B owns two files (`hud.gd`, `game.gd`) that round 10 had changed. Worked around by
  messaging both lanes to `git merge main` mid-flight and telling each what specifically
  had moved in its own files.
  - [G-124] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a spawn that creates a worktree should branch from the repo's CURRENT
    HEAD, or say in the spawn result which commit it branched from. The failure is silent
    and cheap to detect (`git worktree list`) but nothing prompts you to look — I only
    checked because I wanted to see whether the lanes had committed yet. A lane that
    reports "all gates clean" against a 17-commit-stale base is telling the truth about
    the wrong tree, which is the same failure class as a clean `name_check` in a fresh
    worktree that compiles nothing.

- Note for the ledger, not a gap: the `hb43` survey is the clearest case this session of
  a **zero that had to be earned**. Two wrong versions produced 554 and 144 findings; the
  right one produces 0. A control file now pins all four outcomes, because "0 findings"
  and "the sweep is broken" are the same output.

## 2026-08-18 — merged the reach-ring lane and verified three pixel changes on one frame

- Value: **warranted** — this is the case screenshots exist for, and one frame settled
  three separate claims that no headless gate can reach.
  - Expected: the shared `draw_reach_ring()` paints for a plant that inherits `_draw()`
    and for one that overrides it; and the Corn's wash is actually gone rather than
    merely deleted from a constant.
  - Got: one 560x340 crop with three plants selected at once — the Chomp's new rose ring
    at 73.6 px (which `find-nodes --call reach_ring_radius` had already reported, but a
    getter returning 73.6 says nothing about whether `_draw` ran), the Sundew's new edge
    around its sap disc, and the Corn's 176 px ring with grass and dirt at their normal
    colours inside it.
  - Found: nothing broken. The suite was green before the screenshot and stayed green.
    The value was **disproving** the cheap worry — that a `_draw()` override might
    silently skip the shared call, which is the exact trap the bead named and the one
    thing 851 headless tests structurally cannot see, because headless runs no `_draw()`.
  - Cheaper: nothing. `node-bounds` and property reads cannot answer "did this paint".

- Gap: **no gap this turn.** `set-state --property _selected --value true` on three
  plants was the whole setup, and it let one capture carry three claims instead of three
  captures carrying one each — `place_plant` refusing with "not paid for" and then
  "something is already growing there" named both causes precisely enough to fix in one
  step each.

- Worth recording: `find-nodes --class Plant` matched **nothing**, because every plant on
  the board is a concrete subclass and the verb's `--class` did not walk up to the base
  `class_name`. `--class ChompFlower` worked. The docs say `--class` "takes a script
  `class_name` too (subclasses included)" — that reads as *subclasses of the named class
  are included*, which is what I assumed and is not what happened here. Not filed as a
  gap because the workaround was one call and the behaviour may be intended for scripts
  that are never directly attached; noted in case it recurs.

## 2026-08-18 — merged the selection-budget lane; run_tests.py earned its wrapper

- Value: **warranted** — the live `cmd budgets` read confirmed a number the lane could
  only model, and the headless wrapper caught a test that reported PASS while aborting.
  - Expected: the new `hud_selection_panel` entry appears among the budgets and reports
    the lane's modelled 0 px.
  - Got: verbatim off the running game — `the selection stack's foot 184 of 184 px max
    -- 0 px left`, with `widest line is "Regrowing — 3/3 fluff, armed in 4.9s." at 266 of
    232 px`. The model and the engine agree.
  - Found: **two defects, both fixed mid-run.** (1) The lane's headline test asserted a
    bare `budget_regressions([entry])` was empty — true in its sandbox, false here,
    because that function also warns about every declared floor nothing measured, so one
    entry produces five complaints about the other five budgets. (2) A format string fed
    an `Array` to a single `%s`, which aborts the method *after* its assertions pass and
    returns `""` — reported `[PASS]`.
  - Cheaper: nothing. (2) is unreachable by reading; it is the exact failure the
    `run_tests.py` wrapper exists for.

- Gap: **no gap this turn.** `cmd budgets` answered the whole verification in one call,
  and its `when_it_runs_out` string carried the three available fixes plus a warning that
  one of them spends another budget's clearance — which is more than I would have thought
  to check.

- The entry worth keeping for the ledger: **`run_tests.gd` printed `ALL TESTS PASSED` and
  `run_tests.py` exited 1 on the same run.** The harness docs describe this split
  precisely (0.27.0, gh#27) and this is the first time this project has hit it in anger.
  Anyone who had run the bare `.gd` would have merged a test that asserts nothing past
  its third line. The denominator that exposed it was not a count but the wrapper's
  `Errors: 1 emitted` line.

## 2026-08-18 — round 12: yoc2 decided, wf4i built, two lanes merged with no failures

- Value: **warranted** — `eval.gd` turned a design question into four measurements in
  about a minute each, and two of the four were wrong in ways only running them showed.
  - Expected: the run summary's value column had comfortable headroom; its own header
    said the widest row was 36 characters and "nowhere near" the limit.
  - Got: `{"text": "10 of 10 beds — 44 walked in untouched", "needed": 330.0,
    "slot": 335.2, "left": 5.2}`. The header named the right string, in characters,
    which is not a unit a proportional font respects. 1.5% clearance.
  - Found: **two defects in my own corpus, both caught by running it.** (1) Invented
    `_stats` key names meant every producer fell through to its default and the corpus
    measured a card of zeroes — reporting a comfortable 118 px. The tell was that the
    **all-zeroes control came out widest**; a worst case that loses to its own control
    is not a worst case. (2) A guessed `road_cells: 24` against a real 32 kept one row
    in its short form, so the longest thing that row can say went unmeasured. **A corpus
    can be wrong by being plausible.**
  - Cheaper: nothing. Both defects are invisible in the diff and both produce a
    confident, plausible number.

- Gap: **no gap this turn.** `eval.gd --expr 'RunSummary.value_column_budget()'` is the
  right shape for exactly this — a pure static answering a design question with no game
  running and no test written yet. Worth noting it took four iterations and each cost
  one command.

- Worth recording: **`suite_reach_check` caught `value_slot_width` as named only inside
  a string literal** — the budget's own `constant` field. It refuses to count that as
  reach and was right to: the function existed, the budget divided by it, and no test
  ever called it. The fix was the assertion its doc comment already claimed (the drawn
  column equals the measured one), which is a better test than the one I would have
  written unprompted.

## 2026-08-18 — round 13: 0y0w triaged by the new rule, snba merged

- Value: **warranted** — `eval.gd` answered a design question four times in a row, and
  one of the four answers was wrong in a way only re-running it showed.
  - Expected: the side panel carried "the widest column of text in the game", as its
    bead claimed, and would need a corpus.
  - Got: the plant buttons are **icon-only** with their text in tooltips, so most of the
    panel has no measurable slot at all. The one real surface is the packet rack, whose
    widest label draws `{"text": "Common Packet (20)", "needed": 179.0, "slot": 232.0,
    "left": 53.0}`.
  - Found: **I measured it wrong first.** I passed font size 15 to `GardenTheme.measure`
    and got a comfortable 149 px. These buttons set no font override, so they render at
    `GardenTheme.BUTTON_FONT_SIZE` = 18 and draw 179. A width measured at a size the
    control does not use prices a rack that does not exist — caught only by going to
    look for where the size comes from, not by anything the tool said.
  - Cheaper: nothing. The premise correction needed reading `_build_side_panel`, and the
    number needed the font.

- Gap: **no gap this turn.** Worth noting the shape that worked: `-yoc2`'s verdict turned
  a bead that would have been an afternoon of corpus-building into three greps and one
  measurement, because the rule ("does this surface clip, wrap, or push?") is answerable
  from the source. A decision recorded as a *rule* rather than as a *verdict per item*
  is what made the next item cheap.

- Also: `eval.gd` refuses `&"name"` StringName literals in `--expr` (`PARSE ERROR:
  Expected expression`); `StringName("name")` works. Not filing it — the workaround is
  shorter than the report — but recording it so the next session does not spend the
  two minutes I did.

## 2026-08-18 — round 13 close: the glyph merge, and the caveat firing for real

- Value: **warranted** — lint caught a class of error that three static gates and a
  careful lane all reported clean.
  - Expected: the glyph table was additive and low-risk; both lanes' gates were green.
  - Got: `lint exit=1`, eight times — `Parse Error: Cannot infer the type of "err"
    variable because the value doesn't have a set type` at `test_placement.gd:8085`
    and seven siblings. `var err := _T.assert_gt(...)`, where `_T` is untyped.
  - Found: that, and nothing else. It is **verbatim the failure class the harness's own
    not-a-compile caveat names**, produced by a lane that had quoted the caveat back in
    its report. The first time this project has hit it from a fan-out.
  - Cheaper: nothing. `name_check` reports it clean by construction — it resolves names
    and does not type-check — and a worktree has no `.godot/`, so `--require-compile`
    was unavailable to the lane too.

- Gap: **no gap this turn.** The ordering the docs insist on (`--import` BEFORE lint,
  when a `class_name` arrives) mattered here and worked: `Glyphs` is new, import
  regenerated the cache, and the only errors left were real ones rather than a cascade
  of "Could not find type Glyphs" in files nobody touched.

- Worth recording for the ledger: **`suite_reach_check` caught a dead accessor inside
  the lane**, before the merge — `Glyphs.meaning`, public and named by no test, written
  in the same sitting as the table. That is the third real hole that checker has found
  in three cycles, and none of them were formalities.

## 2026-08-18 — round 14: ip4n photographed at last, 9afm merged

- Value: **warranted** — the bridge did the thing no headless gate can: caught a
  sub-second visual state deterministically, after three sessions had failed to.
  - Expected: an arc partway round the chew ring, at roughly 50% and 90%.
  - Got: 47.4% and 90.4%, each within a percent of target **on the first attempt**, with
    the grab landing at `x = 187.77` against a predicted `x >= 187.7`.
  - Found: the arc **sweeps closed**, which changes what the acceptance was even asking.
    Its ink falls 138 px → 72.7 → 13.3 as the chew completes, so "is the 90% frame
    legible" is arithmetic over two constants rather than a judgement about a photo.
  - Cheaper: nothing for the capture. But the *finding* was cheaper than the capture —
    once the sweep direction was known, `chew_arc_end(p) * CHEW_RING_RADIUS` answered it
    without a renderer. The photograph confirmed the maths; the maths is what got pinned.

- Gap: **no gap this turn**, and one technique worth reusing. `read-a-moving-value` says
  pause before you START the thing. Here the trigger was a physics interaction I could
  not call — a pest had to walk into range — so the sequence was **pause → coarse-step
  the approach (1.0 s) → fine-step the event (0.15 s)**, switching resolution at a
  boundary computed from `GRAB_RADIUS` and the cell centres. That is a variant the skill
  does not cover and it turned a three-time failure into a first-try capture.

- **`[G-124]` may be fixed, and the correlation is worth recording rather than claiming.**
  Both lanes this round were spawned at `2563734`, which WAS main at spawn time — the
  first round in four where a worktree was not ~130 commits behind. The one thing that
  changed is that `main` now has an upstream, because this session pushed. That is a
  plausible cause and not a demonstrated one; I did not test it. Next fan-out will say.
  - [G-124] status: open | seen: 3 | harness: 0.38.0

## 2026-08-18 — round 14 close: verifying a lane's fix, and finding it did not hold

- Value: **warranted** — the suite was the instrument that showed a proposed fix did not
  do what its own message claimed, which no amount of reading would have.
  - Expected: the lane's finding was right (an assertion that cannot fail for its stated
    reason) and its one-line fix closed it.
  - Got: the finding confirmed **by mutation** — deleting `tween_interval(death_linger())`
    from `_play_death` leaves the old test green, all three assertions passing. Then the
    same mutation against the FIXED test: **still green.** The pairing catches an
    on-the-spot `queue_free()` and nothing else, because the remaining fade tween defers
    the free just as well.
  - Found: that second result. A lane's fix, verified by the lane against the checker
    rather than against the defect, closing a narrower hole than its message claimed.
    The message now says only what the pair checks, and the residue is written down.
  - Cheaper: nothing. Two mutations and two filtered runs, about four minutes, and the
    alternative was shipping a comment that overstated its own assertion.

- Gap: **no gap this turn.** Worth recording that the first mutation attempt produced
  **no verdict at all** — I deleted an `else` body and left it empty, which is a parse
  error, and `run_tests.py --filter` printed `Assertions: 0` with no `[PASS]`/`[FAIL]`
  line rather than an error. That is the runner behaving correctly (exit 2 territory,
  selector matched nothing runnable) but it reads at a glance like a test that passed
  quietly. **Read the `Selected: N of M` line on any filtered run**, not just the verdict.

- The pattern this round is worth naming: **a lane verifying its fix against the CHECKER
  is not the same as verifying it against the DEFECT.** The lane ran its edit through
  `settle_read_check` in isolation, got exit 0, and reported it verified — correctly, for
  what it measured. The checker asks "is this read guarded"; the defect was "can this
  assertion fail". Those are different questions and the merge is where the second one
  gets asked.

## 2026-08-18 — round 15: ejfa settled, kjcx filed upstream, G-124 hypothesis disproved

- Value: **warranted** — the walk answered a question two cycles had left open, and then
  produced a second finding that changed what the check should be.
  - Expected: the recoil reaches its written `(0.88, 1.14)`, and cycle 72's `0.900` was a
    sampling artefact.
  - Got: `0.880000` and `1.140000` at `--seconds 0.01`, in four independent runs, to
    within 3e-6. The artefact confirmed: `TWITCH_OUT_SECONDS` is 0.05 and a 0.03 request
    advances about two frames, so the samples straddle the peak without landing on it.
  - Found: **the peak's VALUE is reproducible but its STEP INDEX is not** — step 3 at
    `--seconds 0.01`, step 5 at `--seconds 0.001`, because `step_time` advances the
    process clock by an amount that is neither the seconds requested nor a whole physics
    frame. Across three runs at one step size the peak stayed on step 3 and the *approach*
    differed every time. So a check reading a fixed step index measures the harness, not
    the tween. Walk past and take the extreme.
  - Cheaper: nothing. Both halves needed the live game; headless runs no tween at all.

- **`[G-124]` is NOT fixed, and my correlation was wrong.** Two rounds of correct worktree
  bases made pushing look causal; this round LANE A reported `STALE: YES`, 9 commits
  behind, and had to merge. So the base is sometimes right and sometimes not, which is
  worse than always wrong — a lane that does not check cannot tell. **Every lane prompt
  should keep the check.** Recording the disproof rather than quietly dropping the claim.
  - [G-124] status: open | seen: 4 | harness: 0.38.0

- Gap: **no gap this turn.** `.claude/surveys/flourish_peak.py` is a live check in the
  house-checker shape (exit 0/1/2, printed denominator, NOT COVERED line) for something
  the headless suite structurally cannot hold, because `animations_enabled()` is false
  there. That split is worth more explicit support: the project now has two of these
  (`heredoc_survey.py`, `flourish_peak.py`) and nothing runs them as a set.

## 2026-08-18 — round 15 close: the readout band, and G-124 confirmed twice more

- Value: **warranted** — `eval.gd` re-derived a lane's headline number independently in
  three calls, which is what turned a report into a verified finding.
  - Expected: the fang crown and the sole-cover ring overlap by 0.7 px, per the lane.
  - Got: crown outer `30.7`, alone-ring inner `30.0`, half-cell `32.0` — read from the
    game's own constants rather than from the report. The overlap is real and the ceiling
    above it is 1.3 px, too little for the 2.0 px ring to move into.
  - Found: nothing beyond confirming it. The finding was the lane's; the value here was
    refusing to take a number on trust when the tool to check it costs one call.
  - Cheaper: nothing. Reading the four constants by hand and multiplying is the same work
    with more places to slip.

- **`[G-124]` confirmed unfixed, twice more.** BOTH lanes this round reported
  `STALE: YES`, 9 commits behind. Combined with the two clean rounds before, the harness
  base is *sometimes* right — which is worse than always wrong, because a lane that skips
  the check cannot tell which round it is in. The explicit "say yes or no" line in the
  prompt is what produced this; without it a lane that silently merges looks identical to
  one with nothing to merge.
  - [G-124] status: open | seen: 5 | harness: 0.38.0

- Gap: **no gap this turn.** Worth recording that the ordering discipline paid again: a
  new `class_name ReadoutBand` arrived, `--import` ran before lint, and lint came back
  `0 error(s)`. Skipping that order would have produced `Could not find type
  "ReadoutBand"` cascading into files nobody touched — which reads as a broad regression
  and is not one.

## 2026-08-18 — cycle 110: the Barrier Bramble, the ninth plant and the first that stands in the road

- Value: **warranted** — the run measured the halt distance against the constant that
  declares it, on the real route, and three headless gates each rejected the plant for a
  different reason before it ever launched.
  - Expected: a plain aphid halts at a Bramble's cell (position stops advancing while the
    Bramble's health falls), and a Bramble places on a road cell where a Corn is refused.
    The thing runtime can show that the 893 headless tests structurally cannot: whether
    the Bramble renders visibly ON the road — plants and road tiles are different draw
    layers, so a plant on a road cell could be painted underneath the tile and be
    invisible — and whether the preview's green brackets actually appear over road cells.
  - Got: the aphid walked 70.7 → 173.4 → **250.1** and stopped there for three seconds
    while the wall went 40.0 → 39.2 → 34.6 → 30.1 → 25.8. The wall stands at x=288, so the
    gap is **37.9 px against `Bramble.STOP_RADIUS` 38.4** — the header's geometry argument
    holds on the real route and not only in a synthetic two-point path. The paired guard
    inverted on the same road with the same species: a WINGED aphid went 47.3 → 150.0 →
    **251.4** → 352.8 → 416 with the wall untouched at `health=40.0` throughout. The
    preview inverted with it — grass `placeable=false`, road `placeable=true`.
  - Found: five things, three of them before launch.
    **(1)** `art_src/bramble.svg` carried a `--` inside an XML comment. Godot's rasteriser
    accepted it and wrote a correct 64×64 PNG, so the sprite *looked* finished — but
    `svg_style_check.py` reported `ERR bramble ? geometry not measured` and skipped both
    `raster_size` checks. The sprite would have shipped exempt from every geometry gate
    while the summary still read `Checked: 28 of 28`. **A checker that names what it
    skipped is what made this visible; a bare pass/fail count would have hidden it.**
    **(2)** the painted base sat at 19.0 against a family spread of 24–27, so the bramble
    would have swayed about a point in its own middle rather than about the ground.
    Invisible in a still; only the pivot gate can see it.
    **(3)** the title lawn overturned a written claim. `PLANT_X`'s header said "a NINTH is
    the two-row day, and this time there is no third trick: five 96px canvases need 480 in
    a 426px band". True, and about the wrong quantity — measuring the nine sprites' real
    ink (mint 32 … sunflower 54) showed the five narrowest fit that band with 17.5 px of
    clear ink per join at the current scale. The file had discarded its own ink argument
    as "slack rather than load-bearing" exactly one plant earlier.
    **(4)** the halt distance above.
    **(5)** two measurement errors of my own, both of which produced confident, well-formed,
    wrong numbers — see the gap below.
  - Cheaper: nothing for the halt distance and the render check; both need a playing game
    on the real route. The three gate catches were all cheaper than the runtime pass and
    all ran in Phase 1, which is an argument for the headless gates rather than for
    launching.

- **Two live reads that were confidently wrong, in one session, for two different reasons.**
  This is not a new gap — it is `read-a-moving-value` biting twice — but the second half is
  worth writing down because the skill does not currently name it.
  First: I sampled `sample-pixels --rect 264,72,48,48` expecting my sprite and got
  `dominant #29c56b (79%)`. The game had been left running while I worked, the garden had
  been eaten, and I was measuring the **run-summary card's cream paper**. Nothing in the
  reply says "a modal is covering the board"; the numbers are well-formed.
  Second, after relaunching and pausing: the crop showed a ~20 px speck where a 64 px plant
  should be. That was `Plant`'s planting-pop tween frozen at its `Vector2(0.4, 0.4)` start
  scale — **`pause` froze the entrance the same way it freezes a fade.** `findings` warns
  about paused `ui_transparent`/`container_layout_drift`; the same hazard applies to any
  `_sprite.scale` entrance and to `sample-pixels`/`screenshot`, which are not UI checks.
  The fix both times was `unpause` → `wait-frames 90` → `pause` → read.
  - [G-127] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `screenshot` and `sample-pixels` should say `TREE IS PAUSED` in their
    reply the way `ping` and `performance` already do. A paused capture is a legitimate
    thing to want (that is the whole point of `--then-pause`), so this is a label and not a
    refusal — but a still of a half-finished entrance is indistinguishable from a still of
    a finished one, and the reply is the only place that could say so.

- Gap: **`run.json`'s `tier` key is dropped by this project's installed ledger.**
  `tools/run_json_check.py` caught it before `record` ran, which is exactly what that
  checker is for: `unknown key 'tier' -- verify_ledger reads it nowhere, so it will be
  dropped without a word`. The `/verify` workflow text this session followed documents
  `tier` as required and says `stats` counts by it; this project runs 0.38.0 and the key
  landed in 0.50.0. Not a defect in either half — it is version skew between the skill
  and the install, and it is blocked behind the same thing everything else is.
  - [G-128] status: open | seen: 1 | harness: 0.38.0
  - Improvement: nothing to fix here — `-ny3h` (refresh 0.38.0 → 0.42.0+) is still
    BLOCKED on upstream gh#43, the deterministic `0xC0000005` segfault at
    `test_corn_shoots_the_pest_closest_to_escaping`. Recording it so the next reader of
    that bead knows the skew has started producing concrete drops rather than only
    missing features. `harness-version --client` reports the machine is now on **0.60.0**
    against this project's 0.38.0 — twenty-two releases, up from four when `-ny3h` was
    filed.

## 2026-08-18 — cycle 111: the surveys get a runner, and the runner got adopted by the wrong pool

- Value: **warranted** — the design was decided by two measured runtimes rather than by
  reading, and the predicted hazard fired invisibly under a green line.
  - Expected: the surveys become reachable by one command that prints how many it ran of
    how many it discovered, with a could-not-run named rather than dropped. Predicted
    before writing: adding a `NOT COVERED` line to a new `tools/*.py` will make
    `check_all.py` adopt it as a checker, because it discovers by that marker and excludes
    only itself by name.
  - Got: the prediction held, and the way it held is the finding. `check_all` adopted
    `survey_all.py` and reported it **`clean`** — correctly, because with no game on the
    bus `survey_all`'s own gate declines to fire — while spending ~30s inside
    `heredoc_survey.py`'s whole-git-history sweep on every run of the pool whose entire
    promise is that it is the fast parallel-safe one. `check_all` went 4.1s → ~34s with a
    green line above it. Fixed by growing `SELF` into `RUNNERS`.
  - Found: four things, and the second and third are the ones worth reading.
    **(1)** the bead's premise was wrong in a way that changed the design. It said all
    three surveys are in the house-checker shape; only `flourish_peak.py` carries a
    `NOT COVERED` line, and the three are three different KINDS —
    `heredoc_survey.py` 29.7s (whole history), `heredoc_survey_controls.py` 0.06s (the
    fixture proving the sweep can fail), `flourish_peak.py` exit 2 (needs a live game).
    Those runtimes are what settled "a second runner" over "a second discovery root",
    and no amount of reading the bead produces them.
    **(2)** the adoption above.
    **(3)** fixing it immediately broke `check_all`'s own arithmetic: `CLASSIFIED`
    printed `19 + 1 + 7 = 27` of 29 tools and looked exactly as authoritative as it does
    now. A classifier that silently loses two files is precisely the bug it exists to
    catch. Added a `runner(s)` category and a `SUM MISMATCH` guard, then mutated the sum
    to prove the guard fires.
    **(4)** `heredoc_survey.py` reports 0 hits for both damage signatures across the whole
    history — the mechanical second opinion on cycle 110's break of the
    no-script-writes-source rule, which I had only checked by hand.
  - Cheaper: nothing. Reading the three surveys instead of running them gives the wrong
    design, and would not have surfaced the adoption hazard at all.

- **Both new guards were mutation-tested, because the skill says a positive control that
  cannot fail is worse than none.** `survey_all --self-check` against a `run_one` forced to
  report exit 0: `3 FAILURE(S)`, exit 1. `check_all`'s sum against a `named` missing
  `len(RUNNERS)`: `SUM MISMATCH: 27 file(s) accounted for against 29 on disk`. Recording
  the mutations rather than only the passes — a fixture reported as passing is the one
  claim in a checker that nothing else checks.

- Gap: **no gap this turn.** The harness was barely involved and correctly so: this is
  tier (f) tooling-only in `/verify`'s own triage — two `tools/*.py` and one skill doc,
  nothing under `res://`, so no Godot phase can speak to it. The ledger row is recorded
  `--no-reach` for that reason rather than because a capture was missed. Worth noting the
  triage table earned its keep by telling me NOT to launch: cycle 110's row cost a game
  launch and twenty minutes, and this one correctly cost neither.

## 2026-08-18 — cycle 111 item 2: the panel learns to say "holds 11s", and a test that had stopped looking

- Value: **warranted** — runtime confirmed the one claim that decided the design, and the
  gate caught a coverage hole the change itself had created a cycle earlier.
  - Expected: the selection panel gains a line saying how long a resisting plant actually
    holds, shown only on a plant that resists. What runtime can show that the headless
    suite cannot: whether the number MOVES as the wall is chewed — that is the entire
    argument for printing seconds rather than a "x4" multiplier, and a static test of the
    formatter proves the format, not the behaviour.
  - Got: `Barrier Bramble / Holds 11s against one pest.`, and it tracks —
    `health=40.0 -> 11s`, `health=39.42 -> 11s`, `health=21.86 -> 6s` (21.86 / 3.5 = 6.2).
    A Corn Cobbler one cell over reads `Corn Cobbler — single / 1.0 dmg / 0.80s, 1
    kernel(s)` and no "Holds", which is the half that stops the line becoming noise.
  - Found: three, and the first is the one worth the cycle.
    **(1) The test that should have gated this had silently stopped covering the plant the
    change is for.** `test_the_selection_box_stays_inside_the_side_panel_when_damaged` says
    "Every plant kind" in its own comment and `continue`d on any placement refusal. The
    Barrier Bramble is refused on grass, so it was skipped — and the test went on passing.
    Worse than one plant: the same `continue` swallowed `not paid for` just as silently, so
    the loop only ever measured whatever the starting unlocks happened to cover. It now
    picks a legal cell per plant, treats a refusal as a FAILURE, and asserts
    `covered == PlantCatalog.ids().size()`. **A skip that reads as a pass, in a test whose
    comment claims exhaustiveness.**
    **(2)** the live tracking above.
    **(3)** a third moving-value misread, third distinct cause. `Holds 0s against one pest.`
    three times running looked like a broken readout; the Bramble had been eaten and freed,
    the box was `visible=false` with `selected_placed=null`, and I was reading stale text on
    a hidden Label. The session's three causes were: a modal covering the board, a paused
    entrance tween, and now a hidden node retaining its last text. None produced a
    malformed reply.
  - Cheaper: nothing for the tracking check — it needs a pest actually eating the plant over
    time. The coverage hole was the cheaper catch and the suite surfaced it the moment the
    loop was made strict, which is an argument for asserting a denominator, not for
    launching.

- **I broke the no-literal-newline-in-a-string rule myself, with the Edit tool, and found
  out what does and does not catch it.** Wrapping a long assertion message put a real
  newline inside a GDScript string literal — the cycle-97 shape, arrived at without a
  heredoc anywhere. What reported CLEAN over it: `name_check.py` (names resolve; its own
  NOT COVERED line says so) and **`heredoc_survey.py`**, which is the project's designated
  countermeasure for exactly this defect. The survey sweeps **git history**, not the working
  tree, so it structurally cannot see an uncommitted break — it is a "how often has this
  happened" tool, not a gate, and the newly-written `tools/survey_all.py` header says as
  much. Only `lint_project.gd` caught it (`Parse Error`, exit 1). Worth writing down
  plainly: **the countermeasure for the rule this project keeps breaking cannot see the
  break until after it is committed.**
  - [G-129] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a working-tree mode for `heredoc_survey.py` (`--worktree`, scanning
    tracked files as they are on disk rather than diffs) would make it a pre-commit gate
    instead of a retrospective. Not a harness gap — this is a project-owned survey — so it
    goes in the queue rather than upstream.

- Gap: **no gap in the harness this turn.** `find-nodes --class Label --where name=X
  --property text` was the whole diagnostic for both the readout and the stale-label
  misread, in one call each, and `step-time --then-pause` gave the health/text pairs with
  no ambient drift. The one thing that would have shortened this: see G-129 above.

## 2026-08-18 — cycle 112: confirm-the-premise built, and turned on a bead nobody wrote it about

- Value: **warranted** — the confirmation changed the shape of the work three times before
  a line was written, and one of those would have shipped a permanently-green test.
  - Expected: the bead's premise is checkable before any code. It claims three tests cover
    three screens and proposes one sweep replacing them. Predicted before checking: the
    count is stale, because every count in a bead of that age has been.
  - Got: three findings, escalating.
    **The COUNT** is seven, not three — seven test functions assert a `focus_mode`
    transition across five screen pairings. One grep.
    **The ASK was already partly satisfied**, and neither the bead nor its kanban source
    said so: `test_the_hud_is_inert_while_an_overlay_is_open` already builds its subject
    from `Hud.interactive_controls()` rather than a written list — the derived-set version
    of this exact idea — for one overlay over one layer. The remaining work was the
    **cross-product**, not the sweep.
    **The PROPOSED IMPLEMENTATION was nearly vacuous as worded.** "Walk every Control under
    a lower CanvasLayer and assert `focus_mode == FOCUS_NONE`" passes identically over a
    screen that went inert and one that was never focusable, because a Label, a ColorRect
    and a Panel are `FOCUS_NONE` at all times. Written as specified it would have been a
    permanently-green test — and the existing test's own defence against that (assert
    `FOCUS_ALL` first, and check a non-empty denominator) is where the fix came from.
  - Found: the three above, plus `name_check` catching the new test reaching for
    `NotebookScreen.NODE_NAME`, which does not exist — the notebook is held as
    `PauseScreen._notebook` while the other two overlays do declare `NODE_NAME`. An
    asymmetry that would otherwise have surfaced at runtime.
  - Cheaper: nothing for the vacuity finding. The other two were one grep each, which is
    the argument — confirming cost about five minutes and changed the work three times.

- **The test was mutation-tested, and passing first time is why.** A test that goes green on
  its first run has told you nothing yet. Forcing `PauseScreen._set_card_active` to always
  `FOCUS_ALL` produced `GateButton is unfocusable behind the notebook screen ... Expected 0
  but got 2`, exit 1. Recording it because "it passed" and "it can fail" are different
  claims and only the first one is free.

- Gap: **no gap this turn**, and the harness was correctly barely involved: `/verify`'s
  triage puts this at tier (c) headless-only — the test itself instantiates `GAME_SCENE`,
  pauses the run, and drives all three real overlays through `PauseScreen`'s own buttons and
  Escape handling, so launching would re-drive that code with a renderer attached and learn
  nothing. The row is `--no-reach` by triage rather than by omission. Second cycle running
  that the triage table has earned its keep by saying **do not launch**.

## 2026-08-18 — cycle 112 item 2: a sentence that stopped being true, and no gate could tell

- Value: **warranted** — the defect is a sentence being FALSE, which nothing in this
  project can detect, and the two follow-on catches were both gates and both instant.
  - Expected: `Hud.eaten_message` says "A hungry pest ate your X!" and that became false for
    the Barrier Bramble in cycle 110, since a wall is chewed by every pest rather than by
    the hungry mutation. Predicted: the message row's budget will object, because the
    replacement is longer.
  - Got: it did, and by exactly the amount predicted — "The wave chewed through your
    Barrier Bramble!" is 45 characters against 39, so pricing only the line each plant can
    actually reach would have under-measured the row by 6. Both lines are now priced for
    every plant, the same over-pricing `selection_corpus()` already does.
  - Found: three.
    **(1)** the falsehood itself. `Pest._physics_process` only reaches `_adjacent_plant()`
    inside its `is_hungry` branch — which is precisely what made that sentence true of all
    eight plants and false of the ninth. The commonest plant death in the game was being
    announced by a sentence naming a mutation with nothing to do with it. **Found by
    reading the producer while looking for something else. No gate in this project knows
    whether a sentence is true**, and that is worth stating plainly next to 19 clean
    checkers and 898 passing tests.
    **(2)** the hand-maintained per-plant multiplier in
    `test_the_message_corpus_covers_every_catalogue_producer` caught the arithmetic moving
    6 → 7, with a message that says which direction to read the change. That test is the
    reason the widened row could not slip through quietly.
    **(3)** `message_corpus_check.py` rejected the SHAPE of the fix rather than the fix.
    Introducing a one-line dispatcher between the call site and the two producers broke its
    model in both directions at once — the call site called no corpus producer, and both
    producers became "priced and called by nothing else". Waived three times with the real
    reason rather than reshaping the code to suit the checker, which is what its own
    `waive:` line is for.
  - Cheaper: nothing. The defect was invisible to every mechanical check by construction.

- Gap: **no gap this turn.** Tier (c) headless-only again, and the reasoning is worth
  recording because it is the third cycle running the triage table has said *do not launch*:
  the branch is covered over the whole catalogue by a new test, and the only failure a
  launch could add — the row clipping silently rather than erroring — is already swept for
  every plant name by `test_no_message_clips_for_any_plant_in_the_catalogue` against the
  real `MessageLabel` width.

## 2026-08-18 — cycle 113: a cue that promised one plant while describing another

- Value: **warranted** — the bead left reachability explicitly open, and the run settled it
  twice; the launch then earned its keep on the one claim no headless test can make.
  - Expected: the bead says the disagreeing state may be unreachable and that
    `_arm_uproot`/`_disarm_uproot` must be read before writing code. Predicted from
    reading: it IS reachable, because `_select()` writes `selected_placed` while the shop's
    `selected_plant` is a separate field nothing in that path touches. Runtime should show
    green brackets over a road cell with a cob armed.
  - Got: reachable, confirmed as a RED test first (`Expected false but got true`) and then
    on the running game — `placeable=false, plant_id=corn_cobbler, visible=true` after the
    fix, and the cropped capture shows the brackets rendering **blocked** while the cob's
    reach ring still draws from that cell. Before the fix those brackets were green over
    ground no cob can occupy, which reads as "your cob moves here" and plants a Bramble.
  - Found: three.
    **(1)** the state is reachable and the bug is real — the half the bead refused to claim.
    **(2)** the fix is a **no-op for every pre-Bramble configuration**, which is what makes
    it safe to put in a path every hover runs: with nothing armed `previewing ==
    selected_plant`, so the new term asks the question `would_plant_at` just answered. That
    is why 898 existing tests were unmoved, and it is worth stating rather than assuming.
    **(3)** `arm_uproot()` returns `"confirm needed"` on success, not `""` like
    `place_plant()`. The first draft of the reproduction asserted `""` and failed on its
    own precondition — **a test that fails for the wrong reason looks exactly like one that
    works**, and only reading the failure message told them apart.
  - Cheaper: the red test alone justified the fix and cost far less than the launch. The
    launch earned one thing the test cannot assert — that the brackets RENDER blocked
    rather than merely carrying `placeable=false`, since nothing headless draws them.

- **Red-then-green beats a post-hoc mutation, and this is the cleanest example so far.**
  Three cycles running I have mutated a passing test to prove it can fail. Here the test was
  written before the fix, failed for the stated reason, and passed after — the same evidence
  with none of the ceremony. Worth preferring where the defect is already understood well
  enough to write the assertion first.

- Gap: **no gap this turn.** `find-nodes --class PlacementPreview --property placeable
  --property plant_id` gave both halves of the contradiction in one call, which is exactly
  the shape this cue needed: the defect IS the disagreement between two properties, and a
  screenshot alone can only show one of them.

## 2026-08-18 — cycle 114: the wall shows what it has taken, and one mutant was right to survive

- Value: **warranted** — measuring the rendered PNGs caught the only real defect, and the
  launch earned the one claim nothing headless makes.
  - Expected: three frames swapped by health, changing at the same fractions the panel's
    "Holds Ns" number passes. What runtime can show that the suite cannot: whether the
    frames swap under a REAL pest chewing rather than under a test writing `health`, and
    whether the swap makes the plant visibly jump.
  - Got: `health 40 -> bramble.png`, `25 -> bramble_chewed.png`, `10 -> bramble_ragged.png`,
    read off the live `Sprite2D`'s `texture.resource_path`. And under a real aphid the frame
    changed between health **32.53** (fraction 0.813) and **25.83** (0.646) — the 2/3
    boundary, hit by damage rather than by a setter.
  - Found: three.
    **(1)** the two new frames rendered with painted bases at 53 and 52 against the whole
    frame's 56. That is a 3–4 px **jump the instant the plant is bitten** — invisible in any
    still, obvious in play — and it put two of the three outside the family's stem-pivot
    spread. Caught by measuring the PNGs, not by looking at them. Now pinned by a test that
    holds the three frames against EACH OTHER, which is tighter than the style suite's
    per-frame check against the family.
    **(2) the first mutation SURVIVED and was right to.** Swapping `DAMAGE_THRESHOLDS`
    changes nothing, because `texture_for_health` COUNTS how many thresholds the fraction is
    below rather than walking them in order. An equivalent mutant.
    `house-static-checker` names this case ("a mutation that changes nothing is not a
    survivor") and it is worth logging, because *"the mutant survived"* and *"the test is
    weak"* read identically in a log and only one of them is a finding. The second mutation
    — making the ragged frame unreachable — was caught, naming the frame that vanished.
    **(3)** the wiring, which is the launch's whole contribution: a test that writes
    `health` proves the function; only the running game proves the function is connected to
    the thing that damages plants.
  - Cheaper: the PNG measurement, by a wide margin — one snippet, and it found the only real
    defect. The launch bought the wiring check and nothing else.

- Gap: **no gap this turn**, but one workflow note worth keeping: `find-nodes` reports an
  auto-named node's path, and `scene-tree --root <that path> --depth 2` is what turns it
  into a child path. Three attempts were burnt guessing `Sway/Sprite2D` when the child is
  `Sway/@Sprite2D@161`. The verbs are right; the habit of guessing a child name is not, and
  `scene-tree --root` is one call.

## 2026-08-18 — cycle 115: two plants that said they were waiting for a pest they cannot touch

- Value: **warranted** — the sweep found a second instance of the class it was filed for,
  and the fix is a rule the tenth plant inherits rather than three named cases.
  - Expected: HUD sentences naming a MECHANISM go stale as the mechanism list grows, and
    nothing can detect it. Predicted before reading: at least one more producer besides
    `eaten_message` has rotted, and the likeliest is `idle_detail`, whose own comment
    already carries a stale plant count.
  - Got: exactly that, and worse than predicted. `idle_detail` reads "Idle — waiting for a
    pest." and is shown by every plant without its own branch — which is Garden Mint, Salve
    Aloe and Prickly Nettle. **Mint and Aloe cannot touch a pest at all.** Confirmed live:
    Mint now reads "Quickening the beds beside it — never the lane.", Aloe "Mending the beds
    beside it, slowly.", and the Nettle correctly KEEPS the idle line because it stings.
  - Found: three.
    **(1)** the two plants above. The damning part is that **the argument was already
    written down and not applied** — the Sundew has its own line, and the comment three
    lines above the fall-through says "'Idle' was simply the wrong word for the one plant
    that cannot be." Right, and never extended when Mint and Aloe landed.
    **(2)** two stale claims in `wave_director.gd`'s own headers ("three of the eight
    plants", "A drought doubles every plant's firing interval" — three of nine do). Found by
    following the MECHANISM rather than the producer list, which is the half a
    producer-only sweep would have missed.
    **(3)** the shape that makes a sentence safe. **21 of 33 producers interpolate the thing
    they describe** and therefore cannot outlive it; every defect found across two cycles
    has been in the handful that name a mechanism in prose. That is a reviewable property,
    not a checkable one.
  - Cheaper: the extraction script that dumped all 33 sentences — that IS the method, and it
    cost one snippet. Honestly the launch was the cheaper half to skip this time: the new
    test drives the real scene and reads the real Label, so runtime only re-confirmed it.

- **Decision recorded: this cannot be mechanised, and the reason is not "too hard".**
  `message_corpus_check.py` verifies a line is PRICED, which is the only property of a
  sentence a static tool can decide. Accuracy is a claim about the relationship between
  English and code, and there is no shared vocabulary to check — "hungry", "shoots", "idle"
  are not identifiers. The useful residue is a review heuristic, not a gate.

- Gap: **no gap this turn.** One habit worth keeping from the runtime pass: I burnt four
  bridge calls on shell arithmetic mangling cell → screen coordinates, and placed a plant
  that silently was not placed. `find-nodes --class Aloe --property cell` returning
  `0 node(s) matched` is what caught it. **Read the placement's own reply, or ask the tree —
  do not assume a `cmd place_plant` landed.**

## 2026-08-18 — cycle 116: disputing a NOT COVERED line, and finding it was half right

- Value: **warranted** — the two controls are the whole verification and one of them would
  have been vacuous without reading a denominator on the SETUP run.
  - Expected: `citation_check`'s own `NOT COVERED:` line calls drift "the one nothing can
    automate". Predicted: the undecidable half is whether a line SUPPORTS a claim; whether
    it is the SAME line is a string comparison. A snapshot of the landed text should catch
    the exact cycle-112 and cycle-115 failures.
  - Got: it does. Inserting one line above a cited line reports
    `DRIFTED: game/bramble.gd:120-120 / was: super.take_damage(...) / now: func
    take_damage(...)`, exit 1; reverting returns exit 0; a missing snapshot is exit 2 rather
    than a clean "0 drifted".
  - Found: three, and none of them was the feature.
    **(1) Confirming the premise stopped me overloading an existing flag.**
    `citation_check` already has `--baseline`/`--baseline-write` and I nearly reused them.
    They snapshot **findings** — "which broken citations are new". Drift is about citations
    that still **resolve**. One flag meaning both would have made a clean `--baseline` run
    read as evidence about drift, which it is not.
    **(2)** the new mode's denominator contradicted the tool's existing one: **310 against
    351**, because `landed` is keyed by `file:start-end` so a target cited from two entries
    collapses to one. Correct behaviour; printing only the smaller number beside a default
    run saying 351 reads as 41 citations gone missing. Both numbers now print in both modes.
    **(3)** the fixture had to cite a REPO-RELATIVE path — an absolute Windows path's drive
    colon is not matched by the `CITATION` regex, so the first fixture reported
    `0 citation(s), 0 resolved` and **both controls would have been vacuous**. Caught by
    reading the denominator on the setup run, not on the assertion.
  - Cheaper: nothing. The two controls are one command each, and a drift detector that
    cannot fire is exactly the failure this repo's fixture rule exists for.

- **The tool is wired into step 3, not just written.** Cycle 111's whole lesson was that
  `.claude/surveys/` held three scripts nobody ran; shipping a checker without a caller
  repeats it one directory over. Step 3 now carries the snapshot-before / check-after pair
  with the reason.

- Gap: **no gap this turn.** Tier (f) tooling-only, and this is the first cycle where the
  triage rule added last cycle was applied to *decline* a launch rather than to justify one:
  nothing under `res://` changed, so no Godot phase could have spoken to it.

## 2026-08-18 — cycle 117: the fourth hint, and the page that only held three

- Value: **warranted** — `run_tests.py` caught two freed-object defects the suite itself
  reported as 903/903 passing, and the notebook's own gate refused the fourth hint exactly
  as its prose said it would.
  - Expected: the fourth hint teaches the one rule that REVERSES what eight plants taught.
    Predicted: the trigger is the decision, and firing on SELECTION beats firing on the
    refusal, because the refusal already posts its own message ("No pests walk there.") —
    so what is missing is not feedback but the positive instruction. Runtime should show
    whether the tip reaches a real priority-queued row and whether a second notebook page
    renders and is reachable.
  - Got: both. `Your Barrier Bramble goes ON the road, not beside it.` on the live row, and
    hint page 0 holding the three old hints with page 1 holding the road tip, the notebook
    reading `4 of 4 seen` across both and the pager at 16/16.
  - Found: five, and only one was the feature.
    **(1)** the hints page holds exactly THREE, and the file predicted it: *"a FOURTH hint
    does not fit"*. Its two named ways out were "drop the pitch or split the page" — and the
    pitch cannot drop, because four rows need a pitch of 67 against a row that is 94 tall,
    and shrinking the note to reach it clips the UNSHOWN form, which the same block calls
    the state a reader most needs. So: split, with the capacity still finite and still
    loud — a seventh hint fails the suite exactly as the fourth did.
    **(2)** `queue_free()` on the rebuilt pane is DEFERRED, so the old `Hints` was still in
    the tree when the new one was added; Godot renamed the newcomer and every
    `get_node("Hints")` kept returning page one. It presented as "a hint with no row" for a
    row that existed and rendered.
    **(3) and (4)** two freed-object accesses — a cast and a `.text` read on Labels whose
    pane the next page rebuild had freed. **The suite reported `903/903 | ALL TESTS PASSED`
    through both.** Only `run_tests.py`'s stderr check saw them. Third time this session it
    has earned its place over `run_tests.gd`.
    **(5)** `suite_reach_check` found `road_plant_tip` public with no test naming it — I had
    built the whole notebook split and never written the hint's own tests. The checker
    noticed what I had *forgotten*, not what I had got wrong.
  - Cheaper: nothing for (3) and (4). The notebook capacity was caught headlessly and was
    the expensive finding; the launch bought the priority-queue claim and page two rendering.

- **The two-door contract is now asserted rather than worked around.** The hint is DEFERRED
  at scene start because the prep note owns the row and `show_message` queues rather than
  stomping an unread line. My first test "fixed" this by clearing the row; the test now
  asserts BOTH — a busy row leaves the hint owed, a free row spends it — because a future
  change that spent the hint on the CALL would pass every other assertion in the file.

- Gap: **no gap this turn.** Worth noting which tool caught what, since the answer was not
  the obvious one: the engine gates caught nothing, `check_all` caught the untested public
  surface, the notebook's own layout test caught the capacity, and the two defects that
  would actually have shipped were caught by the TEST RUNNER reading stderr — not by any
  assertion anyone wrote.

## 2026-08-18 — cycle 118: deciding the half of a question that was still open

- Value: **warranted** — the confirm step reshaped the item before any code, and the third
  assertion exists only because the first two were satisfiable by making the game worse.
  - Expected: the bead asks whether a 60-seed husk should rot faster than a 9-seed one and
    says the two answers want opposite code. Predicted: the decision is PARTLY recorded
    already, since `FULL_VALUE`'s own comment argues against widening it — but that argues
    about the KNOB, not about whether rot should distinguish above 9 by some other means.
  - Got: exactly that. The comment reads *"widening it to 60 would silently slow the rot of
    every husk in the game — a balance change wearing a legibility fix's clothes"*, which
    settles the knob and leaves the design question open. So the cycle recorded the
    DECISION with reasons the comment does not have: 4.5s is a reaction time, the richest
    husks come from the two bosses (`Pest.SPECIES` — Nurse 39, Queen 40) and so drop at the
    busiest moment on the board, and the failure modes are asymmetric.
  - Found: four.
    **(1)** the prediction, which changed what shipped — from "decide" to "decide the half
    that is still open", without re-deriving a constraint already written down.
    **(2) the third assertion is the load-bearing one.** "Everything above the floor shares
    it" and "nothing rots faster than the floor" are BOTH satisfiable by flattening the
    curve entirely — which would "fix" the inconsistency by making every husk rot at 4.5s.
    Confirmed by mutation: `HUSK_LIFETIME = MIN_HUSK_LIFETIME` fires only the ordering
    assertion. **A decision pinned only where it holds is not pinned.**
    **(3)** the reachable values are DERIVED from `Pest.SPECIES` crossed with the
    multipliers rather than pasted from the bead, and re-deriving them independently got
    the same ten — which is what made the premise safe to build on.
    **(4)** three of this cycle's own citations drifted, from the comment I inserted pushing
    cited lines down.
  - Cheaper: reading `FULL_VALUE`'s existing comment. That IS the confirm step and it
    reshaped the item. Nothing here needed a running game.

- **The drift report's new "written at" line paid for itself immediately.** Last cycle the
  same report named a target in `game.gd` and left 20 citations to be grepped out of a
  4000-line file. This cycle it named all three drifts AND where each was written, and the
  fix was three edits with no searching.

- Gap: **no gap this turn.** Tier (c) headless-only and the reasoning is on the row:
  `lifetime_for`, `husk_value_for` and `value_fraction` are pure statics with no node, no
  scene and no clock, so a launch would re-evaluate the same functions with a renderer
  attached. Second cycle running that naming *the claim a launch would make* has correctly
  said there is none.

## 2026-08-18 — cycle 119: the shop line already promised the thing the bead called a defect

- Value: **warranted** — the confirm step found the answer in a sentence the player reads
  before buying, and the measurement turned that sentence from written into true.
  - Expected: the bead suspects 0.45s is too short for the chew ring to say anything and
    proposes suppressing it below a threshold. Predicted: the numbers will show the aphid
    is not merely shortest but in a different league, and the decision will turn on what the
    ring MEANS rather than on how long it lasts.
  - Got: both. `Pest.SPECIES` chew_seconds are 0.45 / 2.6 / 3.0 / 5.0 / 11.0 with armoured
    doubling any of them — the aphid is **5.8x shorter than the next one up** — and
    `PlantCatalog`'s Chomp entry already reads *"Eats small pests instantly. Big ones take a
    while — and it is busy the whole time."*
  - Found: four.
    **(1)** the shop blurb promises the behaviour the bead calls a defect. A 0.45s sweep
    reading as instantaneous is the cue agreeing with the sentence the player was sold.
    **(2)** suppression would have been actively harmful for a reason the bead did not
    raise: **the ring means BUSY.** A Chomp mid-chew cannot grab, so hiding the ring makes a
    busy mouth read as a free one at the moment the player is looking for one — and the
    aphid is the commonest pest, so any threshold above 0.45s removes the ring from most
    chews in the game.
    **(3)** the bead asked for "both durations recorded as numbers", and numbers go stale.
    Deriving the relationship from `SPECIES` means a new species lands in the test the day
    it is added; the mutation (aphid 0.45 → 1.2) proves the 4x gap is load-bearing.
    **(4)** writing the test **paid down recorded debt and a gate noticed** —
    `chew_progress` was in `suite_reach_baseline.json` as a symbol no test named, and the
    suite failed telling me to re-bank it. A debt list that notices its own repayment is
    rare; this one does.
  - Cheaper: reading the shop blurb, which is where the answer was. The measurement was
    still worth doing — the 5.8x gap is what makes the blurb TRUE rather than merely
    written — but the decision did not need it.

- Gap: **no gap this turn.** Third cycle running that naming *the claim a launch would make*
  correctly declined one, and this time for a reason worth recording: the only runtime
  question here — "is 0.45s long enough to READ" — is a fact about human perception that no
  bridge verb can measure. The harness can photograph the sweep (cycle 14 did, `-ip4n`) and
  cannot tell you whether anyone parsed it.

## 2026-08-18 — cycle 120: a save that fails now says so, and a launch declined for safety

- Value: **warranted** — small change, and the two judgements in it are the kind that only
  surface once you have to write the sentence a player reads.
  - Expected: `RunConfig._save` has four failure paths, all reporting via `push_warning`,
    which no screen can read. Predicted: returning a bool is backward-compatible for all 13
    callers, and the interesting decision is the RENAME failure — where the data IS on disk.
  - Got: exactly that. Three paths return false; the rename path returns **true**, because
    its own warning says *"The finished save is at %s and _load will adopt it"* — the record
    is complete, validated and on disk, and the next launch picks it up. **A save
    confirmation that claims work was lost when it was not is worse than no confirmation.**
  - Found: three, none of them a bug.
    **(1)** the rename judgement above.
    **(2)** the SUCCESS sentence deliberately says nothing. Appending "saved" to every
    capture would put a word about disks on a screen about keys, forever, to cover a case
    that essentially never happens. Silence is the confirmation; only the failure gets
    words — which is also what made `persisted_note` return its caller's sentence unchanged
    and therefore testable without a screen.
    **(3)** the failure sentence is unreachable in normal play, which is exactly the kind
    that ships misspelled. It is built by a pure static both branches of the test read,
    rather than assembled inline at the two call sites where nothing could see it.
  - Cheaper: little. The change is small and the mutation was one command.

- **The launch was declined for a SAFETY reason, which is a first this session.** Every
  earlier decline was "the test already makes this claim". Here the branch is only reachable
  by making a save FAIL, and doing that live writes the developer's real `user://` —
  CLAUDE.md warns about exactly this and `--isolated` does not isolate `user://`. The test
  redirects `RunConfig.save_path` to an unwritable path and restores it, which is the only
  safe way in. Worth adding to the launch-triage question from cycle 115: **"what claim can
  the launch make" has a sibling, "what would the launch have to break to make it".**

- Gap: **no gap this turn.**

## 2026-08-18 — cycle 121: a skill whose first application disproved one of its own sections

- Value: **warranted** — the run's whole product is a correction to the thing it produced,
  which is only visible by running the method on a real set.
  - Expected: the skill has been identified three times and never built. Predicted: applying
    it to the existing sprites will find at least one whose fill is too close to its
    background, because the Mint and Nettle post-mortems say the trap is easy to fall into.
  - Got: the prediction was **wrong in the useful direction**. The corrected audit over 22
    sprites found ZERO real problems. What it found instead was that **the skill's own audit
    method was wrong**: reading the DOMINANT colour's luminance gap flagged five sprites —
    Mint (dL 13), Aloe (9), aphid, Shield Bug and Queen (17–18) — and every one is fine.
  - Found: three.
    **(1) five false positives out of five flagged.** The separation lives in the RIM,
    because `STYLE.md` mandates "outline = darker shade of the fill, 2px" — so the fill is
    free to sit anywhere. The section now reads the best MAJOR colour and records the
    false-positive rate, so nobody re-derives the naive version.
    **(2)** the 5% floor guards the OPPOSITE failure: without it, "best major colour" is
    whatever two-pixel highlight is brightest and the check passes on everything. Two
    corrections, opposite directions, both needed.
    **(3)** the rim is doing a job `STYLE.md` does not claim for it — it justifies the
    outline as a Flash-export lookalike, and its real function is legibility against the
    ground. Filed to kanban.
  - Cheaper: nothing. The false-positive rate is invisible without running the method on a
    real set, and reading the sprites would not have shown it.

- **This is exactly what the loop's "USE the skill in the same cycle" rule is for.** The
  rule says the first application tells you whether the skill is a recipe or an essay. One
  section of this was an essay, it took about ten minutes to find out, and the correction is
  now the most useful paragraph in the file.

- Gap: **no gap this turn.** Tier (e) — the diff IS the run's output rather than its subject,
  so reach is not expected and the row says so. Worth noting the harness was not involved at
  all: this was PIL over rendered PNGs, and the one thing that would need the bridge
  (sampling the aphid's rim at its drawn 0.72 scale rather than in the source) is filed
  rather than done.

## 2026-08-18 — cycle 122: the obvious implementation was wrong, and only a probe showed it

- Value: **warranted** — the first implementation shipped the exact defect the bead exists
  to remove, and nothing static could have told me.
  - Expected: the bead proposes a real touch layer committing on RELEASE so a finger can
    slide to the right cell with the preview following. Predicted: mouse emulation is on by
    default and must STAY on (every Button is a Control answering mouse events), so the work
    is telling the emulated press apart from the real one — and the obvious way is a flag
    set by the touch handler.
  - Got: **the flag cannot work.** Probed on the running game with
    `set-feature --touchscreen true` and one `touch press`:

        PROBE mouse press  device=-1  touch_index=-1
        PROBE screen touch pressed index=0 device=0

    The emulated `InputEventMouseButton` arrives **before** the `InputEventScreenTouch` that
    produced it. A guard set by the touch handler is always too late, and my first
    implementation planted at the PRESS cell — precisely the behaviour commit-on-release
    exists to remove. No ordering of the branches fixes it.
  - Found: three.
    **(1)** the ordering above, and that the obvious design is wrong because of it.
    **(2)** the discriminator is the **device id** — Godot marks the emulated event -1 and a
    real one 0. Narrowed by `is_touchscreen_available()` on purpose: `device == -1` means
    *synthesised*, not *from touch*, and the bridge's own `mouse-move` sends one, so on a
    desktop with no touchscreen a -1 event is a test driving the game and must be honoured.
    **(3)** the headless test **cannot** reach the emulated-mouse half, because
    `is_touchscreen_available()` is a property of the machine. A rare case this session
    where the bridge check and the suite genuinely cover different halves rather than the
    launch re-confirming what a test already asserted.
  - Cheaper: nothing. Reading Godot's source might have settled the ordering; a probe took
    two minutes and is quotable in a comment.

- **The bridge's touch verbs are the only reason this was verifiable at all.**
  `set-feature --touchscreen`, `touch press/drag/release/list` drove the whole acceptance
  gesture — press at one cell, drag to another, release — and showed 0 plants, 0 plants,
  then one plant at the cell under the finger at RELEASE. Without them this would have been
  "implemented, untested, needs a phone".

- Gap: **no gap this turn.** Worth recording the shape that worked, since three cycles of
  declining launches makes it easy to forget: a `print()` probe, launched, one bridge verb,
  read `.devtools/launch_stdout.log`, probe removed. Two minutes, and it answered a question
  about engine event ordering that no amount of reading the diff could.

## 2026-08-18 — cycle 123: the shop and the panel disagreed about the same plant

- Value: **warranted** — the sweep found one promise that had stopped being true, and the
  player could see the contradiction without leaving the screen.
  - Expected: nine blurbs, two already pinned, seven making factual promises nothing checks.
    Predicted at least one has drifted, because these were written across many cycles and
    the constants they name have been retuned since.
  - Got: one. The Sundew's blurb said *"crawls at half speed"*; `StickySundew.SLOW_FACTOR`
    is **0.55**, and the selection panel prints the real number — *"Slowing N pest(s) to 55%
    speed."* **The shop and the panel disagreed about the same plant**, both on screen, one
    click apart.
  - Found: three.
    **(1)** the Sundew. The SENTENCE moved, not the constant: 0.55 is tuned and carries its
    own overlapping-patch reasoning, and changing a balance number to make a blurb true is
    the tail wagging the dog.
    **(2)** the assertion is a RELATIONSHIP, not a corrected string — the blurb may say "at
    half speed" **if and only if** `SLOW_FACTOR` is 0.5. A future retune to an actual half
    makes the sentence permissible again, rather than leaving a test that hard-codes today's
    wording.
    **(3)** the denominator is what outlives the cycle. Every plant must appear in the test,
    checked or explicitly named as checked elsewhere, so the tenth plant fails until somebody
    decides whether its blurb makes a checkable claim.
  - Cheaper: reading the nine blurbs beside the constants they name — which is what this
    was, about fifteen minutes. The test is what stops it needing doing again.

- **Six of the seven were true, and that is the useful shape of the result.** Mint's "a
  third again as fast" (1/0.75 = 1.333×), the Aloe's "too slow to save one being eaten"
  (3.0/s against `EAT_DPS` 14.0), the Corn's "upgrades to a bunch" naming the actual top
  rung, the Dandelion rearming inside a prep gap, the Sundew catching a winged pest. The
  writing in this project is careful; what it lacked was anything that would notice when the
  code moved underneath it.

- Gap: **no gap this turn.** Headless-only, and the reason is unusually clean: blurbs live in
  `tooltip_text`, so there is no width budget a launch could measure, and every claim is a
  relationship between two values the test reads directly.

## 2026-08-18 — cycle 124: I broke the file that detects the break, for the third time

- Value: **warranted** — the mode works and is verified both directions, and the way it went
  wrong on the way is better evidence for the rule than the feature is.
  - Expected: the survey sweeps git blobs, so it cannot see an uncommitted defect — which is
    the only time the defect exists, since it is introduced while editing. Predicted a
    `--worktree` mode is a second INPUT to the same two detectors, not a second detector,
    and that the exit code must differ by mode or a historical hit makes it permanently red.
  - Got: both, and it now catches what it could not. Positive control — a broken string
    literal in a tracked `.gd` — gives `2 hit(s)` named by `file:line`, exit 1. Negative
    control, fixture removed: 0 hits, exit 0. History mode unchanged at 1028 versions and
    still advisory.
  - Found: three.
    **(1) I broke this file with the exact defect it detects, for the THIRD time in its
    history.** Writing its `NOT_COVERED` constant through a shell heredoc turned every
    escaped newline into a real one inside a string literal — twice in one patch. The file's
    own header already records two such incidents while it was being written. Fixed by
    joining a list of plain lines, which has no escape to eat.
    **(2)** the exit code HAD to differ by mode and the first draft did not. A hit in
    HISTORY already happened and was already fixed — gating on those is permanently red,
    which `house-static-checker` calls worse than no gate. Only `--worktree` gates.
    **(3)** the positive control needed a TRACKED file: `worktree_versions` uses
    `git ls-files`, so an untracked fixture is invisible and the control would have passed
    over nothing. `git add -N` was the fix — the same vacuity trap cycle 116's citation
    fixture hit from the other direction.
  - Cheaper: nothing. Both controls are one command each.

- **The rule now has a check that runs in a fan-out lane.** `lint_project.gd` was the only
  thing that could see this class and it is not parallel-safe, so a lane got `name_check`
  and nothing else. `--worktree` is stdlib, opens no project, and takes a second — it is in
  the cycle skill's step 2 beside the rule it guards.

- Gap: **no gap this turn.** Third occurrence of the no-scripts-write-source rule this
  session, and the honest note is that all three were mine, in a file whose entire subject is
  that failure. The rule is right; I keep reaching for the tool it forbids when an `Edit`
  match looks awkward, and the correct move is `Read` the bytes and `Edit` again.

## 2026-08-18 — cycle 125: the rung names were budgeted, and the survey missed its own signature

- Value: **warranted** — two real defects, each caught by a different gate, and neither was
  the feature.
  - Expected: the bead's taste call was two rungs buying TIME via resistance rather than
    health, so the Aloe scales with the upgrade. Predicted the two hand-lists it names would
    both fail until fed — those are deliberate gates and they did.
  - Got: the ladder works and the panel tracks it live — `Holds 11s` → `Holds 16s` →
    `Barrier Bramble — bulwark / Holds 24s`, with a fourth upgrade refused as "already fully
    grown".
  - Found: three.
    **(1) THE RUNG NAMES ARE BUDGETED, and nothing said so.** The panel's first line is
    display + rung and `selection_corpus` crosses every plant with every rung, so
    *"Barrier Bramble — deep thicket"* at 30 characters against the previous worst of 25
    pushed `hud_selection_panel` **25 px through its floor**. The budget check reported it
    with three ways out, one being "shorten the plant name". Renamed to "bulwark" — 25
    characters, exactly the existing worst case, so this ladder spends none of that budget.
    **(2) I dropped a leading `#` while editing through a script — SIGNATURE B, the exact
    defect the survey I built LAST CYCLE detects — and it reported 0 hits.** Its `PROSE`
    regex needs a line starting with a capitalised word and containing no code tokens; mine
    started lowercase and contained `selection_level_names()`. **lint** caught it at the
    exact line. The survey's coverage of SIGNATURE B is far narrower than its name suggests,
    on a codebase whose comments cite function names constantly.
    **(3)** the design assertion had to be about what a HEAL is worth, not about the wall
    lasting longer — "each rung holds longer" is equally true of the bigger-pool ladder the
    bead argued against. Mutation-tested by flattening the resistances, which is exactly
    what the pool version looks like from here.
  - Cheaper: the budget check and lint caught both real defects, headlessly. The launch
    confirmed the readout tracks the rung, which IS the feature and which no headless test
    reads across an upgrade.

- **Fourth script-edit damage this session, and the first the survey could not see.** The
  previous three were caught by lint or by the runner's stderr; this one was too, and the
  tool built one cycle ago specifically for it stayed silent. Filed rather than patched
  blind — widening `PROSE` without a fixture would trade a false negative for false
  positives, and its first version already reported 554 of those.

- Gap: **no gap this turn.**

## 2026-08-18 — citation_check names its sources and reads bead prose

- Value: **warranted** — the harness proper did not run at all (tier (f), tooling-only), and
  the run that mattered was the new checker over the real bead export, which falsified its
  own first result.
  - Expected: `--beads` would read ~500 citations out of bead prose and either find broken
    ones or confirm they resolve; the interesting part would be the findings.
  - Got: `citation_check: 362 citation(s) across 1 file(s) [kanban.md] + 468 bead(s), 362
    resolved, 0 finding(s)` — ten new citations from 468 beads, printed as a clean sweep.
    `bd` stores `description` and `close_reason` as PLAIN TEXT, so the markdown backtick
    convention `CITATION` requires is simply absent: measured 95 backticked against 495
    unbackticked. The mode was reading one citation in six.
  - Found: that, plus `check_all.py`'s `run_one(name, [])` — an opt-in mode added to a
    pooled checker never runs in the pool, so the feature would have shipped inert. Then
    two more, both from running the new checker over what this cycle itself wrote: the
    first bead the feature ever closed WAIVED ITSELF, because its close reason quotes the
    waiver marker and the marker was a bare substring (468 beads → 467, three citations out
    of the denominator, exit 0, silent); and step 3's own `--against` run came back with
    five drifted citations, all in closed beads pointing into `cycle-log.md`, which grows
    ~25 lines at its top every cycle — a gate that would have been red every cycle forever.
    Closed-bead drift is advisory now, and the gating half was positive-controlled by
    corrupting a `kanban.md`-cited snapshot entry (exit 1, `DRIFTED:
    game/OVERLAY_GRAMMAR.md:55-56 (written at kanban.md:1424)`).
  - Cheaper: nothing. The 95-vs-495 split is a fact about how `bd` stores prose; it is
    invisible in the diff and only shows up by running the extraction over the real export.

- Gap: **the installed ledger drops `tier` without a word** — `/verify` Phase 0.5 (plugin
  0.60.0) says "Record the tier on the row … `run.json` carries `"tier": …`", and this
  project runs harness 0.38.0, whose `verify_ledger.py` reads no such key. The row was
  written with `tier: "tooling"` and came back without it.
  - Only this repo's own `tools/run_json_check.py` said so: `FINDING: unknown key 'tier' --
    verify_ledger reads it nowhere, so it will be dropped without a word and the row will
    not carry it.` A project without that checker records the field, sees a clean
    `recorded pass run`, and believes its ledger is tier-tagged.
  - [G-130] status: open | seen: 1 | harness: 0.38.0
  - Improvement: this is the 0.38.0-vs-0.60.0 spread (`-ny3h`, blocked on upstream gh#43),
    not a new upstream defect — the key landed in 0.50.0. Worth logging because it is the
    first time the version spread produced a SILENT wrong record rather than a missing
    feature: the skill text and the installed tool disagreed, and the skill won on the
    write side while the tool won on the read side.

## 2026-08-18 — the notebook audit, and the legend page counting its own rows

- Value: **warranted** — the launch produced a claim the diff could not, and the headless
  runner caught a defect in my own test that the suite itself reported as a pass.
  - Expected: the derived note would read "six" and the two extra characters would still
    fit the note box; the launch would confirm what the unit test already asserted.
  - Got: `NoteLabel.text` on the live screen carries "...so the six here are worth more
    than six facts...", and `contained-in NoteLabel within Paper` passed at
    `658,372 400x142` inside `76,32 1000x584`. `findings --no-scenes`: `0 finding(s)
    across 4 of 5 checks`.
  - Found: three things, none of them the thing I was looking for. (1) `_T.assert_equal`
    does not exist in this suite — it is `assert_eq` — and the aborted method returned
    `""`, which `run_tests.gd` prints as `[PASS]`. Only `run_tests.py`'s stderr and
    `Assertions: 0 executed` saw it, exactly as CLAUDE.md warns. (2) Pre-existing and
    unrelated: `test/unit/test_selftest.gd:10562` formats a message with `%r`, which
    GDScript cannot format — 12 `String formatting error` lines per full suite run under a
    green `ALL TESTS PASSED`, confirmed pre-existing by stashing and re-running. Filed as
    `-kl7r`. (3) The legend page was showing a correct derived count and a wrong
    hand-written one at the same time, which is why the wrong one survived.
  - Cheaper: for the count itself, the unit test alone. The launch earned its place only
    because a player-facing word got two characters longer, and that is a layout question
    no static check answers.

- Gap: **the ledger's reach denominator measures the BRANCH, not the run** — this run
  reported `reached 2/15 changed file(s)` while `git status --porcelain` shows five
  modified files, two of them `.gd`.
  - `tools/verify_ledger.py:297` derives changed files as
    `git diff --name-only <base> HEAD`, where base is the first of
    `origin/main, main, origin/master, master` that resolves — documented at `:274` as
    "the branch's accumulated diff", which is exactly what it does. This checkout is
    **56 commits ahead of origin/main**, because the project's push policy is deliberately
    to batch (every push auto-deploys to itch.io), so the denominator is 56 cycles of work
    and grows every cycle.
  - The consequence is that `reach` trends toward zero on this project regardless of how
    well any individual run is targeted, and `verify_ledger.py stats` aggregates it. The
    numerator is still honest — `notebook_screen.gd` was reached and is absent from the
    NOT-reached list — but the ratio is not a statement about the run.
  - [G-131] status: open | seen: 1 | harness: 0.38.0
  - Improvement: derive the denominator from the run's own working-tree diff plus the
    commits since the LAST LEDGER ROW, not since the branch base — the ledger already
    knows when it last recorded. Failing that, print both and label them, so a reader can
    tell "this run touched little of a long branch" from "this run verified little of what
    it changed". Filed as a bead so it is not only a log line.

## 2026-08-18 — re-measuring the message row with player actions in it

- Value: **warranted** — the diff was EMPTY and the runtime produced a claim that reverses a
  conclusion two cycles have been carrying, plus a second one that inverts the bead's own
  prime suspect. This is the shape the harness exists for.
  - Expected: cycle 93 read `messages_refused` = 0 over six waves and concluded the row does
    not drop lines in ordinary play. I expected a run containing purchases and uproots to
    confirm it, or to produce a small non-zero number.
  - Got: `messages_refused = 12` after four packet purchases fired back to back during a
    live wave — exactly three per purchase, against `PACKET_OPEN_STEPS` = 3.
  - Found: the cause is not what the bead predicted, and four controls were needed to say so.
    One purchase on a quiet row refuses nothing; one over a deliberately-held ambient line
    refuses nothing and *preempts* four times; twelve pests spawned and killed with no
    purchase refuse nothing. The mechanism then reproduced with **no purchase at all** — one
    `MESSAGE_IMPORTANT` post held for 5s, then five more at equal priority: all five returned
    `false`, three queued (`MESSAGE_QUEUE_MAX` = 3) and two were refused. So the producer is
    the 5-second **reveal**, not the flicker, and the flourish's own comment describes only
    the case that drops nothing. Filed as `-47v7`.
  - Cheaper: nothing. Reading the code produced the *wrong* answer twice here — once in cycle
    93's close and once in the flourish's own comment — and both readings were reasonable.

- Gap: **nothing on the bridge can select a placed plant**, so the `MESSAGE_DEADLINE`
  producer — one of the two the bead named — went unmeasured and half its acceptance is
  unmet.
  - `run-method /root/Game _select ["<path>"]` cannot work: `_select` takes a `Plant` node
    and the bridge passes a `String`. None of the 69 registered verbs selects. And the
    documented workaround failed: `touch press`/`release` at the plant's `global_position`
    (read as `224,296` off the node) left `selected_placed` empty through four attempts,
    with `touch list` reporting `No active touches` after.
  - `cycle-log.md` carries "a plant is selected by a real click, which `cmd touch_press`/
    `touch_release` at its `global_position` will deliver" as durable knowledge. That did not
    hold in this run. Whether the note is stale, whether it needs `set-feature --touchscreen`
    before the scene loads, or whether the emulated-mouse guard in `_unhandled_input` changed
    which events reach the handler is **unestablished** — and the note is deliberately not
    edited until it is known which.
  - [G-132] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a project verb beside the existing `place_plant` / `upgrade_plant` /
    `collect_husk`, all of which already take `x,y` — `select_plant x,y`, plus a cancel, or
    arming becomes a one-way trip that uproots on the second call (which is what happened
    here). Filed as `-cfvb`, which says to settle the touch question FIRST, because if a
    click can select then this is a documentation gap and a verb is only a convenience.

## 2026-08-18 — a verb built on evidence, and the answer it was built to get

- Value: **warranted** — the verb's first real call settled a question that had been filed as
  unestablished one cycle earlier, and that no amount of reading could have answered.
  - Expected: `cmd messages` would collapse cycle 128's four-flag `find-nodes --class Hud
    --property ...` lines into one call, and `refused_log` would name which line a double
    purchase drops.
  - Got: two packet purchases back to back — `refused 1`, `refused_log ["The packet held a
    Chomp Flower!"]`, row showing `"The packet held a Barrier Bramble!"` with `3 pending`.
    The refused line is a **reveal**, so the player is told what the second packet held and
    never told what the first one did.
  - Found: three more. The log survives its own frame — read back after the row had cleared
    (`row_text ""`, `0 pending`) it still named the dropped reveal. A house gate
    (`test_every_positional_devtools_verb_refuses_a_call_with_no_position`) failed the first
    time the suite ran after the verb was registered, until `messages` was classified in
    `DEFAULTED_VERBS` with a reason. And `suite_reach_check` named all four new accessors as
    reached by no test — covered rather than waived, including that `message_queue_snapshot`
    returns a copy, since a debug verb handing out the live Dictionaries lets a caller edit
    the queue by looking at it.
  - Cheaper: nothing. `_queue_message` had the refused text in hand and discarded it, so the
    severity question is unanswerable from source by construction — `messages_refused` is the
    same number whichever of the four posts per purchase was dropped.

- Gap: **no gap this turn.** The bridge did everything asked of it: `cmd` reached a new
  project verb the moment it was registered, `list-commands` picked it up without being
  told, and `findings` / `quit` reported clean including "no file changed during this run".
  Cycle 128's `G-132` (nothing can select a placed plant) was not re-hit, because this
  cycle's producer is a purchase rather than an uproot — it stays `open` at `seen: 1` rather
  than being bumped for a run that never needed it.

## 2026-08-18 — a bead I filed, disproved by the surface it was about

- Value: **warranted** — but note the harness proper barely ran. This was tier (c)
  headless-only, and the thing that produced the result was `grep` plus reading, not the
  bridge. Recording it as warranted because the run produced a claim that reversed a P2 and
  caught two wrong numbers, not because the tooling was clever.
  - Expected: to confirm `-djvk` and give the notebook a weather page. It never says
    "drought" and the player meets drought from wave 4.
  - Got: the bead is wrong, and I filed it. Weather is taught three times, each where it can
    be acted on — the prep note before seeds are spent, a banner carrying the entire mechanic
    in one sentence ("Everything shoots half as often — and every pest pays 150%"), and a
    status row after. Cycle 127 enumerated over `notebook_screen.gd` and concluded about the
    game.
  - Found: two more, both by reading back citations I had just written. The comment recording
    the decision quoted "pests pay 25%" twice, invented rather than read
    (`WEATHER_DROUGHT_SEED_BONUS` is 1.5). And the cycle's 27-line insertion drifted eleven
    citations, of which **six were already wrong before this cycle touched anything** — a
    uniform-offset restore satisfies `--against` while preserving a citation that points at a
    blank line. Filed as `-oa6z`.
  - Cheaper: one `grep drought game/hud.gd` in cycle 127, before filing the bead. Four hits.
    That is now written into `notebook_screen.gd` as a standing instruction rather than as a
    lesson in a closed bead, because a warning inside a bead did not survive to the next one.

- Gap: **`--snapshot`/`--against` cannot distinguish a restored citation from a correct
  one**, and this is a gap in a tool this project owns rather than in the harness.
  - Relocating eleven drifted citations by matching the snapshot's recorded text worked for
    four and reported `AMBIGUOUS` for the rest — **114 candidate lines** for one of them,
    because the recorded text was blank. Applying the uniform `+27` made `--against` report
    `0 drifted` for all eleven, and reading the landings then found six pointing at a blank
    line, an autowrap setting, a Label name, a shelf-greying comment and a sprite path.
  - Not filed as a `[G-NNN]` harness gap: `citation_check.py` is this repo's own tool, so it
    is `-oa6z` with an acceptance that starts with the COUNT — nobody knows how many of 931
    citations land somewhere unverifiable, and the sample this cycle was six wrong out of six
    read.
  - [G-133] status: open | seen: 1 | harness: 0.38.0
  - Improvement: the harness-side half is that `verify_ledger`'s `reach` and this project's
    citation drift both answer "did the thing I claim to have checked actually get checked",
    and neither can see a claim written in prose. A `--weak` pass that lists citations whose
    landed text is uninformative is the cheapest version of that for any project keeping
    file:line citations in markdown, which is why it is logged here as well as filed.

## 2026-08-18 — the clearest case for the runtime pass this project has produced

- Value: **warranted**, and not marginally. Five headless gates and a purpose-written unit
  test all agreed a bug was fixed; one live reproduction of a recipe written two cycles
  earlier said it was not, and it was right.
  - Expected: serialising the packet flourish would stop the first reveal being refused, and
    the unit test asserting the queue would prove it.
  - Got: against fix v1 — `refused 1`, `refused_log ["The packet held a Chomp Flower!"]`,
    **identical to cycle 129's measurement**, while `920/920`, `lint 0/0`, import clean and
    `check_all 19 of 19` all passed. A flourish lasts ~0.25s, so two purchases half a second
    apart never overlap and the guard never engaged; the second flourish started fresh and
    posted behind the first's five-second reveal.
  - Found: that, plus the shape of why the test could not see it — it fires both purchases in
    the same frame, which is the one case serialisation alone did cover. The third test now
    covers the case that actually broke, asserted through the row's state rather than by
    sleeping 3.8 seconds. Against fix v2: `refused 0, 0 pending`, and polling the row shows
    `"The packet held a Salve Aloe!"` → `"...Sticky Sundew?"` → `"The packet held a Sticky
    Sundew!"` — both reveals in turn with the second packet's flicker still playing.
  - Cheaper: nothing, and this is the entry to point at when `overkill` starts to look like
    the usual verdict. The diff was seventeen lines of GDScript, every static gate was green,
    and the game was broken.

- Gap: **no gap this turn**, and one thing worth crediting rather than filing. `cmd messages`
  — built last cycle — is what made this diagnosable at all: `refused 1` plus the refused
  line's text, in one call, is the difference between "something was dropped" and "the first
  packet's reveal was dropped". A verb built one cycle earlier for a different question paid
  for itself here. `launch --snapshot-userstate` also worked exactly as documented: `quit`
  reported `restored 1 file(s)` on both launches, against cycle 128 where an unguarded run
  wrote the developer's real `highscore.save`.

## 2026-08-18 — the count nobody had, and a fixture that had to fail both ways

- Value: **warranted** — the harness proper did not run at all (tier (f), tooling-only), and
  the result is a measurement of this project's own evidence quality rather than of the game.
  - Expected: `--weak` would print how many citations land somewhere no text comparison can
    check. I had no estimate of how many of those would be actually WRONG.
  - Got: `58 of 937 resolved citation(s) land somewhere that carries no information -- 6%`,
    broken down 26 blank / 16 bare `##` / 10 repeated-line / 6 braces and keywords.
  - Found: four sampled from `kanban.md`, **all four wrong**, each confirmed by locating the
    symbol its sentence names — `uproot_armed()` off by 491 lines, the `Really uproot? (+N)`
    button by 586, the `_has_fired` gate by 250, and one pointing at a blank line for a call
    1900 lines away. Fourteen of fourteen across four cycles, so the 6% is a floor on the
    wrong-citation count rather than a triage list.
  - Cheaper: nothing. The count required classifying every resolved citation and the
    wrongness rate required reading them.

- Gap: **no gap this turn** — and one self-inflicted incident worth recording against the
  project's own rule rather than the harness's. Writing the fixture through a Python heredoc
  ate a `\n` inside a string literal, in the cycle whose entire subject is citations that
  silently point at the wrong thing. `.claude/skills/cycle/SKILL.md` forbids exactly this and
  names it as the shape the rule keeps getting broken in — reaching for a script when `Edit`
  looks awkward. Python turned it into an immediate `SyntaxError`, which is the difference
  between this and the GDScript case the rule was written for, where the same damage compiles
  and passes 613 tests. Fixed with `Edit`. That is the fifth occurrence and the log entry is
  the countermeasure the rule already says it is not; using the right tool is.

## 2026-08-18 — the flag that made every save verification meaningless

- Value: **warranted** — the runtime pass disproved a P2 bead's diagnosis and replaced it
  with a worse one, and neither could have been reached by reading.
  - Expected: to confirm `-zzx3` (`--snapshot-userstate` failed to restore, so a run's write
    survived into the developer's real save) and close it.
  - Got: the opposite mechanism. `_save()` returns **FALSE** under the flag and **TRUE**
    without it — same build, same three calls, sixty seconds apart, file byte-identical
    during the flagged run. Nothing survives because nothing is ever written.
  - Found: `quit` prints `userstate: restored 1 file(s) and removed 0 created during the run`
    **unconditionally**. I read that exact line twice in cycle 131 and took it as
    confirmation the flag was doing its job. It is a report about the mechanism, not about
    the run.
  - Cheaper: nothing. Both the symptom and its correction needed a live game driven twice
    with and without one flag.

- Gap: **`launch --snapshot-userstate` prevents the game from saving**, so every runtime
  verification of save-related behaviour taken under it was run against a game that cannot
  save and would pass identically either way.
  - Reproduce: `launch --snapshot-userstate`, then
    `run-method /root/RunConfig --method toggle_mute_sfx` (true) and
    `run-method /root/RunConfig --method _save` (**false**); `user://highscore.save` is
    unchanged. Repeat without the flag: `_save` is **true** and the file changes.
  - The developer's real save was backed up by hand first and verified byte-identical after
    (`4a0369eb1eb6d1716da1`) — this project's own `-zzx3` is the warning that a careless
    experiment here is silent data loss, and it was right about that.
  - Not established: **why** the write fails. The plausible cause is the snapshot holding the
    file open or read-only so `FileAccess.open(WRITE)` fails, but the harness implementation
    was not opened. Read the 0.60.0 template first — this project runs 0.38.0 and
    `harness-version --client` says outright that gaps logged against it may already be fixed.
  - [G-134] status: wontfix | seen: 1 | harness: 0.38.0
  - **WITHDRAWN IN CYCLE 134 — this gap is not a gap.** Re-run with the order reversed
    (plain launch first, flagged second), `_save()` returns TRUE under the flag, twice.
    `userstate_snapshot` (`tools/devtools.py:1835`) copies matching files into `.devtools/`
    with `shutil.copy2` and holds nothing open, so it cannot affect `user://` writability.
    The real trigger was an unknown milestone id left in `earned_milestones` by
    `record_milestones`, which makes `_save()`'s readback fail for the rest of the session —
    a defect in this project's own save code, now fixed. I filed a P1 against the harness on
    a paired measurement without reading the implementation the bead itself told me to read
    first. The half that survives: `quit`'s restore line is printed unconditionally and is a
    report about the mechanism rather than about the run.
  - Improvement: two, and the second is worth having even if the first is fixed upstream.
    (1) make the write succeed under the flag — snapshot by copying, not by holding.
    (2) make `quit`'s restore line report what it DID: "restored 1 file(s), 0 of which the
    run had modified" is the honest form, and it would have exposed this a cycle earlier.
    Filed as `-ooih` at P1.

## 2026-08-18 — a 4-lane fan-out, and every lane started 71 commits behind

- Value: **warranted** — four lanes shipped six beads, and the parent pass found what the
  merge skill says it always finds. The harness itself barely featured; the finding is about
  the fan-out mechanism.
  - Expected: four independent lanes on disjoint files, merged with one appended-test
    conflict.
  - Got: that, plus **every worktree checked out at `origin/main` (`2563734`), 81 commits
    behind local `main`**. `isolation: "worktree"` branches from the remote, and this project
    batches pushes on purpose, so the default base is arbitrarily stale.
  - Found: the failure mode is worse than a merge conflict. On the stale tree
    `tools/citation_check.py` had no `--beads` mode at all, so one lane's bead cited three
    sightings of which one did not exist — it would have reported "premise disconfirmed" and
    been wrong. Two lanes caught it unprompted and rebased; one was told mid-flight and redid
    its work; the fourth was on main by luck of timing. **A stale lane's gates all pass,
    because the stale tree is internally consistent.** Written into
    `.claude/skills/fan-out-a-cycle/SKILL.md` as step 0, with the check and the verbatim
    prompt paragraph, since the next fan-out's author is the person who needs it.
  - Cheaper: `git rev-list --count origin/main..HEAD` before spawning. One command.

- Gap: **no harness gap this turn.** The lane gate allowlist (`check_all.py` alone) held —
  19 of 19 clean in the parent after every merge — and the parent pass caught exactly what
  `merge-the-fanout` predicts it catches: an appended-test conflict where both sides held two
  real tests, resolved by deleting only the three markers and asserting the `func test_` count
  was unchanged (446 → 446) rather than eyeballing it.

## 2026-08-19 — five lanes, and the live game correcting a constant I wrote from a bead

- Value: **warranted** — the runtime pass caught a defect every headless gate passed, and it
  was mine.
  - Expected: five independent lanes, merged with appended-test conflicts, and a parent pass
    over what the lanes could not compile or run.
  - Got: that, and `cmd budgets` on the running game disproving a constant I had just
    written. `BUDGET_FLOOR_ACCEPTED` was drafted from `-ais1`, which says three rows are
    permanently at floor; the live reading is
    `[husk_click, run_summary_values, hud_readouts, hud_selection_panel]` — **four**, and my
    draft named one that is not at floor while missing two that are.
  - Found: **every headless test passed over the wrong list**, because they assert the
    warning's behaviour against whatever the list says. That is correct test design and
    completely blind to the list being wrong. Shipped, it would have warned on every launch —
    the exact wallpaper the bead exists to prevent. Also: lane C rated itself `insufficient`
    for having compiled nothing, and the parent's suite run (933/933) plus a live
    `find-nodes --class NotebookScreen --property name` returning
    `/root/TitleScreen/Notebook name=Notebook` is what actually settled its two runtime-API
    questions.
  - Cheaper: one `cmd budgets` call **before** writing the constant rather than after. The
    launch was going to happen anyway; the ordering was the mistake.

- Gap: **no harness gap this turn**, and one bridge limitation worth recording rather than
  filing. `run-method` cannot pass a typed `Array[String]` parameter — calling
  `new_floor_warning(["a"],["b"])` returns `null` with the "declares `-> String`, check stderr"
  hint, because the untyped Array the bridge builds does not satisfy the typed signature. The
  workaround was to verify the equivalent claim instead: read `at_floor` off `cmd budgets` and
  show it equals the constant, which makes the warning silent by construction. That is a real
  answer and not a lesser one — but it is worth knowing before designing a pure static with
  typed Array parameters and expecting to drive it from the bridge.
  - Credit where it is due: `-6wfo`'s change proved itself on the very next row recorded —
    `union 2/18` beside `worktree 1/1`, same run, opposite readings. The union number is the
    one the ledger printed alone for 148 rows.

## 2026-08-19 — five lanes, and a budget that was wrong in the safe direction

- Value: **warranted** — the runtime pass confirmed a defect a lane had predicted but could
  not execute, and the live game settled two more claims lanes had rated unverifiable.
  - Expected: five lanes on disjoint files, merged with appended-test conflicts, and a parent
    pass over what the lanes could not compile or run.
  - Got: a real budget defect, predicted by the lane that wrote the instrument and confirmed
    by the parent running it — `Root/SidePanel/PacketButton renders at 16 but
    Hud.packet_rack_budget() via GardenTheme.BUTTON_FONT_SIZE prices it at 18`. Live after
    the fix, `cmd budgets` reads `at font size 16` and `159 of 232 px`, against a comment
    claiming 179.
  - Found: the defect was **wrong in the safe direction** — over-pricing, so nothing ever
    overflowed and nothing complained. It reported less headroom than the rack has, for as
    long as the comment beside it argued the reasoning correctly and concluded it wrongly.
    Also settled lane 1's `inconclusive` (943/943 on three tests it never executed) and lane
    4's skill citations (24/24 resolved).
  - Cheaper: nothing for the defect. But for the **relocation** — see the gap below — an
    hour of this cycle went into 105 drifted citations, and that is now the single most
    expensive consequence of fanning out.

- Gap: **a five-lane merge drifts ~100 citations, and relocating them is now a large
  fraction of the cycle.**
  - 72 relocated by matching the snapshot's recorded text; 25 by piecewise offset
    interpolation; **8 refused** because the bracketing anchors disagreed. That refusal is
    the feature — `hud.gd`'s real offsets this cycle span **0 to +127**, so the uniform
    per-file offset that worked in cycle 131 would have laundered errors here exactly as it
    did in cycle 130.
  - Reading the 8 found **three describing problems that had since been solved**, not
    citations that had moved. Those were marked superseded with the derived answer rather
    than repointed.
  - [G-135] status: open | seen: 1 | harness: 0.38.0
  - Improvement: the interpolation logic is currently a scratch script. It belongs in
    `tools/` beside `citation_check.py` as `--relocate --against SNAP`, printing the plan and
    **refusing the ambiguous ones by name** rather than applying a blanket offset. The refusal
    list is the valuable output: it is exactly the set a human must read, and it was 8 of 105
    this cycle rather than all 105.
  - Also worth noting and not filed: `citation_check --beads` does not walk
    `.claude/skills/`, so every skill carrying `file:line` claims is outside the gate's
    denominator. Lane 4's 24 citations were only checked because it invoked the checker on
    its own file by hand.

## 2026-08-19 — Cycle 137: four lanes, two parent items, and a banner nobody has ever seen

- Value: **warranted** — runtime made one claim the suite structurally cannot, and it
  is the claim the cycle's main bead was filed for.
  - Expected: the two new bus verbs (`select_plant`, `deselect_plant`) work OVER THE
    BUS. Every test calls them as pure functions against a hosted `Game` and never
    touches the bridge, so a verb registered under the wrong name, taking the wrong
    arg keys, or dying while building its reply would pass all 959 tests.
  - Got: `list-commands` shows `select_plant  args: x, y` and `deselect_plant (reads
    no args)`. The cycle-128 blocked scenario ran end to end: `select_plant` put a
    plant in `selected_placed`, `arm_uproot` answered `confirm needed` where it had
    answered `nothing is selected` through four attempts, and `deselect_plant`
    reported `was_armed: true` then `uproot_armed: false`.
  - Found: a false defect I nearly filed. `uproot_armed()` read `false` immediately
    after `arm_uproot` returned `confirm needed`. The confirm window is a 4-second
    clock and each bus round trip spends real time, so it had simply expired between
    two calls. Pausing the tree first gave `true`. `read-a-moving-value`'s exact case,
    and it cost one `pause` rather than a bug report.
  - Cheaper: nothing for the bus half — no headless test can reach the bridge, which
    is the entire point of those verbs. The banner-arbitration and key-alignment halves
    WERE cheaper headless and the lanes' own tests already held them; the launch only
    re-confirmed those, which is tier (c) and worth saying.

- Gap: **reach's evidence deadline is earlier than "before quit" — it is "while the
  diff's node is still in the tree", and nothing says so.** I opened the Keys screen,
  measured its nine `RowKey` labels with `node-bounds`, closed both overlays, THEN
  captured `scene-tree` — and `verify_ledger reach` reported `game/key_binding_screen.gd`
  as `NOT reached (loadable, and this run did not load them)`. That is correct and it
  is indistinguishable from a screen I never opened. The loop already warns that a diff
  confined to an unopened screen reaches nothing; the half it does not say is that
  VISITING the screen is not enough, because reach is computed from a snapshot rather
  than from a history. Workaround: capture `scene-tree` while each screen is open and
  pass `--scene-tree` repeatedly — two captures moved the number from 3/7 to 4/7.
  - [G-136] status: open | seen: 1 | harness: 0.60.0 | upstream: SeveralHerr/godot-selftest-harness#61
  - Improvement: `scene-tree` could stamp each capture with the visible screen, and
    `reach` could say "reached in capture 2 of 3" rather than merging silently — or,
    smaller and enough, one sentence in `reach`'s own output naming the deadline.

- Gap: **`run_json_check` is advisory by design, so chaining it before
  `verify_ledger record` does not stop a row losing keys.** Ran
  `python tools/run_json_check.py && python tools/verify_ledger.py record ...`. The
  check printed `6 key(s) in run.json, 11 accepted` and two findings — `'lint' is
  absent`, `'tests' is absent` — exited 0, and `record` proceeded. The row went in with
  `lint: null` and `tests: null` on a run where lint was clean and the suite was
  959/959. The ledger is append-only, so the row stands wrong; recorded here rather
  than rewritten, same rule as a superseded status line.
  - [G-137] status: open | seen: 1 | harness: 0.60.0 | upstream: SeveralHerr/godot-selftest-harness#61
  - Improvement: `record` should refuse a `--run` object missing a key it accepts
    (or warn loudly on stderr), since it is the only writer and the write cannot be
    undone. The check being advisory is right for a check; it is wrong as the last
    guard before an append-only write.

- Gap: **a fresh worktree gives a lane no compile at all, and all four lanes said so
  in the words the prompt asked for.** Not new — this is the known one — but four more
  sightings, and the shape of the cost is now measured: every lane returned
  `inconclusive` or `insufficient` as its own harness verdict, explicitly because
  nothing compiled or executed a line. The parent pass found one real merge failure
  (`suite_reach_baseline` after Lane 3's tests started naming `hide_banner` and
  `show_weather`) and one verb-classification failure on my own parent item. Both were
  facts about files the lane was correctly forbidden to open.
  - [G-129] status: open | seen: 3 | harness: 0.60.0
  - Improvement: unchanged — a `name_check --require-compile` able to bootstrap
    `.godot/` read-only from the parent checkout would close it. Lane 1 proposed the
    same independently.

- Note, not a gap: **`name_check --require-compile` reports `test/unit/test_board.gd`
  as failing on `Identifier not found: RunConfig`, and it does so on the UNMODIFIED
  file** — verified by stashing my change and re-running. The flag cannot see autoload
  singletons, so a test script touching one is un-compilable by it in isolation. That
  is a real limit on the one gate that gives a lane a compile, and it is worth knowing
  before someone reads it as a regression. Already implied by the flag's own docs; not
  filed separately.

## 2026-08-19 — Cycle 138: the launch log's own false alarm, and naming a cue by bisecting the board

- Value: **warranted** — both of this cycle's items produced claims no diff and no headless gate could, and the second one was found by a bridge verb rather than by reading code.
  - Expected: identify the marks in a player's screenshot from the draw calls, then confirm a one-shot hint fires.
  - Got: reading draw calls sent me to `WeatherOverlay.DROUGHT_MARK` (a 7 px horizontal line) and then to a pest health bar, both wrong. What settled it was `screenshot --hide /root/Game/Entities/<plant>/SoleCoverMarks --region 385,140,80,190` — the yellow rings vanished and the dark bars stayed, so they are two cues, not one glyph. Hiding `HuskLayer` and `WeatherOverlay` changed neither. The bar is `Board._redraw_deferred_road`, a Line2D child, which is why no `_draw()` grep could ever have found it.
  - Found: the launch error the user reported — `remove_child` refused mid-add — reproduced from the entry hook and fixed; `fire-entry-point campaign` calling the SAME method wrote nothing to stderr, which is what isolated it to launch timing rather than to the method. And, mid-run, the first cut of the defer hint stacked 11 refused messages into a realistic run; the suite caught that, not the bridge.
  - Cheaper: for the hint's behaviour, nothing — but the headless test already asserted the string reaches the Label, so the launch was only worth its cost for the WIDTH on a real 876 px row (headless measures `label.size.x` under a 64×64 window) and for seeing tip and bars composited.

- Gap: **no verb answers "what drew the pixel at (x, y)"** — identifying a 32×5 mark took five hide-and-capture rounds plus a `scene-tree --depth 1` scan of every child's position, and the answer turned out to be a Line2D pool under a node the first scan did not descend into. `find-nodes --class` cannot help, because the question is not what the node IS.
  - The workaround, which is the shape a verb should have: `screenshot --hide NODE --region X,Y,W,H` twice and compare one pixel. It works and it is O(number of candidate layers) round trips.
  - [G-138] status: open | seen: 1 | harness: 0.38.0
  - Improvement: a `what-drew --at X,Y` verb walking the CanvasItem tree back-to-front and reporting every node whose bounds contain that point, with its `script`, `z_index` and whether it is a `Line2D`/`Sprite2D`/`_draw()` painter. `node-bounds` already computes screen-space rects for one node; this is that, inverted, over the tree.

- Gap: **`reach` still cannot credit a file whose scene the entry hook replaces** — `game/title_screen.gd` read `0/1` on a run that had unquestionably executed `skip_to_game()`, because the title scene is gone by capture time. Recovered by firing `fire-entry-point notebook` to put `/root/TitleScreen` back and passing a second `--scene-tree`, which took the row to 1/1.
  - [G-137] status: open | seen: 2 | harness: 0.38.0
  - Improvement: unchanged — the capture deadline is per SCREEN, not per run. A `--scene-tree-auto` that snapshots on every scene change and unions the captures would remove the judgement call entirely.

## 2026-08-19 — merged the three loop skills into one `/cycle`

- Value: **overkill** — the only harness surface this turn was `name_check.py` inside
  `check_all.py`, and a skill/docs restructure has nothing for it to see.
  - Expected: nothing. No `.gd`, `.tscn` or `.tres` changed; the gates were run to prove
    the restructure did not break `mirror_check` or `citation_check`, not to verify code.
  - Got: `check_all: ran 19 of 19 discovered parallel-safe checker(s) -- 19 clean`, and
    `mirror_check` correctly went `DIFFERENT` after the `CLAUDE.md` pointer edit and back to
    `identical` after `--fix`. That second one was worth having: the pointer block now names
    a directory rather than a file, and the mirror is what stops `AGENTS.md` disagreeing.
  - Found: nothing in the game. In the skills, two rules I had dropped in the restructure
    (the worktree-per-lane default, and "one bus per checkout") — caught by a sentence-level
    no-loss diff of the old files against the new tree, not by any gate.
  - Cheaper: `python tools/mirror_check.py` alone, ~1s. `check_all` was ~4s and told me
    nothing the mirror check did not, but it is the cheapest way to be sure a deleted path
    was not cited by a checker.

- Gap: **no gaps this turn** — nothing was asked of the harness that it could not do. The
  one thing missing was in `skill-creator`, not here, and is logged in
  `C:\Users\gotmi\documents\github\log.md`.

## 2026-08-19 — filed the replayability epic (plant-tower-defense-s1o8) and five children

- Value: **inconclusive** — no gameplay, script or scene changed this turn, so no gate
  had anything to gate. The harness was used as a *reading* instrument, not a runtime
  one: `bead_prose_check.py` and `citation_check.py` ran, the bridge never launched.
  - Expected: nothing from runtime. The question was "what does this repo already
    assert about the road, the wave table and the title menu", which is a static
    question, and I predicted the checkers would confirm the bead prose was undamaged.
  - Got: `bead_prose_check.py` printed no findings against `s1o8*` — but only 1 of the
    6 new ids is in `.beads/issues.jsonl`, so that clean result is a statement about
    one bead, not six. `citation_check.py --quiet` over the six draft bodies:
    "1 citation(s) across 6 file(s), 1 resolved, 0 finding(s)" against roughly forty
    citations actually present.
  - Found: two wrong line citations, both fixed before filing — `Board.GRASS_EDGE_TILE`
    is at `game/board.gd:72` not `:76`, and the up-screen-travel comment is at `:36-43`
    not `:33-45`. Neither checker saw either; opening the file did. Also caught two
    stale claims in the backlog the beads were grown from: `WaveDirector.WAVES` is 22
    rows, not the eight `run_config.gd:14` still says, and `STARTING_SEEDS` is in
    `seed_bank.gd:16`, not `game.gd` as `kanban.md:2898` has it.
  - Cheaper: reading `test/unit/test_selftest.gd:7040-7065` alone, which is a
    hand-written inventory of every road-shape-dependent test and was worth more than
    both checkers put together.

- Gap: **`bead_prose_check.py` reads the JSONL export, and the export lags `bd create` by
  a whole session** — so running it straight after filing checks almost nothing. Ran it
  immediately after creating six beads; `grep -c s1o8 .beads/issues.jsonl` returned `1`.
  The tool's NOT COVERED line names what it cannot judge in the prose it reads, but not
  that the prose it reads may not include the beads you just wrote. Workaround: read one
  bead back with `bd show` and eyeball it.
  - [G-139] status: open | seen: 1 | harness: 0.60.0
  - Improvement: have `bead_prose_check.py` compare its JSONL row count against
    `bd stats` (or the DB directly) and print a second denominator — "N of M issues in
    the export; the export is K issues behind" — so a clean run after a filing session
    is legible as stale rather than as clean.

## 2026-08-19 — a shot pest recoils (plant-tower-defense-qhgs)

- Value: **warranted** — the yaw a player sees only exists in a running game; `_gait`
  early-returns on `animations_enabled()`, so every headless assertion is against the pure
  seam and none of them can read the composed value.
  - Expected: a real pest, shot by a real kernel, shows `_sprite.rotation` deviating beyond
    its own `GAIT_SWING` and returning to the plain gait within `FLINCH_SECONDS` — the
    claim the suite structurally cannot make, since `_gait` early-returns headless and every
    headless assertion is against the pure seam instead.
  - Got: exactly that, and measured rather than seen. `pause`, `run-method flash_hit`,
    then six `step-time --seconds 0.02 --then-pause` reads on one live pest:
    `_flinch_left` 0.28 → 0.2467 → 0.2133 → 0.18 … and `_sway` −0.2217, +0.0531, **+0.3664**,
    +0.1621, −0.0955, −0.0354. The peak is 2.8x `GAIT_SWING` (0.13). Stepping past the
    window: `_flinch_left: 0.0` with `_sway` back at −0.1281, −0.1275, −0.1098, −0.0773 —
    inside the gait's own band, so the recoil leaves no permanent offset.
  - Found: **the two populations do not overlap at all.** 24 samples of unhit pests across
    six steps peaked at `_sway=0.129999750999911` — `GAIT_SWING` to seven decimals, i.e. the
    sine actually reaches its analytic maximum in play. The headless test asserts
    `FLINCH_RADIANS > GAIT_SWING * 2.0` on the *constants*; only the running game showed the
    walk genuinely attains that ceiling, so the separation the constant promises is the
    separation a player gets rather than an upper bound the gait never approaches. A pure
    test cannot distinguish those two worlds.
  - Cheaper: nothing. There is no headless read of the yaw at all — the gate is the whole
    reason `gait_yaw` and `flinch_amount` were extracted.

- Gap: **the installed ledger drops `tier` without a word** — second sighting, same shape as
  the first. `/verify` Phase 0.5 (plugin 0.60.0) instructs `"tier"` on the row; this project
  runs 0.38.0, whose `verify_ledger.py` reads no such key. Written as `"tier": "full"`, the
  row came back without it, and again the only thing that said so was this repo's own
  `tools/run_json_check.py`: `FINDING: unknown key 'tier' -- verify_ledger reads it nowhere,
  so it will be dropped without a word`. `harness-version --client` names the cause in one
  line: `A newer harness (0.60.0) is already on this machine than this project runs (0.38.0)`.
  - [G-130] status: open | seen: 2 | harness: 0.38.0
  - Improvement: unchanged — this is the 0.38.0-vs-0.60.0 spread (`-ny3h`, blocked on
    upstream gh#43), not a new upstream defect. What the second sighting adds: the checker
    fires *after* `record` has already appended the row, so the finding arrives one step too
    late to act on — and the earlier entry at this file's `run_json_check is advisory by
    design` gap already found that chaining it with `&&` cannot work for the same reason.
    So the concrete ask is now one of two: `run_json_check` gates (exit 1) on an unknown
    key, or `record` refuses a key it cannot store.

## 2026-08-20 — the sixth one-shot names the sole-cover rings (plant-tower-defense-bkss)

- Value: **warranted**, and NOT from runtime — the harness never launched. This is a
  tier (c) headless-only row, and the value came from two budgets the diff could not
  show me.
  - Expected: nothing runtime could add. Written before Phase 1: the changed call site is
    driven end-to-end by a hosted-scene test, so I predicted headless-only and said so in
    the triage rather than launching to confirm what a test already asserts. Cycles
    110-115 recorded four launches of which two only re-confirmed a headless assertion;
    this is the triage table being used instead.
  - Got: two failures that are invisible in a diff. `[FAIL]
    test_the_notebook_hints_page_gives_back_a_hint_that_was_never_shown` —
    "'seen_sole_cover_tip' row bottoms out at 335px inside the 300px matte". And
    `message_corpus_check: FINDING: game\game.gd:1494 calls none of the corpus's
    producers -- Hud.sole_cover_tip()`. Then a third, downstream of the second: the
    suite's hand-kept count, "the corpus carries its 10 non-catalogue entries ...
    Expected 10 but got 11", which states its own resolution in the failure message.
  - Found: **the notebook's hints page has its own 300px ceiling and nothing in the repo
    says so.** The legend page's fullness is this project's most-cited budget — three
    beads turn on it — and I knew that one. The hints page uses the same
    `NotebookScreen.DRAWING_BOX` with an independent capacity model
    (`hints_capacity()`, three rows) and a pager of its own. A sixth card overflowed it
    by 35px. I would not have looked, because the surface I was watching was the message
    row's width, which is a different budget again. Filed as a kanban entry.
  - Cheaper: nothing — this WAS the cheap tier. The expensive mistake available here was
    launching, and the triage table is what refused it.

- Gap: **no new gaps this turn.** The one thing that bit twice is already
  filed: relocating drifted citations by script produced an inverted range
  (`2440-2412`), caught by `citation_check` plain mode reporting the target out of
  range. That is not a harness gap — it is the argument `plant-tower-defense-2174`
  already makes for a relocator that refuses rather than renumbers, and this cycle is
  its evidence. G-130 (the ledger dropping `tier`) was avoided rather than re-hit: the
  key was left out of `run.json` on purpose this time, `run_json_check` exited 0, and
  `runtime.skipped` carries the tier reasoning in prose where the schema will keep it.

## 2026-08-20 — the Chomp champs (plant-tower-defense-ts34)

- Value: **warranted** — the wiring from the new hook into `_sway_pivot.transform` sits
  past the `animations_enabled()` gate, so no headless test can read it at all. The suite
  asserts the pure `champ_scale`; only the running game says the composition happens.
  - Expected: that the champ actually reaches `_sway_pivot` on a live Chomp with a real
    pest in its mouth, and that an idle one does not move — the wiring lives past the
    animations gate, so the suite can only assert the pure function.
  - Got: exactly that, measured with `is_busy` and the pivot scale read in the SAME poll.
    Idle, 14 samples, `is_busy false` on each: x spanned `0.978 .. 1.022`. Chewing, 10
    samples with `is_busy true` pinned per read: x spanned `0.9446 .. 1.0478`. Both
    chewing extremes are outside the idle band.
  - Found: **the idle band IS the breathe's analytic maximum in play.** `BREATHE_AMOUNT`
    is 0.022 and the plant reaches `1.022` — so the separation the constants promise is
    the separation a player gets, rather than an upper bound the breathe never
    approaches. A test over the constants cannot distinguish those two worlds. (Same
    finding shape as cycle 139's pest recoil, which is now twice, and is an argument for
    always measuring the QUIET side of a "clearly bigger than" claim rather than the loud
    one.)
    And: **I nearly filed the opposite conclusion.** The first pivot samples read ±7%
    while `find-nodes` had just reported `is_busy false`, which looks exactly like "the
    idle breathe is three times its own constant". The Chomp had grabbed a pest between
    the state read and the scale read. `read-a-moving-value`'s question arriving in a
    shape it does not name: the VALUE and the PREDICATE were both moving, and pausing
    only the value is not enough.
  - Cheaper: nothing. `_wobble` early-returns headless, so the composition has no
    headless reader.

- Gap: **`verify_ledger.py record --about` takes ONE file, and the help does not say so.**
  This change spans `game/chomp_flower.gd` (the champ) and `game/plant.gd` (the hook), so
  `--about game/chomp_flower.gd game/plant.gd` is the honest narrowing. It exits with
  `error: unrecognized arguments: game/plant.gd`. `/verify`'s own Phase 5 text says
  "`--about <file> [<file> ...]` naming only the file(s) this run set out to verify",
  plural and bracketed, so the skill and the installed tool disagree. Recorded without
  `--about`; reach came out `1/2 (+1 by alias)` and correct, so nothing was lost here —
  but in a fan-out, where `--about` is the whole point, a two-file lane would be told to
  drop one.
  - [G-140] status: open | seen: 1 | harness: 0.38.0
  - Improvement: `nargs="+"` on the argument, or one line in the help saying it takes a
    single path. Same 0.38.0-vs-0.60.0 spread as G-130 — check whether 0.60.0 already
    takes several before filing upstream.

- Also worth recording, not a gap: **the run wrote the developer's real
  `highscore.save`**, and `quit` said so unprompted — "A save changed here is loaded by
  the game's next start, including the headless test suite, and reads there as an
  unrelated failure." The suite was re-run afterwards and is clean
  (`user:// writes: 0 file(s) changed by the suite`). `launch --snapshot-userstate` is the
  flag that would have avoided it and I did not use it; worth making the default reflex
  for any run that drives a scoring path.

## 2026-08-20 — the road became a parameter (plant-tower-defense-s1o8.1, first half)

- Value: **overkill**, and recorded that way on purpose. The launch answered one narrow
  question honestly and found nothing; the HEADLESS half — specifically two deliberate
  mutations — is what did the work.
  - Expected: one claim only, and it is the one the suite structurally cannot make: the
    suite builds `Board.new()`, while the GAME uses the Board inside `game.tscn`. If that
    scene had ever carried its own road configuration, every headless assertion about the
    default would be true and irrelevant.
  - Got: `road_corners()` on the live board returns exactly `PATH_CORNERS`
    (`["(0, 1)", "(6, 1)", "(6, 4)", "(2, 4)", "(2, 7)", "(9, 7)", "(9, 3)", "(13, 3)"]`)
    and its cells start `(0,1),(1,1),(2,1)…`. `findings` 0 across 5 of 5.
  - Found: nothing at runtime. What the run DID catch was caught headless and before the
    launch: mutating `road_cell_count` from `steps + 1` to `steps` failed both the corpus
    test and the density test, and deleting the diagonal refusal failed its own test. That
    is the answer to "can these tests fail", and no amount of launching would have produced
    it.
  - Cheaper: the headless suite alone. Two mutations, seconds each, restored after. The
    launch was ~7 minutes for one confirmation.

- The `overkill` here is the useful kind and worth stating plainly: I could name a real
  claim the suite could not make, the claim was worth checking once, and the answer was
  "fine". That is what a narrow tier-(c)-plus-one-question launch is FOR, and the row
  records it as overkill rather than padding `found` to keep a `warranted`. If a stretch of
  these accumulates, the pattern to read is "scene-vs-code drift has not bitten in N
  cycles", not "the harness is not earning its keep".

- **[G-140] is closed by its own workaround, not fixed**: `--about` still takes one path,
  and this run simply did not pass it (the diff was one game file). No new sighting.

- Gap: **no new gaps this turn.** `launch --snapshot-userstate` was used this time after
  last cycle's run wrote the developer's real `highscore.save`, and it did exactly what it
  says — `userstate: restored 1 file(s) and removed 0 created during the run`. Worth
  recording as a fix that worked rather than as a gap: the flag was already there and the
  only thing missing was the reflex.

## 2026-08-20 — moving a plant keeps the plant (plant-tower-defense-h5w6)

- Value: **warranted** — the launch found a real, player-facing defect that no headless
  test could have found, and found it by being SLOW.
  - Expected: that clicking an empty cell while armed MOVES the plant rather than buying a
    second one. The suite calls `commit_move` directly; nothing in it exercises
    `_click_at`, where the new branch was inserted ahead of two existing ones
    (select-a-plant, place-a-plant) and where an ordering mistake would be invisible to
    every headless assertion.
  - Got: both answers, and the second was the valuable one. With the tree paused and
    `uproot_armed()` asserted true in the same breath as the click, the SAME instance
    `@Node2D@129` moved `(1,0)` → `(5,0)`, kept `level=2`, and seeds went `537 → 529` —
    exactly the `move_cost()` of 8 the node itself reported. With the window allowed to
    lapse, the identical click **bought a second level-1 plant at full price, silently**.
  - Found: **`UPROOT_CONFIRM_SECONDS` is 4.0 and now has two jobs.** It was tuned as a
    destructive confirm, which wants to be short; cycle 143 made it the gesture for
    choosing a destination, which wants to be long, and the move tip literally asks the
    player to hover and compare. I lost it to four bridge round-trips — which is precisely
    what a hesitating player is — and ended with two plants and no message. The code is
    correct: the branch is gated on `uproot_armed()` and every guard behaved as designed.
    The interaction is not. Filed P1.
    Second finding: `read-a-moving-value`'s trap for the second cycle running, and again in
    the PREDICATE rather than the value. I armed, ran four commands, clicked, and read the
    result as a failure of my own branch. The fix both times is to freeze the tree and
    assert the predicate in the same breath as the action.
  - Cheaper: nothing. The headless suite cannot reach `_click_at` at all, and the
    window-expiry finding required a driver slow enough to lose the window — which no test
    would ever be, because a test's clock only moves when it says so.

- **A technique worth keeping, not a mishap.** Drive a time-gated interaction at human
  speed once, deliberately, before assuming the gate is generous enough. A paused tree
  proves the feature works; an unpaused, unhurried one proves the WINDOW does. Two cycles
  running, the thing worth knowing came from the clock being allowed to run.

- Gap: **no new gaps this turn.** `launch --snapshot-userstate` was used again and again
  reported `restored 1 file(s)`; the reflex from cycle 141 is holding. `--about` was not
  needed (the run's subject was one file plus its tests), so [G-140] gets no new sighting.

## 2026-08-20 — the move window holds while you decide (plant-tower-defense-b9bl)

- Value: **warranted** — the hold is keyed to `_hover_cell`, the unit test sets that field
  by hand, and only a running game could say whether anything populates it in practice.
  - Expected: that real cursor motion actually engages the hold. A hold keyed to a field
    nothing populates would pass every headless assertion and do nothing for a player.
  - Got: it engages. `_hover_cell` became `(3, 0)` through the real cursor path and
    `_uproot_left` held at **exactly 4.0 across five reads spanning several seconds** —
    before this change it would have been 0 within four. Then resumed `3.4 → 3.1 → 2.8`
    the moment the pointer moved to the plant's own cell.
  - Found: **the bridge cannot drive an absolute mouse position, so nothing reading
    `InputEventMouseMotion.position` is reachable at runtime.** See the gap below. Also,
    self-inflicted and worth writing down: I launched the game before finishing the tests
    and it played itself to a loss while I worked — `place_plant` came back
    `refused at (1, 0): the run is over`. The launch belongs at the moment the runtime
    question is ready to be asked, not at the start of the phase.
  - Cheaper: nothing for the hold. The second finding was free and my own fault.

- The row is recorded **`partial`**, not `pass`, and that is the ledger working rather than
  a problem: I marked the event-delivery check `blocked` and `record` downgraded the
  verdict on its own. A check that could not run is not a check that passed.

- Gap: **`cmd mouse_move` sends `relative` only, so absolute-position input is undrivable.**
  `python tools/devtools.py cmd mouse_move --args '{"position":[224.0,104.0]}'` is refused
  by name — `mouse_move needs relative as [dx, dy]` — and the relative form does not carry
  a position, so a handler doing `_update_cursor(motion.position)` sees `(0, 0)`. Measured:
  two attempts, `_hover_cell` stayed `(-1, -1)` both times; warping `-4000,-4000` then
  `+224,+104` changed nothing, because Godot's relative motion never sets `position`.
  This is not a niche verb — hover cues, tooltips, drag previews, placement previews and
  cursor-following art are all `position` readers, and this project has four of them.
  Workaround used: call the handler below the event layer
  (`run-method --method _update_cursor --args "[[224.0,104.0]]"`), which verifies
  everything except the delivery and has to be reported as such.
  - [G-141] status: open | seen: 1 | harness: 0.38.0
  - Improvement: accept a `position` arg on `mouse_move` and set it on the
    `InputEventMouseMotion` (with `relative` defaulting to the delta from the previous
    position, so existing callers are unaffected). Check 0.60.0 first — this project runs
    0.38.0 and `harness-version --client` says a newer harness is on this machine.

## 2026-08-20 — the armed panel names the move (plant-tower-defense-28un)

- Value: **warranted**, and from the HEADLESS half — no launch, and the tier was checked
  rather than assumed.
  - Expected: nothing runtime could add. Written before Phase 1, and then verified rather
    than believed: cycle 144's lesson was that a behaviour keyed to a field the tests write
    directly has a second question — does anything drive it in the real game. Here that is
    whether ARMING refreshes the panel, since the test calls `_refresh()` by hand. It does,
    at `game/game.gd:1998`, and the armed button's own text has always depended on that
    same call. So the launch was refused on evidence, not on mood.
  - Got: two findings out of the suite. `test_the_hint_cards_agree_with_the_tips_the_
    message_row_posts` failed with "the armed prompt still carries the hover clause", which
    led to the notebook card saying **"Confirming still only uproots"** — false since cycle
    143. And `test_every_selection_detail_producer_is_priced_by_the_corpus` failed
    `Expected 12 but got 13`, which is the hand-enumerated producer list doing its job.
  - Found: **a permanent player-facing reference was teaching a rule the game had stopped
    following, for two cycles, and the only thing that noticed was a test about internal
    consistency.** Nothing in this repo checks a hint card against the GAME — the cards
    make factual claims ("Corn Cobblers can still hit it", "The Barrier Bramble is the
    exception") and read as copy rather than as assertions, so nobody applies
    `kanban-idea-pass`'s standard to them. Filed.
    Also: I guessed a `height` key on `selection_panel_budget` that does not exist. The
    test aborted mid-method and **reported `[PASS]`** — the coerced-empty-return case — and
    `run_tests.py` caught it on the error count. That is the third time this session the
    wrapper has earned its place over `run_tests.gd`.
  - Cheaper: nothing cheaper ran. This was the cheap tier and both findings came out of it;
    the expensive mistake available was launching.

- Gap: **no new gaps this turn.** [G-141] (no absolute mouse position) was not re-hit
  because this cycle never needed to drive the pointer — the panel updates through
  `_refresh()`, not through hover.

## 2026-08-20 — a checker for dangling bead ids (plant-tower-defense-xnmz)

- Value: **warranted**, and no engine gate was involved at all — this is a `tools/` checker,
  the tier the triage table calls (f) tooling-only.
  - Expected: to find zero and build the tool anyway as prevention, since I had corrected
    all three ids I invented this session.
  - Got: **one still there.** `plant-tower-defense-9dq7` (bead-ref-check: ok - quoted) was
    invented in cycle 142, corrected in cycle 142, and was live in cycle 146 — the
    correction patched one occurrence of two. `157 reference(s) across 28 source(s) … 2
    finding(s)`, both in the description of the bead that ASKED for the checker, one of them
    inside a sentence claiming the id appeared there "nowhere, deliberately".
  - Found: that a believed correction had not held, which is a different and worse thing
    than an uncorrected mistake — it leaves no trace and nobody re-reads. Also, by mutation,
    a guard in my own new code that could never fire: `ref == own` is unreachable because a
    bead's own id is in the export by definition. Deleted rather than kept.
  - Cheaper: nothing. The measurement that decided whether to build the tool at all was ~20
    lines of throwaway Python and is exactly what `house-static-checker` asks for first.

- **The `2` that proved nothing, recorded because the skill warns about it.** My first
  mutation replaced the id set with an EMPTY one, expecting every reference to become a
  finding. It exited **2** — tripping the tool's own could-not-run guard — and a sweep
  reading truthiness would have logged that as a kill. Re-run with a single junk id instead:
  `5 -> 163 findings`, which is the result that actually shows the id set is doing the
  deciding.

- Gap: **no new gaps this turn.** No launch, no bridge, nothing asked of the harness that it
  could not do.

## 2026-08-20 — a plant in danger leans (plant-tower-defense-tkwf)

- Value: **warranted** — the composition into `_sway_pivot` is unreachable headless, and
  the run changed what the feature IS rather than merely confirming it works.
  - Expected: two things the suite structurally cannot say. That the held lean actually
    reaches `_sway_pivot.rotation`, since everything past `_wobble`'s
    `animations_enabled()` gate is an early return headless; and the DESIGN question no
    test can ask — a hungry pest kills a full plant in 2.86s, so is the wilt band ever
    visible in play or does it flash past?
  - Got: `rotation: 0.240` at 2hp against a healthy band of ±0.055, `0.034` back at full
    health, and three neighbours at 2hp reading `+0.240 / -0.204 / -0.237` so a row of
    dying beds leans different ways rather than tipping identically.
  - Found: **the cue is mostly about RECOVERY, not death.** The wilt band is exactly
    `EAT_DPS` worth of health, so an uninterrupted chew shows it for one second. A plant
    whose attacker dies mid-meal sits in the band for ~12s while regrowth climbs out —
    which is the intermission, when the player can act. That reframing came from the
    running game and the balance constants together and from neither alone, and it is now
    in the bead's close so the next person does not re-derive it.
  - Cheaper: nothing. No headless reader exists for the composed transform, and the
    two-window reading needed both halves.

- **Third instance this session of reading two moving values in separate bridge calls.**
  `health` and `rotation` were read ~1s apart while regrowth ran, so the lean looked
  0.007 rad outside its predicted range and I nearly filed it. Pausing and reading both on
  a frozen tree reconciled them exactly. The rule has hardened: **any live claim relating
  TWO properties must be read on a PAUSED tree, not merely a stable-looking one.** Cycles
  141, 143 and 147, three different shapes, same root.

- **A test-file constant is not shared, and using one broke the whole FILE.** `GAME_SCENE`
  is declared in `test_selftest.gd`; referencing it from `test_combat.gd` was a parse error,
  so `run_tests.py` exited **2** and nothing in that file ran at all. Exit 2 is "you
  verified nothing", and it would have been easy to read the absence of `[FAIL]` lines as
  success.

- Gap: **no new gaps this turn.** `launch --snapshot-userstate` again restored 1 file; the
  reflex is holding four cycles on.

## 2026-08-20 — the three teaching budgets, decided (plant-tower-defense-4tt4)

- Value: **warranted**, and no game ran. Tier (b): the only production change is a comment
  block, so there was no runtime claim available to make — and saying that plainly is the
  point of the tier table.
  - Expected: nothing from runtime, predicted before Phase 1 and true. The risk in this
    bead was never execution, it was ARITHMETIC — whether the three budgets are really
    three ceilings — and that is answered by reading the functions.
  - Got: **two of the three are not budgets.** `hint_pages_needed()` computes pages from
    the list, so the notebook hints page is a pager with a one-row cost and a test that
    fails until the row is there. And the legend page is COMPLETE rather than full: the
    audit block already dispositions every untaught grammar row by name, and the strongest
    case is refused because a legend row teaches it *worst*, not for want of room.
  - Found: that, plus a stale ledger — `cue_legend.gd` listed row 4 as untaught two cycles
    after the sixth hint taught it. Second hand-maintained teaching table to drift in four
    cycles, after cycle 145's notebook card.
  - Cheaper: nothing cheaper ran. Reading `hint_pages_needed` and the audit block IS the
    work, and it is what turned "raise one of three" into "raise none of them".

- **A decision bead's real deliverable is where the decision is written, not that it was
  made.** This one went into `cue_legend.gd`'s audit block rather than only into the close
  reason, because that block is what the next person pricing a teaching surface opens —
  and its own worked example is the lane-pressure hatch, which went untaught because "the
  decision had already been made by the layout, before anyone asked". A close reason nobody
  greps would have repeated that exactly.

- Gap: **no new gaps this turn.** No launch, no bridge.

## 2026-08-20 — stuck and shot stop being the same word (plant-tower-defense-zdy2)

- Value: **warranted**, and the mutation sweep was worth more than the launch.
  - Expected: that a glancing recoil is visibly gentler than a full one on a real pest and
    still visibly a recoil. `_gait` composes `_flinch_force` past the
    `animations_enabled()` gate, so the composed yaw has no headless reader.
  - Got: exactly that, frozen between reads. Full recoil peaks `0.382`, glancing peaks
    `0.194` — half the amplitude, still 1.5× the walk's `GAIT_SWING` 0.13.
  - Found: **a mutation found a hole in my own tests.** I had written a CONSTANT test (is
    the glance scale sane) and a CALL-SITE test (which callers pass the flag), and pinning
    `_flinch_force = 1.0` — restoring the exact defect the cycle set out to fix — passed
    both. A table is not the thing that reads the table. The tell, in hindsight: neither
    assertion mentioned `flash_hit` at all. Fixed with one behaviour test, and re-mutating
    now dies with `Expected 0.350000 but got 1.000000`.
    Also: the bead asked about the Sundew and the enumeration found a CONTRADICTION beside
    it — a plate-blocked hit flashes at 0.45 against 1.9 saying "that did nothing" while
    the recoil said "that hit hard" in the same frame.
  - Cheaper: the mutation sweep, which is headless and takes seconds. It found the test
    hole; the launch confirmed amplitudes the constants already predicted. The launch was
    still right — the bead's own instruction was "decide by looking", and
    half-amplitude-but-still-above-the-walk is a judgement no constant makes for you.

- **The seam that made the fix testable was built three cycles earlier for another reason.**
  `flash_hit` arms the recoil BEFORE its animations gate, which cycle 139 did so the decay
  in `_gait` could never inherit a value armed only on animated machines. That is what let
  cycle 149 assert `_flinch_force` headlessly at all. Worth noticing when writing a gate:
  what you put above it is what a future test can reach.

- Gap: **no new gaps this turn.** `launch --snapshot-userstate` restored 1 file again.

## 2026-08-20 — the reader audit (plant-tower-defense-4uts)

- Value: **warranted**, and no game ran. Six mutations of READERS rather than tables, one
  per foreground run, full suite each time.
  - Expected: that the gait mutations would survive, because `_gait` early-returns on
    `animations_enabled()` and no headless test can reach its composition — written down
    before running, and confirmed.
  - Got: the control fired first and correctly (road walker skips a cell → 37 failing,
    first kill being cycle 142's own paired test), so the rest is readable. Ladder cost →
    RED 2. Ladder level advance → RED 10. Message row → RED 18. Both gait mutations →
    **SURVIVED, zero failures.**
  - Found: **four test loops that hang the suite**, which the sweep was not looking for.
    Each terminates on a condition the code under test owns, so the `level += 1` mutation
    spun them forever and the runner was SIGTERMed with no output — twice, before I stopped
    reading it as slowness. A hang is worse than a failure and, in a mutation sweep,
    indistinguishable from a mutation that never applied.
  - Cheaper: nothing. Reasoning about which readers are covered is exactly what the sweep
    disproved — three of my four suspicions were wrong.

- **Method note, paid for twice.** Batched sweeps of six mutations were KILLED mid-run in
  this environment, both times leaving a game file mutated with a `.bak` beside it — a state
  that reads exactly like a finding, and which would void every verdict above it if not
  caught. One mutation per foreground call, restore verified before the next. Also: a
  long-running Python child buffers stdout, so a killed batch leaves an EMPTY log; `-u` is
  worth it from the start.

- Gap: **no new gaps this turn**, but two self-inflicted slips worth recording. I set
  `SCRATCH=...` as a shell statement rather than a command prefix TWICE, so `os.environ`
  never saw it and both a patch and a commit-message write failed. Cycle 141's own rule says
  `VAR="$VAR" python - <<'PY'` — as a PREFIX. A shell variable is not an environment
  variable until it is exported or used as one.

## 2026-08-20 — Cycle 151: named the slanted bars, refused a legend page, refused a rot hold

- Value: **warranted** — but only half the session was, and the half that was is the half
  headless CANNOT do. Worth splitting, because the other half is a textbook `overkill` row
  hiding inside a `warranted` one.
  - Expected: the tip would post on hover and would fit the row. Both predicted before running.
  - Got: `MessageLabel` at `876x22`, the sentence ending near 640 px with no ellipsis, and
    `run-method _on_plant_hovered(chomp_flower)` putting `dead_ground_tip()` on the row.
    Then the notebook's new third hints page at 17/17, its card holding the note with room
    and its derived counter reading "6 of 7 seen".
  - Found: **the message row is swept for COMPLETENESS and swept for WIDTH by two tests
    that cover different sets, and neither knows it.**
    `test_the_message_corpus_covers_every_catalogue_producer` calls the corpus "the
    budget's denominator"; `test_no_message_clips_for_any_plant_in_the_catalogue` never
    reads the corpus at all — it builds its own sweep from `PlantCatalog.PLANTS` crossed
    with the level tables. Enumerated function-scoped across the suite: eight functions
    read `message_corpus()` and not one measures a width. So the 13 non-catalogue entries,
    both bar tips among them, are counted by one test and measured by neither. Found only
    because the live run forced the question "what would have told me this headlessly".
  - Cheaper: for the WIDTH, nothing — the row is `clip_text` with `text_overrun_behavior`
    3, the pair `CLAUDE.md` names as making `get_minimum_size()` report the clip stub, so
    there is no headless answer to buy. For the TRIGGER, the two headless tests already
    pinned it and killed two mutations before the game was launched; re-driving
    `_on_plant_hovered` live confirmed what was already known and is the overkill half.

- Gap: **[G-058] again, and I made the same mistake the log already describes.**
  Wrote `"phase4"` in `run.json`; `verify_ledger record` printed `warranted with no Phase 4
  checks recorded - the claim that earned it is not in the row` and the row went in without
  its three Phase 4 entries. The key is `checks` (`tools/verify_ledger.py:1136`). `--help`
  says "the Phase 4 checks" and never names the key; `/verify`'s own doc says the same.
  Recovered only because the evidence also went into `found` and `note`.
  - [G-058] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#46
  - Improvement: unchanged from the first sighting — name the dropped key and suggest the
    nearest known one. Adding the second sighting because the first entry predicted this
    exact string (`did you mean 'checks'?`) and a year of prose in the log did not stop it
    happening again, which is the argument for fixing it in the tool.

- Gap: **reach was `null` until the game was relaunched, and nothing said so at capture
  time.** `scene-tree` was taken after `quit`, so the first `reach` read
  `NOT reached ... game/notebook_screen.gd` — true, and true only because the notebook had
  been closed with the process. A second launch, `fire-entry-point notebook`, a second
  capture, and `--scene-tree A --scene-tree B` gave `3/4, nothing left unreached`. The
  repeatable flag is the fix and it works; what is missing is anything at CAPTURE time
  saying a one-screen snapshot cannot speak for a multi-screen run.
  - This is `plant-tower-defense-fs2b`, already filed as a bead, now on its second sighting.
    Not opening a G id: the bead has the detail and a G would be a second record of one thing.
  - Improvement: `scene-tree` could print the count of `res://` scripts it saw against the
    count `scripts-seen` reports for the session — a one-line denominator that makes
    "this is one screen of several" visible while the game is still running to fix it.

## 2026-08-20 — Cycle 152: reconciled the open gap ledger against 0.60.0 (plant-tower-defense-8wzs)

- Value: **warranted** — no game was launched and none was needed; the claim runtime could
  not have produced came from opening a *different version of the harness* than the one
  this project runs.
  - Expected: that a good fraction of 75 open gaps would turn out to be fixed in the 0.60.0
    on this machine, since the project is 22 releases behind and every `harness-version`
    call says so.
  - Got: `python <0.60.0 templates>/tools/devtools.py --project . harness-version --client`
    prints the reconciliation directly — **17 credited as fixed in releases this project
    does not have**, and 12 supposedly open here that are "already credited in the
    templates it RUNS".
  - Found: **the second of those two numbers is wrong, 12 out of 12.** Cross-checked
    against `gap_ledger.py --open`: eleven of the twelve (G-014, G-016, G-018, G-019,
    G-025, G-029, G-030, G-033, G-046, G-047, G-049) are **already `status: fixed`** in
    this log and appear in `gap_ledger`'s own NOTE as ids "with an earlier `open` line
    above their current status". The twelfth, G-044, is open on purpose: the citation in
    `tools/import_check.py:224` and `:259` is a **retry-until-progress workaround around a
    Godot importer segfault**, not a fix of it, and this log re-confirmed a 7th sighting.
    So the check is resolving `status: open` PER LINE rather than per id from the last
    one — the exact trap `gap_ledger` was built to avoid and that
    `plant-tower-defense-8wzs` warned about in advance ("`grep -c "status: open"` counts
    LINES and once said 61 when the answer was 44"). A citation is also not a credit: a
    workaround marker and a fix marker are the same string to it.
  - Cheaper: nothing. The first number is a real service and would have taken an hour by
    hand; the second is only detectable by having the per-id resolver as a second opinion.

- Gap: **`harness-version --client`'s gap reconciliation over-reports "already fixed here"
  by resolving status per LINE, not per id.**
  - [G-142] status: open | seen: 1 | harness: 0.60.0 (client) / 0.38.0 (installed) | upstream: gh#63
  - Improvement: resolve each id from its LAST status line, the way `gap_ledger.py` does,
    and say which line the verdict came from. And separate CITED from CREDITED: a
    `plant-tower-defense:G-044` in a comment describing a workaround is evidence the gap is
    KNOWN, not that it is closed. The first number in the same output is careful about this
    (it searched for credits in the release notes); the second is not.

- Gap: **no new harness gaps beyond G-142 this turn** — this was a bookkeeping pass over
  the ledger itself and it used one command.

### Reconciled against 0.60.0 — the four-way split

Twelve ids reconciled, one appended status line each. **Fixed upstream and STILL LIVE
HERE** is the large bucket and the status stays `open` deliberately: a fix in 0.44.0 does
nothing for a project running 0.38.0, and G-058 proved it by biting cycle 151. The route
is `/scaffold-godot-harness`, tracked separately as `plant-tower-defense-ny3h` and
out of scope here on purpose.

  - [G-050] status: open | seen: 1 | harness: 0.38.0 | fixed-upstream-in: 0.39.0 | note: reconciled cycle 152, not installed
  - [G-051] status: open | seen: 1 | harness: 0.38.0 | fixed-upstream-in: 0.39.0 | note: reconciled cycle 152, not installed
  - [G-052] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#39 | fixed-upstream-in: 0.40.0 | note: reconciled cycle 152, not installed
  - [G-053] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#39 | fixed-upstream-in: 0.40.0 | note: reconciled cycle 152, not installed
  - [G-054] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#40 | fixed-upstream-in: 0.40.0 | note: reconciled cycle 152, not installed
  - [G-057] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#44 | fixed-upstream-in: 0.44.0 | note: reconciled cycle 152, not installed
  - [G-058] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#46 | fixed-upstream-in: 0.44.0 (`verify_ledger --schema` prints the key set) | note: reconciled cycle 152, not installed — this is the one that cost cycle 151 a row
  - [G-061] status: open | seen: 1 | harness: 0.38.0 | fixed-upstream-in: 0.55.0 (`repaint` verb) | note: reconciled cycle 152, not installed
  - [G-066] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#54 | fixed-upstream-in: 0.56.0 | note: reconciled cycle 152 against 0.60.0, not installed
  - [G-073] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#57 | fixed-upstream-in: 0.60.0 | note: reconciled cycle 152, not installed
  - [G-044] status: open | seen: 7 | harness: 0.38.0 | note: reconciled cycle 152 — upstream calls this fixed in 0.29.0/0.34.0/0.35.0 and the retry-while-progressing loop IS installed here, but what is installed is a workaround around a Godot importer segfault rather than a fix of it, and this log's 7th sighting was taken on that code. Stays open until a run goes a full cycle without the retry firing.
  - [G-069] status: wontfix | seen: 1 | harness: 0.38.0 | note: reconciled cycle 152 — **the gap was simply wrong, and had already been refuted twice before this pass looked.** 0.60.0's line refuses it, and `devtools_ext/commands.gd:196-201` in THIS repo says the same thing in more detail: `touch_press` is the harness's verb and not this project's, and 0.38.0 — the version installed — already refuses a positionless press with "touch_press on a new index requires 'position' as [x, y]" (`dev_tools.gd:2644`). No bead: there is nothing to fix at either end. The first draft of this very line said the cause was a project bug and filed one; opening `commands.gd` before writing the bead is what stopped it.

**The split: 10 fixed upstream and not installed · 1 still open at 0.60.0 (G-044, and it
is a workaround rather than a fix) · 1 wontfix (G-069, a project bug wearing a harness
gap's clothes) · 0 could-not-tell.** Five more of the seventeen (G-063, G-065, G-067,
G-070, G-072) already carried a `reconciled` note against 0.54.0 and were left alone
rather than re-stated, and G-060 was already `fixed`. 63 open ids remain unreconciled;
they are older and were filed against versions further back, so the same pass over them
is likely to be at least as productive.

## 2026-08-20 — Cycle 153: counted what the reads_on gate is aimed at, then aimed it once more

- Value: **warranted**, and on a claim the arithmetic had already got wrong.
  - Expected: the darkened `RISK_COLOR` to read as a warning on grass, which is the only
    ground the hovered CELL can be. Predicted before launching, and written into the
    constant's header as a reasoned exclusion of dirt.
  - Got: a paused board with `at_risk` forced on, and the dashed ring's lower arc lying
    **across the road**. `RISK_RADIUS` is 30 against a 64 px cell, so a ring anchored one
    cell from the lane spills onto it. The first amber sat at 0.063 separation there.
  - Found: **a cue whose geometry LEAVES the cell it is anchored to does not inherit that
    cell's ground.** Every number in the working said grass-only; the picture said
    otherwise. Re-picked the colour to clear both grounds (0.237 / 0.144) and the sweep
    now prices both rows. This is the cheapest possible argument for looking at a visual
    change even when the arithmetic is clean — the arithmetic was clean and wrong.
  - Cheaper: nothing. `node-bounds` would have given the ring's radius, which I already
    knew; what was missing was the relationship between that radius and where the cell
    sits, and no verb answers that.

- Gap: **`new-uid --write` mints a `.uid` sidecar for any path, including a `.py`.**
  Ran `python tools/devtools.py new-uid --write tools/gate_aim_check.py` out of habit
  after adding a new tool file; it printed
  `uid://bwfh52uu6dksi  -> ...\tools\gate_aim_check.py.uid` and wrote it. A UID is a Godot
  resource identity; a sidecar beside a Python file is meaningless, is not tracked by
  lint's UID pass (which walks `.gd`), and would sit in the tree unexplained. Deleted by
  hand. The verb has the information to refuse — it knows the extension.
  - [G-143] status: open | seen: 1 | harness: 0.38.0
  - Improvement: refuse a path whose suffix is not one Godot mints UIDs for
    (`.gd`, `.tscn`, `.tres`, `.gdshader`), naming the suffix it got. One `if`, and it
    turns a silent wrong file into a one-line error.

- Gap: **the unit suite takes >2 minutes while a launched game is up, and ~90 s when it is
  not.** `CLAUDE.md` says a headless gate "never touches the bus ... safe to run while
  another session drives this game", which is true — it passed cleanly once the game was
  quit, and nothing was corrupted. What is missing is the COST: the run exceeded a
  two-minute budget and was killed, which reads as a hang rather than as contention.
  - Not opening an id: this is a documentation sharpening rather than a defect, and the
    claim it sharpens ("safe") is correct as written.
  - Improvement: add "safe, but slower — expect roughly double while a game holds
    `.godot/`" to that line, so a killed run is diagnosed rather than investigated.

## 2026-08-20 — Cycle 154: probed a number two cycles had assumed, and caught a ledger drifting twice

- Value: **warranted**, and the cheapest run in a while — no game was launched at all.
  - Expected: `label.size.x` under `_T.instantiate_scene` to be the 64x64 headless window,
    which is what this project's own notes had said for two cycles and what sent cycle 151
    to the running game to measure one tip.
  - Got: **876.0**, exactly what `node-bounds` reports live. A two-line temporary
    assertion settled it. The `get_window().size` caveat in `CLAUDE.md` is real and does
    not touch a Control laid out under a properly-sized root, which is what
    `instantiate_scene` gives.
  - Found: two things, and the second is the one that matters.
    `plant-tower-defense-9ji4`'s premise is FALSE — `Game._budget_hud_message_row`
    (`game/game.gd:3632`) already sweeps `Hud.message_corpus()` through
    `GardenTheme.measure` and adds both mute lines at their current keybinds on top.
    Lengthening one bar tip past the row turned THREE tests red through it. And the
    enumeration that produced the bead — "eight test functions call `message_corpus()` and
    not one measures a width" — was literally true and over the wrong set: the measurer is
    in `game/`, not `test/`. **Third instance of that shape in this project.**
  - Cheaper: the probe itself, which is what should have happened in cycle 151 before
    launching. Two lines and one suite run.

- Gap: **no new harness gaps this turn.** The two runs that mattered were `run_tests.py`
  and a temporary assertion; neither needed the bridge, and the one number in question
  turned out to be readable headlessly all along. [G-143] was not re-hit.

- Process note, not a harness gap: recovering from a checker mutation with
  `git checkout -- game/cue_legend.gd` silently reverted an unrelated fix in the same file
  that was made earlier in the same cycle. Nothing caught it; re-reading did. The standing
  rule about verifying a restore is about `.bak` files and says nothing about `checkout`,
  which is the blunter instrument — it restores the whole file, not the mutated span.

## 2026-08-20 — Cycle 155: difficulty profiles, verified through the real title -> game path

- Value: **warranted**, and the live half answered a question no headless assertion can.
  - Expected: a harsh run to open on 5 beds / 9 s prep / 15 seeds, and the HUD to show it
    on the FIRST frame rather than showing 25 seeds and correcting itself — which is the
    whole reason the profile is applied ahead of every node `_ready()` builds.
  - Got: `set-state /root/RunConfig difficulty harsh` then `fire-entry-point campaign`
    reported `lives: 5, starting_lives: 5, prep_seconds: 9.0, seeds: 15`, and the top-bar
    capture reads **"Seeds 15 / Garden 5"** with no correction visible.
  - Found: the ORDERING claim is the only part of this that needed a running game, and it
    is the part a test cannot make — a headless assertion reads the settled state and
    would pass either way. Everything else (the table, the fallback, the post-mortem
    denominator) is pinned by four new headless tests and two mutations.
  - Cheaper: for the logic, the tests — and they carry it. For "does the player ever see
    the standard numbers", nothing.

- Gap: **no new harness gaps this turn.** `set-state` on an autoload field followed by
  `fire-entry-point` is exactly the shape the bridge documents, and it worked first try
  including the `StringName` coercion (`difficulty = harsh  (coerced)`).

- Note on the ledger, not a gap: `reach` read 1 of 3 because `run_summary.gd` is only
  loaded when a run ENDS, and this session started one. That is the known
  `plant-tower-defense-fs2b` shape — a screen the capture never visited — and it is
  honest rather than wrong. Not bumping its sighting count: the earlier sightings were
  about a screen CLOSED before capture, which is a different and fixable thing.

## 2026-08-20 — Cycle 156: swept the profile-varied constants, and found prose rather than code

- Value: **overkill**, and writing that down is the point of this field. No game was
  launched and none should have been.
  - Expected: several sites computing a proportion against a constant a difficulty profile
    now varies — the shape cycle 155 found two of while shipping the profiles.
  - Got: **three arithmetic readers across `game/`, all correct.** The running code reads
    run STATE rather than the constants: `_refresh_prep_bar` divides `prep_left` by
    `prep_total` and both are per-run; `milestones.gd` compares `lives_lost` to zero, which
    no profile can move.
  - Found: nothing in the code, and that is the honest answer. What the sweep found was
    PROSE — three headers priced against "PREP_SECONDS is 18" — one of which
    (`Dandelion`'s full-head-within-prep) is an INVARIANT rather than a reading and had
    survived three profiles with nothing between the claim and the table. Now gated.
  - Cheaper: two greps and a scan, which is what it cost. The harness was not involved and
    did not need to be; a sweep whose subject is "which expressions exist" is a source
    question, and reaching for `findings` or the bridge here would have been the overkill
    this entry is naming.

- Gap: **no new harness gaps this turn, and none were expected** — this cycle used
  `run_tests.py`, `lint_project.gd` and `check_all.py` and nothing else. Recording it
  explicitly so an absent gap is distinguishable from a forgotten log.

- Method note worth more than a gap: the first derivation blanked string bodies and so
  missed dictionary-key access, which is exactly how run state crosses to the HUD. It
  returned THREE readers rather than zero, and a plausible small number invites belief
  where an empty one invites a second look. Caught by asking whether the number was
  plausible for the question rather than whether the command had worked — the first time
  this project has caught that shape mid-flight rather than a cycle later.

## 2026-08-20 — Cycle 157: a difficulty button, decided by a capture rather than by a number

- Value: **warranted**, and the run that mattered was `capture.gd`, not the bridge.
  - Expected: the sixth menu button to fit and the layout to hold. Both were computed
    first — `menu_capacity()` is 8 at `PRIMARY_COUNT` 2 and 5 at 3, and a half-band cell
    is 142 px against "Difficulty · Standard" at 173 — so the shape was decided before
    anything was built.
  - Got: a rendered menu that fits, pairs evenly, and clears the lawn. **And a label that
    was wrong while passing every number.** "Standard" draws 80 in a 142 px cell; in a
    column with Notebook, Keys and Options it reads as a fourth destination announcing
    nothing. Swapped so the button carries the noun and the Start row carries the value.
  - Found: **a width budget is a necessary condition and never a sufficient one.** Both
    label drafts cleared every measured constraint and only the picture separated them.
    Also that the Start row had said "8 waves" against a 22-row table.
  - Cheaper: nothing for the label. The arithmetic decided primary-vs-secondary correctly
    and could not have decided the wording.

- Technique worth recording, not a gap: **`entry_hook` advances past the title screen
  automatically, so the bridge cannot see it on a launched game.** The route through is
  `fire-entry-point notebook` / `keys` / `options` — all three carry
  `"scene": "res://game/title.tscn"`, so they switch scene first and the title is behind
  whatever they opened. `capture.gd` was used instead, and for a static layout question it
  is the better tool anyway: no launch, no hook, one command.
  - `--frames` matters more than usual here. At the default 3 the entrance stagger has
    barely started and half the menu is invisible; at 40 two buttons were still fading; 90
    was clean. A capture of this screen at the default would have shown a menu with holes
    in it and invited a fix for a bug that does not exist.

- Gap: **no new harness gaps this turn.**

## 2026-08-20 — Cycle 158: read four screens as a player, using the bridge as a tour bus

- Value: **warranted**, and the harness was used in a shape it is not documented for: not
  to assert anything, but to GET SOMEWHERE so a human could look.
  - Expected: label problems on the screens this project measures most carefully.
  - Got: `fire-entry-point options` / `keys` / `pause` plus one `press` on each Back
    button walked four screens in about a minute, and the pause card turned up two buttons
    three words apart doing opposite things — "Back to the garden" resumes, "Back to the
    gate" abandoned the run, with "Start over" between them.
  - Found: **every width budget on that card was clear the whole time.** The defect is a
    reading, and the only instrument that produces it is a rendered screen and a person.
    Also that neither label had a test.
  - Cheaper: nothing. `capture.gd` covers the two `.tscn` scenes and no more — the
    notebook, keys, options, pause and summary are all built in code as children, so the
    bridge is the only route to them.

- Technique, worth writing down because it is a bridge USE the reference does not describe:
  **`fire-entry-point` does not re-fire while its screen is already open.** Firing `keys`
  with the options overlay up printed the fired line and changed nothing, because the entry
  point only switches SCENE and the title scene was already loaded. The route between two
  overlays is `press --node .../BackButton` first, then fire. Obvious in hindsight and it
  cost one confused capture that looked identical to the previous one apart from the
  background bugs having moved.

- Gap: **no new harness gaps.** [G-143] not re-hit; nothing needed that the bridge lacked
  for the four screens it can reach. The two it CANNOT reach are a project problem rather
  than a harness one — the run summary needs a finished run, which no entry point can
  produce because what is missing is a history rather than a scene. Filed as
  `plant-tower-defense-dklv` against `devtools_ext/commands.gd`, not upstream.

## 2026-08-20 — Cycle 159: built a verb to reach the screens a run has to produce

- Value: **warranted**, and the bridge was the only instrument that could have done it.
  - Expected: `cmd end_run` to put the post-mortem card on screen so the five surfaces
    behind a finished run could be looked at.
  - Got: both variants in one command each — "The garden is eaten" at 11 of 22, and "The
    garden holds!" at 22 of 22 with three beds lost. First time anything in this project
    has seen either.
  - Found: three things, and the third is the one that matters.
    (1) Cycle 158's blind rename was right, and is now SEEN rather than inferred.
    (2) The verb writes the real save and there is no version of it that does not —
    `_end_run` files the score and the milestone flags, which is what ending a run MEANS.
    Measured: the first call changed `highscore.save` and unlocked a milestone off a
    synthetic run. `launch --snapshot-userstate` restored 1 file on quit, exactly as
    documented, and the verb's reply now warns on every call.
    (3) **`game.run_over()` — a method `Game` does not have — passed `name_check`.**
  - Cheaper: nothing. The card cannot be rendered without a run.

- Gap: **`name_check` does not resolve `x.method()` call sites, and `CLAUDE.md` says it
  resolves "engine classes and their MEMBERS".** Three mutations, each restored and
  verified: a bogus method on a project type, one on a `Node`-typed receiver with the
  engine index live (1036 classes), and one inside `game/` to rule out a scan-root
  question. `name_check` clean, `import_check` clean, `lint_project.gd` 0 errors 0
  warnings. The line fails at runtime and nowhere else.
  - [G-144] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#64
  - Improvement: two, and the first stands alone. **Correct the claim** — `name_check`'s
    own `NOT COVERED` names type inference and says nothing about call sites, so a
    careful reader is told the wrong thing twice; it should say a `x.method()` receiver
    is not checked. **Then consider whether it can be**: Godot has a GDScript warning for
    unsafe method access under `debug/gdscript/warnings/`, which `project.godot` sets none
    of, and `lint_project.gd` is the one gate that actually compiles. Expect a large first
    count — this codebase calls methods on `Variant`-typed Dictionary values everywhere —
    so the work is finding the gating subset, not flipping a switch.

- Worth recording as the harness working: an EXISTING project test caught the new verb
  before I could forget it. `test_every_positional_devtools_verb_refuses_a_call_with_no_position`
  failed with "commands.gd registers 'end_run' and this test does not classify it",
  naming both options and where the reason goes. That is a gate that knows about a file
  the suite cannot otherwise drive.

## 2026-08-20 — Cycle 160: measured the fix for G-144 and found it does not work

- Value: **warranted**, and the result is a NEGATIVE one that saves the next attempt.
  - Expected: enabling Godot's own `gdscript/warnings/unsafe_method_access` in
    `project.godot` to surface the missing-method class through `lint_project.gd`, which
    is the one gate that compiles.
  - Got: **nothing.** With all three unsafe warnings on and a bogus method planted, lint
    reported `0 error(s), 0 warning(s)` — and the one warning it did report in a later
    probe was a missing `.uid` sidecar, not the call. The reason is in lint's own code:
    `_check_scripts_compile` (`tools/lint_project.gd:693`) is `load()`-based and inspects
    `res == null` / `can_instantiate()`, so a script carrying an unknown-method call loads
    and instantiates perfectly well and no warning ever reaches the exit code.
  - Found: the cheap fix is not available, and closing this properly would need the
    analyzer's warning OUTPUT captured rather than the load RESULT inspected. Written into
    `check_all.py`'s own `NOT COVERED` so it is not re-tried.
  - Cheaper: nothing — the question was whether a setting works, and the only way to know
    was to set it and look.

- Gap: **[G-144] filed upstream as gh#64.** The documentation half is the ask and stands
  alone: `name_check`'s `NOT COVERED` names type inference and points at lint as the
  backstop, and lint does not catch this either — so the sentence written to stop a reader
  being misled is the second place they are misled.
  - [G-144] status: open | seen: 2 | harness: 0.38.0 | upstream: gh#64
  - SECOND ISSUE THIS SESSION against that repo, after gh#63, and the one-per-session rule
    was weighed rather than ignored: this is a documented capability that does not exist,
    in the gate every fan-out lane depends on, and deferring it a second time would have
    been the rule protecting nobody.

- Also recorded: `--check-only` on any file in this project reports
  `Compile Error: Identifier not found: RunConfig` and cascades into
  `Failed to compile depended scripts`. That is the known autoload false-positive
  `CLAUDE.md` documents for `--require-compile`, hit here for the first time — so the
  per-file compile route is not available as a workaround either.

## 2026-08-20 — Cycle 161: read the notebook, using the bridge as a page-turner

- Value: **warranted**, and the instrument again was a rendered screen and a person.
  - Expected: label problems on the game's most prose-heavy surface, 17 pages of it.
  - Got: `fire-entry-point notebook` plus `run-method go_to` walked to any page by index
    in one call each — four pages by KIND (two plant, cue-legend, shelf) in under a
    minute. The hints pages were read in cycle 151.
  - Found: the notebook's nettle note hard-codes "wave 8" while its twin in
    `PlantCatalog`'s shop line has been pinned against `WaveDirector.MUTATION_START_WAVE`
    for cycles. **One copy checked and one silent is worse than neither** — move the
    constant and the shop line fails, gets fixed, and the notebook is the only version
    left saying the old number with nothing pointing at it. Confirmed by mutation.
  - Cheaper: nothing for the reading. The four-line gate that followed would never have
    been written without it.

- Technique: `run-method --node <notebook> --method go_to --args '[N]'` is a page-turner
  and made this cheap. Worth pairing with the cycle-158 note that `fire-entry-point` will
  not re-fire while its screen is open — together they are the whole recipe for touring a
  screen that lives inside another one.

- Gap: **no new harness gaps.** One tooling consequence of MY OWN earlier work surfaced
  instead, on the shelf page: "Nothing left on the ground" reads as earned, because cycle
  159's first `cmd end_run` call unlocked it off a synthetic run before
  `--snapshot-userstate` was in use. That is the verb behaving exactly as its own docstring
  now warns, one cycle too late to help. **An attempt to clear the flag was refused by the
  sandbox, and that is the right default** — it is the developer's save, the flag is
  cosmetic, and a wrong clear is worse than a wrong set. Reported rather than fixed.

## 2026-08-20 — Cycle 162: three probes killed the filed fix and produced a better one

- Value: **warranted**, and the harness's own engine API index is what made the fix
  possible at all.
  - Expected: to enable Godot's `unsafe_method_access` and have `lint_project.gd` capture
    it, closing the gap cycle 159 found.
  - Got: **there is no warning to capture.** `project-settings --filter debug/gdscript`
    on the running game showed all 52 settings and confirmed the four `unsafe_*` ones
    exist and default to 0. Then three `--check-only` probes: a `Dictionary` receiver
    hard-errors on an unknown method (exit 1, no settings); a `Node2D` receiver does not
    (exit 0, silent); and `unsafe_method_access` is the OPPOSITE case, firing on a
    Variant-typed receiver. Godot is silent here BY DESIGN, because a method may arrive
    with a script at runtime.
  - Found: cycle 160's null result is now explained rather than filed, and the fix had to
    be a checker that resolves the call itself. Built as `tools/method_call_check.py`,
    reading the SAME engine API cache `name_check.py` maintains rather than a second copy.
  - Cheaper: nothing. Each of the three probes changed the design, and the first draft —
    written without them — resolved 0 calls of 2214.

- Gap: **no new harness gaps.** The opposite, in fact: `name_check.py`'s cached engine API
  index turned out to be reusable by a project checker with no work at all, which is a
  harness asset nothing had drawn on before. Worth knowing that the cache is
  `~/AppData/Local/godot-selftest-harness/api/engine_api_<version>.json.gz`, shaped
  `{"classes": {Name: {"inherits": ..., "members": [...]}}}`, and that a project tool can
  read it directly.
  - One measured caveat, and it cost four false findings: **`Object.free` is not in the
    index** (60 members for `Object`, no `free`), while `Node.queue_free` is. Engine
    built-ins ClassDB does not expose as ordinary methods are absent, so a consumer needs
    a named list. `[G-144]` is not re-hit by this; it is a separate property of the cache
    and is recorded here rather than filed, since the workaround is four characters.

## 2026-08-20 — Cycle 163: the arithmetic picked the colour, the picture confirmed the reading

- Value: **warranted**, and the split between what each half answered is the point.
  - Expected: darkening `DANGER` to clear the floor on both grounds. Computed first — raw
    DANGER fails dirt at 0.119, `darkened(0.15)` gives 0.242 and 0.161 — so the VALUE was
    settled before anything was launched.
  - Got: hovering a road cell (`_update_cursor` then reading `placeable` until it came
    back false) and capturing it showed a deep red bracket and wash, plainly legible on
    brown. The green placeable bracket on grass is unchanged.
  - Found: the arithmetic could not have answered whether a deep red still reads as a
    REFUSAL rather than as shadow, and that is the only question the launch was for.
    Everything else — which colour, how much, on which ground — came from a table.
  - Cheaper: for the value, yes, and it was taken. For the reading, nothing.

- Technique that made the live half quick: `_update_cursor` at a screen position, then
  `get-state --property placeable` on the PlacementPreview, in a loop over four guesses.
  Three came back `true` and one `false` — so finding the state a cue exists to show cost
  four round-trips and no screenshots. **Reading a boolean to locate a visual state is
  cheaper than looking for it**, and `node-bounds`/`get-state` being the token-cheap pair
  is already the standing advice; this is that advice applied to FINDING the frame rather
  than to measuring one.

- Gap: **no new harness gaps.** [G-143] and [G-144] not re-hit.

## 2026-08-20 — Cycle 164: priced 25 colours in one command, no game launched

- Value: **overkill avoided**, and the entry exists to say so. No harness verb ran at all
  and none should have: the question was "what is the luminance separation of every
  world-space colour against both grounds at its shipped alpha", which is arithmetic over
  two const tables.
  - Expected: a handful of ungated cues, most of them fine.
  - Got: 25 colours priced in a single scan. Four already gated, four added, two added
    ungated with their numbers, fourteen out of scope as sprite-drawn, four as washes.
  - Found: `CornCobbler.SPREAD_ARC_COLOR` clears NEITHER ground and lies across the lane —
    found by walking the list, not by anything looking wrong. And the sharper one:
    `WARNING_COLOR` is `Color(GardenTheme.DANGER, 0.95)`, the same palette colour the
    blocked bracket failed with, clearing dirt at 0.151 purely because of its alpha.
  - Cheaper: nothing — one command was the whole measurement.

- Worth recording about the HARNESS specifically: `tools/gate_aim_check.py` is now doing
  the job it was built for. Its ratio moved 3 of 35 to 8 of 35 because of this cycle's
  work, which is what makes a coverage number worth having — it is watchable. The two
  categories it counts and this cycle did NOT walk (colours declared but never drawn in
  their own file, and colours reached only through a getter) are the next list, and they
  are already derived and printed.

- Gap: **no new harness gaps.** Nothing was asked of the bridge.

## 2026-08-20 — Cycle 165: two computed failures that could not happen

- Value: **overkill avoided** again, and deliberately. No harness verb ran; the question
  was arithmetic over const tables plus reading two call sites.
  - Expected: the remaining two `gate_aim_check` lists to hold something deletable or
    something failing.
  - Got: nothing deletable — all seven declared-but-undrawn colours are consumed — and
    the one real find was a CONVENTION rather than a colour: `SelectionMarker.held_ink`
    halves the alpha, separation scales by exactly alpha, so every held-over mark loses
    half its contrast and nobody had priced it.
  - Found: **two computed failures that described nothing.** A dimmed WARNING fails dirt
    at 0.075 and cannot occur ("ARMED OUTRANKS HELD" at both call sites); a dimmed
    sole-cover ring fails grass at 0.103 and cannot occur (road cells only). Both numbers
    were correct. Neither was a finding. What caught them was READING the call site and
    the class header, not computing harder.
  - Cheaper: the scan was one command and the reachability checks were two greps. The
    expensive version of this cycle would have been filing two beads and having a later
    cycle disprove them.

- Gap: **no new harness gaps, and nothing was asked of the bridge.** Recording it so the
  absence is a choice rather than an omission — this is the third cycle running where the
  right instrument was arithmetic, and saying so is what keeps `overkill` an honest
  category rather than a thing that only appears when a run disappoints.

## 2026-08-20 — Cycle 166: the live pass added the least of the three instruments

- Value: **insufficient** for the live half specifically, and that is the honest word.
  - Expected: a capture to settle whether a dark rim makes a light arc read heavy.
  - Got: it did not. The arc is 34 px in radius with a 1.2 px rim, and neither a 200x160
    crop nor a tighter one resolved the outline. `sample-pixels` over the cob's region
    reports `darkest r=0.302 g=0.204 b=0.067` — `PIP_RIM_COLOR` composited on grass, so
    the ink IS in the frame — but the PIPS carry the same ink at the same radius, so it
    cannot isolate the arc's rim from theirs. It proves presence and nothing finer.
  - Found: the run's real finding came from a MUTATION, not the game — deleting the rim
    pass left all 1002 tests green, because the contrast table asserts a colour clears the
    floor and says nothing about anything drawing with it.
  - Cheaper: the arithmetic picked the fix and a source-reading test caught the
    regression. The launch was the weakest of the three and is recorded as such.

- Not a gap, a limit worth naming: **`sample-pixels` answers "is this ink in this rect",
  not "is this ink at this place".** For a 1.2 px feature adjacent to another mark using
  the identical colour, that is not enough, and no combination of `--rect` narrowing fixes
  it because the two marks share a radius. The verb behaved exactly as documented; what
  was missing was a way to ask about one DRAW rather than one region — which is
  `plant-tower-defense-0cl8`'s territory ("ask a cell which cues claim it") and is now a
  second sighting of that need.

- Gap: **no new harness gaps.** [G-143] and [G-144] not re-hit.

## 2026-08-20 — Cycle 167: measured coverage by deleting the thing, six times

- Value: **warranted**, and no harness verb was involved — the instrument was
  `run_tests.py` and a text editor.
  - Expected: a few of the contrast table's 24 rows to be uncovered.
  - Got: deleting FOUR draw sites in `placement_preview.gd` left all 1003 tests green, as
    did short-circuiting `SelectionMarker._draw` and `SoleCoverMarks._draw`. The same
    mutation on `Board.mark_dead_ground` fails four tests.
  - Found: the split is STRUCTURAL. A cue pushed onto a node is asserted; a cue painted in
    `_draw()` is not — and `board.gd:914` says exactly that as its own reason for choosing
    `Line2D`, having been bitten by "a mark 72 px out of place that every test passed".
    The rule was written down and applied in one file out of five.
  - Cheaper: nothing. "Is this cue asserted" has exactly one honest answer and it is
    deleting the cue.

- Not a harness gap but worth recording as a HARNESS-SHAPED observation: this is the
  argument for `Line2D`-over-`_draw()` stated in the project's own code, and it generalises
  past this project. Anything a headless suite must see has to exist as node STATE. The
  harness's own docs make the point for `capture.gd` and for the UI checks; the inverse —
  "if you want it assertable, do not paint it" — is a design rule the harness could state
  once and save every project rediscovering it. Not filing it upstream: it is advice rather
  than a defect, and gh#63 and gh#64 are already open against that repo from this session.

- Gap: **no new harness gaps.** [G-143] and [G-144] not re-hit.

## 2026-08-20 — audited every player message for whether it names a verb, and found the defect in the refusals

- Value: **warranted** — the defect this cycle shipped is invisible to every static gate in
  the project, and the only thing that surfaced it was calling the real function on the
  running game.
  - Expected: the tips would mostly pass, one or two would be facts on purpose, and the
    cycle would end in a verdict table with no code change.
  - Got: `PROBE: Expected  but got Pests Walk There | No Pests Walk There`. Godot's
    `String.capitalize()` title-cases every word, so both refusal display sites have been
    printing headlines at the player since refusals were wired. Then live, through the real
    `show_message`: `text=Pests walk there — try the grass.  visible_ratio=1.0` in an
    876px row.
  - Found: three things, none of which was the thing the bead asked about. (1) The Title
    Case. (2) `commit_move` held a second copy of the `"pests walk there"` literal under a
    comment claiming it was "the same refusal text `place_plant` gives" — my own rewording
    falsified it in the same edit that read it and believed it. (3) Refusals were the one
    class of player-visible message no width gate priced: `message_corpus_check` waives the
    call site as runtime-assembled, correctly, and that waiver was silently doing double
    duty as an exemption from the row budget, which is a different gate.
  - Cheaper: nothing for (1) — `capitalize()` resolves, lints, and passes 1006 tests, and
    the only way to see what it returns is to run it. (3) would have come from reading
    `test_no_message_clips`'s sweep source against the waiver list, ~2 minutes, and I got
    there by running the tool rather than reading it.

- Gap: **no NEW gap this turn.** Two old ones showed up again.
  - [G-058] status: open | seen: 3 | harness: 0.38.0 — wrote `"phase": "checks"` in the
    ledger row for the third time; `record` wants one of `import, lint, tests, runtime,
    other` and silently recorded all three `found` entries as `null`. It warns, which is
    why it is caught, but the row keeps the finding text with a null phase. The smallest
    fix is still the same: `record` should name the legal set in the warning it prints, or
    accept `checks` as an alias for `other`.
  - **The version gap is now the biggest single thing about this log.** `harness-version
    --client` says 0.60.0 is on this machine against 0.38.0 installed — 22 releases. This
    cycle wanted to evaluate `Hud.as_sentence(x)` against the running game and had to route
    it through `run-method` on a node that happens to carry the script; a
    `class_name X extends RefCounted` static utility has no such node and would have been
    unreachable. 0.60.0 ships `tools/eval.gd`, which this project does not have. I am not
    filing that as a gap, because filing gaps against an install 22 releases behind is how
    a project verifies fixes against a harness it does not run.
  - **And the version gap bit inside this same entry.** `run_json_check.py` — a house
    checker a previous cycle built for exactly this — reported `unknown key 'tier'`,
    `'kind'`, `'item'`: the /verify skill on this machine documents `"tier"` as required on
    every row, and the installed 0.38.0 `verify_ledger` reads it nowhere and drops it
    silently. Worse, the same run had recorded as `verdict: unknown` with null `lint` and
    `tests`, because I wrote the fields the newer skill names and not the ones this ledger
    accepts. Fixed by writing the 0.38.0 schema and re-recording; the blank row was removed
    rather than left beside its replacement, since it is the same run and would double-count
    in `stats`. **A checker this project built caught a defect caused by following its own
    harness documentation** — which is the argument for the refresh, not against the
    checker.

## 2026-08-20 — checked every notebook hint card against the game it describes

- Value: **overkill**, and the row says so — no game was launched, and none should have
  been. The bead predicted this ("no running game needed, since these are claims about
  code") and was right. Recording it rather than dressing a clean headless run as a
  runtime win.
  - Expected: the six cards the bead listed would mostly check out, and the work would be
    writing assertions for claims that were already true.
  - Got: they were all true. `1007 tests / 19203 assertions`, and the only thing runtime
    could have added is a screenshot of a page whose text is already asserted.
  - Found: two things, both from the derived sweep rather than from any gate. `HINT_CARDS`
    holds **seven** cards; the bead enumerated six, because `seen_dead_ground_tip` arrived
    between filing and working it. And `Dandelion.RANGE` is 192 against
    `CornCobbler.RANGE`'s 176, so the dead-ground card's cob is not the longest reach in
    the game — the sentence survives on a technicality it did not know it was relying on.
    Neither needed the harness. Both needed reading the table instead of the bead.
  - Cheaper: nothing cheaper existed. This IS the cheap tier.

- Gap: **[G-145] `_T` has no way to read a script's source.**
  - [G-145] status: open | seen: 1 | harness: 0.38.0 | upstream: gh#65
    Filed against SeveralHerr/godot-selftest-harness as issue 65, re-checked against
    the **0.60.0** templates rather than the 0.38.0 install — `run_tests.gd@0.60.0`
    still ships no source-reading helper, so this is current and not a stale-install
    false alarm. Symptom and mechanism verified; the fix is NOT — I have not run the
    proposed static inside `run_tests.gd` itself, and whether `res://` resolves the
    same for a static on `_T` as for one on the test script is the open question.
  - The assertions this cycle needed most were about GUARDS, not values: "a winged pest
    passes a Chomp Flower untouched" is `if pest.is_winged: continue` inside a private
    method, with no predicate to call and nothing to read off an instance. Going through a
    live grab would assert the grab, not the exemption. So the check has to read
    `chomp_flower.gd` — and every test that has ever needed this opened a `FileAccess` by
    hand. **There are eight such call sites across `test/unit/`** (5 in `test_selftest.gd`,
    2 in `test_placement.gd`, 1 in `test_economy.gd`), each re-deciding what to do with a
    null handle. I added a ninth as `_source_text`, local to one file, because that is
    cheaper than the alternative and is exactly how the eighth got there.
  - Improvement: `_T.file_text(path: String) -> String` on the test helper, returning `""`
    for a path that will not open. Six lines. The null-handle policy is the part worth
    centralising: an unreadable source is precisely the case where a `contains()` check
    passes for the wrong reason, and a caller who has to remember that will eventually not.

## 2026-08-20 — finished making the road's numbers properties rather than one snake's measurements

- Value: **overkill**, and correctly so — no game was launched and none could have been.
  `Board.set_road` refuses once the board is in the tree, by design (the tiles are built
  from the old road and there is no container to re-tile through), so the road corpus is
  reachable headless and nowhere else. A runtime pass here would have re-driven the
  shipped board with a renderer attached.
  - Expected: the two remaining road-dependent numbers would turn into properties and the
    work would be arithmetic.
  - Got: it was, and the arithmetic held. `1010 tests / 19605 assertions`. Five mutations,
    five distinct failures — the useful one being the corpus collapsed to three identical
    roads, which fails the Sundew spread claim printing `5..5 over {default: 5, short
    straight: 5, long serpentine: 5}`.
  - Found: a live parse error, and it is the documented gap rather than a new one.
    `name_check.py` printed `errors: 0 | warnings: 1` over
    `Parse Error: There is already a parameter named "road" declared in this scope` —
    `_over_promise_run` has two `for road:` loops and I named the new parameter `road`.
    Every name in it resolves, which is exactly what `name_check`'s own `NOT COVERED:`
    line says it can and cannot do. The import gate caught it in the next command. Worth
    recording as a **sighting** rather than a gap: the tool said in advance it would miss
    this, and it did, and the gate that exists for it worked.
  - Cheaper: nothing. This is the cheap tier.

- Gap: **no new gap this turn.** The `name_check` parse error above is the documented
  limitation behaving as documented, not a defect — filing it would be filing the tool's
  own `NOT COVERED` text back at it. The two standing items are unchanged: **[G-145]** is
  open upstream as gh#65, and the harness is still 0.38.0 against 0.60.0 on this machine
  (`plant-tower-defense-qcp1`), which is the item that would let this project verify any
  of its 77 open gaps against the harness it actually runs.

## 2026-08-20 — put what an upgrade buys on the button that charges for it

- Value: **warranted**, but the credit belongs mostly to the HEADLESS gate, and saying so
  is the point of this field. The width test caught two real overflows on its first run —
  252px and 238px in a 232px box — before the game was ever launched. What the launch
  added was the **reading**: whether "1.0→3.6 dmg" is a phrase a player parses in the
  moment of deciding, which no measurement answers.
  - Expected: the three gain phrases would fit, since the bead argued the two-line
    selection label was the constraint and the button was the way around it.
  - Got: `the widest upgrade button face fits its box: 252px of 232 -- 'Upgrade (30) ·
    holds 11.4→15.9s'`, then 238 of 232 for the Chomp. Live afterwards:
    `text: Upgrade (20) · 1.0→3.6 dmg`, `Rect: 908, 526, 232x40`, `findings` 0 across 4 of
    5, and a screenshot showing it unclipped beside the current-state line.
  - Found: the two overflows, and that **three** plants have ladders rather than the one
    the bead named.
  - Cheaper: for the fit, yes — the headless test, and it is now permanent. For the
    reading, nothing; a 232px number does not tell you whether a sentence lands.

- Gap: **no new gap this turn**, and one near-miss worth recording because I nearly filed
  it as one.
  - The ledger's reach line said `game/bramble.gd` was NOT reached, in a run where I had
    just called `upgrade_gain()` on a live Bramble through `find-nodes --class Bramble
    --call upgrade_gain` and read back `11.4→15.9s`. That reads exactly like reach
    under-reporting a file that was executing. It is not: the Bramble is the one plant
    that stands ON the road, a pest ate it between the read and the `scene-tree` capture,
    and reach correctly reported the tree as it was at capture time. **The harness was
    right and my timing was wrong.** Checking the capture for the node (`@Node2D@149`,
    absent; the Chomp's `@Node2D@156`, present with its script) is what settled it, and it
    cost two commands against the cost of a false gap report upstream.
  - `find-nodes --class X --call METHOD` is the verb that made this cycle cheap: an
    auto-named node found by what it IS and a computed value read off it in one trip, with
    no path to guess. Three of the four live facts here came from it.

## 2026-08-20 — stopped a headless run rewriting the player's save

- Value: **warranted**, and there was no cheaper option even in principle. The defect is
  what an AUTOLOAD does at process start, so it cannot be reproduced without starting a
  process, and the proof is an md5 of a file on disk before and after — which no unit
  test can take of itself.
  - Expected: the redirect would move the boot load off the player's save and the hard
    part would be writing it.
  - Got: the redirect was five lines. The GUARD took three tries and the first two looked
    fine. `assert RunConfig.save_path != SAVE_PATH` **survived** the ordering mutation it
    was written for, because both orders leave `save_path` on the scratch file by the time
    a test can read it. The second version worked only while the test happened to run
    before its neighbours. Neither would have been noticed without mutating.
  - Found: those two, plus `OS.has_feature("headless")` being **false** under `--headless`
    — the obvious reach, wrong, established with a four-line probe script before anything
    depended on it. `DisplayServer.get_name()` returns `"headless"`.
  - Cheaper: nothing. `python tools/run_tests.py` against a planted v6 save, and an md5
    either side, IS the cheap version.

- Gap: **no new gap this turn**, and one piece of harness behaviour worth writing down
  because it shaped the fix rather than merely annoying me.
  - `launch --isolated` isolates the **bus only**; `user://` cannot be isolated at all
    (harness gh#28, already recorded in `CLAUDE.md`). That is why the fix could not be
    "give each run its own user dir" and had to be "point this one file elsewhere". The
    scratch save is consequently shared between concurrent headless runs — better than
    sharing the player's real save, and not isolation. `PLANT_TD_SAVE_PATH` is the seam
    left for whoever decides that trade; it is filed rather than guessed at.
  - Worth recording against the harness's own advice: `CLAUDE.md` says a headless gate
    "brings the autoload up passive: safe to run while another session drives this game."
    True of the BUS. It was not true of `user://`, and this cycle is why. The sentence is
    about DevTools and reads as being about headless runs generally.

## 2026-08-20 — audited the harness drift before refreshing, and did not refresh

- Value: **warranted**, and it is the cheapest `warranted` this log has recorded — the
  whole finding came from hashing fourteen files against `harness_history.json`. No
  engine, no game, a Python loop. What would have been expensive is running
  `/scaffold-godot-harness` first and finding out afterwards.
  - Expected: the install is cleanly stale, the refresh is one command, and three cycles
    of "gaps filed against a version this project does not run" ends today.
  - Got: `addons/godot_selftest/dev_tools.gd  LOCAL EDITS -- hash in NO released version`,
    and the same for `tools/verify_ledger.py`. Twelve of fourteen files are cleanly stale;
    two are not. **Refreshing would have reverted a shipped-game fix** — the exported-build
    guard from upstream #58, which is still OPEN and absent from the 0.60.0 templates, and
    without which `entry_hook` skips the title screen for every itch.io player.
  - Found: that, plus two numbers the newer client prints and the installed one cannot —
    **17** gaps this project filed are credited as fixed in releases it does not have, and
    **12** open gaps in its own log are already fixed in the templates it RUNS. The second
    twelve need no refresh at all. G-058, which I have hit three cycles running, is in the
    first list.
  - Cheaper: nothing. This IS the cheap version, and the expensive version is the one that
    happens if you skip it.

- Gap: **no new gap this turn.** Two things worth recording that are not gaps.
  - The `/verify` skill's drift procedure is the reason this cycle went well, and it earned
    its length: the per-file bearing (`LOCAL EDITS` vs `matches 0.38.0` vs `plugin ahead
    unreleased`) is the whole finding, and a plain `diff -q` would have reported all
    fourteen as drifted with no way to tell which mattered. Worth saying out loud because
    the previous cycles skimmed that block as boilerplate.
  - `harness-version --client` takes `--project` BEFORE the subcommand, not after
    (`devtools.py --project . harness-version --client`). `-p .` after it is an
    `unrecognized arguments` error. One retry, no consequence, noted so the next reader of
    this log does not spend it again.

## 2026-08-20 — made the record know which difficulty earned it

- Value: **warranted**, and unusually clearly: the live pass caught two defects the whole
  headless suite could not, and both were player-visible.
  - Expected: the per-difficulty records would be the hard part and the title line a
    one-line change.
  - Got: the records were mechanical. The line was where the bugs were. Pressing the
    picker twice left the label reading `on Standard` both times — `_cycle_difficulty`
    updated the difficulty and start buttons and not the record label — and the empty case
    read `No garden on record yet on Harsh`, which is the same " on X" clause the record
    sentence uses, with a spare "on" in a sentence that had no room for it.
  - Found: those two, plus the migration running on the developer's REAL v8 file during
    the windowed pass — `v8 -> v9`, `4138`/`5008` intact, a `d0` line. That is the
    migration exercised on real data, which no fixture can be.
  - Cheaper: nothing, for either. The suite asserts the RENDERER and both bugs were in
    callers that never re-rendered or in a sentence only a reader can judge. The headless
    width tests are permanent and cover the fit; they cannot cover the reading.

- Gap: **no new gap this turn.** Three notes, all about the harness being right.
  - **The bridge answering while PAUSED is what made the pause card checkable at all.**
    `findings` ran clean with `TREE IS PAUSED`, and the heading was read and measured in
    that state. `CLAUDE.md` calls this out and it is the first cycle here that depended on
    it.
  - **Cycle 172's headless-save guard did its job on the first format bump since it
    landed.** Every headless run left the real `user://highscore.save` alone; only the
    windowed launch migrated it. Before that guard, the v8 → v9 bump would have been
    performed by whichever `run_tests.py` ran first — which is precisely the bug that
    filed `-58u7`, arriving on schedule.
  - **`suite_reach_check`'s two-numbers-together design paid.** The new test named
    `card_width` and the baseline test went red; `--baseline-write` rewrites the whole
    file, so acting on the `PROGRESS:` line alone can bank a regression in the same
    stroke. `0 NEW` beside it is what made re-banking safe, and it is printed there
    deliberately.

## 2026-08-20 — made a wrong-ground refusal point at the packet that would work

- Value: **warranted**, and the useful part was not what I expected. The headless test
  covers the ASYMMETRY, which is the design and is arithmetic. What runtime added was
  proof that the branch is reached from a real click — and the click path is exactly where
  I made a mistake the suite could never have shown me.
  - Expected: a one-line branch, with the interesting decision being which packet to point
    at.
  - Got: `_shake_tweens: {"Button_bramble:<Button#77930170130>": "<Tween#...>"}` — one
    entry, the right control, named. And at `set-game-speed 0.05` the rotation reads
    `-0.0197` rad, which is the shake caught in flight rather than inferred from the call
    having happened.
  - Found: two mistakes, both mine. `_click_at` takes a SCREEN position and subtracts
    `_entities.position` `(0, 72)`; I fed it board-local coordinates from
    `cell_to_world` **twice** and got a silent no-op each time — no message, no cue, no
    error, indistinguishable from the feature being broken. And I read the shake record as
    a false positive on grass because I compared it against a read taken before an
    intervening repeat click.
  - Cheaper: for the asymmetry, yes, and it is now a permanent test. For "does a click
    reach this branch", nothing.

- Gap: **no new gap this turn.** Three notes about technique, because two of them are what
  turned a confused reading into a settled one and I want the next session to reach for
  them sooner.
  - **`_shake_tweens` is a durable record of a transient event.** `Hud._shake_control`
    stores its tween per control, so "did the right button shake" is answerable *after*
    the shake is over. That is worth more than catching the animation: it is a fact rather
    than a race. Look for the bookkeeping a transient effect leaves behind before trying
    to photograph the effect.
  - **Bracket ONE action with two reads.** I had `_shake_tweens` before and after, but the
    "before" was three commands stale, and a changed tween id read as a false positive.
    Re-reading immediately either side of a single `run-method` settled it in one command.
    The `read-a-moving-value` skill asks "what was moving when I read it"; the companion
    question is "what else happened between my two reads".
  - **A silent early return is the worst shape to drive blind.** Nothing in the harness can
    distinguish "your coordinates were wrong" from "the feature does not work", because
    both produce an unchanged screen. `run-method` reporting `returned_null` +
    `declared_return` helps for a `-> String`; a `-> void` guard clause offers nothing. The
    workaround that worked was to call the pure predicate (`sole_legal_plant_for`) directly
    and compare it against the observed behaviour — i.e. verify the parts separately when
    the whole is silent.

## 2026-08-20 — recovered the citation drift cycle 175 banked, and built the tool that re-points it

- Value: **warranted**, and none of it involved the game. The harness earned its keep as a
  set of INVARIANTS rather than as a bridge: what caught the fixer corrupting a citation
  was `citation_check` falling from `537 of 537 resolving` to `536`, a number the fixer
  does not compute and cannot fake.
  - Expected: the 98 drifted citations were gone, because the snapshot that found them had
    been overwritten and `.devtools/*` is gitignored.
  - Got: recoverable exactly. The file was dated 10:11, `25cac96` closed cycle 167 at
    10:08, and a worktree there reproduced **98 drifted / 38 new / 83 closed-bead** to the
    unit.
  - Found: five things, and four of them are mine. Cycle 175's refresh **banked** all 98.
    Its close said "15 gating", which was `98 - 83` where the two are separate counts, not
    a subset. The fixer's first apply corrupted a range citation into `:2151-2071`. Its
    second wrote **one of thirty-four** and reported success. And `check_all` refused to
    classify a fixer that carried the checker contract line, printing the contradiction
    *and* a sum mismatch rather than picking one.
  - Cheaper: nothing. The recovery needs a worktree at the right commit; the rebind needs
    the snapshot's stored text. The alternative was 98 hand edits, which contains a
    transcription error by construction.

- Gap: **no new gap this turn**, and two notes about tools this project owns rather than
  the harness.
  - **`check_all.py` behaved better than I did.** Given a tool listed as a non-checker
    whose source still declared the contract marker, it printed
    `UNCLASSIFIED: ... one of the two is wrong` and a `SUM MISMATCH` saying the counts
    above could not be trusted. It refused to let a contradiction pass as a number. That
    is the "print both numbers at the point of invitation" rule from
    `house-static-checker`, applied to its own classification, and it is why the fixer got
    registered properly instead of half-registered.
  - **A gitignored baseline cannot be recovered, only re-derived.** Three baselines in this
    repo work this way and only `tools/suite_reach_baseline.json` is tracked. Re-deriving
    took a worktree and a lucky timestamp match; the next one may not be datable at all.
    Filed as an idea rather than a gap, because it is this project's choice and not the
    harness's.

## 2026-08-20 — put the profile on the post-mortem, and found the rebinder had been lying about "text gone"

- Value: **warranted**, and the finding was not the feature. The feature is three
  sentences. What runtime and the citation tooling between them produced was a correction
  to a number this log published one cycle ago.
  - Expected: the score line takes the profile the way the title line already does, and
    the only open question is width.
  - Got: all THREE branches over-claimed rather than the one the bead named, and the
    ribbon entry titled "The record book opens" said "the first score this garden has
    kept" — which record book being exactly the missing word. Live:
    `308 seeds grown — a new best on Harsh` at 640x26.
  - Found: **`citation_rebind.py` compared lines with `rstrip()` only**, while
    `citation_check --snapshot` records each line with its LEADING indentation already
    removed. Every tab-indented GDScript line therefore reported as `TEXT IS GONE` —
    text sitting in the file, findable by grep, one indent away. On this cycle's own six
    drifted citations: `rstrip` gave 4 gone / 1 rebindable, `strip` gives 0 gone / 5
    rebindable. **Cycle 176's headline "54 text gone" is inflated by an unknown amount**,
    and the bead scoped around it now carries a correction note.
  - Cheaper: for the feature, the headless test — and it is permanent. For the bug,
    nothing: it only surfaced because I distrusted a "text gone" verdict enough to grep
    for the string myself.

- Gap: **no new gap.** Two notes.
  - **`cmd end_run` can never reach the first-record branch.** It leaves `previous_best`
    at its `-1` default, so a synthetic run always takes the new-best sentence. Nothing is
    wrong with the verb — it is classified `DEFAULTED` precisely to record that its setters
    leave a partial state — but it means one of three branches on this card is
    headless-only, and that is worth knowing before trying to photograph it. Filed as an
    idea: each DEFAULTED verb reaches some branches and not others and nobody has written
    down which.
  - **A tool's own verdict is evidence, not proof, and "gone" is the verdict most worth
    distrusting.** `TEXT IS GONE` reads as final. It took one `grep -n` to disprove it
    four times over. The general form for this log: when a tool reports an ABSENCE, the
    cheap check is to look for the thing yourself, because absence is the verdict a
    comparison bug produces most readily.

## 2026-08-20 — told the packet whether the plant can ever grow

- Value: **warranted**, and the runtime half answered a question the suite structurally
  cannot: whether THREE clauses compose in the right order on one tooltip. The tests
  assert each clause; nothing asserts the assembled string on a locked plant, and that is
  the string a player reads.
  - Expected: a tooltip clause, with the only real question being where the catalogue gets
    the answer from.
  - Got: `Sticky Sundew — Hurts nothing. ... / Does not grow — this is the plant it stays.
    / Still in a packet: a Rare Packet (45) can hand it over.` Read off the running plant
    bar, in that order.
  - Found: `grep -rln "^const LEVELS" game/*.gd` returns FOUR files and only three are
    plants — `Sfx.LEVELS` is a volume table. That is why the cross-check instantiates every
    plant and asks `has_upgrades()` rather than scanning source: the object cannot be
    confused about what it is, and a grep would have found three plants and one impostor.
  - Cheaper: for the content, the headless tests, and they are permanent. For the
    composition, nothing short of reading the real tooltip.

- Gap: **no new gap.** One note about this project's own tooling, and it is a good-news
  one.
  - **`citation_rebind.py` paid for itself this cycle.** Step 3 reported 40 drifted —
    over the ten-line, which the loop says makes relocation a work item rather than part
    of the step. The rebinder cleared 19 mechanically in one command, and the residual is
    the set already filed. Two cycles ago this would have been an hour of hand edits or a
    bead deferring all forty.
  - And the rule from cycle 177 held on its first real use: **the fixer said "19 written"
    and the number I believed was `citation_check`'s `1423 resolved, 0 findings`.** Those
    are different claims and only the second one is an invariant.

## 2026-08-20 — Pushed 8 banked commits to origin/main

- Value: **inconclusive** — the harness was not exercised at all; this was a bare `git push` of work already gated in earlier cycles.
  - Expected: nothing from runtime — no code changed in this response.
  - Got: `2b53e43..edff14e  main -> main`.
  - Found: nothing.
  - Cheaper: `git push` alone, which is exactly what was run.

- Gap: no gaps this turn — no harness command was needed or attempted.

## 2026-08-21 — Removed the sole-cover rings and the deferred-road bars from the lanes

- Value: **warranted** — the request was about what the board LOOKS like, so only a live
  screenshot could answer it, and the static gates then found a real hole the diff hid.
  - Expected: a mechanical two-cue deletion whose only complaints would be unresolved
    names, closed by `name_check` and a test run.
  - Got: `name_check` clean at 0 errors, `run_tests.py` **1007 passed / 19363
    assertions / 7 test script(s)**, `findings` **0 across 5 of 5 checks**, and a
    `scene-tree` under `Board` carrying `DeadGroundMarks` with **no** `DeferredRoadMarks`
    and **no** `SoleCoverMarks` anywhere under `Entities`, with 6 `SelectionMarker`s still
    built — which is the claim "the cue is gone and the selection cue is not".
  - Found: `suite_reach_check.py` caught that the deleted tests were the **only** callers
    of three still-live public methods — `Plant.set_uproot_armed`,
    `SelectionMarker.held_over` and `set_held_over`. Deleting a cue silently took live API
    out of the suite's reach while every remaining assertion stayed green. Replaced with
    `test_the_held_over_setters_reach_the_state_they_name`, 8 assertions, driving the
    setters rather than reading the statics beside them.
    Also: six independent denominator guards fired on the removal rather than passing
    quietly (draw-call census, ground-contrast sweep, readout-band pair count,
    band-membership count, judged-message set, notebook hints-page count), and
    `citation_check` found two `kanban.md` entries citing the deleted file — one of them
    the backlog entry asking whether the rings needed a sixth hint or a second legend
    page, which is the question this change answered by deletion.
  - Cheaper: nothing for the verdict. The gates were the expensive half and they earned
    it — no reading of the diff would have surfaced live API losing its only test.

- Gap: **no gaps this turn**, but one note the ledger's own contract should carry.
  - `python tools/devtools.py scripts-seen` prints a human header
    (`Scripts seen since launch (23):`) and `verify_ledger record` wants JSON, so the
    obvious `scripts-seen > seen.json` produces an **unreadable capture** — and `record`
    then writes the row anyway with reach derived from the scene tree alone. That row said
    6/11 reached; `--json` gave 9/11. The failure is quiet in the direction that matters:
    an understated reach reads as "this run did not verify those files".
  - Improvement: `record` already refuses a row with *unknown* reach. It should treat an
    **unparseable** `--scripts-seen` the same way — exit 1 naming `--json` — rather than
    degrading to a scene-tree-only number that looks like a measurement. Logged here
    rather than filed upstream: the harness is `0.60.0` on this machine and this is one
    flag on one verb, below the bar the global instructions set for an issue.
