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
		if fx != null and slug in ["ambience_army_march", "ambience_parade", "ambience_villagers"]:
			fx.set("_time", 7.0)  # Walkers: well along the rim instead of just popping in.
	if not ShopThumbs.is_clip(category):
		_save(_grab(STILL), category, slug)
		return
	# Clips: start the demo, then grab frames at set moments. Frame ShopThumbs.POSTER (the card's
	# still) always lands on the peak: the explosion, the splat, the prop at full size.
	var times: Array[float] = []
	for i in ShopThumbs.FRAMES:
		times.append(i * (0.3 if category == "ambience" else 0.12))
	match category:
		"trail":
			_game.board.apply_move_result({"piece_id": "a", "from": {"x": 4, "y": 2}, "to": {"x": 5, "y": 2}, "clash": null})
			_game.board.apply_move_result({"piece_id": "a", "from": {"x": 5, "y": 2}, "to": {"x": 4, "y": 2}, "clash": null})
			for i in ShopThumbs.FRAMES:
				times[i] = 0.08 + i * 0.11
		"kill":
			_game.board.apply_move_result({"piece_id": "hero", "from": {"x": 3, "y": 4}, "to": {"x": 4, "y": 4},
				"clash": {"defender_id": "foe", "outcome": "attacker", "eliminated": ["foe"]}})
			times = _kill_times(slug)
		"taunt":
			TauntFX.throw(_game.board, Ranks.BLACK, slug, 7)
			# Close in on wherever this throw lands.
			for child in _game.board.get_children():
				if child is TauntFX and not child.is_queued_for_deletion():
					var land: Vector3 = child.target_local
					_aim(land + Vector3(0.0, 3.4, 2.1), land + Vector3(0.0, 0.2, -0.1), 27.0)
			times = [0.45, 0.72, 0.92, 1.12, 1.28, 1.48, 1.72, 2.02]
	var frames: Array[Image] = []
	var began := Time.get_ticks_msec() / 1000.0
	for i in ShopThumbs.FRAMES:
		var wait := times[i] - (Time.get_ticks_msec() / 1000.0 - began)
		await _wait(maxf(wait, 0.0))
		frames.append(await _grab_async(FRAME))
	if category == "ambience":
		# Ambience never peaks on cue: turn the loop so its busiest frame becomes the card still.
		var busiest := _busiest(frames)
		var poster: int = ShopThumbs.POSTER.get(category, 0)
		var turned: Array[Image] = []
		for i in frames.size():
			turned.append(frames[(i + busiest - poster + frames.size()) % frames.size()])
		frames = turned
	var strip := Image.create_empty(FRAME.x * ShopThumbs.FRAMES, FRAME.y, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, FRAME), Vector2i(i * FRAME.x, 0))
	_save(strip, category, slug)
	while _game.board.is_animating():
		await get_tree().process_frame
	await _wait(0.4)


## The frame that differs most from the clip's average look: the one with the most going on
## (a firework mid-burst, the flock overhead, the column of soldiers in view).
func _busiest(frames: Array[Image]) -> int:
	var step := 4
	var mean := {}
	for f in frames:
		for y in range(0, FRAME.y, step):
			for x in range(0, FRAME.x, step):
				var key := y * FRAME.x + x
				mean[key] = mean.get(key, Color(0, 0, 0, 0)) + f.get_pixel(x, y) / float(frames.size())
	var best := 0
	var best_score := -1.0
	for i in frames.size():
		var score := 0.0
		for y in range(0, FRAME.y, step):
			for x in range(0, FRAME.x, step):
				var a: Color = frames[i].get_pixel(x, y)
				var m: Color = mean[y * FRAME.x + x]
				score += absf(a.r - m.r) + absf(a.g - m.g) + absf(a.b - m.b)
		if score > best_score:
			best_score = score
			best = i
	return best


## When to grab each kill frame: the build-up, then the peak on frame ShopThumbs.POSTER["kill"]
## (just after impact), then the aftermath. The clash starts once the attacker's lunge lands.
func _kill_times(slug: String) -> Array[float]:
	var clash := 0.33
	var impact: float = KillFX.ACTIONS.get(slug, {}).get("impact", 0.0)
	var times: Array[float] = []
	if impact > 0.0:
		times.append_array([clash + impact * 0.2, clash + impact * 0.5, clash + impact * 0.8])
	else:
		times.append_array([clash - 0.25, clash - 0.12, clash + 0.0])
	var peak := clash + impact + 0.1
	times.append(peak)
	for after: float in [0.16, 0.32, 0.52, 0.8]:
		times.append(peak + after)
	return times


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
			# The clash: the winner lunges from x -1 toward the loser at the origin of row 4 (z -0.5).
			_aim(Vector3(-0.3, 1.9, 1.85), Vector3(-0.3, 0.68, -0.5), 38.0)
		"taunt":
			# Where the throw lands: the empty middle tile of the white half.
			_aim(Vector3(0.0, 3.7, 3.5), Vector3(0.0, 0.25, 1.4), 34.0)
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
