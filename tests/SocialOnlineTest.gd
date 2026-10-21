extends SmokeTestBase
## Social features against a running backend: rooms (password, is_yours), match and global chat,
## voice signalling, shoutouts and the ranked queue. This client is player A through Social and
## GameSession; player B uses raw HTTP. Realtime isn't needed (run the backend with
## BROADCAST_CONNECTION=log); it changes nothing here.
##   godot --headless --path . res://tests/SocialOnlineTest.tscn -- --api-url=http://127.0.0.1:8077
## Use a backend whose database has no other waiting rooms or ranked players.


func _ready() -> void:
	print("API: ", ApiManager.base_url)
	await boot()
	var stamp := str(Time.get_ticks_usec()).right(6)
	var reg := await ApiManager.register("sa" + stamp, "sa%s@example.test" % stamp, "password123", "password123")
	check(reg.ok, "player A registered")
	var b_reg := await _raw(HTTPClient.METHOD_POST, "/api/register", {"username": "sb" + stamp,
		"email": "sb%s@example.test" % stamp, "password": "password123", "password_confirmation": "password123"}, "")
	var token_b := str(b_reg.data.get("token", ""))
	check(token_b != "", "player B registered")

	# Rooms.
	var created: Dictionary = await Social.create_room("E2E Room " + stamp, "secret1")
	check(created.ok and GameSession.match_id() > 0, "A hosts a locked room")
	var room_id := GameSession.match_id()
	var mine: Dictionary = await Social.list_rooms()
	var my_row := _find(mine.data.get("data", []), room_id)
	check(my_row.get("is_yours", false) and my_row.get("has_password", false), "A sees the room as theirs, locked")
	var listed := await _raw(HTTPClient.METHOD_GET, "/api/rooms", null, token_b)
	var their_row := _find(listed.data.get("data", []), room_id)
	check(their_row.get("name", "") == "E2E Room " + stamp and not their_row.get("is_yours", true), "B sees the room in the list")
	var wrong := await _raw(HTTPClient.METHOD_POST, "/api/rooms/%d/join" % room_id, {"password": "nope"}, token_b)
	check(wrong.status == 422 and Social.field_error(wrong, "password") != "", "wrong password is refused with a message")
	var joined := await _raw(HTTPClient.METHOD_POST, "/api/rooms/%d/join" % room_id, {"password": "secret1"}, token_b)
	check(joined.ok, "B joins with the password")
	await GameSession.refresh()
	check(GameSession.status() == "setup", "the room match moves to setup")
	var busy: Dictionary = await Social.create_room("Second room", "")
	check(busy.status == 409 and int(busy.data.get("match_id", 0)) == room_id, "hosting again points back to the current match")

	# Match chat (text + emoji-only), as both players see it.
	var sent: Dictionary = await Social.send_match(room_id, "gl hf 😎")
	check(sent.ok and sent.data.get("message", {}).get("id") != null, "A sends a match chat line")
	await get_tree().create_timer(1.1).timeout  # One message per second.
	var emoji: Dictionary = await Social.send_match(room_id, "🔥 🔥")
	check(emoji.ok and str(emoji.data.get("message", {}).get("kind")) == "emoji", "emoji-only line goes as kind emoji")
	var history := await _raw(HTTPClient.METHOD_GET, "/api/games/%d/chat" % room_id, null, token_b)
	var bodies: Array = history.data.get("data", []).map(func(m: Dictionary) -> String: return str(m.get("body")))
	check("gl hf 😎" in bodies, "B reads the match chat")
	var from_a: Array = await Social.load_match_chat(room_id)
	check(from_a.size() >= 2, "A loads the match chat history")

	# Voice signalling relay.
	var signal_res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/voice" % room_id,
		{"type": "mute_state", "data": {"joined": true, "muted": false, "ack": false}})
	check(signal_res.status == 202, "voice signal accepted")

	# Global chat.
	var global_res: Dictionary = await Social.send_global("Hello from the E2E test " + stamp)
	check(global_res.ok and Social.global_messages.any(func(m: Dictionary) -> bool: return str(m.get("body")).ends_with(stamp)), "A posts to global chat")
	var loaded: Dictionary = await Social.load_global()
	check(loaded.ok and Social.global_loaded, "global chat history loads")

	# Shoutout (free in test mode; shown locally because realtime is off).
	var queued_before := Social.marquee.queued()
	var shout: Dictionary = await Social.send_shoutout("E2E shoutout " + stamp, "fireworks")
	check(shout.ok and str(shout.data.get("shoutout", {}).get("theme")) == "fireworks", "A sends a shoutout")
	check(shout.data.has("credits"), "shoutout response carries the new credit balance")
	check(Social.marquee.queued() == queued_before + 1, "the shoutout plays locally without realtime")
	var themes: Array = await Social.shoutout_themes()
	check(themes.size() >= 8, "shoutout themes load")

	# Ranked: finish the room match, then both queue at the same tier and get paired.
	await GameSession.resign()
	await wait_until(func() -> bool: return GameSession.status() in ["finished", "cancelled"], 8.0)
	var queued: Dictionary = await Social.queue_ranked()
	check(queued.ok and str(queued.data.get("status")) == "queued", "A joins the ranked queue")
	var b_queue := await _raw(HTTPClient.METHOD_POST, "/api/ranked/queue", null, token_b)
	check(str(b_queue.data.get("status")) == "matched", "B is paired with A")
	var status: Dictionary = await Social.ranked_status()
	check(str(status.data.get("status")) == "matched" and status.data.get("match") is Dictionary, "A's poll says matched")
	var opened: Dictionary = await Social.adopt_match(status)
	check(opened.ok and GameSession.match_id() == int(status.data["match"].get("id", -1)), "A opens the ranked match")

	await GameSession.resign()
	await ApiManager.logout()
	finish()


func _find(rows: Array, id: int) -> Dictionary:
	for row: Variant in rows:
		if row is Dictionary and int(row.get("id", 0)) == id:
			return row
	return {}


## Player B: plain HTTP with B's token.
func _raw(method: int, path: String, body: Variant, token: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	if body != null:
		headers.append("Content-Type: application/json")
	if token != "":
		headers.append("Authorization: Bearer " + token)
	http.request(ApiManager.base_url + path, headers, method, JSON.stringify(body) if body != null else "")
	var response: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var status: int = response[1]
	return {"ok": status >= 200 and status < 300, "status": status, "data": parsed if parsed is Dictionary else {}}
