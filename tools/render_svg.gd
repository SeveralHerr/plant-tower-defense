extends SceneTree
## Rasterises the authored SVG sources in art_src/ into game-ready PNGs.
##
##   godot --headless --path . --script res://tools/render_svg.gd
##   godot --headless --path . --script res://tools/render_svg.gd -- --only corn
##
## Writes assets/sprites/<name>.png at the SVG's own size and
## assets/sprites/retina/<name>@2x.png at double.
##
## art_src/ carries a .gdignore, so these SVGs are NOT imported as textures —
## which is the point: one sprite, one resource. That also means we read them
## through the OS path rather than res://.

const SRC_DIR := "art_src"
const OUT_DIR := "assets/sprites"
const RETINA_DIR := "assets/sprites/retina"

func _init() -> void:
	var only := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--only" and i + 1 < args.size():
			only = args[i + 1]

	var root := ProjectSettings.globalize_path("res://")
	var src := root.path_join(SRC_DIR)
	var out := root.path_join(OUT_DIR)
	var retina := root.path_join(RETINA_DIR)

	if not DirAccess.dir_exists_absolute(src):
		push_error("No source directory: %s" % src)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(retina)

	var names := _svg_names(src)
	if names.is_empty():
		push_error("No .svg files in %s" % src)
		quit(2)
		return

	var rendered := 0
	var failed := 0
	for file_name in names:
		var stem := file_name.get_basename()
		if only != "" and not stem.contains(only):
			continue
		var bytes := FileAccess.get_file_as_bytes(src.path_join(file_name))
		if bytes.is_empty():
			print("[FAIL] %s — unreadable or empty" % file_name)
			failed += 1
			continue
		var one := _render(bytes, 1.0, out.path_join("%s.png" % stem))
		var two := _render(bytes, 2.0, retina.path_join("%s@2x.png" % stem))
		if one.is_empty() or two.is_empty():
			failed += 1
			continue
		print("[OK]   %-16s %s  ->  %s" % [stem, one, two])
		rendered += 1

	print("Rendered: %d of %d discovered | failed: %d" % [rendered, names.size(), failed])
	if only != "" and rendered == 0:
		push_error("SELECTED NOTHING — --only %s matched no source" % only)
		quit(2)
		return
	quit(1 if failed > 0 else 0)


func _svg_names(dir_path: String) -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return names
	for f in dir.get_files():
		if f.get_extension().to_lower() == "svg":
			names.append(f)
	names.sort()
	return names


## Returns "WxH" on success, "" on failure.
func _render(bytes: PackedByteArray, scale: float, dest: String) -> String:
	var img := Image.new()
	var err := img.load_svg_from_buffer(bytes, scale)
	if err != OK or img.is_empty():
		print("[FAIL] %s — load_svg_from_buffer returned %d" % [dest.get_file(), err])
		return ""
	if img.is_invisible():
		print("[FAIL] %s — rendered fully transparent (bad path data?)" % dest.get_file())
		return ""
	if img.save_png(dest) != OK:
		print("[FAIL] %s — could not write" % dest)
		return ""
	return "%dx%d" % [img.get_width(), img.get_height()]
