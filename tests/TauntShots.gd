extends Node
## Renders every taunt for review: a wide mid-flight frame from white's camera, a close-up of the
## splat and a later "lingering" close-up, composed into contact sheets (needs a real renderer):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/TauntShots.tscn -- --out=<dir> [--only=<slug>]

const CELL := Vector2i(426, 240)

var _out := "user://taunts"
var _only := ""
var _game: Node3D
var _board: Node3D
var _main_cam: Camera3D
var _close_cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	_game = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(_game)
	await _frames(8)
	_board = _game.get_node("Board3D")
	var rig: Node3D = _game.get_node("CameraRig")
	rig.set("attract", false)
	rig.call("set_side", Ranks.WHITE)
	_main_cam = rig.get_node("Camera3D")
	_close_cam = Camera3D.new()
	_close_cam.fov = 45.0
	_game.add_child(_close_cam)
	await get_tree().create_timer(1.2).timeout

	var rows: Array = []
	var next_seed := 100
	for slug: String in TauntFX.STYLES:
		if _only != "" and slug != _only:
			continue
		rows.append(await _film(slug, Ranks.WHITE, next_seed))
		next_seed += 1
	if _only == "":
		rows.append(await _film("cream_pie", Ranks.BLACK, 7))
	for i in range(0, rows.size(), 4):
		_sheet(rows.slice(i, i + 4), "%s/sheet_%d.png" % [_out, i / 4])
	print("taunt sheets saved to ", _out)
	get_tree().quit()


func _film(slug: String, side: String, rng_seed: int) -> Array:
	for child in _board.get_children():
		if child is TauntFX:
			child.free()
	_main_cam.make_current()
	TauntFX.throw(_board, side, slug, rng_seed)
	var fx: TauntFX = _board.get_children().filter(func(c: Node) -> bool: return c is TauntFX)[-1]
	var target := _board.to_global(fx.target_local)
	var away := -1.0 if target.z < 0.0 else 1.0  # Look at the splat from the victim's end.
	_close_cam.global_position = target + Vector3(0.5, 3.3, 1.7 * away)
	_close_cam.look_at(target + Vector3(0.0, 0.25, 0.0), Vector3.UP)
	var start := Time.get_ticks_msec()
	var shots: Array = []
	await _until(start, 0.5)
	shots.append(await _grab("%s_%s_flight" % [slug, side]))
	_close_cam.make_current()
	await _until(start, 1.28)
	shots.append(await _grab("%s_%s_splat" % [slug, side]))
	await _until(start, 2.6)
	shots.append(await _grab("%s_%s_linger" % [slug, side]))
	_main_cam.make_current()
	print("filmed ", slug, " from ", side)
	return shots


func _grab(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	return img


func _sheet(rows: Array, path: String) -> void:
	var sheet := Image.create_empty(CELL.x * 3, CELL.y * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in rows[r].size():
			var img: Image = rows[r][c].duplicate()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
	sheet.save_png(path)


func _until(start: int, seconds: float) -> void:
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
