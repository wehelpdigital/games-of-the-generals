extends SmokeTestBase
## Screenshots of Boot Camp for visual review: the title nudge, the Boot Camp and How to Play
## pages, the coach during drills (marks, notes, the formation, cards, the clock, a finished
## drill), the graduation medal, the in-match Rules card and the dashboard nudge. Needs a real
## renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/TutorialShots.tscn -- --out=<dir>
## Phones and tablets: add --device=phone_portrait (with --resolution 390x844) and so on. --audit
## prints anything that runs off the screen (LayoutAudit).

const W := Ranks.WHITE

var _out := "user://tutorial_shots"
var _audit := false
var ui: UIRoot


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--audit":
			_audit = true
	DirAccess.make_dir_recursive_absolute(_out)
	TutorialProgress.reset()
	await boot()
	ui = main.get_node("UI")
	await _shot("01_title_nudge", 1.6)
	ui.show_screen("boot_camp")
	await _shot("02_boot_camp", 0.8)
	ui.show_screen("how_to_play")
	await _shot("03_how_to_play", 0.8)
	var page: Dictionary = ui.screen("how_to_play").get("_page")
	(page["scroll"] as ScrollContainer).scroll_vertical = 520
	await _shot("04_how_to_play_ladder", 0.4)

	GameSession.start_lesson("goal")
	await _settle()
	await _shot("10_goal_marks", 0.8)
	await _play_step()
	await get_tree().create_timer(0.9).timeout
	await _shot("11_goal_reaction", 0.2)
	await _settle()
	await _shot("12_goal_flag_march", 0.6)

	GameSession.start_lesson("ranks")
	await _settle()
	await _shot("20_ranks_note", 0.6)
	GameSession.tutorial.next_pressed()
	await _settle()
	await _shot("21_ranks_attack", 0.4)

	GameSession.start_lesson("spy")
	await _settle()
	await _play_step()
	await _settle()
	await _shot("30_spy_after", 0.4)

	GameSession.start_lesson("setup")
	await _settle()
	await _shot("40_setup", 0.8)

	GameSession.start_lesson("powerups")
	await _settle()
	await _shot("50_powerups", 2.0)  # After the opening deal turns the cards up.

	GameSession.start_lesson("clock")
	await _settle()
	await _shot("60_clock", 0.6)

	GameSession.start_lesson("moving")
	await _settle()
	var guard := 0
	while GameSession.tutorial and not GameSession.tutorial.done and guard < 20:
		guard += 1
		await _play_step()
		await _settle()
	await _shot("70_drill_complete", 0.8)

	var rules: Node = _hud_widget("res://ui/hud/RulesHelp.gd")
	rules.call("_open")
	await _shot("80_rules_card", 0.6)
	ui.close_dialog()

	GameSession.start_lesson(TutorialLessons.GRADUATION_ID)
	await _settle()
	await _shot("90_graduation", 0.8)
	var arbiter: LocalArbiter = GameSession._arbiter
	arbiter._finish(W, "flag_captured")
	GameSession._practice_load("finished", GameSession.version + 1)
	await _shot("91_graduated", 1.0)
	ui.close_dialog()
	await _shot("92_graduated_coach", 0.4)

	GameSession.leave()
	TutorialProgress.reset()
	await _dashboard()
	TutorialProgress.reset()
	finish()


## The dashboard nudge, with a pretend logged-in player (requests fail fast).
func _dashboard() -> void:
	ApiManager.base_url = "http://127.0.0.1:9"
	ApiManager.token = "fake-token"
	ApiManager.user = {"id": 7, "username": "CadetJuan", "credits": 500}
	Profile.mock = func(_method: int, _path: String, _body: Variant) -> Dictionary: return {"ok": false, "status": 0, "data": {}, "error": "offline"}
	Profile._set_data({"id": 7, "username": "CadetJuan", "rank_tier": 0, "xp": 20, "credits": 500}, true)
	ui.game.show_attract()
	ui.show_screen("dashboard")
	await _shot("95_dashboard_nudge", 1.4)


func _play_step() -> void:
	var run := GameSession.tutorial
	var s := run.step()
	match str(s.get("do", "")):
		"note":
			run.next_pressed()
		"move":
			await tap_move(run._cell(s["piece"]), TutorialRun._xy(s["to"]))
		"any":
			var move: Dictionary = GameSession._arbiter.legal_moves(W)[0]
			await tap_move(move["from"], move["to"])


func _settle() -> void:
	await frames(2)
	await wait_until(_ready_for_player, 12.0)
	await frames(2)


func _ready_for_player() -> bool:
	var run := GameSession.tutorial
	if run == null:
		return true
	if run.done:
		return not board.is_animating()
	var ready_turn := GameSession.status() == "setup" or GameSession.is_my_turn()
	return not run.waiting and ready_turn and not board.is_animating()


func _shot(file_name: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name + ".png"))
	if _audit:
		LayoutAudit.report(ui, file_name)
	print("shot ", file_name)


## A HUD widget by script: in its slot, or moved out of it (the coach on phones).
func _hud_widget(path: String) -> Control:
	for node in ui.screen("hud").find_children("*", "Control", true, false):
		if node.get_script() and (node.get_script() as Script).resource_path == path:
			return node
	return null
