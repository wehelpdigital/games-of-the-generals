extends Node
## Player profile module: the account profile (photo, hometown, XP, rank, tasks, stats, guild),
## the rank ladder, multi-level location leaderboards and guilds. Registers its screens with
## ScreenRegistry. Every call goes through api(), which tests can redirect with `mock`.
##
##     await Profile.refresh()
##     print(Profile.data.rank_name, " ", Profile.data.xp)

signal changed
signal promoted(tier: int)  ## The rank went up since the last refresh.

## Rank XP thresholds (config/progression.php), used until /api/progression answers.
const FALLBACK_TIER_XP := [0, 100, 250, 500, 900, 1400, 2100, 3000, 4200, 5700, 7500, 9800, 12500]
const FALLBACK_CHARTER_PRICE := 5000
const DEFAULT_COUNTRY := {"code": "PH", "name": "Philippines"}

var data: Dictionary = {}  ## The `profile` object from GET /api/profile ({} when logged out).
var loaded := false  ## True once the server answered (else `data` is built from ApiManager.user).
var tiers: Array = []  ## [{tier, name, xp, tasks: [{key, label, target}]}]
var pending_promotion := -1  ## Tier to celebrate the next time the dashboard opens.

## Tests: func(method: int, path: String, body: Variant) -> Dictionary (an ApiManager result).
var mock: Callable

var _locations: Dictionary = {}  # "level|parent" -> Array
var _charter_price := -1
var _last_refresh := -100000


func _ready() -> void:
	ScreenRegistry.register("dashboard", preload("res://ui/screens/DashboardScreen.gd"))
	ScreenRegistry.register("profile", preload("res://ui/screens/ProfileScreen.gd"))
	ScreenRegistry.register("ranks", preload("res://ui/screens/RanksScreen.gd"))
	ScreenRegistry.register("guilds", preload("res://ui/screens/GuildsScreen.gd"))
	ScreenRegistry.register("guild", preload("res://ui/screens/GuildScreen.gd"))
	ApiManager.auth_changed.connect(_on_auth_changed)
	ApiManager.user_updated.connect(_on_user_updated)
	if ApiManager.is_logged_in():
		_seed_from_user()
		refresh.call_deferred()


# --- Requests ---------------------------------------------------------------------------------

func api(method: int, path: String, body: Variant = null, authenticated := true) -> Dictionary:
	if mock.is_valid():
		return mock.call(method, path, body)
	return await ApiManager.request(method, path, body, authenticated)


## Reloads the profile. `min_interval` skips the call if the last one was that recent (seconds).
func refresh(min_interval := 0.0) -> void:
	if not ApiManager.is_logged_in():
		return
	var now := Time.get_ticks_msec()
	if now - _last_refresh < int(min_interval * 1000.0):
		return
	_last_refresh = now
	var res := await api(HTTPClient.METHOD_GET, "/api/profile")
	if res.ok and res.data.get("profile") is Dictionary:
		_set_data(res.data["profile"], true)
	if tiers.is_empty():
		await load_tiers()


func load_tiers() -> Array:
	var res := await api(HTTPClient.METHOD_GET, "/api/progression", null, false)
	if res.ok and res.data.get("tiers") is Array and not (res.data["tiers"] as Array).is_empty():
		tiers = res.data["tiers"]
		changed.emit()
	return tiers


func upload_avatar(image: Image) -> Dictionary:
	var old_url := avatar_url()
	var res := await api(HTTPClient.METHOD_POST, "/api/profile/avatar", FilePicker.to_upload(image))
	if res.ok:
		RemoteImage.forget(old_url)
		_take_profile(res)
	return res


func remove_avatar() -> Dictionary:
	var old_url := avatar_url()
	var res := await api(HTTPClient.METHOD_DELETE, "/api/profile/avatar")
	if res.ok:
		RemoteImage.forget(old_url)
		if not _take_profile(res):
			data["avatar_url"] = null
			changed.emit()
	return res


## fields: {country, region?, province?, city?} — codes (a free-text city outside the Philippines).
func set_location(fields: Dictionary) -> Dictionary:
	var res := await api(HTTPClient.METHOD_PUT, "/api/profile", fields)
	if res.ok:
		_take_profile(res)
	return res


## Records a share for the share tasks; returns the result with data.xp_awarded.
func record_share(platform: String) -> Dictionary:
	var res := await api(HTTPClient.METHOD_POST, "/api/tasks/share", {"platform": platform})
	if res.ok:
		_take_profile(res)
	return res


