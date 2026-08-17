# Cycle 60

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 60 taught

**Teaching a one-time lesson in a recurring message is a permanent tax, and the budget put
a number on it.** The armed uproot prompt now points at the move preview — "Hover to
compare a new spot" — which is what the feature needed, since the only previous hint said
"Really uproot?", the opposite of what it does.

It cost **185 px of the message row's 306 px of headroom**, every uproot, forever, to teach
something once. `cmd budgets` went 570 → 784 of 876 and flipped to state `tight`;
shortening the tip brought it to 755, leaving 121 against a declared floor of 40. It
passes, so shipping it was right — but the measurement is what turns "a one-shot hint would
be nicer" into a costed argument, and `RunConfig`'s milestone set is already a persisted
seen-once mechanism, so the fix needs no save-version bump.

**The wording is a comparison, not a promise.** Confirming still only uproots; whether a
move should be one action, and what it should cost, is undecided (`-h5w6`). A prompt
offering something the game cannot do would be worse than the silence it replaced.

**And running `findings` for the first time in twelve cycles found that the UI baseline is
gone**, so every `ui_layout` finding has been gating as NEW for an unknown stretch. That is
this cycle's workflow change: if the game was launched at all, run `findings` before
quitting it. Twelve cycles of runtime work went past on hand-picked reads, each answering
the question I already had — which is exactly the coverage a checklist of known failure
modes exists to replace.

## Where things stand

Seventy-five beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **561/561**, 12268 assertions; lint 0/0; nine checkers clean; save md5
unchanged. Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

Two, and the second is new:

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview now shows a player exactly what
repositioning would do, and the game then charges full price to act on it. Free moves make
placement mistakes costless; full price makes the preview cruel; refund-minus-cost is the
middle and is already computed.

Best buildable item is **`-23fa`**: show the move tip once instead of on every uproot, which
returns 185 px to the row and makes the hint more likely to be read, since a message that
appears once is not wallpaper.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
findings baseline **no longer exists** (`-v9px`) — until it is re-captured, every
`ui_layout` finding gates as NEW. Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. And **`pause` right after `launch`**, remembering it
is a tool and a hazard in one command: this cycle it froze a panel mid-fade and produced
four findings that vanished on unpause.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (`-a6bq` is filed to re-read
them all); `list-commands --offline` answers "does this verb exist" with no game running.
Bump the number at the top of this file every time you refill.
