---
name: godot-devtools-concurrent-launch
description: Launching the devtools bridge (python tools/devtools.py launch) when more than one worktree or agent might be running against this project at once. Use whenever you are about to launch a windowed Godot instance for live bridge verification, and especially when a launch reports "launched, but the bus never answered a ping within 20s" — that message alone does not tell you which of two very different problems you have.
---

# Concurrent launches: use `--isolated`, not a bare `--devtools-session`

## The symptom that sends you the wrong way

`python tools/devtools.py launch -- --devtools-session NAME` reports:

```
ERROR: launched, but the bus never answered a ping within 20s.
```

The spawned process is real and alive (`tasklist` / `Get-Process` shows it), but stuck at
~6MB working set with ~0.01s of total CPU time however long you wait — not slow, not
warming up a shader cache, genuinely idle. This reproduces identically on D3D12 and
`--rendering-driver opengl3`, which rules out the GPU-contention theory it looks like when
several agents are launching Godot at once on shared hardware.

**The real cause is unrelated to contention, and it is a real bug in `tools/devtools.py`'s
`cmd_launch()`, not a fact of life to work around forever.** Passing `--devtools-session X`
after a bare `--` on the CLI, with no top-level `--session` flag before the `launch`
subcommand, leaves the function's internal `user_args` empty — so the line that would add
Godot's OWN `--` separator (`cmd += ["--"] + user_args`) never runs, and `cmd += passthrough`
appends `--devtools-session X` straight onto the engine's command line as two unrecognized
top-level tokens. They never reach `OS.get_cmdline_user_args()`, which is where the addon
reads the session id from. Godot itself is left holding a malformed command line, which is
why the process starts (device init, window) and then goes idle forever rather than erroring
visibly. Filed upstream: SeveralHerr/godot-selftest-harness#28.

Time spent checking GPU load, killing sibling processes, or waiting longer is time spent on
the wrong layer.

## The fix

Use `--isolated` instead — it sets `--devtools-session` **and** `--devtools-busdir`
together, verified before it prints the follow-up command:

```bash
python tools/devtools.py launch --isolated --kill-survivors
# prints back the exact command to use, e.g.:
#   python tools/devtools.py --session 9b71bff8 --userdata C:\...\devtools_bus_lfz7jx68 <verb>
```

Copy that printed `--session`/`--userdata` pair verbatim into every subsequent call. Do not
hand-pick a session name and reuse it across calls without `--isolated` — that is the
bare-`--devtools-session` shape that hangs.

**Through Git Bash, convert the printed `--userdata` path to forward slashes and quote
it.** The launcher prints a Windows path; pasted into a Bash tool call the backslashes
are consumed as escapes and the path silently becomes `C:UsersyouAppData...`:

```bash
# printed:  --userdata C:\Users\you\AppData\Local\Temp\devtools_bus_ab12cd34
# use:      --userdata "C:/Users/you/AppData/Local/Temp/devtools_bus_ab12cd34"
```

The error this produces is the misleading part, and it is why this belongs next to the
two hangs below rather than in a footnote:

```
game not running: 'input_tap' was never picked up (2.0s grace, ...)
  polling: C:UsersyouAppDataLocalTempdevtools_bus_ab12cd34
```

That is verbatim the message a crashed game gives, on a game that is alive and answering
— the client cannot tell "wrong directory" from "dead process", and says so. **Read the
`polling:` line before believing a `game not running` on a launch that just succeeded**:
if it has no separators in it, the path was eaten, the game is fine, and nothing needs
relaunching.

Note what `--isolated` does **not** do: `user://` (saves, screenshots, UI baselines,
`.godot/`) stays shared across concurrent worktrees, and there is no supported way to
isolate it — Godot has no `--user-data-dir`/`--userdata` engine flag at all. Despite what
this project's own generated `CLAUDE.md` says, **setting `GODOT_USERDATA` before `launch`
does not move `user://`** (confirmed live: the owner file still landed under the default
`%APPDATA%/Godot/app_userdata/<project>/` with the env var set). See
SeveralHerr/godot-selftest-harness#28 for the full diagnosis. If several agents are driving
live games against the same project name at once, saves, screenshots and UI baselines can
still collide; only the command bus itself is isolated by `--isolated`.

## Signature to recognize fast

- `launch` (not `--isolated`) hangs at ping.
- The process exists, is "Responding: True", but CPU time never advances.
- Killing and relaunching reproduces the exact same hang, renderer-independent.

That combination means: wrong flag, not a resource fight. Switch to `--isolated
--kill-survivors` before spending more time on any other theory.

## A second hang that looks identical and has nothing to do with this bug

`--isolated --kill-survivors` used correctly (verified `--session`/`--userdata` pair,
printed and copied) can *still* time out at "the bus never answered a ping within 20s"
— alive process, near-zero CPU, one thread. Before concluding it's the bug above again,
check the window title:

```bash
powershell -Command "Get-Process -Id <pid> | Select-Object MainWindowTitle"
```

If it reads `ALERT!`, the process is not idle on a malformed command line — it is
blocked on a genuine, modal `OS.alert()` box, almost always "Main scene's path could not
be resolved from UID. Make sure the project is imported first." That box draws no child
controls (`EnumChildWindows` returns nothing), so reading the message text means
screen-scraping the window with `PrintWindow` into a bitmap rather than pulling text out
of a control.

The cause: `godot --headless --path . --import` can print a clean-looking run all the
way through `[ DONE ] reimport` and still not have written `.godot/uid_cache.bin` —
observed once in a fresh worktree with a sibling agent's own `--import` running
concurrently in a different worktree at the same time. `ls .godot/uid_cache.bin` after
an import that looked clean is the fast check; a second, identical `--import` call wrote
it and the next `launch` came up clean. This is a different failure of the same
underlying tool as the segfault-then-clean-retry gap already logged against the harness
(G-044) — here the first run didn't error at all, it just silently didn't finish the one
file the next launch depends on.

### When the second `--import` crashes too

Observed 2026-08-16 in a fresh worktree: `python tools/import_check.py` exited 2 twice in
a row with `no parse/load errors in the output, but Godot exited 3221225477` (0xC0000005,
an access violation), `.devtools/import.log` ending at the same line both times —

```
[   0% ] reimport | question_002.ogg
```

— and `.godot/imported` holding nothing but `.tmp` files afterwards. "Run it again" does
not help when the importer is crashing deterministically on one asset.

The fix is that **the import cache is keyed on the `res://` path, which is identical in
every worktree of the same project**, so a sibling checkout's finished cache is byte-valid
here:

```bash
rm -rf .godot/imported
cp -rf <main-checkout>/.godot/imported .godot/imported
cp -f  <main-checkout>/.godot/uid_cache.bin .godot/
cp -f  <main-checkout>/.godot/scene_groups_cache.cfg .godot/
python tools/import_check.py     # now exits 0 in seconds
```

Check the denominator before trusting it: `ls .godot/imported | wc -l` should be in the
hundreds, not the dozen `.tmp` files a crashed run leaves. Then confirm
`.godot/uid_cache.bin` exists, as above.

`--isolated` does nothing to fix this — it isolates the command bus, not the import
cache, and killing and relaunching just reproduces the same alert with a new pid. Rerun
`--import` (and confirm `uid_cache.bin` exists) before touching `launch` again.
