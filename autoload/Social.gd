extends Node
## Social module: custom rooms, ranked matchmaking, global and match chat, voice chat and
## shoutouts. Registers its screens and widgets with ScreenRegistry / HudRegistry /
## DashboardRegistry, keeps the public `global` channel and the player's `private-user.{id}`
## channel subscribed, and routes their realtime events:
##
##     global              ChatMessage {message}, Shoutout {id, user, message, theme, duration}
##     private-user.{id}   RankedMatched {match_id}
##     private-game.{id}   ChatMessage {message}, VoiceSignal {match_id, from_side, type, data}
##
## The shoutout marquee lives on its own canvas layer here, so it shows over every screen.

signal global_message(message: Dictionary)
signal match_message(match_id: int, message: Dictionary)
signal ranked_matched(match_id: int)
signal live_changed(live: bool)

const GLOBAL_CHANNEL := "global"
const GLOBAL_KEEP := 100
const MAX_CHAT_LENGTH := 300
const MAX_SHOUTOUT_LENGTH := 120
const SHOUTOUT_LAYER := 60
const RECENT_SHOUTOUTS := 3  # Shown to late joiners at start-up.

var global_messages: Array[Dictionary] = []
var global_loaded := false
var voice: VoiceChat
var marquee: ShoutoutMarquee
## Off in headless runs (tests, servers) so nothing dials out at boot.
var auto_connect := DisplayServer.get_name() != "headless"

var _user_channel := ""
var _connecting := false


func _ready() -> void:
	ScreenRegistry.register("rooms", preload("res://ui/screens/RoomsScreen.gd"))
	ScreenRegistry.register("ranked", preload("res://ui/screens/RankedScreen.gd"))
	ScreenRegistry.register("shoutout", preload("res://ui/screens/ShoutoutScreen.gd"))
	HudRegistry.register(preload("res://ui/hud/VoiceWidget.gd"), "top_left")
	HudRegistry.register(preload("res://ui/hud/MatchChat.gd"), "bottom_left")
	DashboardRegistry.register(preload("res://ui/widgets/GlobalChatPanel.gd"), "side")

	voice = VoiceChat.new()
	voice.name = "VoiceChat"
	add_child(voice)
	var layer := CanvasLayer.new()
	layer.name = "Shoutouts"
	layer.layer = SHOUTOUT_LAYER
	add_child(layer)
	marquee = ShoutoutMarquee.new()
	layer.add_child(marquee)

	ReverbManager.event_received.connect(_on_event)
	ReverbManager.subscribed.connect(_on_subscribed)
	ReverbManager.disconnected.connect(func() -> void: live_changed.emit(false))
	ApiManager.auth_changed.connect(_on_auth_changed)
	if auto_connect:
		_start.call_deferred()


func _start() -> void:
	await get_tree().create_timer(1.0).timeout
	fetch_recent_shoutouts()
	connect_realtime()


func _on_subscribed(channel: String) -> void:
	if channel == GLOBAL_CHANNEL:
		live_changed.emit(true)


func is_live() -> bool:
	return ReverbManager.is_subscribed(GLOBAL_CHANNEL)


## Joins the realtime server (if configured) and the global + personal channels.
func connect_realtime() -> void:
	if _connecting:
		return
	_connecting = true
	var ok: bool = await GameSession.ensure_realtime()
	_connecting = false
	if not ok:
		return
	ReverbManager.subscribe(GLOBAL_CHANNEL)
	_sync_user_channel()


func _on_auth_changed(_logged_in: bool) -> void:
	_sync_user_channel()
	if ApiManager.is_logged_in() and auto_connect:
		connect_realtime()


func _sync_user_channel() -> void:
	var wanted := ""
	if ApiManager.is_logged_in() and int(ApiManager.user.get("id", 0)) > 0:
		wanted = "private-user.%d" % int(ApiManager.user.get("id", 0))
	if wanted == _user_channel:
		return
	if _user_channel != "":
		ReverbManager.unsubscribe(_user_channel)
	_user_channel = wanted
	if wanted != "":
		ReverbManager.subscribe(wanted)


## Laravel names events by class unless they define broadcastAs(); accept both forms.
static func event_name(event: String) -> String:
	return event.get_slice("\\", event.get_slice_count("\\") - 1).trim_prefix(".")


func _on_event(channel: String, event: String, data: Dictionary) -> void:
	var short := event_name(event)
	if channel == GLOBAL_CHANNEL:
		match short:
			"ChatMessage":
				_add_global(_payload(data, "message"))
			"Shoutout":
				marquee.enqueue(_payload(data, "shoutout"))
	elif channel == _user_channel and channel != "":
		if short == "RankedMatched":
			ranked_matched.emit(int(data.get("match_id", 0)))
	elif channel.begins_with("private-game."):
		var id := int(channel.get_slice(".", 1))
		match short:
			"ChatMessage":
				match_message.emit(id, _payload(data, "message"))
			"VoiceSignal":
				voice.handle_signal(id, data)


func _payload(data: Dictionary, key: String) -> Dictionary:
	return data[key] if data.get(key) is Dictionary else data


# --- Chat -------------------------------------------------------------------------------------

func load_global() -> Dictionary:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/chat/global?limit=50", null, ApiManager.is_logged_in())
	if res.ok:
		global_messages.clear()
		for message: Variant in res.data.get("data", []):
			if message is Dictionary:
				global_messages.append(message)
		global_loaded = true
	return res


