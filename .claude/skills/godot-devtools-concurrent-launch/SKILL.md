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
