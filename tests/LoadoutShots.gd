extends SmokeTestBase
## Renders random cosmetic loadouts (menu board, shop, in-game) for visual review. Real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/LoadoutShots.tscn -- --out=<dir>

var _out := "user://loadouts"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	seed(7)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	ui.show_screen("shop")
	for i in 4:
		Loadout.randomize_all()
		print("loadout %d: %s" % [i, Loadout.items])
		await _shot("shop_%d" % i, 1.6)
	ui.show_screen("title")
	Loadout.randomize_all()
	print("game loadout: ", Loadout.items)
	GameSession.start_practice(SalpakanAI.Difficulty.MEDIUM)
	await _shot("game_setup", 1.5)
	GameSession.submit_setup(board.get_setup_placements())
	await _shot("game_play", 2.0)
	main.get_node("Game3D").throw_taunt(Ranks.WHITE, "cream_pie")
	await _shot("game_taunt", 1.3)
	Loadout.reset()
	get_tree().quit()


func _shot(file: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
