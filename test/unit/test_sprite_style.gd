extends RefCounted

## Turns art_src/STYLE.md from a document into a gate.
##
## The style contract was measured out of the Kenney "Tower Defense" kit (all 299
## sprites are 64x64; the outline is always a darker shade of the fill; the palette
## is fixed). A sprite that drifts off it still loads, still draws, and looks
## subtly foreign next to the kit — nothing else in the project would notice.
##
## It also asserts that the PNGs it reads CAME FROM the SVGs in art_src/. For a long
## time it did not: this file read only `assets/sprites/*.png` against the hand-written
## EXPECTED_SIZE table below, and `tools/svg_style_check.py` read only `art_src/*.svg`,
## so the two sprite gates shared no artefact and a stale render passed both — edit an
## SVG, forget to run `tools/render_svg.gd`, and everything stayed green over a PNG that
## no longer matched its source. mtime cannot answer that (a fresh clone or a branch
## switch stamps every file with the checkout time in arbitrary order, which would
## report a perfectly in-sync tree as entirely stale), so what is asserted instead is a
## property that is DERIVED rather than recorded: render_svg.gd rasterises with
## `load_svg_from_buffer(bytes, scale)`, so a PNG's pixel dimensions are its source's
## declared canvas times the scale. A disagreement is proof, needs no manifest and no
## build step, and cannot be forgotten. See test_rendered_png_matches_its_svg_source_size.
##
## Run: godot --headless --path . --script res://tools/run_tests.gd -- --file test_sprite_style.gd

const SPRITE_DIR := "res://assets/sprites"
const RETINA_DIR := "res://assets/sprites/retina"

## The authored SVG sources. art_src/ carries a .gdignore so nothing in it is imported
## as a texture — which is why render_svg.gd reaches it through the globalised project
## path rather than through res://, and why this file does the same.
const SRC_SUBDIR := "art_src"

## name -> expected edge length at 1x. Everything the kit ships is 64; our two
## projectiles are deliberately smaller because they are not tile-sized objects.
## `dandelion_seed` is 24 rather than `corn_kernel`'s 16 because it is the one
## projectile the player is meant to watch: it arcs for SeedBomb.FLIGHT_SECONDS
## and is scaled up at the apex, where 16px of art is a smudge.
const EXPECTED_SIZE := {
	"aloe": 64,
	# The ninth plant, and the only sprite in this table drawn to read against the ROAD
	# rather than against the lawn — art_src/bramble.svg's header has the measurement
	# (towerDefense_tile050.png is a flat #BB8044) and why that rules out the brown family
	# every other bramble would be drawn in.
	"bramble": 64,
	# The Cutworm's head, and the second sprite in this table drawn against the ROAD
	# rather than the lawn — for the same reason the Bramble is, arrived at by the same
	# measurement. Pest red on the road's #BB8044 is 1.14:1 and the kit's sand #ECDCB8
	# is 2.47:1; a 64px bug survives the first ratio and a 953px body does not.
	# art_src/pest_cutworm.svg's header carries it. Only the HEAD is a sprite — the
	# trunk is swept along the road's spine by cutworm.gd and never rasterised.
	"pest_cutworm": 64,
	# The Bramble's two damage frames (plant-tower-defense-a180). One drawing at three
	# states; every step REMOVES rather than redraws, and all three share a painted base so
	# the swap does not make the plant jump. Damage is taken symmetrically because this
	# file's own bilateral-centring check would otherwise fail a perfectly good drawing.
	"bramble_chewed": 64,
	"bramble_ragged": 64,
	"chomp_flower": 64,
	"chomp_flower_eating": 64,
	"chomp_flower_eating_late": 64,
	# The frame AT the bite, held for BITE_SQUASH_OUT_SECONDS before the eating
	# sprite takes over (plant-tower-defense-81g9).
	"chomp_flower_gape": 64,
	"corn_cobbler": 64,
	"mint": 64,
	# The Shield Bug and its corpse. Added by the parent rather than by the agent that
	# drew them: two lanes each needed a row in this table and it is the one file they
	# would have collided in.
	"pest_shieldbug": 64,
	"pest_shieldbug_dead": 64,
	"nettle": 64,
	"corn_kernel": 16,
	# The Bomb Dandelion's four fluff frames. One drawing, four tuft counts --
	# see art_src/dandelion.svg for why every set is symmetric about the vertical
	# axis (this file's own bilateral-centring check is what makes it a rule).
	"dandelion": 64,
	"dandelion_thinning": 64,
	"dandelion_sparse": 64,
	"dandelion_bare": 64,
	"dandelion_seed": 24,
	"pest_aphid": 64,
	"pest_aphid_dead": 64,
	"pest_beetle": 64,
	"pest_beetle_dead": 64,
	# The Nurse Beetle's own art (plant-tower-defense-cnn7). Same 64px canvas as
	# every other pest; Pest.SPECIES[NURSE].scale (1.30) does the enlarging, the
	# way the Queen's does.
	"pest_nurse": 64,
	"pest_nurse_dead": 64,
	# The boss reads bigger than a beetle on the board, but it does it on the
	# kit's own 64 px canvas — Pest.SPECIES[QUEEN].scale does the enlarging, so
	# nothing here needs a second canvas size to justify.
	"pest_queen": 64,
	"pest_queen_dead": 64,
	# The Leafhopper and the Locust (plant-tower-defense-4zyb) — two more pests,
	# each asking a question none of the first five do (Pest.SPECIES has both
	# arguments). Same 64 px canvas as every other pest; neither needs a second
	# size to justify, exactly like the Queen's and the Nurse's own rows above.
	"pest_hopper": 64,
	"pest_hopper_dead": 64,
	"pest_locust": 64,
	"pest_locust_dead": 64,
	"seed_packet": 64,
	"sticky_sundew": 64,
	"sunflower": 64,
}

