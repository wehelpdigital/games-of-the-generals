extends SmokeTestBase
## Renders every chip shape on the menu board: an overview from the player's seat and a close-up of
## own pieces (faces) next to enemy pieces (neutral side). Real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/ShapeShots.tscn -- --out=<dir> [--only=<slug>]

var _out := "user://shapes"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	seed(3)
	await boot()
	var game: Game3D = main.get_node("Game3D")
	main.get_node("UI").visible = false
	game.rig.attract = false
	game.rig.set_side(Ranks.WHITE)
	var close := Camera3D.new()
	close.fov = 38.0
	game.add_child(close)
	close.look_at_from_position(Vector3(1.2, 3.4, 6.6), Vector3(0.6, 0.2, 1.4))
	for slug: String in CosmeticCatalog.slugs("shape"):
		if _only != "" and slug != _only:
			continue
		Loadout.equip("shape", slug)
		game._opponent_loadout = {"shape": slug, "chip": "pieces_candy"}
		game.refresh_cosmetics()
		game.rig.camera.make_current()
		await _shot("%s_overview" % slug, 0.6)
		close.make_current()
		await _shot("%s_close" % slug, 0.3)
	Loadout.reset()
	get_tree().quit()


func _shot(file: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
