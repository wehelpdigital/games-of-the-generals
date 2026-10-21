extends Node
## Social module: custom rooms, ranked matchmaking, global and match chat, voice chat,
## shoutouts, friends, invites (to a friend or by link), rematches, blocks and reports. Registers
## its screens and widgets with ScreenRegistry / HudRegistry / DashboardRegistry, keeps the public
## `global` channel and the player's `private-user.{id}` channel subscribed, and routes their
## realtime events:
##
##     global              ChatMessage {message}, Shoutout {id, user, message, theme, duration}
##     private-user.{id}   RankedMatched {match_id}, FriendUpdate {type, user, request_id?},
##                         InviteUpdate {type, invite, user?}, RematchUpdate {type, rematch, user?}
##     private-game.{id}   ChatMessage {message}, VoiceSignal {match_id, from_side, type, data}
##
## The shoutout marquee and the invite/rematch toasts live on their own canvas layers here, so
## they show over every screen. Chat lines from players you blocked are dropped here.

signal global_message(message: Dictionary)
signal match_message(match_id: int, message: Dictionary)
signal ranked_matched(match_id: int)
signal live_changed(live: bool)
signal friends_changed  ## Friend list or requests changed; `friends` is fresh after load_friends().
signal blocks_changed
signal invite_update(type: String, invite: Dictionary)  ## For the host: accepted, declined, cancelled.
signal rematch_update(type: String, rematch: Dictionary)  ## requested, declined, cancelled, started.

const GLOBAL_CHANNEL := "global"
const GLOBAL_KEEP := 100
const MAX_CHAT_LENGTH := 300
const MAX_SHOUTOUT_LENGTH := 120
const SHOUTOUT_LAYER := 60
const RECENT_SHOUTOUTS := 3  # Shown to late joiners at start-up.
const TOAST_LAYER := 65
const INVITE_POLL_SECONDS := 15.0  # Without realtime, pending invites are polled this often.
const REPORT_REASONS := [
	["cheating", "Cheating"], ["harassment", "Harassment or bullying"],
	["inappropriate_name", "Inappropriate name"], ["inappropriate_photo", "Inappropriate photo"],
	["other", "Something else"],
]

var global_messages: Array[Dictionary] = []
var global_loaded := false
var voice: VoiceChat
var marquee: ShoutoutMarquee
var toasts: InviteToast
## Last GET /api/friends: {friends: [Friend], incoming: [Request], outgoing: [Request], recent: [Player]}.
var friends: Dictionary = {}
## Players you blocked (user id -> PlayerCard): their chat lines are hidden and they can't reach you.
var blocked: Dictionary = {}
## The last invite this player sent and is waiting on ({} when none).
var sent_invite: Dictionary = {}
## Off in headless runs (tests, servers) so nothing dials out at boot.
var auto_connect := DisplayServer.get_name() != "headless"

var _user_channel := ""
var _connecting := false
var _seen_invites: Dictionary = {}  # invite id -> true, so realtime and polling show each once
var _pending_link: Dictionary = {}  # {room, code} from a shared link, used once logged in
var _invite_poll := INVITE_POLL_SECONDS


func _ready() -> void:
	ScreenRegistry.register("rooms", preload("res://ui/screens/RoomsScreen.gd"))
	ScreenRegistry.register("ranked", preload("res://ui/screens/RankedScreen.gd"))
	ScreenRegistry.register("shoutout", preload("res://ui/screens/ShoutoutScreen.gd"))
	ScreenRegistry.register("friends", preload("res://ui/screens/FriendsScreen.gd"))
	HudRegistry.register(preload("res://ui/hud/VoiceWidget.gd"), "top_left")
	HudRegistry.register(preload("res://ui/hud/RoomShareWidget.gd"), "top_center")
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
	var toast_layer := CanvasLayer.new()
	toast_layer.name = "SocialToasts"
	toast_layer.layer = TOAST_LAYER
	add_child(toast_layer)
	toasts = InviteToast.new()
	toast_layer.add_child(toasts)

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
	_read_link()
	if ApiManager.is_logged_in():
		load_blocks()
		_use_link()
	elif not _pending_link.is_empty():
		var ui := _ui()
		if ui:
			ui.toast("Log in to join your friend's game!", AppTheme.BLUE)
			ui.show_screen("auth", {"next": "home"})


