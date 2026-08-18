# `show_message` call sites: edge-triggered or level-triggered?

`plant-tower-defense-rqe7`. Audit only — no `game/` file was changed by it.

## The defect being swept for

`Hud.show_message` (`game/hud.gd:1885`) returns `false` when the row is still readable,
**but it queues the arriving text rather than dropping it**:

```gdscript
elif _message_left > MESSAGE_MIN_READABLE or priority < _message_priority:
    _queue_message(text, seconds, priority)
    return false
```

For an **edge-triggered** caller that is correct. `Game._on_flight_ignored` fires once per
winged pest crossing a Chomp's reach; a queued copy is the line it meant to post.

For a **level-triggered** caller it is not. Its condition is still true on the next call, so
a refused post is followed by another offer, stacking a second copy into the queue, then a
third, until `MESSAGE_QUEUE_MAX` (3) refuses the rest — a one-shot hint shown four times.

The question is a property of the **call site**, not of `show_message`. Hence this table.

## Denominator

`python tools/message_corpus_check.py` reports:

```
message_corpus_check: 42 .gd file(s) under game, 17 show_message() call site(s), 5 waived;
corpus declares 8 producer(s) and 6 literal(s); 0 finding(s) + 0 unpriced variant(s) +
0 dead producer(s)
```

**17, and I count the same 17** — all of them in `game/game.gd`. The 5 waived sites are
waived for the *corpus* rule (their text is assembled at runtime), which has nothing to do
with this audit; they are classified below like every other site.

### What that denominator does and does not cover

The checker's scope is *"call sites whose text must be priced in `Hud.message_corpus()`"*,
scanned as the literal token `show_message(` in comment-blanked source under `game/` only.
My question is different — *"call sites that can be refused"* — so I checked the ways the
two scopes could differ rather than inheriting its number on trust:

| Could it be missed? | Checked | Result |
|---|---|---|
| A site outside `game/` (the checker only walks `--sources game`) | grepped `show_message` across every `.gd` and `.tscn` in the repo | none outside `game/` except `test/` and doc comments |
| A call through `call("show_message")` / `callv` / a stored `Callable` | grepped `call("show`, `callv`, `Callable(` under `game/` | none; the only `.bind()` uses are button `pressed` connections |
| A second entry point into the queue that skips `show_message` | grepped every writer of `_message_text` / `_message_left` / `_message_queue` in `hud.gd` | `_queue_message` has exactly two callers, both inside `show_message`. `show_message` is the only door. |
| A `.tscn`-embedded script | grepped `.tscn` | none |

**The one thing that looks like an 18th site and is not:** `Hud._idle_message`
(`game/hud.gd:2012-2015`), set from `hud.refresh(state())` on the `_refresh` funnel. It is
genuinely level-triggered — but it is a plain **assignment**, never touches the queue, and
is therefore idempotent. It cannot stack, and it is the reason "level-triggered" alone is
not the defect; "level-triggered **through the queue**" is.

**What a search of this shape would still step over:** a site added in a file loaded at
runtime by path, or one built by string concatenation (`hud.call("show_" + "message", …)`).
Neither exists here, but neither would this method find it.

## The classification

Edge = fires from an event that happens once. Level = fires from a funnel (`_refresh`,
`_process`, a per-state-change path) where the condition can still be true on the next call.

| # | Site | Enclosing trigger | Class | Reason |
|---|---|---|---|---|
| 1 | `game.gd:246` | `bank.purchase_failed` lambda, wired in `_ready` | **EDGE** | One signal per failed purchase attempt; no attempt, no signal. |
| 2 | `game.gd:280` | `_ready` body | **EDGE** | Runs once per run, at startup. |
| 3 | `game.gd:453` | `_check_wave_cleared`, called from `_process` | **EDGE (latched)** | Per-frame path, but `if not _wave_live: return` guards it and `_wave_live = false` is set *before* the post. Self-clearing latch; the condition cannot survive to the next frame. |
| 4 | `game.gd:1332` | `_on_flight_ignored`, from `ChompFlower.flight_ignored` | **EDGE (latched)** | `ChompFlower._act` is per-frame, but `_flight_noted` (`chomp_flower.gd:272`) latches the emit and is cleared only when the condition goes false. One emit per stretch of being walked past. This is the site the bead names as correctly queueing. |
| 5 | `game.gd:1395` | `_maybe_teach_upgrading`, called from `_refresh` | **LEVEL — condition persists** | The one real case. See below. **Already fixed** by the `row_is_quiet()` guard at `game.gd:1390`. |
| 6 | `game.gd:1427` | `_on_plant_destroyed`, from `Plant.destroyed` | **EDGE** | `destroyed.emit(self)` fires once per plant, from the plant's own death. |
| 7 | `game.gd:1460` | `upgrade_selected`, the "costs %d seeds" refusal | **EDGE** | Reached only by the Upgrade button / an explicit call. No press, no message. |
| 8 | `game.gd:1470` | `upgrade_selected`, the success line | **EDGE** | Same trigger, and it follows a mutation (`plant.upgrade()`) that changes the state it was conditioned on. |
| 9 | `game.gd:1534` | `arm_uproot` | **EDGE** | Button press. `MESSAGE_DEADLINE` priority, deliberately. |
| 10 | `game.gd:1582` | `_tick_uproot_confirm`, called from `_process` | **EDGE (latched)** | Per-frame path, but `_disarm_uproot()` sets `_uproot_left = 0.0` *before* the post, and the guard `if _uproot_left <= 0.0: return` then returns on every later frame. Fires exactly once per expiry. |
| 11 | `game.gd:1660` | `_open_packet`, inside the flicker loop | **EDGE (burst)** | A bounded `PACKET_OPEN_STEPS` loop per packet bought, each step `await`ing its own duration so the previous line has expired. Not a funnel. |
| 12 | `game.gd:1670` | `_reveal_plant_unlock` | **EDGE** | Once per packet reveal. |
| 13 | `game.gd:1727` | `_unhandled_input`, mute SFX | **EDGE** | `event.is_action_pressed` — one keypress. |
| 14 | `game.gd:1731` | `_unhandled_input`, mute music | **EDGE** | Same. |
| 15 | `game.gd:1747` | `_unhandled_input`, colourblind toggle | **EDGE** | Same. |
| 16 | `game.gd:1890` | `_click_at`, husk composted | **EDGE** | One mouse click, and it follows `compost.collect_at` consuming the husk. |
| 17 | `game.gd:1907` | `_click_at`, placement refusal | **EDGE** | One mouse click. |