## STYLE.md's palette, sampled by frequency from the kit's own PNGs, plus the
## three shades extrapolated along an existing hue (documented there).
const PALETTE: PackedStringArray = [
	"1F8A4C", "2ECC71", "31D978", "229C56", "2ABB67",
	"C29A00", "FFCC00", "FFD73A", "8A6D00",
	"AF392D", "E74C3C", "D24536", "8C2D24", "7A2820",
	"727272", "939393", "AAAAAA", "5E5E5E",
	"758C8E", "89A4A6", "A3C3C6",
	"A69B81", "ECDCB8", "FFEDC6", "D7C9A8",
	"A8723B", "C48647", "D9944E",
	"C25000", "FF6600", "FF9C3C",
	"FFFFFF",
]

## What makes a stem a sport's, and the only thing MUTANT_PALETTE is keyed off.
## `tools/gen_sport_svg.py` appends it and `PlantMutation.sport_texture_path` looks for
## it; `--check` there fails if this spelling and that one disagree.
const SPORT_SUFFIX := "_sport"

## The two mutant ramps a sport sprite is recoloured onto, and the ONLY sprites they are
## legal in: `_palette_rgb` hands them out for a `_sport` stem and withholds them for
## every other, so the kit contract above is exactly as tight for the ordinary sprites
## after this table existed as it was before.
##
## Eight anchors each, constant-hue by construction and monotone in luminance — derived,
## not chosen. `python tools/gen_sport_svg.py --palette` prints this block, and that
## tool's `--check` fails when this copy and its RAMPS disagree, so the two cannot drift.
## The derivation and why it has these properties are in that file's docstring.
const MUTANT_PALETTE: PackedStringArray = [
	"2A3A05", "415A08", "597A0B", "709A0E", "88BA12", "9DD618", "C0EC5A", "E7FCB6",
	"46063B", "690859", "910C7B", "B91A9E", "DE34C2", "F56EDE", "FCB0EF", "FFCEF7",
]

## What makes a stem a skin's, and the only thing SKIN_PALETTES is keyed off.
## `tools/gen_skin_svg.py` builds `<parent>_skin_<family>` with it and `Skins.texture_path`
## looks for it; a bare run of that tool fails if this spelling and its own disagree.
const SKIN_SUFFIX := "_skin_"

