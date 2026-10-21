extends Node
## Frames from kill effects: a white piece attacks the black piece in front of it and wins, so the
## white side's kill effect plays. Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 960x600 res://tests/KillShots.tscn -- --out=<dir> [--only=slug] [--actions]

var _out := "user://kill_shots"
var _only := ""
var _actions_only := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg == "--actions":
			_actions_only = true
	DirAccess.make_dir_recursive_absolute(_out)
	var game: Game3D = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rig.attract = false
	game.set_showcase(Loadout.complete({}), Loadout.complete({}))
	var board := game.board
	for slug: String in CosmeticCatalog.slugs("kill"):
		if (_only != "" and slug != _only) or (_actions_only and not KillFX.is_action(slug)):
			continue
		board.sync_pieces([
			{"id": "hero", "side": Ranks.WHITE, "x": 3, "y": 4, "rank": "G5"},
			{"id": "foe", "side": Ranks.BLACK, "x": 4, "y": 4, "rank": null},
			{"id": "w2", "side": Ranks.WHITE, "x": 2, "y": 2, "rank": "PVT"},
			{"id": "b2", "side": Ranks.BLACK, "x": 6, "y": 5, "rank": null},
		])
		board.set_kill_effect(Ranks.WHITE, slug)
		await get_tree().create_timer(0.4).timeout
		# A sideways attack, so the play camera sees both the winner and the loser.
		board.apply_move_result({"piece_id": "hero", "from": {"x": 3, "y": 4}, "to": {"x": 4, "y": 4},
			"clash": {"defender_id": "foe", "outcome": "attacker", "eliminated": ["foe"]}})
		var impact: float = KillFX.ACTIONS.get(slug, {}).get("impact", 0.0)
		var times := [0.32 + 0.12, 0.32 + maxf(0.15, impact - 0.08), 0.32 + impact + 0.15, 0.32 + impact + 0.6]
		if _only != "":
			times = [0.42, 0.6, 0.75, 0.9, 1.1, 1.35, 1.6, 1.85]
		var start := Time.get_ticks_msec() / 1000.0
		for i in times.size():
			var wait: float = times[i] - (Time.get_ticks_msec() / 1000.0 - start)
			if wait > 0.0:
				await get_tree().create_timer(wait).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%d.png" % [slug, i]))
		while board.is_animating():
			await get_tree().process_frame
		await get_tree().create_timer(0.8).timeout
		print("shot ", slug)
	get_tree().quit()
