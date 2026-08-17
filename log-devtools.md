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
