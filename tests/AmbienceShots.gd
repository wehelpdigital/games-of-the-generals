extends Node
## Screenshots of every ambience on the player's half of the board (opponent plain). Needs a real
## renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/AmbienceShots.tscn -- --out=<dir> [--only=slug,slug]

var _out := "user://ambience_shots"
var _only: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	var game: Game3D = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rig.attract = false
	var plain := Loadout.complete({})
	for slug: String in CosmeticCatalog.slugs("ambience"):
		if slug == AmbienceFX.NONE or (not _only.is_empty() and slug not in _only):
			continue
		var look := plain.duplicate(true)
		look["ambience"] = slug
		game.set_showcase(look, plain)
		await get_tree().create_timer(2.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join(slug + ".png"))
		print("shot ", slug)
	get_tree().quit()
