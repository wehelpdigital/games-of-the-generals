extends SmokeTestBase
## Renders every table topper (three at a time on the player's pedestals), flags with designed and
## uploaded-picture cloths, an overview with the opponent's toppers, and the flag texture sheet.
## Real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/TopperShots.tscn -- --out=<dir>

var _out := "user://toppers"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	seed(5)
	await boot()
	var game: Game3D = main.get_node("Game3D")
	main.get_node("UI").visible = false
	game.rig.attract = false
	game.rig.set_side(Ranks.WHITE)
	game._opponent_loadout = {"toppers": {"slots": [{"slug": "topper_trophy"}, {"slug": "topper_flag_gold", "flag": {"shape": "burgee", "pattern": "cross", "emblem": "dragon", "color": "#1b3f8f", "color2": "#ffd23f"}}, {"slug": "topper_lucky_cat"}]}}
	game.refresh_cosmetics()

	var right := Camera3D.new()
	right.fov = 40.0
	game.add_child(right)
	right.look_at_from_position(Vector3(3.2, 2.0, 5.9), Vector3(5.5, 0.45, 2.1))
	var left := Camera3D.new()
	left.fov = 40.0
	game.add_child(left)
	left.look_at_from_position(Vector3(-3.4, 1.9, 5.6), Vector3(-5.6, 0.4, 2.8))

	var objects: Array = ToppersLibrary.object_slugs()
	var group := 0
	while group * 3 < objects.size():
		var slots: Array = []
		for slug: String in objects.slice(group * 3, group * 3 + 3):
			slots.append({"kind": "object", "slug": slug})
		Loadout.set_toppers({"slots": slots})
		print("group %d: %s" % [group, objects.slice(group * 3, group * 3 + 3)])
		right.make_current()
		await _shot("objects_%d_right" % group, 0.8)
		left.make_current()
		await _shot("objects_%d_left" % group, 0.2)
		group += 1

	var photo := _sample_photo()
	var path := Loadout.save_local_flag_image(photo)
	Loadout.set_toppers({"slots": [
		{"kind": "flag", "slug": "topper_flag_wood", "flag": {"shape": "swallowtail", "pattern": "stripes_h", "emblem": "star"}},
		{"kind": "flag", "slug": "topper_flag_steel", "flag": {"shape": "rectangle", "local_image": path}},
		{"kind": "flag", "slug": "topper_flag_gold", "flag": {"shape": "guidon", "pattern": "sunburst", "emblem": "raven", "color": "#8b5cf6", "color2": "#22f2ff"}},
	]})
	right.make_current()
	await _shot("flags_right", 0.8)
	left.make_current()
	await _shot("flags_left", 0.2)
	game.rig.camera.make_current()
	await _shot("overview", 0.3)

	# Flag design sheet: every shape and pattern, a few emblems.
	var sheet := Image.create_empty(1344, 864, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("efe6d6"))
	var shapes: Array = FlagFactory.SHAPES.keys()
	var patterns: Array = FlagFactory.PATTERNS.keys()
	var emblems: Array = FlagFactory.EMBLEMS.keys()
	for i in 16:
		var design := {"shape": shapes[i % shapes.size()], "pattern": patterns[i % patterns.size()], "emblem": emblems[i % emblems.size()],
			"color": FlagFactory.PALETTE[i % 16], "color2": FlagFactory.PALETTE[(i * 5 + 3) % 16]}
		var img: Image = FlagFactory.texture(design).get_image()
		img.decompress()
		if img.has_mipmaps():
			img.clear_mipmaps()
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 4) * 336, (i / 4) * 216))
	var with_photo: Image = FlagFactory.texture({"shape": "wave"}, photo).get_image()
	with_photo.clear_mipmaps()
	sheet.save_png("%s/flag_sheet.png" % _out)
	with_photo.save_png("%s/flag_photo.png" % _out)
	print("saved flag sheets")
	Loadout.reset()
	get_tree().quit()


## A stand-in "uploaded photo": sky gradient, sun and hills.
func _sample_photo() -> Image:
	var img := Image.create_empty(320, 240, false, Image.FORMAT_RGBA8)
	for y in 240:
		for x in 320:
			var c := Color("3d8bff").lerp(Color("ffd6a5"), y / 240.0)
			if Vector2(x - 220, y - 80).length() < 34:
				c = Color("ffd23f")
			if y > 170 + 25 * sin(x / 40.0):
				c = Color("27c98f")
			img.set_pixel(x, y, c)
	return img


func _shot(file: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
