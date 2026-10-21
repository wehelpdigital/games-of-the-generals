extends SmokeTestBase
## Renders the social screens and widgets with fake data for visual review. Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/SocialShots.tscn -- --out=<dir>
## Add `--portrait` after `--` for a phone-shaped run (use --resolution 420x860).

var _out := "user://social_shots"
var _prefix := ""

const ME := {"id": 42, "username": "kapitan", "rank_tier": 4, "xp": 1240, "credits": 2500, "elo": 1288}
const ROOMS := [
	{"id": 101, "name": "Friday Night Generals", "has_password": true, "is_yours": false, "created_at": "",
		"host": {"id": 7, "username": "maria_clara", "rank_tier": 6, "avatar_url": null}},
	{"id": 102, "name": "Alcala Barkada", "has_password": false, "is_yours": false, "created_at": "",
		"host": {"id": 8, "username": "jose.r", "rank_tier": 2, "avatar_url": null}},
	{"id": 103, "name": "Kapitan's den", "has_password": true, "is_yours": true, "created_at": "",
		"host": {"id": 42, "username": "kapitan", "rank_tier": 4, "avatar_url": null}},
	{"id": 104, "name": "Newbies welcome!", "has_password": false, "is_yours": false, "created_at": "",
		"host": {"id": 9, "username": "Lakan", "rank_tier": 0, "avatar_url": null}},
]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg == "--portrait":
			_prefix = "p_"
	DirAccess.make_dir_recursive_absolute(_out)
	ApiManager.base_url = "http://127.0.0.1:9"  # Offline: every request fails fast, no toasts of 401s.
	await boot()
	var ui: UIRoot = main.get_node("UI")
	ApiManager.token = "offline-shots"
	ApiManager.user = ME.duplicate()

	# Rooms list + the locked-room prompt.
	var rooms: Screen = ui.screen("rooms")
	rooms.set("_loading", true)
	ui.show_screen("rooms")
	rooms.call("show_rooms", ROOMS)
	await _shot("01_rooms", 0.8)
	rooms.call("join_room", ROOMS[0])
	await _shot("02_room_password", 0.5)
	ui.close_dialog()

	# Ranked: idle, then searching with a widened window.
	ui.show_screen("ranked")
	await _shot("03_ranked_idle", 0.8)
	var ranked: Screen = ui.screen("ranked")
	ranked.set("_waited", 52.0)
	ranked.call("_set_searching", true)
	await _shot("04_ranked_searching", 1.2)
	ranked.call("_set_searching", false)

	# Shoutout composer with a live preview.
	ui.show_screen("shoutout")
	var shout: Screen = ui.screen("shoutout")
	var field: LineEdit = shout.get("_field")
	field.text = "Happy fiesta, Pangasinan! 🎉🔥 GG everyone"
	shout.call("_on_swatch_toggled", true, "fireworks")
	for b in (shout.get("_grid") as GridContainer).get_children():
		if b is Button and b.get_meta("slug", "") == "fireworks":
			(b as Button).button_pressed = true
	await _shot("05_shoutout", 1.5)

	# Global chat panel (as the dashboard shows it) with the emoji picker open.
	ui.show_screen("title")
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.theme = AppTheme.get_theme()
	layer.add_child(holder)
	var panel := GlobalChatPanel.new()
	panel.custom_minimum_size = Vector2(420, 600)
	holder.add_child(AppTheme.centered(panel, 420))
	var view: ChatView = panel.get("_chat")
	for message: Dictionary in _fake_global():
		view.add_message(message)
	(panel.get("_picker") as Control).visible = true
	await _shot("06_global_chat", 1.0)
	layer.queue_free()

	# In-match chat (practice) with messages, a taunt and the AI talking back.
	GameSession.start_practice(SalpakanAI.Difficulty.MEDIUM)
	await frames(10)
	var hud: Screen = ui.screen("hud")
	var chat: Control = _widget(hud, "res://ui/hud/MatchChat.gd")
	chat.call("_toggle_panel")
	var chat_view: ChatView = chat.get("_chat")
	chat_view.add_message({"kind": "text", "body": "Good luck, have fun! 🫡", "user": ME, "mine": true})
	chat_view.add_message({"kind": "text", "body": "My spy sees everything 👀", "user": chat.call("_ai_user")})
	chat_view.add_message({"kind": "taunt", "body": CosmeticCatalog.slugs("taunt")[0], "user": chat.call("_ai_user")})
	chat_view.add_message({"kind": "emoji", "body": "😂🔥", "user": ME, "mine": true})
	await _shot("07_match_chat", 1.2)
	chat.call("_toggle_panel")

	# Powerups and effect banners down the left, chat bottom-right: both stay readable.
	await _effects_on()
	await _shot("07b_hud_effects", 0.8)
	chat.call("_toggle_panel")
	await _shot("07c_hud_effects_chat_open", 0.8)
	chat.call("_toggle_panel")

	# Voice widget in an online match (faked state; no server).
	GameSession.leave()
	GameSession.kind = GameSession.Kind.ONLINE
	GameSession.match_view = {"id": 77, "status": "active", "your_side": "white", "turn": "white",
		"players": {"white": ME, "black": {"id": 7, "username": "maria_clara", "rank_tier": 6}}, "pieces": []}
	var voice: VoiceChat = Social.voice
	voice.match_id = 77
	voice.my_side = "white"
	voice.state = "live"
	voice.peer_joined = true
	var widget: Control = _widget(hud, "res://ui/hud/VoiceWidget.gd")
	widget.call("_refresh")
	widget.call("_on_levels", 0.2, 0.0)
	widget.call("_toggle_panel")
	await _shot("08_voice_live", 0.6)
	widget.call("_toggle_panel")
	voice.state = "idle"
	voice.match_id = 0
	widget.call("_refresh")
	await _shot("08b_voice_join", 0.4)
	GameSession.kind = GameSession.Kind.NONE
	GameSession.match_view = {}

	# Every marquee theme, then the real overlay over the title screen.
	ui.back_to_menu()
	var sheet := CanvasLayer.new()
	sheet.layer = 5
	add_child(sheet)
	var bg := ColorRect.new()
	bg.color = AppTheme.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(bg)
	var column := AppTheme.vbox(14)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	column.theme = AppTheme.get_theme()
	sheet.add_child(column)
	var users := [{"username": "maria_clara", "rank_tier": 6}, {"username": "kapitan", "rank_tier": 4}, {"username": "Lakan", "rank_tier": 0}]
	var i := 0
	for slug: String in ShoutoutMarquee.THEMES:
		var strip := ShoutoutMarquee.new(true)
		column.add_child(strip)
		strip.preview({"user": users[i % users.size()], "theme": slug,
			"message": "%s theme · Happy birthday Lolo! 🎉 Salpakan night at 8 🔥" % ShoutoutMarquee.THEMES[slug]["name"]})
		i += 1
	await _shot("09_marquee_themes", 1.6)
	sheet.queue_free()
	Social.marquee.enqueue({"id": 9001, "user": {"username": "maria_clara", "rank_tier": 6}, "theme": "gold_royal",
		"message": "The Royal Guild is recruiting! Majors and up, DM me 👑", "duration": 12})
	await _shot("10_marquee_live", 1.6)

	# Portrait phone: chat beside the bottom action buttons (last: window resizes can stall drivers).
	GameSession.start_practice(SalpakanAI.Difficulty.EASY)
	await frames(10)
	await _effects_on()
	chat = _widget(ui.screen("hud"), "res://ui/hud/MatchChat.gd")
	get_window().size = Vector2i(720, 1280)
	await frames(5)
	chat.call("_toggle_panel")
	await _shot("11_portrait_chat_open", 1.2)
	ApiManager.token = ""
	ApiManager.user = {}
	get_tree().quit()


