---
name: ask-with-the-evidence
description: Exhaust the evidence already on disk before asking the user a question only they can answer, then ask once with that evidence attached. Use when a bead or task turns on a fact you cannot derive — where an asset came from, why a value was chosen, what a decision was for — and when you are about to write "unknown" into a document, a licence, or a close reason. Also use when a question to the user is about to be vague enough that any answer leaves you still guessing.
---

# Ask with the evidence

Some questions are genuinely the user's. Where an asset came from, what a magic
number meant, which of two designs was intended — no amount of reading resolves
those. The failure is not asking. The failure is **asking before looking**, which
produces a vague question, a vague answer, and a document that records a guess.

## The order

**1. Exhaust what the repo already knows.** Before the question exists in a form
worth asking:

- `git log --diff-filter=A -- <path>` — which commit introduced it, and what its
  message says. A single commit adding five files together is itself a fact.
- The bytes. Binary assets carry provenance far more often than people expect:
  Vorbis comments, ID3 frames, RIFF `LIST`/`INFO`, EXIF, PDF producer strings,
  font name tables. Read them; do not assume a file is opaque because it is
  binary.
- The neighbours. What do the files you are NOT asking about carry? That contrast
  is usually the whole finding — a set where thirteen files carry `ARTIST=Kenney`
  and two carry nothing is a much sharper question than "where did these come
  from".

**2. Form the question around what you found.** State the evidence, state what it
normally means, and ask whether that reading is right. The user is then correcting
a specific claim rather than recalling a fact from months ago.

**3. Offer the outcomes, including "I don't remember".** That is a real answer with
a real consequence, and it needs its own option — otherwise it arrives as free
text and you have to ask again.

## Then write the evidence down, not just the answer

This is the half that gets dropped, and it is the half that stops the question
recurring.

If a fact *looked* like something else, record what it looked like and why it is
not, **in the place the next person will be standing when they wonder**. Not in a
close reason, not in a commit message — in the document itself.

> Two audio cues carried `TITLE=place10` / `TITLE=place6` with batch gain tags and
> no artist, which is the ordinary fingerprint of a numbered sound pack. They were
> the owner's own take numbering. `License.txt` now quotes those exact tags beside
> the explanation, so `ogginfo` over that directory finds the answer rather than
> the question. Without that, the bead is refileable by anyone who looks.

## And ask whether a gate can hold the answer

An answer written in prose decays. If the fact you just established is one a tool
could re-check — every file is named, every credit is accounted for, every constant
is derived — that gate is usually small, and it is what makes the answer durable
rather than merely recorded. See `.claude/skills/house-static-checker/SKILL.md`.

## When NOT to use this

When the answer changes nothing you would do. Investigating provenance you will
not record, or asking about a preference where a sensible default exists, is just
a slower way to the same commit.
