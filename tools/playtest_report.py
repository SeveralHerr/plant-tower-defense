#!/usr/bin/env python3
"""playtest_report.py - reads a playtest record back and prints the table a balance pass
actually reads.

WHY THIS EXISTS (plant-tower-defense-t5yy.4).

The request was to "use the logs & metrics to determine if any balancing is needed". Half
of that is a gate and lives in `test_dir`. This is the other half, and it is deliberately
not a gate: a green suite says no rule was broken, and cannot say wave 14 is boring, that
the Aloe is never worth buying, or that harsh and standard play identically. Those are
judgements a person makes from numbers, and until `tools/playtest.gd --out` there were no
numbers that survived the run that produced them -- the only `FileAccess.open` calls under
`game/` are the save reader and the save writer.

WHICH GATE WOULD HAVE CAUGHT THIS AND WHY IT DOES NOT. None -- this is a record, not a
defect class. What it *does* gate is the record's own integrity, and there the precedent
is exact: `tools/run_json_check.py` exists because `verify_ledger.py record` builds its
row from a fixed set of key lookups and **silently ignores every other key**, so a
plausible-but-wrong name produced a well-formed row that under-reported a clean run. A
balance baseline has that failure available to it and would express it as a table quietly
describing less than it appears to. So an unrecognised key here is a FINDING, not a shrug.

DERIVED, NOT RESTATED. The wave-row schema is read out of `RunSim.RECORD_KEYS` and the
plant list out of `PlantCatalog.ORDER`. A column added to the driver reaches this reader
the same day; a plant no run has ever unlocked shows as NEVER instead of vanishing from a
list built by looking at what the record happens to contain.

Exit: 0 clean | 1 findings | 2 could not run.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import tempfile

DEFAULT_PATH = os.path.join("docs", "playtest-runs.jsonl")

RUN_SIM = os.path.join("tools", "run_sim.gd")
CATALOGUE = os.path.join("game", "plant_catalog.gd")

RECORD_KEYS_RE = re.compile(r"const\s+RECORD_KEYS\s*:[^=]*=\s*\[(.*?)\]", re.S)
CONST_RE = re.compile(r'^const\s+([A-Z_][A-Z0-9_]*)\s*:=\s*&"([^"]+)"', re.M)
ORDER_RE = re.compile(r"^const\s+ORDER\s*:[^=]*=\s*\[(.*?)\]", re.M | re.S)

# The five keys that identify which run a row belongs to. Written on EVERY row by
# `playtest.gd._collect_jsonl` so a single grepped line is readable without a join.
#
# `policy` IS PART OF THE IDENTITY, not decoration (plant-tower-defense-i8oh). The same
# difficulty on the same seed reaches wave 7 under `greedy` and far past it under
# `thicken`, so two runs that differ only in policy are two different runs -- and without
# this key they would collide into one, `cross_check` would report "two 'run' rows", and a
# table holding both ends of the skill range would be unreadable.
RUN_KEYS = {"difficulty", "endless", "seed", "swept", "policy"}

SUMMARY_EXTRA = {"kind", "ended", "failure", "waves_played", "waves_attempted",
                 "foreign_pests", "foreign_plants"}


def record_keys(path=RUN_SIM):
    """`RunSim.RECORD_KEYS` as a set, or (None, reason)."""
    try:
        source = io.open(path, encoding="utf-8").read()
    except OSError as exc:
        return None, "could not read %s (%s)" % (path, exc)
    found = RECORD_KEYS_RE.search(source)
    if not found:
        return None, "no `const RECORD_KEYS` array in %s" % path
    keys = set(re.findall(r'&"([^"]+)"', found.group(1)))
    if not keys:
        return None, "`RECORD_KEYS` in %s parsed to nothing" % path
    return keys, ""


def catalogue_ids(path=CATALOGUE):
    """The plant ids `PlantCatalog.ORDER` names, in its order, or (None, reason)."""
    try:
        source = io.open(path, encoding="utf-8").read()
    except OSError as exc:
        return None, "could not read %s (%s)" % (path, exc)
    literals = dict(CONST_RE.findall(source))
    order = ORDER_RE.search(source)
    if not order:
        return None, "no `const ORDER` array in %s" % path
    ids, unknown = [], []
    for name in [n.strip() for n in order.group(1).replace("\n", " ").split(",")]:
        if not name:
            continue
        if name in literals:
            ids.append(literals[name])
        else:
            unknown.append(name)
    if unknown:
        return None, 'ORDER names %s, which have no `const X := &"..."` in %s' % (
            ", ".join(unknown), path)
    return ids, ""


def run_id(row):
    return (row.get("difficulty"), bool(row.get("endless")), row.get("seed"),
            bool(row.get("swept")), row.get("policy"))


def label(rid):
    difficulty, endless, seed, swept, policy = rid
    return "%s/%s/%s/%s/seed %s" % (difficulty, policy,
                                    "endless" if endless else "campaign",
                                    "swept" if swept else "unswept", seed)


def load(path, wave_keys):
    """Returns (waves, summaries, findings) or raises OSError."""
    wave_required = RUN_KEYS | {"kind"} | wave_keys
    summary_required = RUN_KEYS | SUMMARY_EXTRA
    waves, summaries, findings = [], [], []
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except ValueError as exc:
                findings.append("%s:%d is not JSON: %s" % (path, number, exc))
                continue
            if not isinstance(row, dict):
                findings.append("%s:%d is not an object" % (path, number))
                continue
            kind = row.get("kind")
            if kind == "wave":
                expected = wave_required
                waves.append(row)
            elif kind == "run":
                expected = summary_required
                summaries.append(row)
            else:
                findings.append("%s:%d has kind %r -- known kinds are 'wave' and 'run'"
                                % (path, number, kind))
                continue
            # BOTH DIRECTIONS. A missing key makes the table lie by omission; an
            # unrecognised one means the driver and this reader have drifted and the
            # column it carries is being dropped silently -- the run_json_check failure,
            # arriving through the front door.
            for key in sorted(expected - set(row)):
                findings.append("%s:%d (%s) is missing key %r" % (path, number, kind, key))
            for key in sorted(set(row) - expected):
                findings.append(
                    "%s:%d (%s) carries unrecognised key %r -- this reader would drop it "
                    "silently, so it is reported instead" % (path, number, kind, key))
    return waves, summaries, findings


def cross_check(waves, summaries):
    findings = []
    by_run = {}
    for row in waves:
        by_run.setdefault(run_id(row), []).append(row)
    seen = set()
    for row in summaries:
        rid = run_id(row)
        if rid in seen:
            findings.append("two 'run' rows for %s -- a run is written once" % label(rid))
        seen.add(rid)
        counted = len(by_run.get(rid, []))
        if int(row.get("waves_played", -1)) != counted:
            findings.append("%s says waves_played=%s and the file carries %d wave row(s)"
                            % (label(rid), row.get("waves_played"), counted))
        if str(row.get("failure", "")):
            findings.append("%s stopped on a DRIVER failure, not a game one: %s"
                            % (label(rid), row.get("failure")))
        # The contamination census. `RunSim` takes it at the start of `play()`, and
        # `playtest.gd` prints it to stderr -- which does not survive into a committed
        # baseline. A run that began with a previous run's plants still standing measured
        # a garden nobody built, and every number in it is describing that garden.
        strays = int(row.get("foreign_pests", 0)) + int(row.get("foreign_plants", 0))
        if strays:
            findings.append(
                "%s began with %s foreign pest(s) and %s foreign plant(s) already in the "
                "tree -- it measured a garden it did not build, so every number in it is "
                "suspect" % (label(rid), row.get("foreign_pests"),
                             row.get("foreign_plants")))
    for rid in by_run:
        if rid not in seen:
            findings.append("%s has wave rows and no 'run' row -- the sweep was "
                            "interrupted, or the file was concatenated" % label(rid))
    return findings


def by_run_map(waves):
    out = {}
    for row in waves:
        out.setdefault(run_id(row), []).append(row)
    return out


def print_report(waves, summaries):
    print("")
    print("RUNS")
    print("  %-42s %-10s %6s %7s %8s %8s" % ("run", "ended", "waves", "lives", "earned",
                                             "plants"))
    for row in sorted(summaries, key=lambda r: label(run_id(r))):
        rows = sorted(by_run_map(waves).get(run_id(row), []),
                      key=lambda r: int(r.get("wave", 0)))
        last = rows[-1] if rows else {}
        print("  %-42s %-10s %6s %7s %8s %8s" % (
            label(run_id(row)), row.get("ended"), row.get("waves_played"),
            last.get("lives_end", "-"), last.get("seeds_earned", "-"),
            last.get("plants_alive", "-")))

    for rid, rows in sorted(by_run_map(waves).items(), key=lambda kv: label(kv[0])):
        rows = sorted(rows, key=lambda r: int(r.get("wave", 0)))
        print("")
        print("  %s" % label(rid))
        print("    %4s %4s %-8s %6s %7s %7s %6s %6s %6s %7s %7s"
              % ("wave", "lvl", "weather", "spawn", "killed", "escape", "lives",
                 "earned", "idle", "plants", "lost"))
        for row in rows:
            print("    %4s %4s %-8s %6s %7s %7s %6s %6s %6s %7s %7s" % (
                row.get("wave"), row.get("threat_level"), row.get("weather"),
                row.get("spawned"), row.get("killed"), row.get("escaped"),
                row.get("lives_end"), row.get("seeds_earned"), row.get("seeds_end"),
                row.get("plants_alive"), row.get("plants_lost")))


def print_income(waves):
    """Where the seeds came from and where they went, summed per run.

    The split is the whole reason this record is worth committing: "the run earned 3453"
    is a number, and "40% of it was husks the policy happened to sweep" is a balance
    reading. `RunSim` records the three sources separately; nothing else in the repo does.
    """
    print("")
    print("INCOME AND SPEND, summed over each run")
    print("  %-42s %8s %8s %8s %10s %9s" % ("run", "kills", "growth", "husks",
                                            "on plants", "on packets"))
    for rid, rows in sorted(by_run_map(waves).items(), key=lambda kv: label(kv[0])):
        def total(key):
            return sum(int(r.get(key, 0)) for r in rows)
        print("  %-42s %8d %8d %8d %10d %9d" % (
            label(rid), total("seeds_from_kills"), total("seeds_from_growth"),
            total("seeds_from_husks"), total("seeds_spent_plants"),
            total("seeds_spent_packets")))


def print_unlocks(waves):
    by_run = by_run_map(waves)
    first_seen = {}
    for rows in by_run.values():
        held = {}
        for row in sorted(rows, key=lambda r: int(r.get("wave", 0))):
            for plant in row.get("unlocked", []):
                held.setdefault(plant, int(row.get("wave", 0)))
        for plant, wave in held.items():
            first_seen.setdefault(plant, []).append(wave)

    ids, reason = catalogue_ids()
    print("")
    print("UNLOCK PACING -- the wave by which a run is HOLDING each plant, over %d run(s)"
          % len(by_run))
    print("  %-18s %6s %6s %6s %6s" % ("plant", "runs", "best", "median", "worst"))
    for plant in (ids if ids is not None else sorted(first_seen)):
        held = sorted(first_seen.get(plant, []))
        if not held:
            print("  %-18s %6d %6s %6s %6s   NEVER unlocked in any run" % (plant, 0, "-", "-", "-"))
            continue
        print("  %-18s %6d %6d %6d %6d" % (plant, len(held), held[0],
                                           held[len(held) // 2], held[-1]))
    if ids is None:
        print("  NOTE: the plant list above came from the RECORD, not the catalogue -- %s. "
              "A plant no run ever unlocked cannot appear in it." % reason)
    else:
        extra = sorted(p for p in first_seen if p not in ids)
        if extra:
            print("  NOTE: %s appear in the record and not in PlantCatalog.ORDER -- the "
                  "record is older than the catalogue, or a plant was renamed."
                  % ", ".join(extra))


def self_check():
    """Feeds the reader a row it must reject, and fails if it does not.

    A checker nobody has watched fail is a checker nobody knows works. The bad row is the
    exact shape this file exists for: valid JSON, a known kind, every required key
    present, and one extra column a drifted driver added -- the case that reads as
    perfectly clean to a reader that only looks for what it already knows.
    """
    keys, reason = record_keys()
    if keys is None:
        print("self-check could not run: %s" % reason, file=sys.stderr)
        return 2
    good = {k: 0 for k in keys}
    good.update({"kind": "wave", "difficulty": "standard", "endless": False, "seed": 1,
                 "swept": True, "policy": "greedy", "weather": "clear", "unlocked": []})
    bad = dict(good)
    bad["seeds_wasted"] = 3
    handle, path = tempfile.mkstemp(suffix=".jsonl")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as out:
            out.write(json.dumps(good) + "\n")
            out.write(json.dumps(bad) + "\n")
        _, _, findings = load(path, keys)
    finally:
        os.unlink(path)
    if any("is missing key" in f for f in findings):
        print("self-check FAILED: a row carrying every RECORD_KEYS column was reported "
              "incomplete -- the schema this reader derives does not match the driver's.",
              file=sys.stderr)
        return 1
    if not any("seeds_wasted" in f for f in findings):
        print("self-check FAILED: an unrecognised key was accepted silently, which is the "
              "one thing this reader exists to refuse.", file=sys.stderr)
        return 1
    print("self-check: 2 synthetic rows over %d RECORD_KEYS -- the good one accepted, the "
          "one carrying 'seeds_wasted' rejected." % len(keys))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", default=DEFAULT_PATH)
    parser.add_argument("--self-check", action="store_true",
                        help="prove the reader can fail, on a synthetic bad row")
    args = parser.parse_args()

    if args.self_check:
        return self_check()

    keys, reason = record_keys()
    if keys is None:
        print("playtest_report: %s -- the wave schema is read from the driver, so nothing "
              "could be checked." % reason, file=sys.stderr)
        return 2
    if not os.path.exists(args.path):
        print("playtest_report: no record at %s -- run `godot --headless --path . --script "
              "res://tools/playtest.gd -- --out %s` first. Nothing was checked."
              % (args.path, args.path), file=sys.stderr)
        return 2
    try:
        waves, summaries, findings = load(args.path, keys)
    except OSError as exc:
        print("playtest_report: could not read %s: %s" % (args.path, exc), file=sys.stderr)
        return 2

    findings += cross_check(waves, summaries)

    if summaries or waves:
        print_report(waves, summaries)
        print_income(waves)
        print_unlocks(waves)

    difficulties = sorted({str(r.get("difficulty")) for r in summaries})
    policies = sorted({str(r.get("policy")) for r in summaries})
    modes = sorted({"endless" if r.get("endless") else "campaign" for r in summaries})
    seeds = sorted({r.get("seed") for r in summaries})
    print("")
    print("playtest_report: %d run(s) over %d wave row(s) from %s, against %d RECORD_KEYS "
          "read from %s; %d difficulty (%s) x %d policy (%s) x %d mode (%s) x %d seed(s); "
          "%d finding(s)"
          % (len(summaries), len(waves), args.path, len(keys), RUN_SIM,
             len(difficulties), ", ".join(difficulties),
             len(policies), ", ".join(policies),
             len(modes), ", ".join(modes), len(seeds), len(findings)))
    if not summaries:
        print("NOTE: nothing to report -- the record holds no completed run. That is a "
              "clean result only if you expected none; a sweep that aborted before "
              "writing anything leaves a file exactly like this one.")
    for finding in findings:
        print("  FINDING: %s" % finding)

    print("NOT COVERED: this reads a record; it does not play the game and it judges "
          "nothing. No threshold here says a wave is too hard, an unlock too late or a "
          "difficulty indistinguishable from the one below it -- those are "
          "plant-tower-defense-t5yy.2 and .3, and until they exist the tables above are "
          "read by a person. Every number is a statement about the POLICY that produced "
          "it and not about the game, which is why `policy` is part of a run's identity "
          "here: `RunSim.greedy_cover` stops planting once the road is covered and "
          "`RunSim.thicken_cover` keeps going, and on one seed those two reach different "
          "waves -- so read a depth here as a statement about one policy, never as the "
          "curve. The unlock table is the wave a run was HOLDING a plant, at best one "
          "prep window after it could first have afforded it. It cannot tell a stale "
          "record from a fresh one, so re-sweep before believing a number against a "
          "balance edit. And it only knows the keys the driver declares: a column that "
          "changes MEANING while keeping its name reads as clean here.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
