---
name: devtools-kill-safety
description: Before running `devtools.py quit --kill` (or any process kill) on this project, when more than one worktree, agent, or session might be active on the same machine. Use whenever `tasklist`/`Get-Process` shows more than one Godot process, before killing anything by pid, and whenever a `quit`/`quit --kill` report names a pid you did not expect.
---

# Check whose process it is before you kill it

`.beads/issues.jsonl`, `log-devtools.md`, and `.claude/skills/` are shared files in one
checkout — other Claude Code sessions (other worktrees under `.claude/worktrees/`, or
another session on the parent checkout) can be actively running `run_tests.gd`,
`lint_project.gd`, or a live windowed instance **at the same moment you are**. A `pid`
CLAUDE.md's own devtools bridge reports (from `.devtools/launched.jsonl`, from a stale
`devtools_owner.json`, or from `quit`'s own reply) is not guaranteed to be the process
*you* launched — the bus is shared per project path, and a stale owner record can name a
pid that either belongs to someone else's still-live run or no longer exists at all.

**Before `quit --kill`, or any `Stop-Process`/`taskkill` by pid:**

```powershell
Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" |
  Select-Object ProcessId, ParentProcessId, CommandLine
```

Read the `CommandLine`'s `--path` before touching a pid. A path pointing at
`.claude/worktrees/<other-lane>` or a sibling checkout you did not create is not yours —
leave it running even if it looks idle, even if `tasklist` shows near-zero CPU (a
just-started headless test process looks exactly like a hung one for its first several
seconds). Only kill a pid whose `--path` matches the checkout/worktree you are actually
working in, and ideally one whose start time lines up with a launch or test run *you*
started this turn.

If `quit --kill` reports a pid, and `Get-CimInstance`/`tasklist` shows that pid is no
longer in the list at all, nothing of value was touched — a stale owner record naming an
already-dead pid is harmless to "kill" again. The danger is only in guessing a *live*
pid without checking its command line first.

See also `godot-devtools-concurrent-launch` for the companion bus-side hazard (a launch
that hangs because of a busdir collision, not a kill that hits the wrong process).