func send_global(text: String) -> Dictionary:
	var body := clean(text, MAX_CHAT_LENGTH)
	if body == "":
		return {"ok": false, "status": 0, "data": {}, "error": ""}
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/chat/global", chat_body(body))
	if res.ok:
		_add_global(_payload(res.data, "message"))
	return friendly(res)


func load_match_chat(match_id: int) -> Array:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/games/%d/chat?limit=50" % match_id)
	return res.data.get("data", []) if res.ok and res.data.get("data") is Array else []


func send_match(match_id: int, text: String) -> Dictionary:
	var body := clean(text, MAX_CHAT_LENGTH)
	if body == "":
		return {"ok": false, "status": 0, "data": {}, "error": ""}
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/chat" % match_id, chat_body(body))
	if res.ok:
		match_message.emit(match_id, _payload(res.data, "message"))
	return friendly(res)


func _add_global(message: Dictionary) -> void:
	if message.is_empty():
		return
	var id: Variant = message.get("id")
	if id != null:
		for old in global_messages:
			if str(old.get("id")) == str(id):
				return
	global_messages.append(message)
	if global_messages.size() > GLOBAL_KEEP:
		global_messages.pop_front()
	global_message.emit(message)


## Trims, folds newlines and caps the length (the server masks profanity).
static func clean(text: String, max_length: int) -> String:
	var body := text.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	while body.contains("  "):
		body = body.replace("  ", " ")
	return body.left(max_length)


static func kind_of(body: String) -> String:
	return "emoji" if EmojiPicker.is_only_emoji(body) else "text"


## POST body for a chat line. Emoji-only lines go as kind "emoji" (the server wants only emoji
## characters there, so the spaces go).
static func chat_body(body: String) -> Dictionary:
	var kind := kind_of(body)
	return {"body": body.replace(" ", "") if kind == "emoji" else body, "kind": kind}


## The server's message for one invalid field (422 `errors.<field>`), else its main message.
static func field_error(res: Dictionary, field: String) -> String:
	var errors: Variant = res.data.get("errors")
	if errors is Dictionary and errors.get(field) is Array and not errors[field].is_empty():
		return str(errors[field][0])
	return str(res.data.get("message", res.get("error", "")))


## Friendlier wording for the errors players hit in chat and social flows.
static func friendly(res: Dictionary) -> Dictionary:
	if res.ok:
		return res
	match int(res.status):
		429:
			res.error = "Whoa, slow down a little!"
		403:
			if res.data.get("banned", false):
				res.error = "Your account is banned%s." % ((": " + str(res.data.get("reason"))) if res.data.get("reason") else "")
		401:
			res.error = "Log in first."
	return res


# --- Rooms & ranked ---------------------------------------------------------------------------

func list_rooms() -> Dictionary:
	return await ApiManager.request(HTTPClient.METHOD_GET, "/api/rooms")


## Hosts a room and opens it (GameSession switches to the in-match HUD).
func create_room(room_name: String, password: String) -> Dictionary:
	var body := {"name": room_name.strip_edges()}
	if password != "":
		body["password"] = password
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/rooms", body)
	return friendly(await GameSession._online_request(request))


func join_room(id: int, password: String) -> Dictionary:
	var body := {"password": password} if password != "" else {}
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/rooms/%d/join" % id, body)
	return friendly(await GameSession._online_request(request))


func queue_ranked() -> Dictionary:
	return friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/ranked/queue"))


func ranked_status() -> Dictionary:
	return await ApiManager.request(HTTPClient.METHOD_GET, "/api/ranked/queue")


func cancel_ranked() -> Dictionary:
	return await ApiManager.request(HTTPClient.METHOD_DELETE, "/api/ranked/queue")


## Loads a match view the server already returned (e.g. "matched" from the ranked queue).
func adopt_match(res: Dictionary) -> Dictionary:
	var request := func() -> Dictionary: return res
	return await GameSession._online_request(request)


# --- Shoutouts --------------------------------------------------------------------------------

func fetch_recent_shoutouts() -> void:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/shoutouts/recent", null, false)
	if not res.ok or not res.data.get("data") is Array:
		return
	var recent: Array = res.data["data"]
	for shoutout: Variant in recent.slice(maxi(0, recent.size() - RECENT_SHOUTOUTS)):
		if shoutout is Dictionary:
			marquee.enqueue(shoutout)


## Shoutout themes with prices: {data: [{slug, name, price, rarity}]}; falls back to the built-in
## list (free) when the server has none.
func shoutout_themes() -> Array:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/shoutouts/themes", null, ApiManager.is_logged_in())
	if res.ok and res.data.get("data") is Array and not res.data["data"].is_empty():
		return res.data["data"]
	var fallback: Array = []
	for slug: String in ShoutoutMarquee.THEMES:
		fallback.append({"slug": slug, "name": ShoutoutMarquee.THEMES[slug]["name"], "price": 0, "rarity": "common"})
	return fallback


func send_shoutout(message: String, theme: String) -> Dictionary:
	var body := clean(message, MAX_SHOUTOUT_LENGTH)
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/shoutouts", {"message": body, "theme": theme})
	if res.ok:
		if res.data.get("credits") != null:
			ApiManager._merge_user({"credits": res.data["credits"]})
		if not is_live():
			marquee.enqueue(_payload(res.data, "shoutout"))  # No realtime echo coming; show it here.
	elif int(res.status) == 409:
		res.error = str(res.data.get("message", "Not enough credits."))
	elif int(res.status) == 429:
		res.error = "One shoutout every 30 seconds, General."
		return res
	return friendly(res)
