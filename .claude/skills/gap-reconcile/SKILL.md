---
name: gap-reconcile
description: Decide whether an open [G-NNN] gap in log-devtools.md is still open, by opening the harness version installed on this machine rather than the one this project pins. Use at workflow step 4's reconcile bullet, before filing anything upstream, and whenever a gap's upstream issue has been closed.
---

# Reconciling a gap against the harness that actually exists

`python tools/gap_ledger.py --open` says which `[G-NNN]` gaps carry `open` as their last
status. That is a fact about **this file**, and the tool says so in its own words:

> NOT COVERED: this reads statuses, not the harness. It cannot tell you whether an open gap
> has since been FIXED upstream — that needs the installed version opened and the claim
> re-checked, which is the actual reconciliation work and is a human job.

This is that job. It exists as a skill because the loop has skipped it in a specific way:
the ledger's count is easy to read and easy to report, so "41 currently open" gets carried
into a cycle log unchallenged for cycles at a time. Meanwhile the project is pinned at
0.38.0 and the machine has 0.54.0 — **sixteen releases of fixes that no status line knows
about.**

## The version trap, first

Three versions are in play and confusing two of them is how a reconciliation goes wrong:

| Which | Where | What it tells you |
|---|---|---|
| **pinned** | `tools/lint_project.gd`'s `harness-version:` stamp | what your gates actually run |
| **installed** | `~/.claude/plugins/installed_plugins.json` → `installPath` | what a `/scaffold-godot-harness` refresh would bring |
| **the gap's own** | the `harness:` field on the `[G-NNN]` line | what it was observed against |

`python tools/devtools.py harness-version --client` prints the first and warns when the
second is newer. **Reconcile against the installed version**, because that is the code a
fix would arrive in — and say which version you checked, in the appended status line. A
status line that does not name a version cannot be re-reconciled by the next reader.

Note what this means for a pinned project: a gap can be **`fixed` upstream and still
biting you**, and that is not a contradiction. Record it as `fixed` with the version, and
let the pin bead carry the consequence.

## Procedure

1. **Take the open list, and take the ones with an `upstream:` field first.** A closed
   upstream issue is the strongest available signal and the cheapest to check. `gh issue
   list --repo <slug> --state all` gives you the states in one call.
2. **Open the installed source and look for the named thing.** Not the changelog, not the
   release notes, not the reference doc — those describe intent. Grep the template for the
   flag, verb or function the `Improvement:` line named.
3. **Read the code, not just the presence of the name.** This is the step that pays and it
   is the one that gets skipped. A flag can be parsed and ignored; a documented behaviour
   can be absent from the function that documents it. Cycle 88 checked
   `verify_ledger.py`'s reference block, which promises that `warranted` with no `checks`
   "is downgraded", then read `_reconcile_value` and found it returns the value unchanged
   with only a message. **The doc and the code disagreed in the current release**, which
   made the finding sharper than the one originally logged and turned a vague observability
   nit into a one-line defect with two line numbers.
4. **Append a new status line. Never edit the old one.** `gap_ledger.py` derives status
   from the LAST mention on purpose, and a gap fixed in cycle 88 legitimately still carries
   its cycle-70 `open` line as history. Rewriting history breaks the tool's whole model.

   ```markdown
     - [G-059] status: fixed | seen: 1 | harness: 0.54.0 | note: <what you found, where>
   ```
5. **Anything still open and now actionable in-project goes to step 6's refill** — as a
   bead, not as another log line. A gap that has been re-confirmed three times and never
   filed is a gap nobody is going to fix.

## The four verdicts

| Verdict | Means | Evidence required |
|---|---|---|
| `fixed` | the installed version does the thing | the file:line in the installed source that does it, and the version |
| `open` | re-checked, still absent or still wrong | what you grepped for and did not find, or the line that contradicts the doc |
| `wontfix` | the maintainer declined, or it was a misreading | the issue comment, or what you had misread |
| `superseded` | a later gap covers it better | the id that covers it |

**`open` needs evidence too.** "Still open" written without opening anything is the same
non-answer as the ledger's own count, and it costs the next reader the same lookup. Say
what you searched for.

## Do not file upstream before doing this

`skill-feedback-issue` says the same thing and says why — feedback from a stale install is
the most common false alarm in the loop. This skill is the half of that check specific to
the harness, where the gap ledger gives you a queue of candidates and the pinned-vs-installed
split guarantees that some of them are already dead.

Two things reconciliation regularly turns up that are worth expecting:

- **A gap fixed by a release you have not taken.** Common here, by design — the 0.38.0 pin
  is deliberate (gh#43 segfaults the suite).
- **A gap whose upstream issue is closed but whose fix is not what you asked for.** Check
  the code, not the issue state. A closed issue means the maintainer is done thinking about
  it, not that your `Improvement:` line landed.

## What this cannot tell you

Whether a gap is worth fixing. An accurately-`open` gap can be one nobody should build —
that is a judgement, it belongs in the bead, and mixing it in here means arguing about
priority while holding a table about facts.
