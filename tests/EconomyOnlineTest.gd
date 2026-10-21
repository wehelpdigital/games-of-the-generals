extends SmokeTestBase
## The economy against a running backend: the daily login reward, missions, a practice result,
## achievements and titles, and what an online win pays. Player A uses Economy/ApiManager,
## player B raw HTTP. Realtime isn't needed (run the backend with BROADCAST_CONNECTION=log).
##   godot --headless --path . res://tests/EconomyOnlineTest.tscn -- --api-url=http://127.0.0.1:8077

var _token_b := ""
var _token_a := ""


func _ready() -> void:
	print("API: ", ApiManager.base_url)
	await boot()
	var stamp := str(Time.get_ticks_usec()).right(6)
	var reg := await ApiManager.register("ea" + stamp, "ea%s@example.test" % stamp, "password123", "password123")
	check(reg.ok, "player A registered")
	_token_a = ApiManager.token
	var b_reg := await _raw(HTTPClient.METHOD_POST, "/api/register", {"username": "eb" + stamp,
		"email": "eb%s@example.test" % stamp, "password": "password123", "password_confirmation": "password123"}, "")
	_token_b = str(b_reg.data.get("token", ""))
	check(_token_b != "", "player B registered")
	var start_credits := int(ApiManager.user.get("credits", 0))

	# Daily login reward.
	await Economy.refresh_daily()
	check(int(Economy.daily.get("day", 0)) == 1 and not Economy.daily.get("claimed_today", true), "day 1 of the calendar is waiting")
	check(Economy.should_offer_daily(), "the dashboard would pop the calendar up")
	var claimed := await Economy.claim_daily()
	check(claimed.ok and int(claimed.data["reward"]["credits"]) == 50, "claiming day 1 pays 50 credits")
	check(int(ApiManager.user.get("credits", 0)) == start_credits + 50, "the balance updates locally")
	var twice := await Economy.claim_daily()
	check(not twice.ok and twice.status == 409, "a second claim the same day is refused")

	# Missions.
	await Economy.refresh_missions()
	check(Economy.missions.get("daily", {}).get("missions", []).size() == 3, "three daily missions")
	check(Economy.missions.get("weekly", {}).get("missions", []).size() == 3, "three weekly missions")
	var first: Dictionary = Economy.missions["daily"]["missions"][0]
	var swapped := await Economy.reroll_mission(int(first["id"]))
	check(swapped.ok and str(swapped.data["mission"]["key"]) != str(first["key"]), "a daily mission can be swapped")
	var early := await Economy.claim_mission(int(first["id"]))
	check(not early.ok and early.status == 409, "an unfinished mission can't be claimed")

	# Practice vs the AI.
	var practice := await Economy.report_practice("hard", true, 42)
	check(int(practice.get("credits", 0)) == 10 and practice.get("counted", false), "a practice win pays 10 credits")

	# Achievements and titles.
	await Economy.refresh_achievements()
	check(int(Economy.achievements.get("total", 0)) >= 30, "the achievement list loads")
	var title := await Economy.set_title("Warlord")
	check(not title.ok and title.status == 422, "a locked title can't be worn")

	# An online win: B resigns once both armies are deployed.
	var created := await ApiManager.create_match()
	var match_id := int(created.data.get("match", {}).get("id", 0))
	check(created.ok and match_id > 0, "A hosts a match")
	var joined := await _raw(HTTPClient.METHOD_POST, "/api/games/%d/join" % match_id, null, _token_b)
	check(joined.ok, "B joins")
	var setup_a := await _raw(HTTPClient.METHOD_POST, "/api/games/%d/setup" % match_id, {"placements": Ranks.random_formation(Ranks.WHITE)}, _token_a)
	var setup_b := await _raw(HTTPClient.METHOD_POST, "/api/games/%d/setup" % match_id, {"placements": Ranks.random_formation(Ranks.BLACK)}, _token_b)
	check(setup_a.ok and setup_b.ok, "both armies deployed")
	var resigned := await _raw(HTTPClient.METHOD_POST, "/api/games/%d/resign" % match_id, null, _token_b)
	check(resigned.ok, "B resigns")
	var summary := await Economy.fetch_match_rewards(match_id)
	check(int(summary.get("credits", 0)) == 160, "A's win paid 60 + 100 first-win bonus (got %s)" % str(summary.get("credits")))
	check(int(summary.get("breakdown", {}).get("win", 0)) == 60, "the breakdown shows the win")
	check(int(summary.get("xp", 0)) > 0, "the summary includes XP")

	await ApiManager.logout()
	finish()


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
