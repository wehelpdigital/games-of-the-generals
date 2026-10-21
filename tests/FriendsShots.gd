extends SmokeTestBase
## Renders the friends features with fake data for visual review, and checks the in-match HUD
## layout (the turn banner never covers the player chips; HUD slots shrink back with their
## content). Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/FriendsShots.tscn -- --out=<dir> [--audit]
## Phones: --resolution 390x844 with --device=phone_portrait (or 844x390, phone_landscape) after `--`.

var _out := "user://friends_shots"
var _prefix := "desktop_"
var ui: UIRoot

const ME := {"id": 42, "username": "kapitan", "rank_tier": 4, "xp": 1240, "credits": 2500, "elo": 1288}
const MARIA := {"id": 7, "username": "maria_clara", "rank_tier": 6, "avatar_url": null, "title": "Sharpshooter"}
const LONG := {"id": 8, "username": "HeneralLunaNgBayan", "rank_tier": 9, "avatar_url": null, "elo": 1640}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg.begins_with("--device="):
			_prefix = arg.trim_prefix("--device=") + "_"
	DirAccess.make_dir_recursive_absolute(_out)
	ApiManager.base_url = "http://127.0.0.1:9"  # Offline: every request fails fast.
	await boot()
	ui = main.get_node("UI")
	ApiManager.token = "offline-shots"
	ApiManager.user = ME.duplicate()
	Social.friends = _fake_friends()

	# Friends screen: each tab.
	ui.show_screen("friends")
	await _shot("01_friends", 0.8)
	var screen: Screen = ui.screen("friends")
	screen.call("_switch", "requests")
	await _shot("02_requests", 0.5)
	screen.set("_searched", "mar")
	screen.set("_results", [
		MARIA.merged({"relation": "friend"}), {"id": 21, "username": "marco_polo", "rank_tier": 1, "relation": "none"},
		{"id": 22, "username": "MariaMakiling", "rank_tier": 3, "relation": "outgoing"},
		{"id": 23, "username": "mark.s", "rank_tier": 0, "relation": "incoming"},
	])
	screen.call("_switch", "add")
	await _shot("03_add_friend", 0.5)
	screen.call("_switch", "recent")
	await _shot("04_played_with", 0.5)
	screen.call("_switch", "friends")

	# Player cards: a friend, a stranger, the report form.
	var sheet := PlayerCardSheet.open(ui, MARIA)
	await get_tree().create_timer(0.6).timeout  # The offline relation lookup fails first.
	sheet.set("_relation", "friend")
	sheet.call("_render_main")
	await _shot("05_player_card_friend", 0.5)
	sheet = PlayerCardSheet.open(ui, LONG, 77)
	await get_tree().create_timer(0.6).timeout
	sheet.set("_relation", "none")
	sheet.call("_render_main")
	await _shot("06_player_card_stranger", 0.5)
	sheet.call("_render_report")
	await _shot("07_report", 0.5)
	sheet.call("_render_block")
	await _shot("08_block", 0.5)
	ui.close_dialog()

	# Toasts: a game invite and a friend request over the friends screen.
	Social.toasts.show_offer({"key": "invite:1", "user": MARIA, "title": "maria_clara invites you to play!",
		"mode": "random", "expires_at": _iso(110), "accept_text": "Play", "decline_text": "Not now"})
	Social.toasts.show_offer({"key": "friend:2", "user": LONG, "title": "HeneralLunaNgBayan wants to be friends!",
		"seconds": 15, "accept_text": "Accept", "decline_text": "Later"})
	await _shot("09_invite_toasts", 0.8)
	check(Social.toasts.has_offer("invite:1") and Social.toasts.count() == 2, "both offers are up")
	Social.toasts.dismiss("invite:1")
	Social.toasts.dismiss("friend:2")
	await frames(20)
	check(Social.toasts.count() == 0, "offers dismiss")

	# Hosting a private room: the share widget under the turn banner, waiting on a friend.
	var hud: Screen = ui.screen("hud")
	_fake_online({"id": 88, "status": "waiting", "your_side": "white", "turn": "white", "room_name": "Private game",
		"players": {"white": ME}, "pieces": []})
	Social.sent_invite = {"id": 5, "room_id": 88, "expires_at": _iso(95), "to": MARIA}
	ui.show_screen("hud")
	var share := _widget(hud, "res://ui/hud/RoomShareWidget.gd")
	share.call("_refresh")
	hud.call("_refresh")
	await _shot("10_room_share_waiting", 0.8)
	check(share.visible, "room share widget shows while hosting")
	_check_top(hud, "waiting room")
	Social.sent_invite = {}

	# Setup with long names: the banner and the chips share the top row.
	_fake_online({"id": 77, "status": "setup", "your_side": "white", "turn": "white", "setup_ready": {},
		"players": {"white": ME.merged({"username": "kapitan_ng_hilaga"}, true), "black": LONG}, "pieces": []})
	share.call("_refresh")
	hud.call("_refresh")
	await _shot("11_hud_setup_long_names", 0.8)
	check(not share.visible, "room share widget hides once someone joined")
	_check_top(hud, "setup")

	# The left slot shrinks back when its content does.
	var left: Control = hud.get("_slots")["left"]
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(641, 40)
	left.add_child(wide)
	await frames(4)
	wide.custom_minimum_size = Vector2(100, 40)
	await frames(4)
	var view := get_viewport().get_visible_rect().size
	check(left.size.x <= 160.0, "left slot shrinks back with its content (%d px)" % left.size.x)
	var rect := left.get_global_rect()
	check(rect.position.x >= -1.0 and rect.end.x <= view.x + 1.0, "left slot stays on screen")
	wide.queue_free()
	await frames(4)

	# Game over in an online game: Rematch, then waiting, then the opponent's offer.
	_fake_online({"id": 77, "status": "finished", "your_side": "white", "winner": "white", "end_reason": "flag_captured",
		"players": {"white": ME, "black": MARIA}, "pieces": []})
	hud.call("_refresh")
	hud.set("_last_info", {"you_won": true, "end_reason": "flag_captured", "clashes": []})
	hud.call("_show_result_card")
	await get_tree().create_timer(0.6).timeout
	var rematch: RematchButton = null
	for node in ui.find_children("*", "VBoxContainer", true, false):
		if node is RematchButton:
			rematch = node
	check(rematch != null, "online game-over card has Rematch")
	await _shot("12_game_over_rematch", 0.3)
	if rematch:
		rematch.call("_set_state", "waiting", {"expires_at": _iso(48)})
		await _shot("13_rematch_waiting", 0.5)
		check(rematch.state() == "waiting", "rematch waits for the opponent")
		Social.rematch_update.emit("requested", {"match_id": 77, "expires_at": _iso(55)})
		await _shot("14_rematch_offered", 0.5)
		check(rematch.state() == "offered", "the opponent's offer shows on the card")
		Social.rematch_update.emit("declined", {"match_id": 77})
		await frames(2)
		check(rematch.state() == "declined", "a decline shows on the card")
	ui.close_dialog()

	# Practice: no Rematch button.
	GameSession.leave()
	GameSession.start_practice(SalpakanAI.Difficulty.EASY)
	await frames(10)
	hud.set("_last_info", {"you_won": false, "end_reason": "resignation", "clashes": []})
	hud.call("_show_result_card")
	await frames(3)
	var practice_rematch := ui.find_children("*", "VBoxContainer", true, false).any(func(n: Node) -> bool: return n is RematchButton)
	check(not practice_rematch, "practice games have no Rematch")
	ui.close_dialog()
	GameSession.leave()

	ApiManager.token = ""
	ApiManager.user = {}
	finish()