## level: "region" | "province" | "city"; parent: the parent's code. Cached per session.
func locations(level: String, parent := "") -> Array:
	var key := level + "|" + parent
	if _locations.has(key):
		return _locations[key]
	var query := "/api/locations?level=" + level
	if parent != "":
		query += "&parent=" + parent.uri_encode()
	var res := await api(HTTPClient.METHOD_GET, query, null, false)
	if not res.ok:
		return []
	var list: Array = res.data.get("data", [])
	_locations[key] = list
	return list


# --- Leaderboards -----------------------------------------------------------------------------

## The classic rating board: period "global" | "monthly".
func global_leaderboard(period := "global", page := 1, per_page := 20) -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/api/leaderboard?period=%s&page=%d&per_page=%d" % [period, page, per_page], null, false)


## level: city | province | region | country; period: all | monthly.
func location_leaderboard(level: String, code: String, period := "all", page := 1, per_page := 20) -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/api/leaderboard/location?level=%s&code=%s&period=%s&page=%d&per_page=%d" % [
		level, code.uri_encode(), period, page, per_page], null, false)


## My place at each level: {city: {rank, total}, province, region, country, global}.
func my_positions() -> Dictionary:
	var res := await api(HTTPClient.METHOD_GET, "/api/leaderboard/me")
	if not res.ok:
		return {}
	var positions: Variant = res.data.get("data", res.data)
	return positions if positions is Dictionary else {}


# --- Guilds -----------------------------------------------------------------------------------

func guilds(search := "", page := 1) -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/api/guilds?search=%s&page=%d" % [search.uri_encode(), page], null, false)


func guild(id: int) -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/api/guilds/%d" % id, null, false)


func guild_leaderboard(page := 1) -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/api/guilds/leaderboard?page=%d" % page, null, false)


func create_guild(guild_name: String, tag: String) -> Dictionary:
	return await _guild_change(HTTPClient.METHOD_POST, "/api/guilds", {"name": guild_name, "tag": tag})


func join_guild(id: int) -> Dictionary:
	return await _guild_change(HTTPClient.METHOD_POST, "/api/guilds/%d/join" % id)


func leave_guild() -> Dictionary:
	return await _guild_change(HTTPClient.METHOD_POST, "/api/guilds/leave")


func upload_guild_logo(id: int, image: Image) -> Dictionary:
	return await _guild_change(HTTPClient.METHOD_POST, "/api/guilds/%d/logo" % id, FilePicker.to_upload(image, true))


func kick_member(guild_id: int, user_id: int) -> Dictionary:
	return await api(HTTPClient.METHOD_DELETE, "/api/guilds/%d/members/%d" % [guild_id, user_id])


func transfer_guild(guild_id: int, user_id: int) -> Dictionary:
	return await _guild_change(HTTPClient.METHOD_POST, "/api/guilds/%d/transfer" % guild_id, {"user_id": user_id})


## Price of the Guild Charter shop item (0 while the shop is in test mode).
func charter_price() -> int:
	if is_test_mode():
		return 0
	if _charter_price < 0:
		_charter_price = FALLBACK_CHARTER_PRICE
		var res := await api(HTTPClient.METHOD_GET, "/api/shop/items", null, false)
		var items: Variant = res.data.get("data", res.data.get("items", [])) if res.ok else []
		if items is Array:
			for item: Variant in items:
				if item is Dictionary and (item.get("slug") == "guild_charter" or item.get("type") == "guild_charter"):
					_charter_price = int(item.get("price", FALLBACK_CHARTER_PRICE))
					break
	return _charter_price


func _guild_change(method: int, path: String, body: Variant = null) -> Dictionary:
	var res := await api(method, path, body)
	if res.ok:
		await refresh()  # Membership, role or logo changed.
	return res


# --- Derived values ---------------------------------------------------------------------------

func is_test_mode() -> bool:
	return bool(ServerConfig.get_value("shop_test_mode", true))


func tier() -> int:
	return PlayerRanks.clamp_tier(data.get("rank_tier", 0))


func avatar_url() -> String:
	var url: Variant = data.get("avatar_url")
	return str(url) if url != null else ""


func credits() -> int:
	return int(data.get("credits", ApiManager.user.get("credits", 0)))


func my_guild() -> Dictionary:
	var g: Variant = data.get("guild")
	return g if g is Dictionary else {}


