# Enumerate the pairs

`derive-the-list` covers claims about a **set**: don't say "all the X do Y" from memory,
grep the X. This is the case one step up, where the claim is about a **relation between
members** of the set — who beats whom, who reads whose output, which combination is legal.
There the members are not the unit of evidence. **The pairs are.**

Three worked examples feel like coverage and are not, for a reason that is arithmetic
rather than diligence: a set of *n* members has *n²* ordered pairs, and the examples people
write are the ones they were thinking about when they wrote the code. The pair nobody
thought about is exactly the pair the next change lands on.

## When this applies

The tell is a claim or a test whose subject is a comparison, an ordering, or an
interaction:

- a priority ladder, a precedence rule, a z-order, a tie-break
- "this overrides that", "the later one wins", "equal ones queue"
- a conversion or compatibility matrix — which formats read which
- a state machine's transitions, when the interesting part is which are *refused*

If you can phrase the thing as "when A meets B, B wins", it has pairs, and one example
tells you about one cell.

## The procedure

1. **Get the members from the source, not from memory.** That is `derive-the-list`, and it
   is a prerequisite: an enumeration over the wrong set is worse than an example, because
   it looks exhaustive.
2. **Write the loop over the cross product, not the cases.** `for a in members: for b in
   members:`. The point is that adding a member to the list extends the table for free —
   and a member added *without* extending the list is the thing you want to fail.
3. **Compute the expectation, do not tabulate it.** `winner = b if rank(b) > rank(a) else a`
   is the rule under test stated once; a hand-written 3×3 answer key is a second
   implementation that can drift from the first. If the rule cannot be stated as an
   expression, that is itself a finding about the rule.
4. **Assert both halves at every pair.** In this project's message queue: *who is on the
   row*, and *the loser was deferred rather than dropped*. The second half is the one a
   screenshot cannot distinguish and the one an example test usually omits.
5. **Guard the denominator.** Assert the member count first, with a message that says what
   to do — `"three rungs -- add the new one to this list or the table is a subset"`. A
   cross-product loop over a stale list passes beautifully.
6. **Then mutate.** Break the comparison and confirm the table goes red at the pair you
   expect. A table that has never been watched fail is a table you have not read.

## What it caught here

**Cycle 69, the message-row priority ladder.** Two example tests existed —
`test_an_important_message_is_not_wiped_by_an_ambient_one` and
`test_an_important_message_can_cut_an_ambient_one_short` — and both were correct. Adding a
third rung (`MESSAGE_DEADLINE`) created six new ordered pairs, and the one that mattered,
DEADLINE arriving onto IMPORTANT, was a combination no existing test named. The table
version (`test_a_higher_rung_pre_empts_and_every_other_pair_waits`) covers all nine, is
shorter than a third example would have been, and fails the moment a fourth rung is added
without being listed.

**Cycle 68, the drawn-overlay grammar** — the same rule one level down, on prose. A kanban
entry claimed four cues shared a vocabulary; deriving it from all 55 `draw_` calls found one
of the four rules violated twice, once by a cue written two cycles earlier. That is why the
workflow now says a pattern claim needs the enumeration, not an example.

## What it does not fix

**An enumeration proves the rule is applied uniformly, not that the rule is right.** All
nine pairs of a bad ladder pass a table built from that ladder. Correctness of the ordering
itself is a design question — for the message row it was answered separately, by asking what
each message's `seconds` were tied to, and finding one whose subject was already counting
down elsewhere. The table could not have found that; only reading the three call sites did.

Related: [[derive-the-list]] for getting the member list honestly, and
[[house-static-checker]] for the mutation discipline step 6 borrows.