func _process(delta: float) -> void:
	if not ApiManager.is_logged_in() or not auto_connect:
		return
	if _user_channel != "" and ReverbManager.is_subscribed(_user_channel):
		return  # Invites arrive in realtime.
	_invite_poll -= delta
	if _invite_poll <= 0.0:
		_invite_poll = INVITE_POLL_SECONDS
		poll_invites()


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
	friends = {}
	blocked = {}
	sent_invite = {}
	if ApiManager.is_logged_in():
		load_blocks()
		_use_link.call_deferred()
		if auto_connect:
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
		match short:
			"RankedMatched":
				ranked_matched.emit(int(data.get("match_id", 0)))
			"FriendUpdate":
				_on_friend_update(data)
			"InviteUpdate":
				_on_invite_update(data)
			"RematchUpdate":
				_on_rematch_update(data)
	elif channel.begins_with("private-game."):
		var id := int(channel.get_slice(".", 1))
		match short:
			"ChatMessage":
				var message := _payload(data, "message")
				if not is_blocked_message(message):
					match_message.emit(id, message)
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
			if message is Dictionary and not is_blocked_message(message):
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
	if not res.ok or not res.data.get("data") is Array:
		return []
	return (res.data["data"] as Array).filter(func(m: Variant) -> bool: return m is Dictionary and not is_blocked_message(m))


func send_match(match_id: int, text: String) -> Dictionary:
	var body := clean(text, MAX_CHAT_LENGTH)
	if body == "":
		return {"ok": false, "status": 0, "data": {}, "error": ""}
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/chat" % match_id, chat_body(body))
	if res.ok:
		match_message.emit(match_id, _payload(res.data, "message"))
	return friendly(res)


func _add_global(message: Dictionary) -> void:
	if message.is_empty() or is_blocked_message(message):
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
func create_room(room_name: String, password: String, mode := PowerupLibrary.MODE_SELECT) -> Dictionary:
	var body := {"name": room_name.strip_edges(), "powerup_mode": mode}
	if password != "":
		body["password"] = password
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/rooms", body)
	return friendly(await GameSession._online_request(request))


func join_room(id: int, password: String) -> Dictionary:
	var body := {"password": password} if password != "" else {}
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/rooms/%d/join" % id, body)
	return friendly(await GameSession._online_request(request))


## Joins the ranked queue with the chosen powerup rules (you're only paired with the same).
func queue_ranked(mode := PowerupLibrary.MODE_SELECT) -> Dictionary:
	return friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/ranked/queue", {"powerup_mode": mode}))


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


# --- Friends ------------------------------------------------------------------------------------

## GET /api/friends into `friends` (emits friends_changed).
func load_friends() -> Dictionary:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/friends")
	if res.ok:
		friends = res.data
		friends_changed.emit()
	return friendly(res)


## Players whose name contains `query` (2+ characters), each with a `relation`.
func search_players(query: String) -> Dictionary:
	return friendly(await ApiManager.request(HTTPClient.METHOD_GET, "/api/players/search?q=" + query.strip_edges().uri_encode()))


## How you relate to a player: none, friend, outgoing, incoming, blocked, blocked_you or self
## ("" when it can't be fetched).
func relation_to(user_id: int) -> String:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/players/%d/relation" % user_id)
	return str(res.data.get("relation", "none")) if res.ok else ""


func add_friend(user_id: int) -> Dictionary:
	return await _friend_call(HTTPClient.METHOD_POST, "/api/friends/requests", {"user_id": user_id})


func answer_request(request_id: int, accept: bool) -> Dictionary:
	return await _friend_call(HTTPClient.METHOD_POST, "/api/friends/requests/%d/%s" % [request_id, "accept" if accept else "decline"])


func cancel_request(request_id: int) -> Dictionary:
	return await _friend_call(HTTPClient.METHOD_DELETE, "/api/friends/requests/%d" % request_id)


func remove_friend(user_id: int) -> Dictionary:
	return await _friend_call(HTTPClient.METHOD_DELETE, "/api/friends/%d" % user_id)