## XP needed for a tier: from /api/progression, else the built-in table.
func tier_xp(t: int) -> int:
	for entry: Variant in tiers:
		if entry is Dictionary and int(entry.get("tier", -1)) == t:
			return int(entry.get("xp", 0))
	return FALLBACK_TIER_XP[clampi(t, 0, PlayerRanks.MAX_TIER)]


## {xp, from, to, ratio, maxed}: progress from this rank's threshold to the next one's.
func xp_progress() -> Dictionary:
	var xp := int(data.get("xp", 0))
	var t := tier()
	if t >= PlayerRanks.MAX_TIER:
		return {"xp": xp, "from": tier_xp(t), "to": tier_xp(t), "ratio": 1.0, "maxed": true}
	var from := int(data.get("rank_xp", tier_xp(t)))
	var to := int(next_rank().get("xp", tier_xp(t + 1)))
	return {"xp": xp, "from": from, "to": to, "ratio": clampf(float(xp - from) / maxf(1.0, to - from), 0.0, 1.0), "maxed": false}


## {tier, name, xp_needed, tasks: [{key, label, progress, target, done}]} or {} at the top.
func next_rank() -> Dictionary:
	var next: Variant = data.get("next_rank")
	return next if next is Dictionary else {}


## The tasks for a tier from the ladder (targets only), for the ranks screen.
func tier_tasks(t: int) -> Array:
	for entry: Variant in tiers:
		if entry is Dictionary and int(entry.get("tier", -1)) == t:
			return entry.get("tasks", [])
	return []


## {code, name} at a level ("country", "region", "province", "city"), or {}.
func place(level: String) -> Dictionary:
	var p: Variant = data.get(level)
	if p is Dictionary and str(p.get("name", "")) != "":
		return p
	return {}


func has_location() -> bool:
	return not place("city").is_empty() or not place("province").is_empty()


## "Alcala, Pangasinan" style hometown line ("" when unset).
func location_text(with_country := false) -> String:
	var parts: Array[String] = []
	var levels := ["city", "province"] if not with_country else ["city", "province", "country"]
	for level: String in levels:
		var p := place(level)
		if not p.is_empty():
			parts.append(str(p["name"]))
	if parts.is_empty() and not place("region").is_empty():
		parts.append(str(place("region")["name"]))
	return ", ".join(parts)


func stat(key: String) -> int:
	var stats: Variant = data.get("stats")
	if stats is Dictionary:
		return int(stats.get(key, 0))
	return int(ApiManager.user.get(key, 0))


# --- State ------------------------------------------------------------------------------------

func _take_profile(res: Dictionary) -> bool:
	if res.data.get("profile") is Dictionary:
		_set_data(res.data["profile"], true)
		return true
	return false


func _set_data(profile: Dictionary, from_server: bool) -> void:
	var old_tier := tier() if loaded else -1
	data = profile
	if from_server:
		loaded = true
		if old_tier >= 0 and tier() > old_tier:
			pending_promotion = tier()
			promoted.emit(tier())
	changed.emit()


## Until the profile endpoint answers, show what the login response already told us.
func _seed_from_user() -> void:
	var user := ApiManager.user
	var stats := {"wins": int(user.get("wins", 0)), "losses": int(user.get("losses", 0)),
		"games_played": int(user.get("wins", 0)) + int(user.get("losses", 0)), "ranked_wins": 0}
	var t := PlayerRanks.clamp_tier(user.get("rank_tier", 0))
	_set_data({
		"id": user.get("id"), "username": str(user.get("username", "Player")), "avatar_url": user.get("avatar_url"),
		"xp": int(user.get("xp", 0)), "rank_tier": t, "rank_name": PlayerRanks.name_of(t),
		"credits": int(user.get("credits", 0)), "stats": stats, "guild": user.get("guild"),
		"country": DEFAULT_COUNTRY, "region": null, "province": null, "city": null, "next_rank": null,
	}, false)


func _on_auth_changed(logged_in: bool) -> void:
	if logged_in:
		_seed_from_user()
		refresh()
	else:
		data = {}
		loaded = false
		pending_promotion = -1
		changed.emit()


func _on_user_updated(user: Dictionary) -> void:
	if data.is_empty() or user.is_empty():
		return
	# Credits change in the shop and after matches; keep the header in sync.
	if user.has("credits"):
		data["credits"] = int(user["credits"])
	if user.has("avatar_url"):
		data["avatar_url"] = user["avatar_url"]
	changed.emit()