## The three skin ramps and the ONLY sprites each is legal in. A plant wearing a bought
## skin wears a generated DRAWING (`tools/gen_skin_svg.py`), not a tint, and every shade in
## it comes off its own family's ramp.
##
## Scoped per family, not pooled: `_palette_rgb` hands a `_skin_frost` stem the frost ramp
## and nothing else, so an ember shade that leaked into a frost sprite is still a finding.
## Pooling all twenty-four would have been one line and would have made the three families
## one 24-colour palette with every pair-segment between them legal, which is the same
## mistake in miniature that widening PALETTE itself would have been for the mutants.
##
## Eight anchors each, constant-hue by construction and monotone in luminance -- derived,
## not chosen. `python tools/gen_skin_svg.py --palette` prints this block, and a bare run
## of that tool fails when this copy and its RAMPS disagree in either direction. The
## derivation, the hues and why both end rungs stop short of white and black are in that
## file's docstring and in art_src/STYLE.md.
const SKIN_PALETTES := {
	"golden": ["463604", "695006", "8C6B09", "AF870E", "D0A218", "E8BC37", "F5D36E", "FCE8AA"],
	"frost": ["053046", "084969", "0C618C", "147BAF", "2896CD", "50B3E4", "87CEF2", "B9E4FA"],
	"ember": ["481504", "6C2108", "902D0C", "B43910", "D6491A", "EC6B40", "F89B7C", "FDC7B5"],
}

## An anti-aliased edge between two flat fills lands *on the line between them*
## in RGB, so conformance is "within TOLERANCE of some palette-pair segment",
## not "exactly a palette entry". Measured worst case across all six sprites is
## 8.21; a genuinely new hue lands in the hundreds.
const BLEND_TOLERANCE := 12.0

## Alpha above which a pixel counts as opaque rather than an edge feather.
const OPAQUE := 250

# save-persist-check: ok - the only name this file shares with the persisting set is
# `_load`, which here is the PNG loader defined at the bottom of this script, not
# RunConfig._load(). That tool resolves no receiver types, so a bare method name is
# one entry for every class that spells it the same way; it says so itself under NOT
# COVERED. Nothing in this file reaches RunConfig at all — a redirect here would be a
# line of ceremony pretending to be a guard, which is worse than a stated waiver.

var _T

func test_every_sprite_declared_by_the_contract_exists() -> String:
	for stem: String in _declared():
		var img := _load(stem)
		var err: String = _T.assert_true(img != null, "%s.png is on disk and loads" % stem)
		if err != "":
			return err
	return _T.assert_eq(_stems_on_disk().size(), _declared().size(),
		"every PNG in assets/sprites is declared in EXPECTED_SIZE (an undeclared sprite is ungated)")


func test_sprites_are_square_and_kit_sized() -> String:
	for stem: String in _declared():
		var img := _load(stem)
		if img == null:
			return "%s.png did not load" % stem
		var want: int = _declared()[stem]
		var err: String = _T.assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(want, want),
			"%s is %dx%d" % [stem, want, want])
		if err != "":
			return err
	return ""


func test_retina_is_exactly_double() -> String:
	for stem: String in _declared():
		var img := _load_retina(stem)
		if img == null:
			return "%s@2x.png is missing — the kit ships a Retina copy of every sprite" % stem
		var want: int = int(_declared()[stem]) * 2
		var err: String = _T.assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(want, want),
			"%s@2x is %dx%d" % [stem, want, want])
		if err != "":
			return err
	return ""


func test_sprites_actually_drew_something() -> String:
	# A malformed path renders as a fully transparent PNG. Nothing downstream
	# reports that: the texture loads, the sprite node is there, the screen is empty.
	for stem: String in _declared():
		var img := _load(stem)
		if img == null:
			return "%s.png did not load" % stem
		var err: String = _T.assert_false(img.is_invisible(), "%s has visible pixels" % stem)
		if err != "":
			return err
		err = _T.assert_gt(_opaque_pixel_count(img), 60, "%s has real coverage, not a stray dot" % stem)
		if err != "":
			return err
	return ""


