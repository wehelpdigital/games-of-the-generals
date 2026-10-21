extends "res://tests/DashboardShots.gd"
## Renders the economy UI with fake data for visual review: the daily reward calendar (before and
## after claiming), the missions card (daily and weekly), the achievements screen and the rewards
## strip on a game-over card. API calls go to Profile.mock / Economy.mock; no server needed.
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/EconomyShots.tscn -- --out=<dir>
## Phone: --resolution 390x844 (adds a "phone_" prefix). Headless it still walks every step.

var _daily: Dictionary
var _missions: Dictionary
var _claimed := false


func _ready() -> void:
	_out = "user://screenshots/economy"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await boot()
	var view := get_viewport().get_visible_rect().size
	_prefix = "phone_" if view.y > view.x else ""
	var ui: UIRoot = main.get_node("UI")

	ApiManager.base_url = "http://127.0.0.1:9"
	ApiManager.token = "fake-token"
	ApiManager.user = {"id": ME, "username": "KapitanTikbalang", "credits": 4850}
	_fake_pictures()
	_profile = _fake_profile()
	_profile["title"] = "Shadow Assassin"
	Profile.mock = _mock
	Profile._set_data(_profile.duplicate(true), true)
	Profile.tiers = _fake_tiers()
	Economy.mock = _economy
	_daily = _fake_daily(false)
	_missions = _fake_missions()
	ServerConfig.values["dashboard_theme"] = "classic"

	# Opening the dashboard pops the daily calendar up once.
	ui.show_screen("dashboard")
	await _shot("daily_popup", 1.4)
	check(_find_button(ui, "Claim reward") != null, "the daily calendar pops up with a Claim button")
	var claim := _find_button(ui, "Claim reward")
	if claim:
		claim.pressed.emit()
	await _shot("daily_claimed", 1.6)
	check(_claimed, "claiming calls the server")
	ui.close_dialog()

	ui.show_screen("dashboard")
	await _shot("dash_missions", 1.2)
	var panel := _find_missions_panel(ui)
	check(panel != null, "the missions card is on the dashboard")
	if panel:
		panel.call("_pick", "weekly")
		await _shot("dash_missions_weekly", 0.6)
		panel.call("_pick", "daily")

	ui.show_screen("achievements")
	await _shot("achievements", 1.2)
	check(ui.current_name == "achievements", "achievements screen stays open")

	# A practice win: the game-over card counts the rewards.
	ui.show_screen("dashboard")
	await frames(2)
	GameSession.start_practice(SalpakanAI.Difficulty.HARD)
	await frames(10)
	GameSession.submit_setup(board.get_setup_placements())
	await frames(20)
	GameSession._emit_finished({"winner": GameSession.my_side(), "end_reason": "flag_captured", "pieces": [], "clashes": []})
	await _shot("game_over_rewards", 3.2)
	check(int(Economy.last_rewards.get("credits", 0)) == 10, "practice win reported and summarised")
	ui.close_dialog()
	GameSession.leave()

	ApiManager.token = ""
	ApiManager.user = {}
	print("\n%d screenshots in %s" % [_shots, ProjectSettings.globalize_path(_out)])
	finish()


func _economy(method: int, path: String, _body: Variant) -> Dictionary:
	var data: Variant = null
	if path == "/api/rewards/daily":
		data = _daily
	elif path == "/api/rewards/daily/claim":
		_claimed = true
		_daily = _fake_daily(true)
		data = {"reward": {"day": 3, "credits": 100, "item": null}, "credits": 4950, "status": _daily, "achievements": []}
	elif path == "/api/missions":
		data = _missions
	elif path.begins_with("/api/achievements"):
		data = _fake_achievements()
	elif path == "/api/practice/result":
		data = {"counted": true, "credits_awarded": 10, "credits": 4960,
			"missions": [_mission(91, "beat_general", "Topple the General", "Beat the General AI", "1f451", 1, 1, 150, 25, true, false),
				_mission(92, "weekly_general_ai_3", "AI Nemesis", "Beat the General AI 3 times", "1f916", 3, 2, 700, 100, false, false)],
			"achievements": [{"key": "ai_slayer", "name": "AI Slayer", "desc": "Beat the General AI 10 times", "icon": "1f916"}]}
	if data == null:
		return {"ok": false, "status": 404, "data": {}, "error": "Not found (mock)."}
	return {"ok": true, "status": 200, "data": data, "error": ""}


