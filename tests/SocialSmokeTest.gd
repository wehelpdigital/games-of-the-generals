extends SmokeTestBase
## Social module without a server: screen/widget registration, realtime event routing (fake
## Reverb events), chat de-duplication and emoji markup, the shoutout queue, and the practice
## match chat with its AI replies.
##   godot --headless --path . res://tests/SocialSmokeTest.tscn


func _ready() -> void:
	ApiManager.base_url = "http://127.0.0.1:9"  # Nothing listens here: requests fail fast, offline.
	await boot()
	var ui: UIRoot = main.get_node("UI")

	check(ui.has_screen("rooms") and ui.has_screen("ranked") and ui.has_screen("shoutout"), "rooms, ranked and shoutout screens registered")
	var hud: Screen = ui.screen("hud")
	check(hud.find_children("*", "", true, false).any(func(n: Node) -> bool: return n.get_script() == preload("res://ui/hud/MatchChat.gd")), "match chat widget in the HUD")
	check(DashboardRegistry.in_slot("side").any(func(e: Dictionary) -> bool: return e["script"] == preload("res://ui/widgets/GlobalChatPanel.gd")), "global chat panel registered for the dashboard")

	# Emoji markup.
	var markup := EmojiPicker.bbcode("gg 😀 [b]x[/b] 🔥️", 20)
	check(markup.contains("[img=20x20]res://assets/emoji/1f600.png[/img]"), "emoji become inline pictures")
	check(markup.contains("[lb]b]") and not markup.contains("[b]"), "user BBCode is escaped")
	check(markup.contains("1f525.png") and not markup.contains(String.chr(0xFE0F)), "variation selectors are dropped")
	check(EmojiPicker.is_only_emoji("😂😂") and not EmojiPicker.is_only_emoji("lol 😂"), "emoji-only detection")
	check(Social.event_name("App\\Events\\ChatMessage") == "ChatMessage" and Social.event_name(".Shoutout") == "Shoutout", "event names with or without namespaces")

	# Global chat routed from the public channel, de-duplicated by id.
	var heard: Array = []
	Social.global_message.connect(func(m: Dictionary) -> void: heard.append(m))
	var message := {"id": 7, "user": {"id": 99, "username": "luna", "rank_tier": 4}, "kind": "text", "body": "Hello 👋", "created_at": "2026-10-21T08:00:00Z"}
	ReverbManager.event_received.emit("global", "ChatMessage", {"message": message})
	ReverbManager.event_received.emit("global", "ChatMessage", {"message": message})
	check(heard.size() == 1 and Social.global_messages.size() == 1, "global ChatMessage delivered once")

	var view := ChatView.new()
	view.size = Vector2(360, 300)
	add_child(view)
	check(view.add_message(message) and not view.add_message(message), "chat view shows each id once")
	view.add_message({"kind": "taunt", "body": "pie", "user": {"username": "luna"}})
	view.add_message({"kind": "emoji", "body": "🔥", "user": {"username": "luna"}})
	view.add_system("Welcome")
	check(view.message_count() == 4, "taunt, emoji and system rows")
	view.queue_free()

	# Shoutouts queue once per id and play one after another.
	var shout := {"id": 3, "user": {"username": "maria", "rank_tier": 8}, "message": "Happy fiesta! 🎉", "theme": "fireworks", "duration": 12}
	ReverbManager.event_received.emit("global", "Shoutout", shout)
	ReverbManager.event_received.emit("global", ".Shoutout", shout)
	ReverbManager.event_received.emit("global", "Shoutout", {"id": 4, "user": {"username": "jose"}, "message": "GG all", "theme": "lava"})
	check(Social.marquee.is_playing() and Social.marquee.queued() == 2, "shoutouts queue once per id")

	# Ranked match notification on the personal channel.
	ApiManager.user = {"id": 42, "username": "tester", "rank_tier": 3}
	ApiManager.token = "offline-test"
	Social._sync_user_channel()
	var matched: Array = []
	Social.ranked_matched.connect(func(id: int) -> void: matched.append(id))
	ReverbManager.event_received.emit("private-user.42", "RankedMatched", {"match_id": 1234})
	check(matched == [1234], "RankedMatched routed from private-user.{id}")
	ApiManager.token = ""
	ApiManager.user = {}

	# Practice match chat: local messages and taunts show up, the AI may answer.
	GameSession.start_practice(SalpakanAI.Difficulty.EASY)
	await frames(5)
	var chat: Control = hud.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() == preload("res://ui/hud/MatchChat.gd"))[0]
	check(chat.visible, "match chat visible during a match")
	var chat_view: ChatView = chat.get("_chat")
	var before := chat_view.message_count()
	await chat.call("_say", "hello there 😎")
	check(chat_view.message_count() == before + 1, "practice chat shows my message")
	await GameSession.send_taunt(CosmeticCatalog.slugs("taunt")[0])
	check(chat_view.message_count() == before + 2, "taunts appear in the chat")
	chat.call("_toggle_mute")
	check(ui.setting("mute_taunts", false) and ui.setting("mute_chat", false), "mute opponent mutes chat and taunts")
	chat.call("_toggle_mute")

	# The chat sits bottom-right, clear of the action buttons, and opens upwards.
	var screen := get_viewport().get_visible_rect().size
	chat.call("_toggle_panel")
	await frames(3)
	var chat_rect: Rect2 = chat.get_global_rect()
	check(chat_rect.end.x <= screen.x and chat_rect.end.y <= screen.y and chat_rect.position.x > screen.x * 0.5, "chat sits in the bottom-right corner")
	var actions: Control = hud.get("_actions")
	check(not chat_rect.intersects(actions.get_global_rect()), "open chat panel clears the action buttons")
	chat.call("_toggle_panel")

	# Jammer (needs an active match): input locked with a countdown, unlocked when it ends.
	GameSession.submit_setup(board.get_setup_placements())
	await wait_until(func() -> bool: return GameSession.status() == "active")
	var until := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 90) + "Z"
	GameSession.match_view["jammed_until"] = {GameSession.my_side(): until}
	chat.call("_update_jam")
	var field: LineEdit = chat.get("_field")
	check(not field.editable and field.placeholder_text.begins_with("Jammed! 1:"), "jammer locks the chat input with a countdown")
	var lines := chat_view.message_count()
	await chat.call("_say", "can you hear me?")
	check(chat_view.message_count() == lines, "nothing is sent while jammed")
	GameSession.match_view.erase("jammed_until")
	chat.call("_update_jam")
	check(field.editable, "chat unlocks when the jam ends")

	# Voice chat is a browser feature.
	check(not VoiceChat.supported(), "voice chat reports unsupported on desktop")
	GameSession.leave()
	finish()
