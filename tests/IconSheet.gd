extends SceneTree
## Rasterises every piece icon SVG into one contact sheet PNG (works headless).
##   godot --headless --path . -s res://tests/IconSheet.gd -- --out=<file.png> [--size=256]

const ORDER := ["G5", "G4", "G3", "G2", "G1", "COL", "LTC", "MAJ", "CPT", "1LT", "2LT", "SGT", "PVT", "SPY", "FLG"]


func _init() -> void:
	var out := "user://icon_sheet.png"
	var cell := 256
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			cell = int(arg.trim_prefix("--size="))
	var columns := 5
	var pad := 16
	var rows := ceili(ORDER.size() / float(columns))
	var sheet := Image.create_empty(columns * (cell + pad) + pad, rows * (cell + pad) + pad, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("f1d6b8"))
	for i in ORDER.size():
		var svg := FileAccess.get_file_as_string("res://assets/icons/pieces/%s.svg" % ORDER[i])
		var img := Image.new()
		var err := img.load_svg_from_string(svg, cell / 512.0)
		if err != OK:
			push_error("Could not rasterise %s (%d)" % [ORDER[i], err])
			continue
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(pad + (i % columns) * (cell + pad), pad + (i / columns) * (cell + pad))
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	print("saved ", out)
	quit()
