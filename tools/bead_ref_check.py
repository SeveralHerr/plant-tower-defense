r"""A `plant-tower-defense-XXXX` written in prose that names no issue.

WHY THIS CLASS IS INVISIBLE TO EVERYTHING ELSE. `citation_check.py` resolves
`file:line` citations; a bead id is not one. `bead_prose_check.py` catches prose the
SHELL ate on its way into `bd`; an invented id survives a shell perfectly. Neither asks
whether the id names anything, and no engine gate reads prose at all.

AND IT IS WORSE THAN A DANGLING FILE CITATION. A wrong `file:line` lands somewhere the
reader can SEE is wrong. A wrong bead id sends them to `bd show` and a "not found" they
will assume is their own typo -- so the failure is not just silent, it is misattributed.
Cross-references are how this project chains its evidence (`-nalv` notes onto `-2174`,
`-5w4v` points at `-t7t1`, `s1o8`'s children point at each other), so an invented link is
a break in the one structure that makes the record navigable.

MEASURED BEFORE IT WAS WRITTEN, per .claude/skills/house-static-checker/SKILL.md, because
the procedure legitimately ends in not building one:

    markdown sources   83 refs, 30 backticked / 53 bare, 0 dangling
    bead prose         74 refs,  0 backticked / 74 bare, 1 distinct dangling (x2)

The one live finding is `plant-tower-defense-9dq7`, invented in cycle 142 and still in
`-xnmz`'s own description in cycle 146 -- after being "fixed". That is the argument: the
correction was believed and did not hold, and nothing could say so.

THE EXTRACTION CONVENTION, and it is the citation_check lesson again with its own numbers.
Two very different sources:

  * MARKDOWN (kanban.md, cycle-log.md, log-devtools.md, .claude/skills/**/*.md) is
    rendered, so backticks are rewarded -- and even here only 30 of 83 carry them.
  * BEAD PROSE (description, close_reason, design, notes in .beads/issues.jsonl) renders
    NOWHERE. `bd` stores plain text, nothing rewards a backtick, and the measurement is
    absolute: 0 of 74.

So the pattern is backtick-agnostic in both, which is safe here in a way it is not for
`citation_check`: `plant-tower-defense-` is a 20-character literal prefix that no prose
produces by accident, unlike a bare `file.gd:12`.

# fixture:   a real id / an invented id / an invented id with a waiver / an id inside a
#            fenced code block / the literal prefix with no suffix
# mutations: drop the waiver scan            -> the waived fixture case must go red
#            match `[a-z0-9]+` without the `plant-tower-defense-` prefix
#                                            -> false positives explode on ordinary words
#            replace the id set with one JUNK id -> every ref becomes a finding. NOT an
#                                               empty set: that trips the tool's own
#                                               `could not run` guard and exits 2, which
#                                               proves nothing (exit 2 means nothing was
#                                               verified). Non-empty-but-wrong is what
#                                               shows the set is doing the deciding.
#            (there is no `!= own id` guard: mutating one away changed nothing, because a
#             bead's own id is in the export by definition -- see the note at the check)
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import repo_walk  # noqa: E402  -- one exclusion rule for every tools/ checker

# The id grammar `bd` mints: a slug, optionally a dotted child index (`s1o8.1`).
REF = re.compile(r"plant-tower-defense-[a-z0-9]+(?:\.[0-9]+)+|plant-tower-defense-[a-z0-9]+")

# Prose that legitimately names a non-existent id -- a bead REPORTING an invented
# reference has to be able to quote it. Scoped to the same LINE as the reference, so a
# waiver cannot silence a whole file the way group_leak_check's first draft did.
WAIVER = "bead-ref-check: ok"

MARKDOWN_SOURCES = ()
BEAD_FIELDS = ("description", "close_reason", "design", "notes")


def _read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _markdown_files(root):
    out = []
    for name in MARKDOWN_SOURCES:
        path = os.path.join(root, name)
        if os.path.isfile(path):
            out.append(path)
    skills = os.path.join(root, ".claude", "skills")
    for dirpath, dirnames, filenames in os.walk(skills):
        repo_walk.prune(dirpath, dirnames, root)
        for name in sorted(filenames):
            if name.endswith(".md"):
                out.append(os.path.join(dirpath, name))
    return out


def _load_ids(export):
    """Every id the export knows, plus the export's own row count."""
    ids = set()
    rows = 0
    for line in _read(export).splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        rows += 1
        ident = row.get("id")
        if ident:
            ids.add(ident)
    return ids, rows


