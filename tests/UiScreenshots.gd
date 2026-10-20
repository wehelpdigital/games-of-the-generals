extends SmokeTestBase
## Renders each UI screen to PNG for visual review. Needs a real renderer (not --headless):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/UiScreenshots.tscn -- --out=<dir>

var _out := "user://screenshots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	await _shot("01_title", 1.2)
	ui.show_screen("ai_setup")
	await _shot("02_ai_setup")
	ui.show_screen("auth", {"next": "title"})
	await _shot("03_auth")
	ui.show_screen("leaderboard")
	await _shot("04_leaderboard", 2.5)
	ui.show_screen("shop")
	await _shot("05_shop", 2.5)
	ui.show_screen("title")
	GameSession.start_practice(SalpakanAI.Difficulty.HARD)
	await _shot("06_hud_setup", 1.0)
	GameSession.submit_setup(board.get_setup_placements())
	await _shot("07_hud_play", 1.0)
	# A live battle clip as the defender sees it: their attacker stays a "?".
	ui.play_clash({"attacker": {"side": Ranks.BLACK, "rank": ""}, "defender": {"side": Ranks.WHITE, "rank": "G5"},
		"outcome": "attacker", "viewer": Ranks.WHITE, "reveal": false})
	await _shot("07b_clip_live", 1.25)
	await get_tree().create_timer(1.5).timeout
	GameSession.resign()
	await _shot("08_game_over", 2.5)
	# Battle recap with every rank revealed, and one replayed clip.
	var hud: Screen = ui.screen("hud")
	hud._last_info = {"you_won": false, "end_reason": "flag_captured", "clashes": [
		{"move_number": 9, "outcome": "attacker", "attacker": {"side": Ranks.WHITE, "rank": "SPY"}, "defender": {"side": Ranks.BLACK, "rank": "G5"}},
		{"move_number": 12, "outcome": "attacker", "attacker": {"side": Ranks.BLACK, "rank": "PVT"}, "defender": {"side": Ranks.WHITE, "rank": "SPY"}},
		{"move_number": 15, "outcome": "both", "attacker": {"side": Ranks.WHITE, "rank": "CPT"}, "defender": {"side": Ranks.BLACK, "rank": "CPT"}},
		{"move_number": 20, "outcome": "defender", "attacker": {"side": Ranks.BLACK, "rank": "MAJ"}, "defender": {"side": Ranks.WHITE, "rank": "COL"}},
	]}
	hud._show_recap()
	await _shot("08b_recap", 0.8)
	ui.play_clash(hud._recap_clip(hud._last_info["clashes"][0]))
	await _shot("08c_recap_clip", 1.3)
	await get_tree().create_timer(1.5).timeout
	if ApiManager.base_url != ApiManager.DEFAULT_BASE_URL:
		await _lobby_shot(ui)
	get_tree().quit()


## Only against a local backend: two throwaway accounts, one hosting, so the lobby has a row.
func _lobby_shot(ui: UIRoot) -> void:
	var stamp := str(Time.get_ticks_usec()).right(6)
	var host := HTTPRequest.new()
	add_child(host)
	host.request(ApiManager.base_url + "/api/register", PackedStringArray(["Accept: application/json", "Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify({"username": "luna" + stamp, "email": "luna%s@example.test" % stamp,
		"password": "password123", "password_confirmation": "password123"}))
	var registered: Array = await host.request_completed
	var token: String = JSON.parse_string((registered[3] as PackedByteArray).get_string_from_utf8())["token"]
	host.request(ApiManager.base_url + "/api/games/create", PackedStringArray(["Accept: application/json", "Authorization: Bearer " + token]),
		HTTPClient.METHOD_POST)
	await host.request_completed
	await ApiManager.register("aguinaldo" + stamp, "agui%s@example.test" % stamp, "password123", "password123")
	ui.back_to_menu()
	await _shot("09_title_logged_in", 1.0)
	ui.show_screen("lobby")
	await _shot("10_lobby", 2.5)
	DirAccess.remove_absolute(ApiManager.AUTH_FILE)


func _shot(file: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
