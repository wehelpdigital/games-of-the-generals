extends SceneTree
## Compares mip levels of the old box-filtered chain with PieceIcons' Lanczos chain (headless).
## Each row: an icon at 128/64/40 px, box then Lanczos, blown up 2× (nearest) for inspection.
##   godot --headless --path . -s res://tests/IconSharpness.gd -- --out=<png> [--pack=classic]

const RANKS := ["G5", "COL", "CPT", "SGT"]
const SIZES := [128, 64, 40]


func _init() -> void:
	var out := "user://sharpness.png"
	var pack := "classic"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pack="):
			pack = arg.trim_prefix("--pack=")
	var cell := 2 * 128 + 12
	var sheet := Image.create_empty(cell * SIZES.size() * 2 + 12, cell * RANKS.size() + 12, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("8e8aa3"))
	for r in RANKS.size():
		var lanczos := PieceIcons.icon_texture(RANKS[r], pack).get_image()
		var box := Image.create_from_data(512, 512, false, Image.FORMAT_RGBA8, lanczos.get_data().slice(0, 512 * 512 * 4))
		box.generate_mipmaps()
		for s in SIZES.size():
			for k in 2:
				var src := box if k == 0 else lanczos
				var level := _level(src, SIZES[s])
				level.resize(level.get_width() * 2, level.get_height() * 2, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(level, Rect2i(Vector2i.ZERO, level.get_size()), Vector2i(12 + (s * 2 + k) * cell, 12 + r * cell))
	sheet.save_png(out)
	print("saved ", out, "  (columns: box, lanczos per size ", SIZES, ")")
	quit()


## The mip level of `img` closest to `size` px, or a direct resize for sizes between levels.
func _level(img: Image, size: int) -> Image:
	var level := 0
	var w := img.get_width()
	while w > size and level < img.get_mipmap_count():
		level += 1
		w >>= 1
	if w != size:
		level = max(level - 1, 0)
	var offset := img.get_mipmap_offset(level)
	var lw := img.get_width() >> level
	var bytes := lw * lw * 4
	var out := Image.create_from_data(lw, lw, false, Image.FORMAT_RGBA8, img.get_data().slice(offset, offset + bytes))
	if lw != size:
		out.resize(size, size, Image.INTERPOLATE_BILINEAR)  # What the GPU's trilinear blend approximates.
	return out
