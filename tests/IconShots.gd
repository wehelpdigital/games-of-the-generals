extends Node
## Close-up renders of the rank badges on real pieces (both teams, several skins, a revealed
## enemy). Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/IconShots.tscn -- --out=<dir>

var out_dir := "user://icon_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game: Game3D = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	game.rig.attract = false
	var board := game.board

	# Every rank in two rows facing white's camera, black's revealed ranks in the back rows.
	var list: Array = []
	var codes: Array = Ranks.INFO.keys()
	for i in codes.size():
		list.append({"id": "w%d" % i, "side": Ranks.WHITE, "rank": codes[i], "x": i % 8, "y": 0 if i < 8 else 1})
	for i in 8:
		list.append({"id": "b%d" % i, "side": Ranks.BLACK, "rank": null, "x": i, "y": 4})
	board.sync_pieces(list)
	await get_tree().create_timer(0.3).timeout

	for skin: String in ["pieces_classic_wood", "pieces_holo_glass", "pieces_brass_gold"]:
		board.set_piece_skin(Ranks.WHITE, skin)
		board.set_piece_skin(Ranks.BLACK, skin)
		await _close(game, 5.0, -34.0, 3.0)
		await _shot("close_%s" % skin)

	# Revealed enemies (end of match): black pieces turn their faces to the player.
	board.set_piece_skin(Ranks.WHITE, "pieces_classic_wood")
	board.set_piece_skin(Ranks.BLACK, "pieces_classic_wood")
	var reveal: Array = []
	for i in 8:
		reveal.append({"id": "b%d" % i, "rank": codes[14 - i]})
	board.reveal_ranks(reveal)
	await get_tree().create_timer(0.9).timeout
	await _close(game, 6.0, -40.0, 0.2)
	await _shot("revealed_black")

	# Normal play distance.
	await _close(game, 12.6, -58.0, 0.0)
	await _shot("play_distance")
	get_tree().quit()


func _close(game: Game3D, distance: float, pitch: float, pan_y: float) -> void:
	game.rig._target_distance = distance
	game.rig._distance = distance
	game.rig._target_pitch = pitch
	game.rig._pitch = pitch
	game.rig._target_pan = Vector2(0.0, pan_y)
	game.rig._pan = Vector2(0.0, pan_y)
	await get_tree().create_timer(0.25).timeout


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, file])
	print("saved ", file)
