extends SmokeTestBase
## Screenshots of the pre-game powerup rules (GameOptions): Select with the picker, Random and Off
## before Play vs AI, a locked room's join dialog with the host's rules, and the phone layout.
## Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/GameOptionsShots.tscn -- --out=<dir>

var _out := "user://game_options_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	ui.set_setting(GameOptions.SETTING, PowerupLibrary.MODE_SELECT)
	ui.show_screen("ai_setup")
	ui.screen("ai_setup").call("_start", SalpakanAI.Difficulty.EASY)
	await _shot("01_ai_select", 0.8)
	var options := _options(ui)
	check(options != null and options.mode() == "select", "the dialog opens on the remembered choice")
	check(options.picks().size() == PowerupLibrary.MAX_SLOTS and options.problem() == "", "Select starts with a full hand of 5")
	options._toggle_pick(options.picks()[0])
	check(options.problem() != "", "4 picks: the game can't start yet")
	await _shot("02_ai_select_four", 0.4)
	options._set_mode(PowerupLibrary.MODE_RANDOM)
	await _shot("03_ai_random", 0.4)
	options._set_on(false)
	check(options.mode() == "off", "Off")
	await _shot("04_ai_off", 0.4)
	options._set_on(true)
	check(options.mode() == "random", "On goes back to the last style")
	ui.close_dialog()

	ui.show_screen("rooms")
	ui.screen("rooms").call("join_room", {"id": 7, "name": "Friday Fight", "has_password": true, "powerup_mode": "random",
		"host": {"username": "Mayumi"}})
	await _shot("05_join_locked_room", 0.8)
	var fixed := _options(ui)
	check(fixed != null and fixed.mode() == "random", "joining shows the host's rules")
	ui.close_dialog()

	get_window().size = Vector2i(720, 1280)
	await get_tree().create_timer(0.5).timeout
	ui.show_screen("ai_setup")
	ui.screen("ai_setup").call("_start", SalpakanAI.Difficulty.EASY)
	var phone := _options(ui)
	if phone:
		phone._set_mode(PowerupLibrary.MODE_SELECT)
	await _shot("06_phone_select", 1.0)
	finish()


func _options(ui: UIRoot) -> GameOptions:
	var found := ui.find_children("*", "GameOptions", true, false)
	for node in found:
		if node is GameOptions and not node.is_queued_for_deletion():
			return node
	return null


func _shot(file: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	wait = 0.0
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
