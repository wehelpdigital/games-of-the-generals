extends SmokeTestBase
## Online match against a running backend. This client plays white through the real UI flow
## (ApiManager, GameSession, Reverb, pointer input); a second account plays black over raw HTTP.
## Realtime is verified by timing: the safety poll runs every 20 s, so events seen within a few
## seconds came over the WebSocket.
##
##   godot --headless --path . res://tests/OnlineSmokeTest.tscn -- --api-url=http://127.0.0.1:8000
## Use a backend whose database has no other waiting matches (e.g. after `migrate:fresh --seed`).

const REALTIME_BUDGET := 5.0

var _token_b := ""


func _ready() -> void:
	await boot()
	print("API: ", ApiManager.base_url)
	var stamp := str(Time.get_ticks_usec()).right(7)
	var password := "password123"

	var res := await ApiManager.register("alpha" + stamp, "alpha%s@example.test" % stamp, password, password)
	check(res.ok, "register player A through ApiManager %s" % res.error)
	check(FileAccess.file_exists(ApiManager.AUTH_FILE), "token persisted to user://auth.json")
	var b := await _as_b(HTTPClient.METHOD_POST, "/api/register", {
		"username": "bravo" + stamp, "email": "bravo%s@example.test" % stamp,
		"password": password, "password_confirmation": password,
	})
	check(b.ok, "register player B over raw HTTP")
	_token_b = b.data.get("token", "")

	GameSession.find_match()
	await wait_until(func() -> bool: return GameSession.status() == "waiting")
	check(GameSession.status() == "waiting" and GameSession.my_side() == Ranks.WHITE, "A creates a waiting match as white")
	var match_id := GameSession.match_id()
	var subscribed := await wait_until(func() -> bool: return ReverbManager.is_subscribed(GameSession._channel), 8.0)
	check(subscribed, "A subscribed to %s via /api/broadcasting/auth" % GameSession._channel)

	var started := Time.get_ticks_msec()
	var join := await _as_b(HTTPClient.METHOD_POST, "/api/games")
	check(join.ok and join.data["match"]["id"] == match_id and join.data["match"]["your_side"] == Ranks.BLACK, "B joins the same match as black")
	var saw_join := await wait_until(func() -> bool: return GameSession.status() == "setup", REALTIME_BUDGET)
	check(saw_join, "A saw PlayerJoined in %d ms" % (Time.get_ticks_msec() - started))

	GameSession.submit_setup(board.get_setup_placements())
	await wait_until(func() -> bool: return GameSession.match_view.get("setup_ready", {}).get(Ranks.WHITE, false))
	check(GameSession.match_view["setup_ready"][Ranks.WHITE], "A's formation accepted")

	started = Time.get_ticks_msec()
	var setup_b := await _as_b(HTTPClient.METHOD_POST, "/api/games/%d/setup" % match_id, {"placements": Ranks.random_formation(Ranks.BLACK)})
	check(setup_b.ok, "B's formation accepted")
	var live := await wait_until(func() -> bool: return GameSession.status() == "active" and board.pieces.size() == 42 and not board._busy, REALTIME_BUDGET)
	check(live, "A saw GameStarted and loaded 42 pieces in %d ms" % (Time.get_ticks_msec() - started))
	var hidden := board.pieces.values().filter(func(p: Piece3D) -> bool: return p.side == Ranks.BLACK and p.rank == "")
	check(hidden.size() == 21, "server withheld all 21 enemy ranks")

	# White moves through pointer input.
	await wait_until(func() -> bool: return board._can_interact())
	var move := find_legal_move()
	var before := GameSession.version
	await tap_move(move["from"], move["to"])
	var accepted := await wait_until(func() -> bool: return GameSession.version > before)
	check(accepted and not GameSession.is_my_turn(), "A's move %s -> %s accepted by the arbiter" % [move["from"], move["to"]])

	# Black replies over HTTP; A must animate it from the PieceMoved event.
	var view_b: Dictionary = (await _as_b(HTTPClient.METHOD_GET, "/api/games/%d" % match_id)).data["match"]
	var leaked: Array = view_b["pieces"].filter(func(p: Dictionary) -> bool: return p["side"] == Ranks.WHITE and p["rank"] != null)
	check(leaked.is_empty(), "B's view contains no white ranks")
	var reply := _black_quiet_move(view_b["pieces"])
	before = GameSession.version
	started = Time.get_ticks_msec()
	var sent := await _as_b(HTTPClient.METHOD_POST, "/api/games/%d/move" % match_id, {"from": reply["from"], "to": reply["to"]})
	check(sent.ok, "B's reply accepted %s" % sent.get("error", ""))
	var animated := await wait_until(func() -> bool: return GameSession.version > before and not board._busy, REALTIME_BUDGET)
	var target := Vector2i(reply["to"]["x"], reply["to"]["y"])
	check(animated and board.piece_at(target) != null, "A animated B's PieceMoved in %d ms" % (Time.get_ticks_msec() - started))
	check(GameSession.is_my_turn() and board.can_act, "turn passes back to A")

	# An illegal move is refused and the piece returns home.
	var piece: Piece3D = board.pieces.values().filter(func(p: Piece3D) -> bool: return p.side == Ranks.WHITE)[0]
	var home := piece.cell
	var rejected := await ApiManager.send_move(match_id, home, home + Vector2i(1, 1))
	check(not rejected.ok and rejected.status == 422, "diagonal move rejected with 422")

	GameSession.resign()
	var over := await wait_until(func() -> bool: return GameSession.status() == "finished", REALTIME_BUDGET)
	check(over and GameSession.match_view.get("winner") == Ranks.BLACK, "resignation ends the match, black wins")
	var final_b: Dictionary = (await _as_b(HTTPClient.METHOD_GET, "/api/games/%d" % match_id)).data["match"]
	check(final_b["status"] == "finished" and final_b["end_reason"] == "resignation", "B sees the finished match")
	var board_res := await ApiManager.leaderboard("monthly")
	check(board_res.ok and board_res.data["data"].size() >= 2, "both players on the monthly leaderboard")
	finish()


## Plain HTTP as player B, so the client's own session (player A) is never touched.
func _as_b(method: int, path: String, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if _token_b != "":
		headers.append("Authorization: Bearer " + _token_b)
	http.request(ApiManager.base_url + path, headers, method, "" if body == null else JSON.stringify(body))
	var response: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var status: int = response[1]
	return {"ok": status >= 200 and status < 300, "status": status, "data": data, "error": str(data.get("message", ""))}


func _black_quiet_move(pieces: Array) -> Dictionary:
	var occupied := {}
	for p: Dictionary in pieces:
		occupied[Vector2i(p["x"], p["y"])] = true
	for p: Dictionary in pieces:
		if p["side"] != Ranks.BLACK or p["rank"] == "FLG":
			continue
		for cell in Ranks.neighbors(Vector2i(p["x"], p["y"])):
			if not occupied.has(cell):
				return {"from": {"x": int(p["x"]), "y": int(p["y"])}, "to": {"x": cell.x, "y": cell.y}}
	return {}
