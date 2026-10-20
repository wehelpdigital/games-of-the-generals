extends SceneTree
## Rasterises any SVG file (absolute path) to PNG; used to preview icon work (works headless).
##   godot --headless --path . -s res://tests/IconRaster.gd -- --in=<file.svg> --out=<file.png> [--scale=1]


func _init() -> void:
	var src := ""
	var out := "user://raster.png"
	var scale := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--in="):
			src = arg.trim_prefix("--in=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			scale = float(arg.trim_prefix("--scale="))
	var img := Image.new()
	var err := img.load_svg_from_string(FileAccess.get_file_as_string(src), scale)
	if err != OK:
		push_error("Could not rasterise %s (%d)" % [src, err])
		quit(1)
		return
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
