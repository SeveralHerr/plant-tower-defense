---
name: measure-a-balance-change
description: Verify a tuning edit by playing the game before and after on the same seeds, instead of trusting the arithmetic. Use when changing a rate, a chance, a price, a multiplier, an interval or a wave table; when a comment says a constant was "priced against a run"; and whenever two constants were tuned together so that moving one alone changes the mechanic's whole cost. Also use when the only evidence a balance edit works is that its own bounds test still passes.
---

# Measure a balance change, do not compute it

A tuning edit's own test grades the ARITHMETIC. `test_a_sport_is_rare_enough_to_stay_an_event`
reads `CrossBreeder.mean_seconds_between()` and asserts it lands between 90 and 600 seconds
— which is a statement about dividing one constant by another, and would pass identically
if nothing in the game ever read either of them. What a player meets is a count per run,
and the two are not the same number: the mean assumes the mechanic is always eligible to
fire, and a real garden spends most of a campaign not holding a matching pair.

So run the game.

## The A/B

`tools/playtest.gd` plays whole campaigns headless, deterministically, and appends one
JSONL record per wave and per run. Same seeds both sides; the only variable is the diff.

```bash
GODOT=$(python -c "import json;print(json.load(open('tools/gates_config.json'))['godot_bin'])")
"$GODOT" --headless --path . --script res://tools/playtest.gd -- \
    --seeds 6 --policy thicken --out .gates/pt_new.jsonl
```

Then the same command in a checkout without the change — an agent worktree at
`.claude/worktrees/<lane>/` is exactly this, so run one side in the lane and one in the
parent. Sum the metric out of the JSONL:

```python
import json, io
total = sum(int(json.loads(l)["plants_sported"])
            for l in io.open(".gates/pt_new.jsonl", encoding="utf-8")
            if l.strip() and json.loads(l).get("wave") is not None)
```

MEASURED 2026-08-29 (plant-tower-defense-cbbi): dropping `CHANCE_PER_TICK` from 0.04 to
0.025 gave **14 sports against 20** over six identical-seed thicken campaigns — 0.70x,
where the constants alone predict 0.625x. Both numbers are right; they answer different
questions, and only the first one is about the game.

**Pick the policy that exercises the mechanic.** `--policy thicken` keeps planting after
the road is covered, so it grows the adjacent same-kind pairs cross-breeding needs;
`--policy greedy` stops at coverage and would have shown almost nothing. A metric that
comes back near zero on both sides has measured the policy, not the change.

**`RunSim.RECORD_KEYS` is the list of what you can measure**, and it is the only place that
list is written down — `plants_sported`, `seeds_earned`, `lives_end`, `killed`, `escaped`
and the rest. Read it rather than guessing a key name.

## Two constants tuned together are one decision

The commonest shape of a balance bead: a rate and a magnitude that were priced against each
other. Frequent-and-small and rare-and-large are both coherent; frequent-and-large is a
different game. Moving one and leaving the other is how a mechanic's total cost to the
economy silently doubles while every existing test stays green, because each test grades
its own half.

- Find the other half before editing either. It is usually named in the comment: "priced
  against a run", "deliberately small", "tuned against". Grep the constant's readers.
- Say the product out loud in the commit message. "About two thirds as frequent and roughly
  half again as strong, so it costs the economy about what it did" is a claim someone can
  check; "lowered the chance" is not.
- **Add the test for the half that has none.** Here the seconds band graded frequency and
  nothing at all graded SIZE, so a later hand could walk the size back and leave every test
  passing. That test is the deliverable, as much as the new numbers are.

## Check the floors and ceilings the new value now sits near

A multiplier feeds clamps elsewhere, and a clamp is the worst place for a shipped value to
land: once the value is at the bound, the clamp produces the answer, every "is the sport
better?" test still passes, and the **next** increase does nothing at all. Silent, and it
looks exactly like working code.

Grep the constant's readers for `clampf`, `maxf`, `minf`, `MIN_`, `MAX_`. For each, assert
the shipped result is **strictly inside** the bound *and* equal to the unclamped
arithmetic — the second half is what stops a value that is only inside because the clamp
put it there. `test_the_tar_sundews_hold_is_inside_its_own_clamp_and_not_resting_on_it` is
the worked example.

## Then run the standing sweep

`test/unit/test_playtest_sweep.gd` is part of the ordinary suite and is what catches a
board made unwinnable, trivially winnable or unlosable. It is not optional after a balance
edit; see `docs/playtest-sweep.md`. The A/B above tells you the change happened and by how
much — the sweep tells you the game still is one.
