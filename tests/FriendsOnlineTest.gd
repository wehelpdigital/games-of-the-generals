extends SmokeTestBase
## Friends, invites, room links, rematches, blocks and reports against a running backend. This
## client is player A through Social and GameSession; player B uses raw HTTP. Realtime isn't
## needed (run the backend with BROADCAST_CONNECTION=log): realtime notices are fed to Social the
## way Reverb would deliver them, and the polling fallbacks are exercised too.
##   godot --headless --path . res://tests/FriendsOnlineTest.tscn -- --api-url=http://127.0.0.1:8077

var token_b := ""
var b := {}


func _ready() -> void:
	print("API: ", ApiManager.base_url)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	var stamp := str(Time.get_ticks_usec()).right(6)
	var reg := await ApiManager.register("fa" + stamp, "fa%s@example.test" % stamp, "password123", "password123")
	check(reg.ok, "player A registered")
	var b_reg := await _raw(HTTPClient.METHOD_POST, "/api/register", {"username": "fb" + stamp,
		"email": "fb%s@example.test" % stamp, "password": "password123", "password_confirmation": "password123"}, "")
	token_b = str(b_reg.data.get("token", ""))
	b = b_reg.data.get("user", {})
	check(token_b != "" and int(b.get("id", 0)) > 0, "player B registered")
	var b_id := int(b.get("id", 0))
	var a_id := int(ApiManager.user.get("id", 0))

	# Links parse; the password never goes in one.
	check(Social.parse_link("?room=12&code=Ab3x") == {"room": 12, "code": "Ab3x"}, "a shared link parses")
	check(Social.parse_link("?room=12").is_empty() and Social.parse_link("").is_empty(), "a half link is ignored")

	# Friend request: A finds B by name and adds them; B accepts.
	var found: Dictionary = await Social.search_players("fb" + stamp)
	var row := _find(found.data.get("data", []), b_id)
	check(found.ok and str(row.get("relation", "")) == "none", "A finds B by username")
	var added: Dictionary = await Social.add_friend(b_id)
	check(added.ok, "A sends B a friend request")
	await Social.load_friends()
	check(not Social.request_with(b_id, "outgoing").is_empty(), "the request shows under Sent")
	check(await Social.relation_to(b_id) == "outgoing", "relation: outgoing")
	var b_friends := await _raw(HTTPClient.METHOD_GET, "/api/friends", null, token_b)
	var incoming: Array = b_friends.data.get("incoming", [])
	check(incoming.size() == 1 and int(incoming[0].get("user", {}).get("id", 0)) == a_id, "B sees A's request")
	var accepted := await _raw(HTTPClient.METHOD_POST, "/api/friends/requests/%d/accept" % int(incoming[0].get("request_id", 0)), null, token_b)
	check(accepted.ok, "B accepts")
	Social._on_friend_update({"type": "accepted", "user": b})  # As Reverb would deliver it.
	await wait_until(func() -> bool: return _find(Social.friends.get("friends", []), b_id).size() > 0, 5.0)
	var entry := _find(Social.friends.get("friends", []), b_id)
	check(str(entry.get("status", "")) == "online", "B is in A's friends, online")
	check(await Social.relation_to(b_id) == "friend", "relation: friend")

	# A friend request notice shows a toast with Accept.
	Social._on_friend_update({"type": "request", "request_id": 999999, "user": {"id": 777, "username": "someone"}})
	check(Social.toasts.has_offer("friend:999999"), "a friend request pops a toast")
	Social.toasts.dismiss("friend:999999")

	# Invite: A invites B into a new private room; B accepts and both are seated.
	var invited: Dictionary = await Social.invite_friend(b, PowerupLibrary.MODE_OFF)
	check(invited.ok and GameSession.status() == "waiting", "A's invite opens a private room A waits in")
	var room_id := GameSession.match_id()
	check(int(Social.sent_invite.get("room_id", 0)) == room_id, "A's sent invite is tracked")
	check(GameSession.match_view.get("room_name") != null and GameSession.powerup_mode() == "off", "the room has A's rules")
	var rooms := await _raw(HTTPClient.METHOD_GET, "/api/rooms", null, token_b)
	check(_find(rooms.data.get("data", []), room_id).is_empty(), "the private room isn't in the room list")
	var b_invites := await _raw(HTTPClient.METHOD_GET, "/api/invites", null, token_b)
	var invite: Dictionary = (b_invites.data.get("data", []) as Array).front() if not (b_invites.data.get("data", []) as Array).is_empty() else {}
	check(int(invite.get("room_id", 0)) == room_id, "B has A's invite")
	var b_join := await _raw(HTTPClient.METHOD_POST, "/api/invites/%d/accept" % int(invite.get("id", 0)), null, token_b)
	check(b_join.ok and str(b_join.data.get("match", {}).get("status", "")) == "setup", "B accepts and is seated")
	Social._on_invite_update({"type": "accepted", "invite": {"id": invite.get("id")}, "user": b})
	check(Social.sent_invite.is_empty(), "the host's pending invite clears when B answers")
	await GameSession.refresh()
	check(GameSession.status() == "setup", "A's room moves to setup")

	# Rematch: A offers after the game, B accepts, A loads the new game with colours swapped.
	await _play_out(room_id)
	check(GameSession.status() == "finished", "the invited game is played out")
	var offer: Dictionary = await Social.request_rematch(room_id)
	check(offer.ok and str(offer.data.get("status", "")) == "waiting", "A offers a rematch and waits")
	var b_status := await _raw(HTTPClient.METHOD_GET, "/api/games/%d/rematch" % room_id, null, token_b)
	check(str(b_status.data.get("status", "")) == "offered", "B sees the offer")
	var b_yes := await _raw(HTTPClient.METHOD_POST, "/api/games/%d/rematch" % room_id, null, token_b)
	var new_id := int(b_yes.data.get("match", {}).get("id", 0))
	check(b_yes.ok and str(b_yes.data.get("status", "")) == "started" and new_id > 0, "B accepts: the rematch starts")
	var a_status: Dictionary = await Social.rematch_status(room_id)
	check(str(a_status.data.get("status", "")) == "started", "A's poll says started")
	Social._on_rematch_update({"type": "started", "rematch": a_status.data.get("rematch", {})})  # As Reverb would.
	await wait_until(func() -> bool: return GameSession.match_id() == new_id, 6.0)
	check(GameSession.match_id() == new_id and GameSession.status() == "setup", "A is in the rematch")
	check(GameSession.my_side() == "black", "colours are swapped")
	check(GameSession.powerup_mode() == "off", "same powerup rules")

	# Declining: B offers after the rematch, A says no thanks.
	await _play_out(new_id)
	var b_offer := await _raw(HTTPClient.METHOD_POST, "/api/games/%d/rematch" % new_id, null, token_b)
	check(str(b_offer.data.get("status", "")) == "waiting", "B offers a rematch")
	var on_card: Dictionary = await Social.rematch_status(new_id)
	check(str(on_card.data.get("status", "")) == "offered", "A's card sees B's offer")
	GameSession.leave()  # Off the game-over card: the offer comes as a toast.
	Social._on_rematch_update({"type": "requested", "rematch": on_card.data.get("rematch", {}), "user": b})
	check(Social.toasts.has_offer("rematch:%d" % new_id), "the offer pops a toast off the card")
	await Social.withdraw_rematch(new_id)
	check(not Social.toasts.has_offer("rematch:%d" % new_id), "declining clears the toast")
	var b_after := await _raw(HTTPClient.METHOD_GET, "/api/games/%d/rematch" % new_id, null, token_b)
	check(str(b_after.data.get("status", "")) == "declined", "B sees the decline")

	# Room link: B hosts a locked room and shares a link; A opens it and is seated without the password.
	var b_room := await _raw(HTTPClient.METHOD_POST, "/api/rooms", {"name": "Link room " + stamp, "password": "secret1"}, token_b)
	var link_room := int(b_room.data.get("match", {}).get("id", 0))
	var link := await _raw(HTTPClient.METHOD_POST, "/api/rooms/%d/link" % link_room, null, token_b)
	var url := str(link.data.get("url", ""))
	check(link.ok and url.contains("room=%d" % link_room) and not url.contains("secret1"), "B gets a link without the password")
	var parsed := Social.parse_link("?" + url.get_slice("?", 1))
	check(int(parsed.get("room", 0)) == link_room, "the link's room and code parse")
	Social.open_link(int(parsed["room"]), str(parsed["code"]))
	await wait_until(func() -> bool: return GameSession.match_id() == link_room, 6.0)
	check(GameSession.match_id() == link_room and GameSession.my_side() == "black", "A joins through the link")
	var reused := await _raw(HTTPClient.METHOD_POST, "/api/rooms/%d/join" % link_room, {"code": str(parsed["code"])}, "")
	check(not reused.ok, "the code can't be used again")
	await GameSession.resign()
	await wait_until(func() -> bool: return GameSession.status() == "finished", 8.0)

	# A hosting a room gets a link of its own (the password stays out of it).
	var hosted: Dictionary = await Social.create_room("A's room " + stamp, "hunter22")
	check(hosted.ok, "A hosts a locked room")
	var own_link: Dictionary = await Social.room_link(GameSession.match_id())
	check(own_link.ok and str(own_link.get("url", "")).contains("code=") and not str(own_link.get("url", "")).contains("hunter22"), "A copies an invite link")
	await GameSession.resign()

	# Invite to A, by polling (no realtime): a toast with the rules, Accept seats A.
	await get_tree().create_timer(5.2).timeout  # B's invite cooldown.
	var b_invite := await _raw(HTTPClient.METHOD_POST, "/api/invites", {"user_id": a_id, "powerup_mode": "random"}, token_b)
	check(b_invite.ok, "B invites A")
	var invite_id := int(b_invite.data.get("invite", {}).get("id", 0))
	await Social.poll_invites()
	check(Social.toasts.has_offer("invite:%d" % invite_id), "A's invite toast pops (polling)")
	Social.toasts.dismiss("invite:%d" % invite_id)
	var seated: Dictionary = await Social.accept_invite({"id": invite_id})
	check(seated.ok and GameSession.match_id() == int(b_invite.data.get("match", {}).get("id", -1)), "A accepts and is seated")
	check(GameSession.powerup_mode() == "random", "with B's rules")
	await GameSession.resign()

	# Block: B can't reach A any more; B's chat lines vanish for A. Then a report.
	var blocked: Dictionary = await Social.block_player(b)
	check(blocked.ok and Social.is_blocked(b_id), "A blocks B")
	check(Social.is_blocked_message({"user": {"id": b_id}, "body": "hi"}), "B's chat lines are hidden")
	check(await Social.relation_to(b_id) == "blocked", "relation: blocked")
	var again := await _raw(HTTPClient.METHOD_POST, "/api/friends/requests", {"user_id": a_id}, token_b)
	check(again.status == 403, "B can't send A a friend request")
	await get_tree().create_timer(5.2).timeout
	var no_invite := await _raw(HTTPClient.METHOD_POST, "/api/invites", {"user_id": a_id}, token_b)
	check(no_invite.status == 403, "B can't invite A")
	Social._on_invite_update({"type": "invite", "invite": {"id": 999998, "from": b}})
	check(not Social.toasts.has_offer("invite:999998"), "invites from a blocked player never show")
	var reported: Dictionary = await Social.report_player(b_id, "harassment", "E2E report " + stamp, room_id)
	check(reported.ok, "A reports B")
	var unblocked: Dictionary = await Social.unblock_player(b_id)
	check(unblocked.ok and not Social.is_blocked(b_id), "A unblocks B")

	# The screens open with live data.
	ui.show_screen("friends")
	await frames(10)
	check(ui.current_name == "friends", "the friends screen opens")
	var sheet := PlayerCardSheet.open(ui, b)
	await wait_until(func() -> bool: return str(sheet.get("_relation")) not in ["", "unknown"], 5.0)
	check(str(sheet.get("_relation")) == "none", "B's player card loads the relation (no longer friends)")
	ui.close_dialog()

	await ApiManager.logout()
	finish()


## Both armies deploy, then A resigns: the match is finished (not cancelled).
func _play_out(match_id: int) -> void:
	var mine := GameSession.my_side()
	await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/setup" % match_id, {"placements": Ranks.random_formation(mine)})
	await _raw(HTTPClient.METHOD_POST, "/api/games/%d/setup" % match_id, {"placements": Ranks.random_formation(Ranks.opponent(mine))}, token_b)
	await GameSession.refresh()
	await wait_until(func() -> bool: return GameSession.status() == "active", 6.0)
	await GameSession.resign()
	await wait_until(func() -> bool: return GameSession.status() == "finished", 8.0)


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