func test_content_is_bilaterally_centred() -> String:
	# The kit's units face up-screen and are symmetric about their vertical axis;
	# an off-centre sprite rotates about the wrong point the moment anything aims.
	for stem: String in _declared():
		var img := _load(stem)
		if img == null:
			return "%s.png did not load" % stem
		var box := _opaque_bounds(img)
		var mid := (box.position.x + box.end.x) * 0.5
		var err: String = _T.assert_float_eq(mid, img.get_width() * 0.5, 1.0,
			"%s is centred on the vertical axis" % stem)
		if err != "":
			return err
	return ""


func test_content_stays_inside_the_canvas() -> String:
	# Touching the edge means the art was clipped, which shows up as a flat cut
	# on one side that reads as a rendering bug rather than a drawing mistake.
	for stem: String in _declared():
		var img := _load(stem)
		if img == null:
			return "%s.png did not load" % stem
		var box := _opaque_bounds(img)
		var w := img.get_width()
		var h := img.get_height()
		var margin: int = mini(mini(box.position.x, box.position.y), mini(w - box.end.x, h - box.end.y))
		var err: String = _T.assert_gte(margin, 1, "%s keeps a 1px margin (bounds %s in %dx%d)" % [stem, box, w, h])
		if err != "":
			return err
	return ""


func test_rendered_png_matches_its_svg_source_size() -> String:
	# THE staleness check, and the one that needs nothing to be remembered.
	#
	# render_svg.gd calls load_svg_from_buffer(bytes, scale) and saves the result, so a
	# PNG's dimensions are not an independent fact about the PNG — they are a derived
	# property of the SVG that produced it. Comparing them therefore answers "did this
	# PNG come from this SVG", which neither gate could ask before, and it answers it
	# from files that already exist.
	#
	# Its blind spot, stated plainly: an edit that leaves the canvas alone — a recoloured
	# fill, a moved path, a new petal — re-renders at the same size and is invisible
	# here. Catching that needs render_svg.gd to stamp what it rendered; the checking
	# half of that stamp lives in tools/svg_style_check.py's `freshness` check.
	var stems := _svg_stems()
	var err: String = _T.assert_gt(stems.size(), 0,
		"art_src/ has SVG sources to compare the renders against")
	if err != "":
		return err
	for stem: String in stems:
		var canvas := _svg_canvas(stem)
		err = _T.assert_gt(canvas.x, 0, "art_src/%s.svg declares a canvas size" % stem)
		if err != "":
			return err
		var img := _load(stem)
		if img == null:
			return "%s.png is missing — art_src/%s.svg was never rendered (run tools/render_svg.gd)" % [stem, stem]
		err = _T.assert_eq(Vector2i(img.get_width(), img.get_height()), canvas,
			"%s.png is the size art_src/%s.svg declares (a mismatch means the PNG was rendered from an older source)" % [stem, stem])
		if err != "":
			return err
		var retina := _load_retina(stem)
		if retina == null:
			return "%s@2x.png is missing — render_svg.gd writes both outputs from one source" % stem
		err = _T.assert_eq(Vector2i(retina.get_width(), retina.get_height()), canvas * 2,
			"%s@2x.png is exactly double art_src/%s.svg's canvas" % [stem, stem])
		if err != "":
			return err
	return ""


func test_expected_size_agrees_with_the_authored_svg_canvas() -> String:
	# EXPECTED_SIZE is hand-maintained and the SVG declares its own canvas, so the two
	# can drift silently. When they do, every size assertion in this file is checking
	# the PNG against a number nobody derived from anything.
	var stems := _svg_stems()
	var err: String = _T.assert_gt(stems.size(), 0, "art_src/ has SVG sources")
	if err != "":
		return err
	for stem: String in stems:
		if not _declared().has(stem):
			continue  # named by test_every_svg_source_is_declared instead
		var want: int = _declared()[stem]
		err = _T.assert_eq(_svg_canvas(stem), Vector2i(want, want),
			"art_src/%s.svg declares the %dx%d canvas EXPECTED_SIZE claims for it" % [stem, want, want])
		if err != "":
			return err
	return ""