def _refs_in(text):
    """(ref, line_number, line_text, backticked) for every reference in `text`."""
    out = []
    for match in REF.finditer(text):
        start, end = match.start(), match.end()
        line_no = text.count("\n", 0, start) + 1
        line_start = text.rfind("\n", 0, start) + 1
        line_end = text.find("\n", end)
        line = text[line_start:line_end if line_end != -1 else len(text)]
        ticked = start > 0 and text[start - 1] == "`" and end < len(text) and text[end] == "`"
        out.append((match.group(0), line_no, line, ticked))
    return out


def main():
    export = os.path.join(ROOT, ".beads", "issues.jsonl")
    if not os.path.isfile(export):
        print("bead_ref_check: no .beads/issues.jsonl -- nothing to check ids against.")
        print("COULD NOT RUN: the export is the only id set this tool has.")
        return 2

    ids, rows = _load_ids(export)
    if not ids:
        print("bead_ref_check: the export parsed to zero ids.")
        print("COULD NOT RUN: a clean result against an empty id set would flag everything.")
        return 2

    findings = []
    waived = 0
    total = 0
    ticked_count = 0
    sources = 0

    for path in _markdown_files(ROOT):
        sources += 1
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        for ref, line_no, line, ticked in _refs_in(_read(path)):
            total += 1
            ticked_count += int(ticked)
            if ref in ids:
                continue
            if WAIVER in line:
                waived += 1
                continue
            findings.append((rel, str(line_no), ref, line.strip()))

    bead_rows = 0
    for line in _read(export).splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        bead_rows += 1
        own = row.get("id", "")
        for field in BEAD_FIELDS:
            text = row.get(field) or ""
            if not text:
                continue
            for ref, line_no, prose_line, ticked in _refs_in(text):
                total += 1
                ticked_count += int(ticked)
                # NO `ref == own` GUARD, and its absence is load-bearing knowledge rather
                # than an omission. The first draft had one, on the reasoning that a bead
                # naming itself is not a cross-reference. Mutating it away changed nothing,
                # and the reason is an invariant: a bead's own id is IN the export by
                # definition, so `ref == own` can never be true where `ref in ids` is
                # false. One bead does cite itself and is correctly silent either way.
                # Deleted rather than kept as a safety belt -- see
                # .claude/skills/house-static-checker/SKILL.md on a survivor being a
                # finding about the code.
                if ref in ids:
                    continue
                if WAIVER in prose_line:
                    waived += 1
                    continue
                findings.append(("bead %s" % own, "%s:%d" % (field, line_no), ref,
                                 prose_line.strip()))
    sources += 1

    print("bead_ref_check: %d reference(s) across %d source(s) (%d markdown file(s) + "
          "%d bead row(s)); %d id(s) in the export; %d waived; %d finding(s)"
          % (total, sources, sources - 1, bead_rows, len(ids), waived, len(findings)))
    if total == 0:
        print("NOTE: nothing to check -- no prose names a bead id at all. That is a clean")
        print("      result only if you expected none.")
    else:
        # The SECOND denominator, the one the containers-count would hide: how the refs
        # are actually written. A checker demanding backticks would see the first number
        # and miss the rest, which is exactly what citation_check's first --beads mode did.
        print("             extraction: %d of %d backticked, %d bare -- this tool matches "
              "BOTH, and the bare form is the majority in markdown and universal in bead "
              "prose (which renders nowhere and rewards nothing)."
              % (ticked_count, total, total - ticked_count))

    for where, line_no, ref, line in findings:
        print("FINDING: %s:%s cites %s, which names no issue in the export." % (where, line_no, ref))
        print("  line: %s" % (line[:150]))
        print("  fix: correct the id (`bd list --status=open | grep <words>` finds the real")
        print("       one) or delete the reference. A wrong id sends the reader to a")
        print("       `bd show` miss they will blame on their own typo.")
        print("  waive: put `%s` on the SAME LINE -- for prose that quotes an invented id"
              % WAIVER)
        print("         on purpose, which is what a bead REPORTING one has to do.")

    print("NOT COVERED: this reads the JSONL export, which is a PASSIVE EXPORT -- an id "
          "filed since the last `bd export` is not in it and its references would be "
          "reported as dangling. Run `bd export -o .beads/issues.jsonl` first if you have "
          "just filed anything; the row count above is the only handle you get on that "
          "(see plant-tower-defense-4dxf). It also cannot tell a reference to a DELETED "
          "bead from a typo, it does not read commit messages, and it says nothing about "
          "whether a resolvable id is the RIGHT one -- an id that exists and is about "
          "something else reads identically to a correct citation. Nor does it compile "
          "anything: only import_check.py and lint_project.gd do that, and neither is "
          "parallel-safe.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
