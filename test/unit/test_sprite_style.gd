extends RefCounted

## Turns art_src/STYLE.md from a document into a gate.
##
## The style contract was measured out of the Kenney "Tower Defense" kit (all 299
## sprites are 64x64; the outline is always a darker shade of the fill; the palette
## is fixed). A sprite that drifts off it still loads, still draws, and looks
## subtly foreign next to the kit — nothing else in the project would notice.
##
## Run: godot --headless --path . --script res://tools/run_tests.gd -- --file test_sprite_style.gd

const SPRITE_DIR := "res://assets/sprites"
const RETINA_DIR := "res://assets/sprites/retina"

## name -> expected edge length at 1x. Everything the kit ships is 64; our
## projectile is deliberately smaller because it is not a tile-sized object.
const EXPECTED_SIZE := {
	"chomp_flower": 64,
	"chomp_flower_eating": 64,
	"corn_cobbler": 64,
	"corn_kernel": 16,
	"pest_aphid": 64,
	"pest_aphid_dead": 64,
	"pest_beetle": 64,
	"pest_beetle_dead": 64,
	"seed_packet": 64,
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

## An anti-aliased edge between two flat fills lands *on the line between them*
## in RGB, so conformance is "within TOLERANCE of some palette-pair segment",
## not "exactly a palette entry". Measured worst case across all six sprites is
## 8.21; a genuinely new hue lands in the hundreds.
const BLEND_TOLERANCE := 12.0

## Alpha above which a pixel counts as opaque rather than an edge feather.
const OPAQUE := 250

var _T

func test_every_sprite_declared_by_the_contract_exists() -> String:
	for stem: String in EXPECTED_SIZE:
		var img := _load(stem)
		var err: String = _T.assert_true(img != null, "%s.png is on disk and loads" % stem)
		if err != "":
			return err
	return _T.assert_eq(_stems_on_disk().size(), EXPECTED_SIZE.size(),
		"every PNG in assets/sprites is declared in EXPECTED_SIZE (an undeclared sprite is ungated)")


func test_sprites_are_square_and_kit_sized() -> String:
	for stem: String in EXPECTED_SIZE:
		var img := _load(stem)
		if img == null:
			return "%s.png did not load" % stem
		var want: int = EXPECTED_SIZE[stem]
		var err: String = _T.assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(want, want),
			"%s is %dx%d" % [stem, want, want])
		if err != "":
			return err
	return ""


func test_retina_is_exactly_double() -> String:
	for stem: String in EXPECTED_SIZE:
		var img := _load_retina(stem)
		if img == null:
			return "%s@2x.png is missing — the kit ships a Retina copy of every sprite" % stem
		var want: int = int(EXPECTED_SIZE[stem]) * 2
		var err: String = _T.assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(want, want),
			"%s@2x is %dx%d" % [stem, want, want])
		if err != "":
			return err
	return ""


func test_sprites_actually_drew_something() -> String:
	# A malformed path renders as a fully transparent PNG. Nothing downstream
	# reports that: the texture loads, the sprite node is there, the screen is empty.
	for stem: String in EXPECTED_SIZE:
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
	for stem: String in EXPECTED_SIZE:
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
	for stem: String in EXPECTED_SIZE:
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


func test_every_colour_is_kit_palette_or_a_blend_of_two() -> String:
	var pal := _palette_rgb()
	for stem: String in EXPECTED_SIZE:
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


func _palette_rgb() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for hex in PALETTE:
		var c := Color.html(hex)
		out.append(Vector3(c.r, c.g, c.b) * 255.0)
	return out


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
