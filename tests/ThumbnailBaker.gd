extends Node
## Bakes the shop's item pictures into res://assets/shop_thumbs/<category>/<slug>.webp (read by
## ShopThumbs): a 2:1 still for every item, and for animated categories a strip of 8 frames. Each
## item is staged on the real board (Game3D in its own world) with a camera that suits it, rendered
## at twice the size and scaled down. Re-run after adding or changing items, then re-import:
##   godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake [--only=<category>] [--slug=<slug>]
##   godot --headless --path . --import

const OUT := "res://assets/shop_thumbs"
const STILL := Vector2i(240, 120)
const FRAME := Vector2i(192, 96)
const RENDER := Vector2i(480, 240)

var _view: SubViewport
var _game: Game3D
var _camera: Camera3D
var _only := ""
var _slug := ""
var _count := 0


func _ready() -> void:
	var bake := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--bake":
			bake = true
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg.begins_with("--slug="):
			_slug = arg.trim_prefix("--slug=")
	if not bake:
		print("Pass --bake to (re)write the shop thumbnails.")
		get_tree().quit()
		return
	_view = SubViewport.new()
	_view.size = RENDER
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_game = load("res://scenes/game/Game3D.tscn").instantiate()
	_view.add_child(_game)
	await get_tree().process_frame
	_game.rig.set_process(false)  # The baker places the camera itself.
	_camera = _game.rig.camera
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	AmbienceFX.reduced = false
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		if _only != "" and category != _only:
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT, category]))
		for slug: String in CosmeticCatalog.slugs(category):
			if _slug != "" and slug != _slug:
				continue
			await _bake(category, slug)
	print("baked %d pictures" % _count)
	get_tree().quit()


func _bake(category: String, slug: String) -> void:
	var look := Loadout.complete({})
	var one := [{"id": "a", "side": Ranks.WHITE, "x": 4, "y": 2, "rank": "G5"}]
	var pieces: Array = one
	match category:
		"topper":
			look["toppers"] = {"slots": [_topper_slot(slug)]}
			pieces = []
		"taunt":
			pieces = _crowd()
		"icons":
			pieces = _row()
		"board", "territory", "glow", "arena":
			pieces = _row()
		"kill":
			pieces = [{"id": "hero", "side": Ranks.WHITE, "x": 3, "y": 4, "rank": "G5"},
				{"id": "foe", "side": Ranks.BLACK, "x": 4, "y": 4, "rank": null}]
		"ambience":
			pieces = _row()
	if look.has(category):
		look[category] = slug
	_game.set_showcase(look, Loadout.complete({}))
	_game.board.set_mode(Board3D.Mode.SPECTATE, Ranks.WHITE, false)
	_game.board.sync_pieces(pieces)
	_frame_camera(category, slug)
	await _wait(0.6 if category in ["arena", "ambience"] else 0.35)
	if category == "ambience":
		# Flocks cross the sky every few seconds: start this one mid-crossing.
		var fx: Node = _game.board.get("_ambience_nodes").get(Ranks.WHITE)
		if fx != null and fx.get("_flock_time") != null:
			fx.set("_flock_start", float(fx.get("_time")) - float(fx.get("_flock_time")) * 0.35)
	if not ShopThumbs.is_clip(category):
		_save(_grab(STILL), category, slug)
		return
	# Clips: start the demo, then grab frames spread over it.
	var start := 0.0
	var step := 0.12
	match category:
		"trail":
			_game.board.apply_move_result({"piece_id": "a", "from": {"x": 4, "y": 2}, "to": {"x": 5, "y": 2}, "clash": null})
			_game.board.apply_move_result({"piece_id": "a", "from": {"x": 5, "y": 2}, "to": {"x": 4, "y": 2}, "clash": null})
			start = 0.08
			step = 0.11
		"kill":
			_game.board.apply_move_result({"piece_id": "hero", "from": {"x": 3, "y": 4}, "to": {"x": 4, "y": 4},
				"clash": {"defender_id": "foe", "outcome": "attacker", "eliminated": ["foe"]}})
			var impact: float = KillFX.ACTIONS.get(slug, {}).get("impact", 0.0)
			start = 0.3
			step = maxf(0.13, (impact + 0.9) / ShopThumbs.FRAMES)
		"taunt":
			TauntFX.throw(_game.board, Ranks.BLACK, slug, 7)
			start = 0.1
			step = 0.17
		"ambience":
			step = 0.3
	var strip := Image.create_empty(FRAME.x * ShopThumbs.FRAMES, FRAME.y, false, Image.FORMAT_RGBA8)
	await _wait(start)
	for i in ShopThumbs.FRAMES:
		if i > 0:
			await _wait(step)
		var frame := await _grab_async(FRAME)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(i * FRAME.x, 0))
	_save(strip, category, slug)
	while _game.board.is_animating():
		await get_tree().process_frame
	await _wait(0.4)


