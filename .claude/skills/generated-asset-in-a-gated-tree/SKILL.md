---
name: generated-asset-in-a-gated-tree
description: Add machine-generated files to a repo whose gates were written for hand-authored ones — which contract rows to derive instead of typing, how to widen a palette or allow-list for the generated set only, and why the generator itself must be a checker. Use when a feature would mean writing N near-identical assets by hand (recolours, variants, per-locale or per-difficulty copies), when a hand-maintained contract table is about to grow by more than two or three mechanical rows, and when a generated file first fails a gate that every hand-made sibling passes.
---

# Adding generated files to a tree whose gates assume hand-authored ones

The move is: **derive the asset, derive its contract rows, and scope any widened rule to
the generated set alone.** Each of those three has a specific failure that looks like
success, and the third is the one that quietly costs the most.

Worked instance throughout: `plant-tower-defense-bsxh` added 17 mutant plant sprites
(`art_src/*_sport.svg`), each a recolour of a parent, into a tree gated by
`test/unit/test_sprite_style.gd`, `tools/svg_style_check.py` and `art_src/STYLE.md`.

## 1. Derive the asset so the gates come for free

Copy everything you are not changing, **byte for byte**. A sport SVG has its parent's
geometry verbatim and differs only in paint, and that single decision bought every
geometric clause of the contract at once — canvas size, retina doubling, bilateral
centring, in-canvas bounds all hold for the generated file *because* they hold for the
parent, with nothing asserted and nothing to re-check. What is left is exactly the axis you
actually changed, and that is the only thing left to get right.

The corollary: **if the generator has to touch geometry, it is not a variant generator any
more** and the whole argument above evaporates. Push the geometry change into the parent.

## 2. Derive the contract rows too — but only where the parent already vouches

The gate had a hand-declared `EXPECTED_SIZE`, one row per drawing, and its point is that an
undeclared source is a failure rather than a silence. Seventeen mechanical rows whose only
content is "the parent's, again" would be seventeen chances to claim a canvas nobody drew.

So the table grew a derived companion instead:

```gdscript
func _declared() -> Dictionary:
	var out: Dictionary = EXPECTED_SIZE.duplicate()
	for stem: String in EXPECTED_SIZE:
		var sport: String = stem + SPORT_SUFFIX
		if _svg_stems().has(sport):
			out[sport] = EXPECTED_SIZE[stem]
	return out
```

Two properties make this safe rather than a loophole, and check yours has both:

- **The derivation is gated on the PARENT's declaration.** `foo_sport.svg` beside no `foo`
  row is still undeclared and still fails. You have not removed the requirement, you have
  said who satisfies it.
- **Something else owns "which generated files may exist".** Here that is the generator's
  own check, which fails when the set on disk is not exactly the set its derivation
  produces. Without that, deriving the rows means nobody is asking the question at all.

Every parallel reader needs the same derivation. `svg_style_check.py` regex-reads
`EXPECTED_SIZE` out of the gate script, so it had to learn the same rule — and its first
version derived `<stem>_sport` for *every* stem, which invented sports for the five pests
and two projectiles and reported seven files that will never exist. Gate the derivation on
the generated file actually being on disk, exactly as the GDScript side does.

## 3. Scope the widened rule to the generated set — never widen the shared one

This is the expensive one. The mutant sprites need 16 colours the kit palette does not
carry. Adding them to `PALETTE` is one line, and it is wrong: it is 16 more colours every
*hand-drawn* sprite may also use, and because conformance is "within tolerance of the
segment between two palette entries", it is many hundreds more legal pair-segments through
the middle of the colour space. The 34 sprites the gate was written for would be held to a
materially weaker contract, forever, as a side effect of a feature about nine other files.

Instead: a second constant, handed out by stem.

```gdscript
func _palette_rgb(stem: String) -> Array[Vector3]:
	var out := <PALETTE as RGB>
	if not stem.ends_with(SPORT_SUFFIX):
		return out
	return out + <MUTANT_PALETTE as RGB>
```

**Scope every arm of the rule the same way.** The palette check had two arms — literal
membership, and distance-to-a-blend — and the first draft scoped only the second. Result:
102 warnings saying "this colour is not verbatim palette" about colours that were verbatim,
which is the warning becoming noise for exactly the sprites it was written to protect.

Ask, before widening anything shared: *what does this cost the files that were already
passing?* If the answer is anything but "nothing", scope it.

## 4. The generator is a checker, and its default must not write

A derived file is a claim — "this is a function of that" — and nothing in a normal gate can
see it. A hand-edited variant that used legal colours is a perfectly conformant asset; the
raster gate, the source linter and the compiler all pass it. The only thing that can catch
the drift is re-running the derivation and diffing.

So the generator owes a `NOT COVERED:` line and the exit-code contract like any house
checker (`.claude/skills/house-static-checker`), plus one rule that skill now states and
this is where it came from: **`check_all.py` runs every `tools/*.py` with a contract line
bare and in parallel**, so a generator that writes by default rewrites its committed output
during somebody's routine sweep. The check is the default; `--write` is the flag.

Check both directions of every constant the generator shares with a gate. Here the ramps
live in Python and `MUTANT_PALETTE` lives in GDScript; the generator parses the gate's copy
and fails when they disagree, which caught a real desync the moment a ramp anchor changed.

## 5. Expect the second reader to refuse what the first accepted

A generated file goes through more parsers than a hand-made one, and they do not agree.
Two from this instance, both invisible until the second reader ran:

- The generated banner comment named a `--check` flag. `--` is illegal inside an XML
  comment. **Godot's SVG loader accepted all 17 files and rendered them; ElementTree
  refused all 17.** Neither reader is wrong; the file was malformed and one of them cared.
- A ramp's palest rung came out at saturation 0.090, under the linter's 0.12 grey
  threshold, so a saturated rim around it tripped "coloured outline on a grey fill" on five
  shapes of one sprite. A generated palette has to satisfy rules written about hand-picked
  colours, including the ones nobody states as numbers.

Run **every** reader before believing the output, and when one refuses what another
accepted, that disagreement is the finding.

## 6. What no gate can see: the distance between two colours

The gates ask *is this value legal*. They never ask *is this value the right distance from
that one*. The first mapping normalised each colour family against that sprite's own
luminance range, which fans a bunched family across the whole ramp — two leaf greens 14
luminance apart in a drawing spanning 53 landed on rungs 5 and 7 of 8, and the plant grew
one dark leaf and one nearly white one. `svg_style_check` reported 0 errors. All 11 raster
gate tests passed. It was visible in the first screenshot and nowhere else.

**Budget one look at the rendered result, and look at it beside the original.** For a
variant generator specifically, prefer a rule that preserves the parent's relationships
(here: each colour takes the ramp rung nearest its own luminance, so the variant is as
bright, in the same places, as its parent and only the hue moved) over one that
redistributes them.

## Checklist

- [ ] Generated file copies everything it is not changing, verbatim.
- [ ] Contract rows derived from the parent's, gated on the parent having one AND on the
      generated file existing.
- [ ] Every reader of that contract taught the same derivation.
- [ ] Any widened rule scoped to the generated set, on **every** arm of that rule.
- [ ] Generator has the checker contract; a bare run checks, `--write` writes.
- [ ] Shared constants checked in both directions.
- [ ] All readers run, and disagreements treated as findings.
- [ ] One look at the rendered output, beside the original.
