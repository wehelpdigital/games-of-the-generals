extends Node
## Renders the 3D scene under several cosmetic combinations and saves PNGs, for checking the look.
## Needs a real renderer (not --headless):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/Screenshot.tscn -- --out=<dir> [--only=<name>]

const COMBOS := [
	["mahogany_classic", "board_mahogany", "pieces_classic_wood", "pieces_classic_wood"],
	["mahogany_brass", "board_mahogany", "pieces_brass_gold", "pieces_brass_gold"],
	["marble_classic", "board_marble_slate", "pieces_classic_wood", "pieces_classic_wood"],
	["marble_holo", "board_marble_slate", "pieces_holo_glass", "pieces_holo_glass"],
	["steel_brass", "board_military_steel", "pieces_brass_gold", "pieces_brass_gold"],
	["steel_classic", "board_military_steel", "pieces_classic_wood", "pieces_classic_wood"],
	["neon_holo", "board_cyber_neon", "pieces_holo_glass", "pieces_holo_glass"],
	["neon_brass", "board_cyber_neon", "pieces_brass_gold", "pieces_brass_gold"],
]

var out_dir := ""
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var game: Game3D = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await _wait(1.2)

	for combo: Array in COMBOS:
		if only != "" and not combo[0].begins_with(only):
			continue
		game.board.set_board_theme(combo[1])
		game.board.set_piece_skin(Ranks.WHITE, combo[2])
		game.board.set_piece_skin(Ranks.BLACK, combo[3])
		await _wait(0.3)
		_shot(combo[0])

	if only == "" or "closeup".begins_with(only) or only == "clash":
		game.board.set_board_theme("board_mahogany")
		game.board.set_piece_skin(Ranks.WHITE, "pieces_classic_wood")
		game.board.set_piece_skin(Ranks.BLACK, "pieces_classic_wood")
		game.rig._target_distance = 6.0
		game.rig._distance = 6.0
		game.rig._target_pitch = -38.0
		game.rig._pitch = -38.0
		await _wait(0.4)
		_shot("closeup")

		# Selection highlight + valid-move/attack markers on a front-row piece.
		var board := game.board
		board.set_mode(Board3D.Mode.PLAY, Ranks.WHITE, true)
		var front: Piece3D = null
		for piece: Piece3D in board.pieces.values():
			if piece.side == Ranks.WHITE and (front == null or piece.cell.y > front.cell.y):
				front = piece
		if front != null:
			board._last_move = [Vector2i(front.cell.x, front.cell.y - 1), front.cell] as Array[Vector2i]
			board._select(front)
			var hovered: Piece3D = board.piece_at(front.cell + Vector2i(1, 0))
			if hovered == null:
				hovered = board.piece_at(front.cell + Vector2i(-1, 0))
			if hovered != null and hovered.side == Ranks.WHITE:
				hovered.set_highlight(Piece3D.Highlight.HOVER)
			await _wait(0.4)
			_shot("markers")
			board._clear_selection()
			await _wait(0.3)
		ClashFX.burst(game.board, Board3D.cell_to_local(Vector2i(4, 3)) + Vector3(0, 0.45, 0), Color(1.0, 0.62, 0.25))
		await _wait(0.09)
		_shot("clash_early")
		await _wait(0.12)
		_shot("clash_mid")

	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	var path := out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