func test_every_svg_source_is_declared() -> String:
	# Pairing, both directions. A 13th SVG with no EXPECTED_SIZE row renders, ships, and
	# is ungated by every other test in this file — none of them iterate anything else.
	# A row with no SVG points at a PNG nothing regenerates.
	var stems := _svg_stems()
	var err: String = _T.assert_gt(stems.size(), 0, "art_src/ has SVG sources")
	if err != "":
		return err
	for stem: String in stems:
		err = _T.assert_true(_declared().has(stem),
			"art_src/%s.svg has an EXPECTED_SIZE row (an undeclared source renders, ships and is ungated)" % stem)
		if err != "":
			return err
	for stem: String in _declared():
		err = _T.assert_true(stems.has(stem),
			"EXPECTED_SIZE row '%s' has an art_src/%s.svg to have come from" % [stem, stem])
		if err != "":
			return err
	return ""


func test_no_rendered_png_is_an_orphan() -> String:
	# test_every_sprite_declared_by_the_contract_exists compares COUNTS, which an orphan
	# and a missing file satisfy by cancelling out. This names the file: a source that
	# was deleted or renamed leaves its render behind, and the leftover PNG ships.
	var stems := _svg_stems()
	var on_disk := _stems_on_disk()
	var err: String = _T.assert_gt(on_disk.size(), 0, "assets/sprites has rendered PNGs")
	if err != "":
		return err
	for stem: String in on_disk:
		err = _T.assert_true(stems.has(stem),
			"assets/sprites/%s.png has an art_src/%s.svg — an orphaned render ships and nothing regenerates it" % [stem, stem])
		if err != "":
			return err
	return ""


func test_a_skin_carries_more_ink_than_the_plant_it_dresses() -> String:
	# The one claim about a skin that no other test in this file can make, and the one
	# the FEATURE is about: a skin is not a recolour. `tools/gen_skin_svg.py` appends a
	# family motif as real geometry, so a skin's silhouette is strictly bigger than its
	# parent's — the crown, the shards, the scorch all paint where the plant does not.
	#
	# Every other gate here is satisfied by a pure recolour. The palette test passes on
	# one, the size and centring and margin tests pass on one, and the generator's own
	# check compares text and would happily agree with a motif whose `d` Godot silently
	# refuses to draw. Opaque pixel COUNT is the property that separates "the motif is in
	# the file" from "the motif reached the raster", and it is measured against the
	# parent rather than against a number, so a redrawn motif does not need a new
	# constant here.
	var stems := _svg_stems()
	var checked := 0
	for stem: String in _declared():
		var at := stem.find(SKIN_SUFFIX)
		if at < 0:
			continue
		var parent: String = stem.substr(0, at)
		if not stems.has(parent):
			continue  # named by test_every_svg_source_is_declared instead
		var skin := _load(stem)
		var plain := _load(parent)
		if skin == null or plain == null:
			return "%s.png or its parent %s.png did not load" % [stem, parent]
		checked += 1
		var err: String = _T.assert_gt(_opaque_pixel_count(skin), _opaque_pixel_count(plain),
			"%s paints more than %s (a skin appends a motif; equal ink means the motif did not render)"
				% [stem, parent])
		if err != "":
			return err
	# A loop over an empty set returns pass having asserted nothing, which is the
	# [VACUOUS] failure this suite prints for exactly this shape. Say the number.
	return _T.assert_gt(checked, 0, "art_src/ carries skin drawings to compare against their parents")