func _fake_daily(claimed: bool) -> Dictionary:
	var calendar := []
	var credits := [50, 75, 100, 125, 150, 200, 300]
	for i in 7:
		calendar.append({"day": i + 1, "credits": credits[i], "item": {"rarity": "common", "mystery": true} if i == 6 else null,
			"claimed": i < 2 or (claimed and i == 2), "today": i == 2})
	return {"streak": 3 if claimed else 2, "best_streak": 5, "day": 3, "claimed_today": claimed, "calendar": calendar,
		"next_reset_at": _iso_in_hours(9)}


func _fake_missions() -> Dictionary:
	return {"enabled": true,
		"daily": {"resets_at": _iso_in_hours(9), "rerolls_left": 1, "missions": [
			_mission(1, "win_online_1", "Victory!", "Win an online match", "1f3c6", 1, 1, 80, 15, true, false),
			_mission(2, "spy_strike", "Silent Strike", "Take out a General with your Spy", "1f440", 1, 0, 120, 20, false, false),
			_mission(3, "chatty", "Say Hi", "Send 3 chat messages", "1f4ac", 3, 3, 40, 5, true, true)]},
		"weekly": {"resets_at": _iso_in_hours(80), "missions": [
			_mission(4, "weekly_wins_10", "Ten-Win Week", "Win 10 online matches", "1f3c6", 10, 6, 600, 100, false, false),
			_mission(5, "weekly_flags_3", "Flag Collector", "Capture 3 enemy Flags", "1f6a9", 3, 1, 600, 100, false, false),
			_mission(6, "weekly_dailies_10", "Mission Machine", "Claim 10 daily missions", "1f4af", 10, 4, 800, 120, false, false)]}}


func _mission(id: int, key: String, title: String, desc: String, icon: String, target: int, progress: int,
		credits: int, xp: int, completed: bool, claimed: bool) -> Dictionary:
	return {"id": id, "key": key, "period": "weekly" if key.begins_with("weekly") else "daily", "title": title, "desc": desc,
		"icon": icon, "target": target, "progress": progress, "credits": credits, "xp": xp, "completed": completed, "claimed": claimed}


func _fake_achievements() -> Dictionary:
	var rows := [
		["first_blood", "First Blood", "Win your first online match", "1f3c6", 1, 1, 100, 20, null, true],
		["wins_10", "Field Tested", "Win 10 online matches", "1f3c6", 10, 10, 300, 50, "Field Tested", true],
		["spy_20", "Shadow Assassin", "Take out 20 Generals with Spies", "1f480", 20, 20, 1200, 200, "Shadow Assassin", true],
		["streak_5", "On Fire", "Win 5 online matches in a row", "1f525", 5, 3, 600, 100, "On Fire", false],
		["wins_50", "Veteran", "Win 50 online matches", "1f396", 50, 31, 800, 120, "Veteran", false],
		["flag_25", "Flag Snatcher", "Capture 25 enemy Flags", "1f6a9", 25, 9, 900, 150, "Flag Snatcher", false],
		["guild", "Brothers in Arms", "Join or found a guild", "1f91d", 1, 1, 200, 30, "Squadmate", true],
		["collector_25", "Collector", "Own 25 shop items", "1f389", 25, 12, 500, 60, "Collector", false],
		["ai_slayer", "AI Slayer", "Beat the General AI 10 times", "1f916", 10, 4, 800, 120, "AI Slayer", false],
	]
	var data := []
	for r: Array in rows:
		data.append({"key": r[0], "name": r[1], "desc": r[2], "icon": r[3], "target": r[4], "progress": r[5], "credits": r[6],
			"xp": r[7], "title": r[8], "unlocked": r[9], "unlocked_at": "2026-10-20T10:00:00Z" if r[9] else null})
	return {"data": data, "unlocked": 4, "total": 35, "titles": ["Field Tested", "Shadow Assassin", "Squadmate"], "title": "Shadow Assassin"}


func _iso_in_hours(hours: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system() + hours * 3600.0)) + "Z"


func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text == text and (child as Button).is_visible_in_tree():
			return child
		var found := _find_button(child, text)
		if found:
			return found
	return null


func _find_missions_panel(root: Node) -> Node:
	for child in root.get_children():
		if child.get_script() == preload("res://ui/dashboard/MissionsPanel.gd"):
			return child
		var found := _find_missions_panel(child)
		if found:
			return found
	return null