## The open request between you and a player in one direction ("incoming" or "outgoing"), or {}.
func request_with(user_id: int, direction: String) -> Dictionary:
	for request: Variant in friends.get(direction, []):
		if request is Dictionary and int((request.get("user", {}) as Dictionary).get("id", 0)) == user_id:
			return request
	return {}


func _friend_call(method: int, path: String, body: Variant = null) -> Dictionary:
	var res := friendly(await ApiManager.request(method, path, body))
	if res.ok:
		load_friends()
	return res


func _on_friend_update(data: Dictionary) -> void:
	var user: Dictionary = data.get("user") if data.get("user") is Dictionary else {}
	var who := str(user.get("username", "Someone"))
	match str(data.get("type", "")):
		"request":
			var request_id := int(data.get("request_id", 0))
			if not is_blocked(int(user.get("id", 0))):
				toasts.show_offer({
					"key": "friend:%d" % request_id,
					"user": user,
					"title": "%s wants to be friends!" % who,
					"accept_text": "Accept",
					"decline_text": "Later",
					"accept": func() -> void: answer_request(request_id, true),
				})
		"accepted":
			var ui := _ui()
			if ui:
				ui.toast("%s is now your friend!" % who, AppTheme.MINT)
	load_friends()


# --- Invites ------------------------------------------------------------------------------------

## Invite a friend to play: into the room you're hosting (still waiting), or a new private room
## you're taken into (the HUD shows it waiting for them). `mode` sets a new room's powerup rules.
func invite_friend(user: Dictionary, mode := PowerupLibrary.MODE_SELECT) -> Dictionary:
	var body := {"user_id": int(user.get("id", 0)), "powerup_mode": mode}
	var res: Dictionary
	if GameSession.kind == GameSession.Kind.ONLINE and GameSession.status() == "waiting":
		res = friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/invites", body))
	else:
		var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/invites", body)
		res = friendly(await GameSession._online_request(request))
	if res.ok and res.data.get("invite") is Dictionary:
		sent_invite = (res.data["invite"] as Dictionary).duplicate()
		sent_invite["to"] = user
		invite_update.emit("sent", sent_invite)
	return res


## Say yes to an invite: you're seated in the room (the HUD takes over).
func accept_invite(invite: Dictionary) -> Dictionary:
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/invites/%d/accept" % int(invite.get("id", 0)))
	return friendly(await GameSession._online_request(request))


func decline_invite(invite: Dictionary) -> void:
	await ApiManager.request(HTTPClient.METHOD_POST, "/api/invites/%d/decline" % int(invite.get("id", 0)))


func cancel_sent_invite() -> void:
	if sent_invite.is_empty():
		return
	var id := int(sent_invite.get("id", 0))
	sent_invite = {}
	invite_update.emit("cancelled", {"id": id})
	await ApiManager.request(HTTPClient.METHOD_DELETE, "/api/invites/%d" % id)


## Pending invites (used when realtime is down; each one shows once).
func poll_invites() -> void:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/invites")
	if res.ok and res.data.get("data") is Array:
		for invite: Variant in res.data["data"]:
			if invite is Dictionary:
				_show_invite(invite)


func _on_invite_update(data: Dictionary) -> void:
	var invite: Dictionary = data.get("invite") if data.get("invite") is Dictionary else {}
	var type := str(data.get("type", ""))
	var id := int(invite.get("id", 0))
	if type == "invite":
		_show_invite(invite)
		return
	if type == "cancelled":
		toasts.dismiss("invite:%d" % id)
		return
	# For the host: the friend answered.
	if int(sent_invite.get("id", -1)) == id:
		sent_invite = {}
	var user: Dictionary = data.get("user") if data.get("user") is Dictionary else {}
	var who := str(user.get("username", "Your friend"))
	var ui := _ui()
	if ui:
		match type:
			"accepted":
				ui.toast("%s is in! Set up your army." % who, AppTheme.MINT)
			"declined":
				ui.toast("%s can't play right now." % who, AppTheme.BLUE)
	invite_update.emit(type, invite)


