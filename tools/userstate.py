#!/usr/bin/env python3
"""Resolve the game's `user://` directory, and diff what a headless run wrote there.

WHY THIS EXISTS. `run_tests.py` reports `user:// writes: N file(s) changed` beside every
suite result, and that line is not decoration: four tests once staged low scores through a
real `record_score()` -> `_save()` and destroyed both high scores across two runs while
every test restored the in-memory values and the suite said ALL TESTS PASSED. The writes
line is the only place that shows up.

The resolution and the stat helpers used to live in the selftest harness's bridge client
and were imported from there; the bridge is gone and the check is not, so they live here
now, cut down to the three functions `run_tests.py` calls. The snapshot record moves with
them, from the bridge's scratch dir to `.gates/`.

`user://` cannot be isolated per process (Godot has no `--user-data-dir` flag and honours
no env var for it), which is exactly why knowing what a run touched is worth a file.
"""

import json
import os
import re
import sys
import time
from pathlib import Path

STAT_FILE = "userstate_stat.json"
STAT_DIR = ".gates"


def _parse_project_godot(project_file: Path) -> dict:
    """The handful of application/config/* keys the user:// path depends on.

    project.godot is INI-like, but only a few flat keys from [application] are needed,
    so a line scan avoids every INI-parser quirk with `res://` values.
    """
    values: dict = {}
    with open(project_file, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            for key in ("config/name",
                        "config/use_custom_user_dir",
                        "config/custom_user_dir_name"):
                prefix = key + "="
                if line.startswith(prefix):
                    values[key] = line[len(prefix):].strip().strip('"')
    return values


def _sanitize_dir_name(name: str) -> str:
    """Mirror Godot's sanitization of custom_user_dir_name / project name.

    Conservative on purpose: drop anything outside [A-Za-z0-9_.-] while preserving path
    separators, since Godot allows a nested custom user dir.
    """
    normalized = name.replace("\\", "/")
    return re.sub(r"[^A-Za-z0-9_.\- /]", "", normalized).strip()


def _platform_data_dir() -> Path:
    """Base OS data directory Godot writes user data beneath."""
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", str(Path.home())))
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support"
    return Path.home() / ".local" / "share"


def get_user_data_path(project_path: Path) -> Path:
    """The `user://` directory for this project.

    Priority: GODOT_USERDATA, then project.godot's custom user dir, then the
    per-platform default `<data dir>/<Godot|godot>/app_userdata/<config name>`.
    """
    env_override = os.environ.get("GODOT_USERDATA")
    if env_override:
        return Path(env_override).expanduser()

    project_file = project_path / "project.godot"
    if not project_file.exists():
        raise FileNotFoundError("No project.godot found in %s" % project_path)

    cfg = _parse_project_godot(project_file)
    project_name = cfg.get("config/name") or project_path.name

    if str(cfg.get("config/use_custom_user_dir", "")).lower() == "true":
        custom_name = cfg.get("config/custom_user_dir_name", "") or project_name
        # A custom user dir sits directly under the platform data dir, with no
        # Godot/app_userdata prefix.
        return _platform_data_dir() / _sanitize_dir_name(custom_name)

    godot_dir = "godot" if sys.platform not in ("win32", "darwin") else "Godot"
    return _platform_data_dir() / godot_dir / "app_userdata" / _sanitize_dir_name(project_name)


def stat_take(project_path: Path, user_dir: Path) -> int:
    """Record (size, mtime) of every top-level user:// file before a run."""
    stat = {}
    try:
        for f in sorted(user_dir.iterdir()):
            if f.is_file():
                st = f.stat()
                stat[f.name] = [st.st_size, st.st_mtime]
    except OSError:
        return 0
    out = project_path / STAT_DIR / STAT_FILE
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps({"user_dir": str(user_dir), "files": stat,
                               "taken_unix": time.time()}), encoding="utf-8")
    return len(stat)


def stat_diff(project_path: Path):
    """(changed, created, deleted, user_dir) since stat_take, consuming the record;
    None when there is no record. Pure bookkeeping, no printing."""
    path = project_path / STAT_DIR / STAT_FILE
    if not path.is_file():
        return None
    try:
        rec = json.loads(path.read_text(encoding="utf-8"))
        user_dir = Path(rec["user_dir"])
        before = rec["files"]
    except (OSError, ValueError, KeyError):
        path.unlink(missing_ok=True)
        return None
    path.unlink(missing_ok=True)
    if not user_dir.is_dir():
        return None
    now = {}
    for f in user_dir.iterdir():
        if f.is_file():
            st = f.stat()
            now[f.name] = [st.st_size, st.st_mtime]
    changed = sorted(n for n in now if n in before and now[n] != before[n])
    created = sorted(n for n in now if n not in before)
    deleted = sorted(n for n in before if n not in now)
    return changed, created, deleted, user_dir