## An active practice match with three powerups (one used) and an opponent's powerup banner.
func _effects_on() -> void:
	GameSession.submit_setup(board.get_setup_placements())
	await wait_until(func() -> bool: return GameSession.status() == "active" and not board.is_animating())
	var arbiter: LocalArbiter = GameSession._arbiter
	arbiter.loadouts[Ranks.WHITE] = ["spy_card", "freeze", "fortify"]
	GameSession._practice_load("active", GameSession.version)
	await GameSession.use_powerup("spy_card")
	GameSession.powerup_used.emit({"side": Ranks.BLACK, "id": "chaos_order", "name": "Chaos Order", "public": {}, "mine": false})
	await frames(5)


func _fake_global() -> Array:
	var people := [
		{"id": 7, "username": "maria_clara", "rank_tier": 6}, {"id": 8, "username": "jose.r", "rank_tier": 2},
		{"id": 9, "username": "Lakan", "rank_tier": 0}, {"id": 11, "username": "HenLuna", "rank_tier": 9},
	]
	var lines := [
		[0, "text", "Anyone up for a ranked game? Captain here 🎯"], [1, "text", "Just got promoted to 2LT!! 🥳"],
		[3, "emoji", "👏👏"], [42, "text", "Congrats! Rematch later? 😎"], [2, "text", "how do I beat the General AI 😭"],
		[3, "text", "Protect your flag with a privates wall, spies near the front. Works every time 🧠"],
		[0, "taunt", "pie"], [42, "emoji", "😂"],
	]
	var out: Array = []
	var id := 500
	for line: Array in lines:
		id += 1
		var who: Dictionary = ME if line[0] == 42 else people[line[0]]
		out.append({"id": id, "user": who, "kind": line[1], "body": line[2], "created_at": ""})
	return out


func _widget(hud: Screen, path: String) -> Control:
	for node in hud.find_children("*", "", true, false):
		if node.get_script() and node.get_script().resource_path == path:
			return node
	return null


func _shot(file: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [_out, _prefix, file])
	print("saved ", _prefix, file)