func test_every_colour_is_kit_palette_or_a_blend_of_two() -> String:
	for stem: String in _declared():
		var pal := _palette_rgb(stem)
		var img := _load(stem)
		if img == null:
			return "%s.png did not load" % stem
		var worst := 0.0
		var worst_colour := Color.BLACK
		var seen := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a * 255.0 <= OPAQUE:
					continue
				var key := c.to_rgba32()
				if seen.has(key):
					continue
				seen[key] = true
				var d := _distance_to_palette_blend(c, pal)
				if d > worst:
					worst = d
					worst_colour = c
		var err: String = _T.assert_true(worst <= BLEND_TOLERANCE,
			"%s stays on the kit palette (worst pixel #%s is %.2f off, tolerance %.1f)"
				% [stem, worst_colour.to_html(false), worst, BLEND_TOLERANCE])
		if err != "":
			return err
	return ""


# ---------------------------------------------------------------- helpers

## art_src/ as an OS path, reached exactly the way render_svg.gd reaches it: the
## .gdignore there keeps the SVGs out of the import pipeline, so res:// is not the
## route. This script never ships in an export, so the project directory is always there.
func _art_src_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join(SRC_SUBDIR)


func _svg_stems() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(_art_src_dir())
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension().to_lower() == "svg":
			out.append(f.get_basename())
	return out


## The width/height the SVG declares on its own root element, or (-1, -1).
##
## This is the size render_svg.gd will rasterise at, so it is the number the PNG on
## disk has to match. Only the <svg> open tag is searched, so a stroke-width or a
## <rect width=…> further down cannot be mistaken for the canvas.
func _svg_canvas(stem: String) -> Vector2i:
	var path := _art_src_dir().path_join("%s.svg" % stem)
	if not FileAccess.file_exists(path):
		return Vector2i(-1, -1)
	var text := FileAccess.get_file_as_string(path)
	var open_at := text.find("<svg")
	if open_at < 0:
		return Vector2i(-1, -1)
	var close_at := text.find(">", open_at)
	if close_at < 0:
		return Vector2i(-1, -1)
	var tag := text.substr(open_at, close_at - open_at)
	return Vector2i(_tag_attr_int(tag, "width"), _tag_attr_int(tag, "height"))


## `width="64"` out of an element's open tag, or -1. The leading space in the key is
## what keeps `stroke-width="2"` from answering to `width`.
func _tag_attr_int(tag: String, attr: String) -> int:
	var key := " %s=\"" % attr
	var at := tag.find(key)
	if at < 0:
		return -1
	var from := at + key.length()
	var end := tag.find("\"", from)
	if end < 0:
		return -1
	var value := tag.substr(from, end - from)
	return int(value) if value.is_valid_int() else -1


func _load(stem: String) -> Image:
	return _load_png("%s/%s.png" % [SPRITE_DIR, stem])


func _load_retina(stem: String) -> Image:
	return _load_png("%s/%s@2x.png" % [RETINA_DIR, stem])


func _load_png(path: String) -> Image:
	# Decode the bytes on disk rather than load()-ing the imported .ctex, so a
	# stale import cannot make a bad sprite pass. (Image.load_from_file() does the
	# same but emits an "will not work on export" warning per call, which buries
	# the run's real stderr — and this script never ships in an export anyway.)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return img


