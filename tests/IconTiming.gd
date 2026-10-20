extends SceneTree
## Times the pieces of icon rasterisation for one pack (headless).
##   godot --headless --path . -s res://tests/IconTiming.gd -- [--pack=vikings]


func _init() -> void:
	var pack := "vikings"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="):
			pack = arg.trim_prefix("--pack=")
	var bundle: Dictionary = (load("res://assets/icons/packs/%s.json" % pack) as JSON).data
	var t_svg := 0
	var t_512 := 0
	var t_chain := 0
	for rank: String in bundle:
		var t0 := Time.get_ticks_usec()
		var hi := Image.new()
		hi.load_svg_from_string(bundle[rank], 2.0)
		hi.convert(Image.FORMAT_RGBA8)
		var t1 := Time.get_ticks_usec()
		var base := hi.duplicate() as Image
		base.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var t2 := Time.get_ticks_usec()
		var level := base
		var size := 256
		while size >= 1:
			level = level.duplicate() as Image
			level.resize(size, size, Image.INTERPOLATE_LANCZOS)
			size >>= 1
		var t3 := Time.get_ticks_usec()
		t_svg += t1 - t0
		t_512 += t2 - t1
		t_chain += t3 - t2
	var n := bundle.size()
	print("%s: svg@1024 %.1f ms, lanczos->512 %.1f ms, mip chain (from previous level) %.1f ms per icon" % [
		pack, t_svg / 1000.0 / n, t_512 / 1000.0 / n, t_chain / 1000.0 / n])
	quit()