func _row() -> Array:
	return [
		{"id": "a", "side": Ranks.WHITE, "x": 3, "y": 2, "rank": "G5"},
		{"id": "b", "side": Ranks.WHITE, "x": 4, "y": 2, "rank": "SPY"},
		{"id": "c", "side": Ranks.WHITE, "x": 5, "y": 2, "rank": "FLG"},
		{"id": "d", "side": Ranks.WHITE, "x": 2, "y": 1, "rank": "PVT"},
		{"id": "e", "side": Ranks.WHITE, "x": 6, "y": 1, "rank": "COL"},
	]


## Every tile of the white half but the middle one (4, 2), so a thrown taunt lands in view.
func _crowd() -> Array:
	var list: Array = []
	var ranks := ["PVT", "SGT", "2LT", "1LT", "CPT", "MAJ", "LTC", "COL", "G1"]
	for y in range(0, 4):
		for x in Ranks.COLS:
			if Vector2i(x, y) != Vector2i(4, 2):
				list.append({"id": "c%d_%d" % [x, y], "side": Ranks.WHITE, "x": x, "y": y, "rank": ranks[(x + y) % ranks.size()]})
	return list


func _topper_slot(slug: String) -> Dictionary:
	var slot := {"kind": ToppersLibrary.kind_of(slug), "slug": slug}
	if slot["kind"] == "flag":
		slot["flag"] = FlagFactory.DEFAULT_DESIGN.duplicate()
	return slot


## Camera per category, looking at the white half (the player's side in the shop).
func _frame_camera(category: String, slug := "") -> void:
	if category == "ambience":
		if slug in ["ambience_villagers", "ambience_army_march", "ambience_parade"]:
			_aim(Vector3(-2.3, 1.9, 4.6), Vector3(-4.74, 0.3, 1.6), 40.0)  # The left rim, where they march.
		elif slug in ["ambience_birds", "ambience_bats", "ambience_butterflies", "ambience_paper_planes",
				"ambience_balloons", "ambience_ufo", "ambience_clouds", "ambience_meteors", "ambience_aurora", "ambience_fireworks"]:
			_aim(Vector3(0.0, 2.2, 7.4), Vector3(0.0, 2.3, 1.0), 56.0)  # The sky over your half.
		else:
			_aim(Vector3(0.0, 3.0, 6.2), Vector3(0.0, 1.0, 1.6), 50.0)  # Weather over your pieces.
		return
	match category:
		"chip", "aura":
			_aim(Vector3(0.0, 1.3, 3.6), Vector3(0.0, 0.33, 1.5), 32.0)
		"shape":
			_aim(Vector3(0.0, 1.25, 3.4), Vector3(0.0, 0.3, 1.5), 26.0)
		"icons":
			_aim(Vector3(0.0, 1.6, 4.3), Vector3(0.0, 0.32, 1.6), 30.0)
		"board":
			_aim(Vector3(5.6, 3.4, 7.4), Vector3(1.6, -0.2, 2.0), 36.0)
		"territory":
			_aim(Vector3(0.0, 5.2, 7.0), Vector3(0.0, 0.0, 2.0), 36.0)
		"glow":
			_aim(Vector3(3.2, 1.9, 7.0), Vector3(2.2, 0.1, 3.9), 36.0)
		"arena":
			_aim(Vector3(0.0, 6.5, 15.5), Vector3(0.0, 0.6, -1.5), 46.0)
		"trail":
			_aim(Vector3(0.5, 2.0, 4.3), Vector3(0.5, 0.3, 1.5), 30.0)
		"kill":
			_aim(Vector3(-0.5, 2.9, 3.4), Vector3(-0.5, 0.5, -0.5), 40.0)
		"taunt":
			_aim(Vector3(0.0, 3.2, 5.6), Vector3(0.0, 0.5, 1.2), 44.0)
		"topper":
			_aim(Vector3(-4.5, 1.15, 4.9), Vector3(-5.62, 0.5, 3.0), 30.0)
		"ambience":
			_aim(Vector3(0.0, 4.2, 7.4), Vector3(0.0, 0.9, 1.7), 52.0)
		_:
			_aim(Vector3(0.0, 4.0, 7.0), Vector3(0.0, 0.0, 1.5), 40.0)


func _aim(from: Vector3, at: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0


func _grab(size: Vector2i) -> Image:
	var image := _view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return image


func _grab_async(size: Vector2i) -> Image:
	await RenderingServer.frame_post_draw
	return _grab(size)


func _save(image: Image, category: String, slug: String) -> void:
	var file := ShopThumbs.path(category, slug)
	image.save_webp(ProjectSettings.globalize_path(file), true, 0.8)
	# Kept as-is in the export (decoded by ShopThumbs), not imported as a texture.
	var import := FileAccess.open(ProjectSettings.globalize_path(file + ".import"), FileAccess.WRITE)
	import.store_string("[remap]\n\nimporter=\"keep\"\n")
	import.close()
	_count += 1
	print("baked ", file)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