func _stems_on_disk() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(SPRITE_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension().to_lower() == "png":
			out.append(f.get_basename())
	return out


func _opaque_pixel_count(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a * 255.0 > OPAQUE:
				n += 1
	return n


## Inclusive-exclusive bounds of the opaque content, in pixels.
func _opaque_bounds(img: Image) -> Rect2i:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a * 255.0 <= OPAQUE:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Every stem this file gates, and the canvas each is held to.
##
## EXPECTED_SIZE is the hand-declared half — a row per drawing somebody sat down and made,
## which is what makes an undeclared source a failure rather than a silence. The sport
## half is DERIVED, and has to be: a sport SVG is a pure function of its parent
## (`tools/gen_sport_svg.py`), so a hand-typed row per sport would be seventeen rows whose
## only content is "the parent's, again" — seventeen chances for a canvas to be claimed
## that nobody drew.
##
## Deriving here does not reopen the hole EXPECTED_SIZE exists to close. A sport is only
## picked up if its PARENT has a declared row, so `foo_sport.svg` beside no `foo` still
## fails `test_every_svg_source_is_declared`; and which sports may exist at all is not
## this file's question — `gen_sport_svg.py --check` fails when the set on disk is not
## exactly the set its own derivation produces.
##
## Same size as the parent by construction, which is the whole of the geometric claim:
## the sport shares its parent's geometry byte for byte and differs only in paint.
##
## A SKIN is derived the same way and for the same arithmetic — fifty-one more rows whose
## only content is "the parent's, again" — but it earns the row differently and the
## difference is worth stating. A skin is NOT its parent's geometry: it appends a motif.
## What still holds is the only thing this table claims, that the CANVAS is the parent's,
## because `gen_skin_svg.py` keeps every motif inside the same 64x64 box; and the two
## clauses that the sport got for free are instead asserted by the generator's own
## placement rule (mirror-symmetric about x = 32, inside [3, 61]) and re-checked here by
## test_content_is_bilaterally_centred and test_content_stays_inside_the_canvas, which
## iterate `_declared()` and therefore iterate the skins.
##
## The family list is `SKIN_PALETTES` itself rather than three literals, so a fourth
## family is one ramp in one place and not an edit here as well.
func _declared() -> Dictionary:
	var out: Dictionary = EXPECTED_SIZE.duplicate()
	var stems := _svg_stems()
	for stem: String in EXPECTED_SIZE:
		var sport: String = stem + SPORT_SUFFIX
		if stems.has(sport):
			out[sport] = EXPECTED_SIZE[stem]
		for family: String in SKIN_PALETTES:
			var skin: String = stem + SKIN_SUFFIX + family
			if stems.has(skin):
				out[skin] = EXPECTED_SIZE[stem]
	return out


## The colours `stem` may legally be painted in.
##
## The kit palette for every drawing, plus the mutant ramps for a sport and ONLY for a
## sport. Widening PALETTE itself would have been the easy version and it would have cost
## the thing this test is for: sixteen more entries is sixteen more entries every ordinary
## sprite may also use, and — because conformance is "near the segment between two
## entries" — many hundreds more pair-segments through the middle of the colour space.
## Scoping by stem leaves the nine plants, five pests and two projectiles held to exactly
## the contract they were held to before the mutants existed.
##
## A skin stem gets ITS OWN FAMILY's eight anchors and no others — not the pooled
## twenty-four. That is the same argument one level down: three ramps handed out together
## are one 24-entry palette, and because conformance is "near the segment between two
## entries" it would legalise every blend between an ember shade and a frost one. A frost
## anchor appearing in an ember sprite is a real defect (a motif written with the wrong
## index, a family renamed in one file and not the other) and it stays a finding.
func _palette_rgb(stem: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for hex in PALETTE:
		out.append(_rgb255(hex))
	if stem.ends_with(SPORT_SUFFIX):
		for hex in MUTANT_PALETTE:
			out.append(_rgb255(hex))
		return out
	for family: String in SKIN_PALETTES:
		if not stem.ends_with(SKIN_SUFFIX + family):
			continue
		for hex: String in SKIN_PALETTES[family]:
			out.append(_rgb255(hex))
		return out
	return out


func _rgb255(hex: String) -> Vector3:
	var c := Color.html(hex)
	return Vector3(c.r, c.g, c.b) * 255.0


## Shortest distance (0-255 scale) from `c` to the line segment between any two
## palette entries — the set of colours an anti-aliased edge can legitimately produce.
func _distance_to_palette_blend(c: Color, pal: Array[Vector3]) -> float:
	var p := Vector3(c.r, c.g, c.b) * 255.0
	var best := INF
	for i in pal.size():
		for j in range(i, pal.size()):
			var a := pal[i]
			var b := pal[j]
			var ab := b - a
			var len_sq := ab.length_squared()
			var t := 0.0 if len_sq == 0.0 else clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
			if best == 0.0:
				return 0.0
	return best
