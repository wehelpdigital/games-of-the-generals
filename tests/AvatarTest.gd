extends SmokeTestBase
## Default cartoon avatars: every file loads (with mipmaps), the pick for a player is stable and
## the same whichever payload names them, players spread across the set, photos and guild logos
## keep their own behaviour. Writes a sample row of avatars with --out=<dir> (needs a renderer).
##   godot --headless --path . res://tests/AvatarTest.tscn
##   godot --path . --rendering-driver opengl3 --resolution 900x220 res://tests/AvatarTest.tscn -- --out=<dir>


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")

	var all_load := true
	var all_mips := true
	for avatar_name: String in AvatarView.DEFAULTS:
		var texture: Texture2D = load(AvatarView.DEFAULT_DIR + avatar_name + ".webp")
		all_load = all_load and texture != null and texture.get_width() >= 128
		all_mips = all_mips and texture != null and texture.get_image().has_mipmaps()
	check(all_load, "all %d cartoon avatars load" % AvatarView.DEFAULTS.size())
	check(all_mips, "the avatars have mipmaps (crisp when small)")

	var maria: Texture2D = AvatarView.default_for({"username": "MariaClara", "id": 7})
	check(maria != null, "a player without a photo gets a cartoon avatar")
	check(AvatarView.default_for({"username": "MariaClara", "id": 7}) == maria, "the pick is stable")
	check(AvatarView.default_for({"username": "mariaclara", "user_id": 99, "rank_tier": 3}) == maria,
		"the same player gets the same avatar from any payload (chat, leaderboard, match)")
	check(AvatarView._stable_hash("mariaclara") == 1015174776, "the pick doesn't depend on the engine's hash()")
	check(AvatarView.default_for({}) == null and AvatarView.default_for({"username": ""}) == null,
		"no name and no id: no avatar (initials fallback)")
	check(AvatarView.default_for({"id": 12}) != null, "a payload with only an id still gets one")

	var used := {}
	for i in 400:
		used[AvatarView.default_for({"username": "player_%d" % i})] = true
	check(used.size() >= AvatarView.DEFAULTS.size() - 2, "players spread across the set (%d of %d used)" % [used.size(), AvatarView.DEFAULTS.size()])

	var view := AvatarView.new(64)
	view.set_user({"username": "MariaClara", "rank_tier": 4})
	check(view._cartoon == maria and view._texture == null, "set_user shows the cartoon while there's no photo")
	var photo := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGB8))
	view.set_texture(photo)
	check(view._texture == photo, "a photo still wins over the cartoon")
	view.set_avatar("", "PGT")
	check(view._cartoon == null, "guild logos (set_avatar) keep the initials fallback")
	view.free()

	if out != "":
		await _sample(out)
	finish()


## A row of avatars at chat, list and header sizes, on the game's backdrop colour.
func _sample(out: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("f1d6b8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 16)
	row.add_theme_constant_override("separation", 14)
	layer.add_child(row)
	var names := ["KapitanTikbalang", "MayumiPH", "LakanDiwa", "Datu_Puti", "TestGeneral", "TestColonel", "sa123456", "Bayani"]
	for i in names.size():
		var diameter: float = [28.0, 36.0, 44.0, 60.0, 96.0, 128.0, 60.0, 44.0][i]
		var avatar := AvatarView.new(diameter)
		avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(avatar)
		avatar.set_user({"username": names[i], "rank_tier": i})
	await frames(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out.path_join("avatars_row.png"))
	print("saved ", out.path_join("avatars_row.png"))