func _show_invite(invite: Dictionary) -> void:
	var id := int(invite.get("id", 0))
	if id <= 0 or _seen_invites.has(id):
		return
	_seen_invites[id] = true
	var from: Dictionary = invite.get("from") if invite.get("from") is Dictionary else {}
	if is_blocked(int(from.get("id", 0))):
		return
	toasts.show_offer({
		"key": "invite:%d" % id,
		"user": from,
		"title": "%s invites you to play!" % str(from.get("username", "A friend")),
		"mode": str(invite.get("powerup_mode", "")),
		"expires_at": str(invite.get("expires_at", "")),
		"accept_text": "Play",
		"decline_text": "Not now",
		"accept": func() -> void: _accept_from_toast(invite),
		"decline": func() -> void: decline_invite(invite),
	})


func _accept_from_toast(invite: Dictionary) -> void:
	var res: Dictionary = await accept_invite(invite)
	var ui := _ui()
	if ui:
		if res.ok:
			ui.close_dialog()
		else:
			ui.toast(str(res.error) if str(res.error) != "" else "That invite is no longer open.", AppTheme.RED)


# --- Room links ---------------------------------------------------------------------------------

## A shareable link to your waiting room: {ok, url, data: {code, expires_at}}. Whoever opens it is
## seated straight in (one use, 30 minutes); the room's password never goes in it.
func room_link(room_id: int) -> Dictionary:
	var res := friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/rooms/%d/link" % room_id))
	if res.ok:
		res["url"] = link_url(room_id, str(res.data.get("code", "")), str(res.data.get("url", "")))
	return res


## This page's address with the room and code (the server's URL off the web).
static func link_url(room_id: int, code: String, fallback := "") -> String:
	var base := ""
	if OS.has_feature("web"):
		var here: Variant = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		base = str(here) if here is String else ""
	if base == "":
		if fallback != "":
			return fallback
		base = ApiManager.base_url + "/"
	return "%s?room=%d&code=%s" % [base, room_id, code.uri_encode()]


func join_with_code(room_id: int, code: String) -> Dictionary:
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/rooms/%d/join" % room_id, {"code": code})
	return friendly(await GameSession._online_request(request))


## Opens a shared room link once logged in (also used by tests and other entry points).
func open_link(room_id: int, code: String) -> void:
	_pending_link = {"room": room_id, "code": code}
	if ApiManager.is_logged_in():
		_use_link()


## {room, code} from "?room=<id>&code=<code>", or {}.
static func parse_link(query: String) -> Dictionary:
	var room := 0
	var code := ""
	for pair in query.trim_prefix("?").split("&", false):
		var key := pair.get_slice("=", 0)
		var value := pair.get_slice("=", 1).uri_decode() if pair.contains("=") else ""
		if key == "room":
			room = int(value)
		elif key == "code":
			code = value
	return {"room": room, "code": code} if room > 0 and code != "" else {}


## Reads a shared link from the page address (web), then clears it from the address bar.
func _read_link() -> void:
	if not OS.has_feature("web"):
		return
	var query: Variant = JavaScriptBridge.eval("window.location.search", true)
	_pending_link = parse_link(str(query) if query is String else "")
	if not _pending_link.is_empty():
		JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname + window.location.hash)", true)


func _use_link() -> void:
	if _pending_link.is_empty() or not ApiManager.is_logged_in():
		return
	var link := _pending_link
	_pending_link = {}
	var res: Dictionary = await join_with_code(int(link["room"]), str(link["code"]))
	var ui := _ui()
	if ui and not res.ok:
		var why := field_error(res, "code")
		ui.toast(why if why != "" else str(res.error), AppTheme.RED)


# --- Rematch ------------------------------------------------------------------------------------

## Offer a rematch after an online game, or accept the opponent's offer. When it starts, the new
## match (colours swapped, same powerup rules) is loaded. data.status: waiting | started.
func request_rematch(match_id: int) -> Dictionary:
	var res := friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/rematch" % match_id))
	if res.ok and str(res.data.get("status", "")) == "started" and res.data.get("match") is Dictionary:
		toasts.dismiss("rematch:%d" % match_id)
		var loaded: Dictionary = await adopt_match(res)
		if not loaded.ok:
			return friendly(loaded)
		var ui := _ui()
		if ui:
			ui.close_dialog()
	return res


## Withdraw your offer, or decline theirs.
func withdraw_rematch(match_id: int) -> void:
	toasts.dismiss("rematch:%d" % match_id)
	await ApiManager.request(HTTPClient.METHOD_DELETE, "/api/games/%d/rematch" % match_id)


