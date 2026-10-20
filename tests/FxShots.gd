extends Node
## Renders every chip, board theme, territory, aura, move trail and kill effect into contact sheets
## (one PNG per category, cells in catalog order). Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/FxShots.tscn -- --out=<dir> [--only=chips,boards,...]

const CELL := Vector2i(480, 270)
const COLUMNS := 4

var out_dir := "user://fx_shots"
var only: PackedStringArray = []
var game: Game3D
var board: Board3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await _wait(0.6)
	game.rig.attract = false
	board = game.board

	if _wants("chips"):
		await _chips()
	if _wants("boards"):
		await _boards()
	if _wants("territories"):
		await _territories()
	if _wants("auras"):
		await _auras()
	if _wants("trails"):
		await _trails()
	if _wants("kills"):
		await _kills()
	if _wants("glows"):
		await _glows()
	if _wants("glowclose"):
		await _glow_close()
	get_tree().quit()


func _wants(category: String) -> bool:
	return only.is_empty() or only.has(category)


# --- Categories -------------------------------------------------------------------------------

func _chips() -> void:
	var codes: Array = Ranks.INFO.keys()
	var list: Array = []
	for i in 6:
		list.append({"id": "w%d" % i, "side": Ranks.WHITE, "rank": codes[i * 2], "x": i + 1, "y": 3})
		list.append({"id": "b%d" % i, "side": Ranks.BLACK, "rank": codes[i * 2 + 1], "x": i + 1, "y": 4})
	board.sync_pieces(list)
	await _wait(0.2)
	for piece: Piece3D in board.pieces.values():
		if piece.side == Ranks.BLACK:
			piece.face_toward(Ranks.WHITE)
	await _camera(5.2, -30.0, Vector2(0.0, 0.0))
	await _wait(0.7)
	var frames: Array[Image] = []
	for slug: String in CosmeticLibrary.PIECE_SKINS:
		board.set_piece_skin(Ranks.WHITE, slug)
		board.set_piece_skin(Ranks.BLACK, slug)
		await _wait(0.15)
		frames.append(await _grab("chip_" + slug))
	_sheet("chips", frames, CosmeticLibrary.PIECE_SKINS.keys())
	board.set_piece_skin(Ranks.WHITE, CosmeticLibrary.DEFAULT_PIECES)
	board.set_piece_skin(Ranks.BLACK, CosmeticLibrary.DEFAULT_PIECES)


func _boards() -> void:
	_full_armies()
	await _camera(12.6, -58.0, Vector2.ZERO)
	var frames: Array[Image] = []
	for slug: String in CosmeticLibrary.BOARD_THEMES:
		board.set_board_theme(slug)
		await _wait(0.15)
		frames.append(await _grab())
	_sheet("boards", frames, CosmeticLibrary.BOARD_THEMES.keys())
	board.set_board_theme(CosmeticLibrary.DEFAULT_BOARD)


func _territories() -> void:
	_full_armies()
	await _camera(12.6, -58.0, Vector2.ZERO)
	var slugs: Array = CosmeticLibrary.TERRITORIES.keys()
	var frames: Array[Image] = []
	var labels: Array = []
	for i in range(0, slugs.size(), 2):
		var w: String = slugs[i]
		var b: String = slugs[(i + 1) % slugs.size()]
		board.set_territory(Ranks.WHITE, w)
		board.set_territory(Ranks.BLACK, b)
		await _wait(0.15)
		frames.append(await _grab())
		labels.append("%s | %s" % [w, b])
	_sheet("territories", frames, labels)
	board.set_territory(Ranks.WHITE, "default")
	board.set_territory(Ranks.BLACK, "default")


func _auras() -> void:
	_full_armies()
	await _camera(6.2, -36.0, Vector2(0.0, 2.2))
	var frames: Array[Image] = []
	for slug: String in AuraFX.STYLES:
		board.set_aura(Ranks.WHITE, slug)
		board.set_aura(Ranks.BLACK, slug)
		await _wait(0.9)
		frames.append(await _grab("aura_" + slug))
	_sheet("auras", frames, AuraFX.STYLES.keys())
	board.set_aura(Ranks.WHITE, AuraFX.NONE)
	board.set_aura(Ranks.BLACK, AuraFX.NONE)


