extends Node
## Checks the animated GameLogo and the title screen that shows it: layer textures have mipmaps,
## and PNG frames of the intro and idle animation at landscape and portrait sizes for review.
## Needs a real renderer (not --headless):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/LogoShots.tscn -- --out=<dir>

var _out := "user://logo_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)

	var ok := true
	for part: String in GameLogo.TEXTURES:
		var texture: Texture2D = GameLogo.TEXTURES[part]
		var has_mips := texture.get_image().has_mipmaps()
		print("layer %s %dx%d mipmaps=%s" % [part, texture.get_width(), texture.get_height(), has_mips])
		ok = ok and has_mips

	# A flat warm backdrop stands in for the 3D board, so the test only depends on the UI.
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = AppTheme.get_theme()
	layer.add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("f1d6b8")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var title: Screen = load("res://ui/screens/TitleScreen.gd").new()
	root.add_child(title)
	title.open({})
	_t0 = _now()
	for at: float in [0.15, 0.45, 0.8, 1.2, 2.4, 3.6]:
		await _shot_at("title_%04d" % int(at * 1000), at)
	DisplayServer.window_set_size(Vector2i(540, 960))
	await get_tree().create_timer(0.3).timeout
	title.open({})
	_t0 = _now()
	await _shot_at("portrait_intro", 0.5)
	await _shot_at("portrait_idle", 2.6)

	# Small and large standalone logos on a flat background.
	title.queue_free()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.3).timeout
	var bg := ColorRect.new()
	bg.color = Color("2c2166")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 40)
	root.add_child(row)
	for h: float in [90.0, 180.0, 420.0]:
		row.add_child(GameLogo.new(h, false))
	_t0 = _now()
	await _shot_at("sizes", 0.5)
	print("LOGO_TEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


var _t0 := 0.0


func _shot_at(file_name: String, at: float) -> void:
	await get_tree().create_timer(maxf(0.01, at - _since())).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name + ".png"))
	print("shot ", file_name)


func _since() -> float:
	return _now() - _t0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
