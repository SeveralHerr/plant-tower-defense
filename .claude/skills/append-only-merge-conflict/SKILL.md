---
name: append-only-merge-conflict
description: Resolve a git conflict in an append-only file (log-devtools.md, kanban.md, cycle-log.md) when merging or cherry-picking across branches that each appended independently. Use whenever such a file shows a merge/cherry-pick conflict.
---

# Resolving an append-only-file conflict

These files are never edited, only appended to — so a real conflict means two branches
each appended after the same point. The fix is almost always **keep both blocks, in
whichever order makes chronological sense**, never pick one side over the other.

## The trap this exists for

A shared ID (a `[G-NNN]` gap id, a cycle number) can appear at the tail of BOTH sides'
diff hunks even when the two appended entries are about completely different things —
two unrelated cycles each independently closed out an in-progress paragraph that used
the same id. That is NOT a real duplicate to dedupe; it is two different log entries
that happen to share an id. Resolving by deleting one side loses a real entry.

**Before resolving, read past the `<<<<<<<`/`=======`/`>>>>>>>` markers on BOTH sides
back to the nearest `## ` heading**, not just the few lines the diff hunk shows. A
narrow conflict region can start mid-paragraph, and copying only what's inside the
markers drops the heading and lead-in that make the block make sense standing alone.

## Procedure

1. `grep -n "^<<<<<<<\|^=======\|^>>>>>>>"` to find every conflict region.
2. For each region, use `git show <side>:<file>` to see each side's FULL entry back to
   its `## ` heading — the visible conflict hunk is usually a fragment.
3. Concatenate both full entries in whatever order matches their content (usually
   HEAD's, then the incoming side's), delete the conflict markers, keep every line.
4. `grep -c` each entry's heading afterward to confirm exactly one copy of each survived
   — not zero (dropped), not two (duplicated).
5. Re-run whatever gate reads the file (e.g. `gap_ledger.py`) to confirm it still parses.