**Totals: 16 edge, 1 level.** Of the 16, four (#3, #4, #10, #11) sit on a per-frame or
looping path and are edge only because of an explicit latch — those are the ones worth
re-reading if any of those guards is ever touched.

## The one level-triggered site, and whether it still stacks

`_maybe_teach_upgrading` (`game/game.gd:1381`) is called from `_refresh` (`game.gd:1995`),
the funnel every purchase, uproot, plant death and wave change already runs through. Its
condition — the player holds at least what the cheapest upgrade on their board costs —
**stays true once true**. That is the full defect shape.

It **does not stack today**, because of the guard added by `-gz53`:

```gdscript
if not hud.row_is_quiet():
    return
```

The one-shot is spent on `show_message`'s return value, so a refresh that declines to offer
leaves the hint owed rather than burnt.

**No other call site needs this guard, and none should be given it.** For the other 16, a
queued copy is the line the caller meant to post; `row_is_quiet` there would silently drop
messages the player is owed. `row_is_quiet()` having exactly one caller is the correct
state, not an oversight — the audit's conclusion is that the count should stay at one.

## The measurement

Reading 17 call sites establishes intent. It does not establish that nothing stacks in a
run. Two tests were added at the end of `test/unit/test_placement.gd`:

- `test_a_realistic_run_refuses_no_messages_and_evicts_none` — drives a real `Game`
  through six placements, an upgrade, a refused upgrade, an armed-and-expired uproot and
  three waves, advancing the row's clock with explicit `_process(delta)` calls between
  beats, then reads `Hud.messages_refused` and `Hud.messages_evicted`.

- `test_row_is_quiet_is_what_stops_a_level_triggered_caller_stacking` — the control,
  in three parts: (1) the counter is driven to a known non-zero by hand, (2) an
  **unguarded** level-triggered caller is shown to stack copies on a busy row, (3) the
  **guarded** funnel is shown to queue nothing across six refreshes with the condition
  still true, and to leave the one-shot unspent.

Part (2) of the control is what makes a zero in the first test a result. `messages_refused`
counts only the terminal symptom — an arrival at a queue already holding
`MESSAGE_QUEUE_MAX` entries — so a zero could otherwise mean either "nothing stacked" or
"this counter never moves headlessly", which are different facts.

**These tests had not been executed at the time this document was written.** The lane that
wrote them was restricted to `python tools/check_all.py --quiet` and could not run
`run_tests.py`, `lint_project.gd` or the game. Their results are a prediction until the
suite runs.

## Two stale prose claims found on the way (findings, not edits)

Both are in `game/hud.gd`, which this audit does not own. Both are the
`scope-vs-claim` shape: a sentence that cannot fail, describing a set that has since moved.

- `game/hud.gd:1848` — *"All 22 call sites under `game/` ignore it"*. There are **17**, and
  the sentence is wrong twice over: two of them (`game.gd:1332`, `game.gd:1395`) read the
  return value into `var posted` and spend a one-shot on it, which is the entire reason the
  return value exists.
- `game/hud.gd:1924` — *"19 of the game's 22 `show_message` call sites pass no priority at
  all and therefore all tie"*. The real figures are **14 of 17** passing no priority. Exactly
  three pass one: `game.gd:1537` (`MESSAGE_DEADLINE`), `game.gd:1661` and `game.gd:1671`
  (both `MESSAGE_IMPORTANT`). The *argument* the sentence supports — that a tie is the
  common case, so the `>=` in `queue_outcome` matters more here than anywhere else —
  survives intact and is if anything slightly stronger; only the numbers are wrong.

Suggested edits are in the lane report for the parent to apply.