func _trails() -> void:
	board.sync_pieces([{"id": "runner", "side": Ranks.WHITE, "rank": "SPY", "x": 2, "y": 3},
		{"id": "watcher", "side": Ranks.BLACK, "rank": null, "x": 7, "y": 5}])
	await _camera(6.0, -42.0, Vector2(0.0, 0.0))
	await _wait(0.3)
	var frames: Array[Image] = []
	var runner: Piece3D = board.pieces["runner"]
	for slug: String in TrailFX.STYLES:
		board.set_trail(Ranks.WHITE, slug)
		runner.snap_to(Board3D.cell_to_local(Vector2i(1, 3)))
		await _wait(0.15)
		runner.slide_to(Board3D.cell_to_local(Vector2i(6, 4)))
		await _wait(0.42)
		frames.append(await _grab("trail_" + slug))
		await _wait(0.6)
	_sheet("trails", frames, TrailFX.STYLES.keys())


func _kills() -> void:
	_full_armies()
	await _camera(7.0, -40.0, Vector2(0.0, 0.0))
	var frames: Array[Image] = []
	var labels: Array = []
	for slug: String in KillFX.STYLES:
		KillFX.play(board, Vector3(0.0, 0.45, 0.0), slug, Color(1.0, 0.7, 0.25), 1.0)
		await _wait(0.16)
		frames.append(await _grab("kill_" + slug + "_a"))
		await _wait(0.22)
		frames.append(await _grab("kill_" + slug + "_b"))
		labels.append(slug + " @0.16")
		labels.append(slug + " @0.38")
		await _wait(1.4)
	_sheet("kills", frames, labels)


# --- Helpers ----------------------------------------------------------------------------------

func _full_armies() -> void:
	var list: Array = []
	var i := 0
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		for p: Dictionary in Ranks.random_formation(side):
			list.append({"id": "%s%d" % [side, i], "side": side, "x": p["x"], "y": p["y"], "rank": p["rank"] if side == Ranks.WHITE else null})
			i += 1
	board.sync_pieces(list)


func _camera(distance: float, pitch: float, pan: Vector2) -> void:
	var rig := game.rig
	rig._target_distance = distance
	rig._distance = distance
	rig._target_pitch = pitch
	rig._pitch = pitch
	rig._target_pan = pan
	rig._pan = pan
	rig._target_yaw = 0.0
	rig._yaw = 0.0
	await _wait(0.2)


func _grab(full_name := "") -> Image:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if full_name != "":
		image.save_png("%s/%s.png" % [out_dir, full_name])
	image.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return image


func _sheet(name: String, frames: Array[Image], labels: Array) -> void:
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create_empty(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in frames.size():
		var img := frames[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLUMNS) * CELL.x, (i / COLUMNS) * CELL.y))
	var path := "%s/%s.png" % [out_dir, name]
	sheet.save_png(path)
	print("saved %s: %s" % [path, ", ".join(labels.map(func(l: Variant) -> String: return str(l)))])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _glows() -> void:
	_full_armies()
	await _camera(13.5, -50.0, Vector2.ZERO)
	var slugs: Array = BoardGlowFX.STYLES.keys()
	var frames: Array[Image] = []
	var labels: Array = []
	for i in range(1, slugs.size(), 2):
		var w: String = slugs[i]
		var b: String = slugs[(i + 1) % slugs.size()]
		board.set_board_glow(Ranks.WHITE, w)
		board.set_board_glow(Ranks.BLACK, b)
		await _wait(0.8)
		frames.append(await _grab("glow_%s__%s" % [w, b]))
		labels.append("%s | %s" % [w, b])
	_sheet("glows", frames, labels)
	board.set_board_glow(Ranks.WHITE, BoardGlowFX.NONE)
	board.set_board_glow(Ranks.BLACK, BoardGlowFX.NONE)


func _glow_close() -> void:
	_full_armies()
	board.set_board_glow(Ranks.WHITE, "glow_fire")
	board.set_board_glow(Ranks.BLACK, "glow_neon")
	await _camera(7.0, -28.0, Vector2(0.0, 2.5))
	await _wait(0.8)
	await _grab("glow_close_front")
