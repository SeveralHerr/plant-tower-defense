#!/usr/bin/env python3
r"""One exclusion rule for every tools/ checker that walks the repo tree.

NOT A CHECKER. This is a library; it prints nothing, gates nothing, and is listed
in check_all.py's NOT_A_CHECKER for exactly that reason. It deliberately does not
carry the house contract marker line, because check_all.py classifies by reading
source for that string and a library carrying it would be run as a checker.

WHY THIS EXISTS.
Agent git worktrees live at `.claude/worktrees/<lane>/`, which is INSIDE the repo.
They are gitignored (`.gitignore` names `.claude/worktrees/`), but neither
`os.walk` nor `Path.rglob` reads `.gitignore`, so every checker rooted at the repo
root walks N+1 copies of the whole project during a fan-out.

The failure is nastier than a false positive, because it is asymmetric:

  * The PARENT sees the nested copies and its numbers change.
  * A LANE running the same checker inside its own worktree sees none of them and
    reports clean.

So the finding count depends on which process is asking, which is the one property
a gate must not have. Measured on citation_check.py during cycle 102: five lanes
turned one clean run into a six-way ambiguity for every bare citation in
kanban.md, and only the parent ever saw it. Measured again here with a planted
fixture: world_control_check.py went from `19 world-space script(s), 3 of them
build Controls` to `38 ... 6 ...` with one fake nested checkout present.

TWO RULES, AND WHY BOTH.
`is_nested_checkout` is the derived one and the one that matters: a directory
holding a `.git` entry is another checkout, wherever it sits and whatever it is
called. `git worktree` writes `.git` as a FILE (`gitdir: ...`) rather than a
directory, so this tests existence, not is_dir. That rule needs no hardcoded path
and covers a nested checkout somebody puts somewhere new.

`NESTED_CHECKOUT_DIRS` is the hardcoded backstop, and it is not redundant: a
COPY of a checkout (an archive someone unpacked, the fixture this was verified
with) carries no `.git` at all and the derived rule is blind to it. Its single
entry is transcribed from `.gitignore`; if that line moves, this one is wrong and
nothing will say so. That is the known limitation, stated rather than hidden.

WHAT THIS DOES NOT DO.
It does not read `.gitignore`. A tool wanting full gitignore semantics needs
`git check-ignore`, which is a subprocess per path and not worth it here. It has
no opinion about which FILES a checker should read - only about which directories
are a different copy of this project.

# fixture:   .claude/worktrees/fake-lane-COPY/  full copy, no .git  (path rule)
#            .claude/worktrees/fake-lane-GITFILE/ copy + a `.git` FILE (both rules)
#            fixture-GITONLY/                   copy + a `.git` FILE, NOT under
#                                               .claude/ (derived rule only)
#            98 planted .gd files. With all three present, `python
#            tools/check_all.py` output was BYTE-IDENTICAL to the unplanted run.
# mutations: (measured 2026-08-17, all three fixtures planted; baseline
#            `world_control_check: 19 world-space script(s), 3 of them build
#            Controls` and `citation_check: ... 298 resolved, 0 finding(s)`)
#            NESTED_CHECKOUT_DIRS = ()                  -> RED. world_control
#              19 -> 38 script(s), 3 -> 6 Controls; citation_check exits 1 with
#              37 ambiguity findings. fake-lane-GITFILE stays excluded, so the
#              +19 is exactly one lane's worth: the two rules are separable.
#            is_nested_checkout: exists() -> isdir()    -> RED. world_control
#              19 -> 20, 3 -> 4. Only fixture-GITONLY reappears, because a `git
#              worktree` writes .git as a FILE. This is the mutation that says
#              the derived rule is doing work the path constant cannot.
#            drop the `root` guard in is_nested_checkout -> RED, but only via
#              the public API, not the fixture: this repo's own root holds a
#              `.git` file, so `is_nested_checkout(root)` with no root arg is
#              already True. Verified by direct call, not by a checker run --
#              no current caller passes root as `path`, so a fixture cannot
#              reach it. Kept because it guards the function's contract, and
#              named here so the next reader does not mistake it for dead code.
"""

import os

# Pre-existing noise every .gd walker in tools/ already skipped, gathered here
# rather than retyped. `.godot` is engine cache, `.beads` is the issue DB export,
# `__pycache__` is ours.
SKIP_DIR_NAMES = frozenset({".godot", ".git", ".beads", "__pycache__"})

# Relative paths (posix, from the repo root) that hold nested checkouts which may
# carry no `.git` of their own. Transcribed from `.gitignore`:
#     # Agent git worktrees live inside the repo; never commit them as a nested repo.
#     .claude/worktrees/
NESTED_CHECKOUT_DIRS = (".claude/worktrees",)


def _rel_posix(path, root):
    try:
        return os.path.relpath(os.path.abspath(path), os.path.abspath(root)).replace(os.sep, "/")
    except ValueError:
        # Different drives on Windows; it cannot be under root, so it is not ours.
        return None


def is_nested_checkout(path, root=None):
    """True when `path` is a different checkout of this project.

    Derived test first: anything holding a `.git` entry is a checkout. `git
    worktree` writes `.git` as a file, so this is `exists`, not `is_dir`. The
    repo's own root is excluded when `root` is given - without that guard a walk
    rooted at the repo would prune itself and return nothing, which reads exactly
    like a clean run over an empty tree.

    Then the hardcoded backstop, for a copy that carries no `.git`.
    """
    if root is not None:
        if os.path.abspath(path) == os.path.abspath(root):
            return False
        rel = _rel_posix(path, root)
        if rel is not None and rel != "..":
            for nested in NESTED_CHECKOUT_DIRS:
                if rel == nested or rel.startswith(nested + "/"):
                    return True
    return os.path.exists(os.path.join(path, ".git"))


def prune(dirpath, dirnames, root=None):
    """Filter `dirnames` IN PLACE for an `os.walk` loop. Returns it, for chaining.

    Must be called with the walk's own `dirnames` list and assigned via slice
    inside `os.walk` semantics - which is what this does - or os.walk will
    descend anyway.
    """
    dirnames[:] = [d for d in dirnames
                   if d not in SKIP_DIR_NAMES
                   and not is_nested_checkout(os.path.join(dirpath, d), root)]
    return dirnames


def excluded(path, root):
    """True when a path produced by rglob/glob is inside something prune() skips.

    The rglob counterpart of prune(): rglob has no hook to stop descending, so a
    checker using it filters results instead. Same two rules, applied to every
    ancestor directory between `root` and `path`.
    """
    rel = _rel_posix(path, root)
    if rel is None or rel.startswith("../"):
        return False
    parts = rel.split("/")
    if any(p in SKIP_DIR_NAMES for p in parts[:-1]):
        return True
    for i in range(1, len(parts)):
        prefix = "/".join(parts[:i])
        for nested in NESTED_CHECKOUT_DIRS:
            if prefix == nested:
                return True
        if os.path.exists(os.path.join(root, *parts[:i], ".git")):
            return True
    return False