## data.status: none | waiting | offered | started | declined | cancelled | expired.
func rematch_status(match_id: int) -> Dictionary:
	return await ApiManager.request(HTTPClient.METHOD_GET, "/api/games/%d/rematch" % match_id)


## Loads a started rematch if you're still looking at the old game (or nothing else).
func open_rematch(rematch: Dictionary) -> void:
	var new_id := int(rematch.get("new_match_id", 0))
	var old_id := int(rematch.get("match_id", 0))
	if new_id <= 0 or GameSession.match_id() == new_id:
		return
	if GameSession.has_match() and GameSession.match_id() != old_id:
		return  # Busy with another game.
	var res: Dictionary = await GameSession.open_match(new_id)
	var ui := _ui()
	if ui and res.ok:
		ui.close_dialog()


func _on_rematch_update(data: Dictionary) -> void:
	var rematch: Dictionary = data.get("rematch") if data.get("rematch") is Dictionary else {}
	var type := str(data.get("type", ""))
	var old_id := int(rematch.get("match_id", 0))
	var user: Dictionary = data.get("user") if data.get("user") is Dictionary else {}
	var on_card := GameSession.match_id() == old_id and GameSession.status() == "finished"
	match type:
		"requested":
			if not on_card and not is_blocked(int(user.get("id", 0))):
				toasts.show_offer({
					"key": "rematch:%d" % old_id,
					"user": user,
					"title": "%s wants a rematch!" % str(user.get("username", "Your opponent")),
					"expires_at": str(rematch.get("expires_at", "")),
					"accept_text": "Rematch",
					"decline_text": "No thanks",
					"accept": func() -> void: request_rematch(old_id),
					"decline": func() -> void: withdraw_rematch(old_id),
				})
		"started":
			toasts.dismiss("rematch:%d" % old_id)
			open_rematch(rematch)
		_:
			toasts.dismiss("rematch:%d" % old_id)
	rematch_update.emit(type, rematch)


# --- Blocks and reports -------------------------------------------------------------------------

func load_blocks() -> void:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/blocks")
	if res.ok and res.data.get("data") is Array:
		blocked = {}
		for card: Variant in res.data["data"]:
			if card is Dictionary:
				blocked[int(card.get("id", 0))] = card
		blocks_changed.emit()


## Block a player: no requests, invites or rematches between you, and their chat lines vanish.
func block_player(user: Dictionary) -> Dictionary:
	var res := friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/blocks", {"user_id": int(user.get("id", 0))}))
	if res.ok:
		blocked[int(user.get("id", 0))] = user
		var kept: Array[Dictionary] = []
		for message in global_messages:
			if not is_blocked_message(message):
				kept.append(message)
		global_messages = kept
		blocks_changed.emit()
		load_friends()
	return res


func unblock_player(user_id: int) -> Dictionary:
	var res := friendly(await ApiManager.request(HTTPClient.METHOD_DELETE, "/api/blocks/%d" % user_id))
	if res.ok:
		blocked.erase(user_id)
		blocks_changed.emit()
	return res


## `reason`: one of REPORT_REASONS' keys.
func report_player(user_id: int, reason: String, note := "", match_id := 0) -> Dictionary:
	var body := {"user_id": user_id, "reason": reason}
	if note.strip_edges() != "":
		body["note"] = note.strip_edges().left(500)
	if match_id > 0:
		body["match_id"] = match_id
	var res := friendly(await ApiManager.request(HTTPClient.METHOD_POST, "/api/reports", body))
	if not res.ok and int(res.status) in [409, 429]:
		res.error = str(res.data.get("message", res.error))
	return res


func is_blocked(user_id: int) -> bool:
	return blocked.has(user_id)


## Whether a chat line comes from a player you blocked.
func is_blocked_message(message: Dictionary) -> bool:
	var user: Variant = message.get("user")
	return user is Dictionary and blocked.has(int((user as Dictionary).get("id", 0)))


## The UI root, for toasts and screens from here (null in tests without the main scene).
func _ui() -> UIRoot:
	return get_tree().root.find_child("UI", true, false) as UIRoot
