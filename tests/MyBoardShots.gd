extends SmokeTestBase
## My Board screenshots and checks: the locker per category, equipping from it (the board and the
## saved loadout change), toppers and the flag editor, trying an item on without equipping it, and
## leaving. Run at desktop size and as a phone (--device=phone_portrait --resolution 390x844).
## Real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/MyBoardShots.tscn -- --out=<dir> [--audit]

var _out := "user://my_board"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	ApiManager.base_url = "http://127.0.0.1:9"  # Offline: every request fails fast.
	seed(5)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	var board: Screen = ui.screen("my_board")
	ApiManager.token = "offline-test"
	ApiManager.user = {"username": "tester", "credits": 1200}
	Loadout.reset()
	ui.show_screen("my_board")
	await _shot("board_arena", 1.4)
	check(ui.game.visible and not ui.game.rig.attract, "My Board shows the board with a still camera")

	board.call("_switch", "chip")
	await _shot("board_chip", 1.0)
	board.call("_pick", "chip", "pieces_jade")
	await frames(5)
	check(Loadout.get_item("chip") == "pieces_jade", "tapping a chip wears it")
	board.call("_switch", "shape")
	board.call("_pick", "shape", "shape_wish_orb")
	await _shot("board_shape_worn", 1.2)
	board.call("_switch", "aura")
	board.call("_pick", "aura", "aura_flame")
	await _shot("board_aura", 1.2)
	board.call("_switch", "kill")
	board.call("_pick", "kill", "kill_bazooka")
	await _shot("board_kill_demo", 1.0)
	board.call("_switch", "ambience")
	board.call("_pick", "ambience", "ambience_snowfall")
	await _shot("board_ambience", 1.6)
	board.call("_switch", "taunt")
	await _shot("board_taunts", 0.8)

	board.call("_switch", "topper")
	board.call("_place_topper", "topper_cactus")
	board.call("_place_topper", "topper_flag_gold")  # A flag opens the flag editor.
	await _shot("board_flag_editor", 1.2)
	check(board.get("_editor") != null, "placing a flag opens the flag editor")
	(board.get("_editor") as FlagEditor).done.emit()
	await _shot("board_toppers", 1.0)
	check((Loadout.get_toppers()["slots"] as Array).size() == 2, "two toppers placed")

	# Try on: shown on the board, not equipped.
	ui.show_screen("my_board", {"try_category": "arena", "try_slug": "lava_pit"})
	await _shot("board_try_on", 1.6)
	check(Loadout.get_item("arena") != "lava_pit", "trying an arena on doesn't equip it")
	check((board.get("_try_bar") as Control).visible, "the try-on bar shows")
	board.call("_end_try")

	# A Featured Board's whole look, then "Wear the set" (everything is owned in test mode).
	ui.show_screen("my_board", {"try_look": "fb_great_wave"})
	await _shot("board_try_look", 1.8)
	check(Loadout.get_item("arena") != "great_wave_coast", "trying a whole look on doesn't equip it")
	board.call("_wear_tried")
	await _shot("board_wore_set", 1.4)
	check(Loadout.get_item("kill") == "kill_wave_crash" and Loadout.get_item("arena") == "great_wave_coast", "Wear the set equips the whole look")
	check((Loadout.get_toppers()["slots"] as Array).size() == 3, "the set's three toppers are placed")
	Loadout.reset()

	if (board.get("_fold_button") as Button).visible:
		board.call("_toggle_fold")
		await _shot("board_folded", 0.8)
		board.call("_toggle_fold")

	ui.show_screen("title")
	await frames(5)
	check(ui.game.rig.screen_shift == Vector2.ZERO and ui.game.rig.attract, "leaving My Board puts the menu camera back")
	Loadout.reset()
	ApiManager.token = ""
	finish()


func _shot(file: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
