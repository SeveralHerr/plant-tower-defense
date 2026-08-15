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