## The turn banner and the player chips don't overlap, and both chips keep some of their name.
func _check_top(hud: Screen, what: String) -> void:
	var turn: Control = hud.get("_turn")
	var banner := turn.get_global_rect().grow_individual(turn.size.x * 0.04, 0, turn.size.x * 0.04, 0)
	for chip_name in ["_you", "_them"]:
		var chip: Control = hud.get(chip_name)
		var label := chip.get_child(0) as Label
		check(not chip.get_global_rect().grow(-1.0).intersects(banner), "%s: turn banner clear of %s" % [what, chip_name])
		check(label.size.x >= 40.0, "%s: %s keeps its name visible (%d px)" % [what, chip_name, label.size.x])
		var view := get_viewport().get_visible_rect().size
		check(chip.get_global_rect().end.x <= view.x + 1.0, "%s: %s on screen" % [what, chip_name])


func _fake_online(view: Dictionary) -> void:
	GameSession.kind = GameSession.Kind.ONLINE
	GameSession.match_view = view


func _fake_friends() -> Dictionary:
	var ago := func(minutes: int) -> String: return _iso(-minutes * 60)
	return {
		"friends": [
			MARIA.merged({"status": "online", "last_seen_at": ago.call(1)}),
			{"id": 11, "username": "HenLuna", "rank_tier": 9, "status": "in_match", "last_seen_at": ago.call(0)},
			LONG.merged({"status": "offline", "last_seen_at": ago.call(190)}),
			{"id": 12, "username": "jose.r", "rank_tier": 2, "status": "offline", "last_seen_at": ago.call(60 * 50)},
		],
		"incoming": [{"request_id": 31, "user": {"id": 23, "username": "mark.s", "rank_tier": 0}, "sent_at": ago.call(4)}],
		"outgoing": [{"request_id": 32, "user": {"id": 22, "username": "MariaMakiling", "rank_tier": 3}, "sent_at": ago.call(90)}],
		"recent": [
			LONG.merged({"relation": "friend"}), {"id": 24, "username": "Lakan", "rank_tier": 0, "relation": "none"},
			{"id": 25, "username": "tala_star", "rank_tier": 5, "relation": "outgoing"},
		],
	}


static func _iso(from_now: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system() + from_now)) + "Z"


func _widget(hud: Screen, path: String) -> Control:
	for node in hud.find_children("*", "", true, false):
		if node.get_script() and node.get_script().resource_path == path:
			return node
	return null


func _shot(file: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [_out, _prefix, file])
	print("saved ", _prefix, file)
