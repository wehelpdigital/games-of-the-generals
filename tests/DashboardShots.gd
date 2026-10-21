extends SmokeTestBase
## Renders the profile screens with fake data for visual review: the dashboard in every theme, a
## promotion, profile, hometown picker, share sheet, rank ladder, leaderboards and guilds. All API
## calls go to Profile.mock, so no server is needed. Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/DashboardShots.tscn -- --out=<dir>
## Phone: --resolution 390x844 (adds a "phone_" prefix). --only=<prefix> renders a subset.
## Headless (no images) it still walks every screen and fails on script errors.

const ME := 7
const NAMES := ["KapitanTikbalang", "MayumiPH", "LakanDiwa", "bayani_09", "Datu_Puti", "LolaBasyang", "SpyNiJuan",
	"ApoyAtTubig", "Kidlat23", "TalaNgUmaga", "AgilaNgNorte", "BantayBuhangin", "SalpakQueen", "Heneral_Luna_Fan",
	"Mangyan_Mage", "PusoNgAlcala", "Sinigang_Supreme", "TaongBundok", "Bagwis", "Kalabaw_Kid"]

var _out := "user://screenshots/dashboard"
var _only := ""
var _prefix := ""
var _profile: Dictionary
var _shots := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	await boot()
	var view := get_viewport().get_visible_rect().size
	_prefix = "phone_" if view.y > view.x else ""
	var ui: UIRoot = main.get_node("UI")

	# A pretend session: requests that slip past the mock fail fast instead of logging us out.
	ApiManager.base_url = "http://127.0.0.1:9"
	ApiManager.token = "fake-token"
	ApiManager.user = {"id": ME, "username": "KapitanTikbalang", "credits": 4850}
	_fake_pictures()
	_profile = _fake_profile()
	Profile.mock = _mock
	Profile._set_data(_profile.duplicate(true), true)
	Profile.tiers = _fake_tiers()
	ServerConfig.values["shop_test_mode"] = false

	var themes: Array = DashboardThemes.keys()
	if _prefix != "":
		themes = ["classic", "neon_city", "sakura"]
	for theme: String in themes:
		ServerConfig.values["dashboard_theme"] = theme
		ServerConfig.values["dashboard_palette"] = null
		ServerConfig.values["season"] = null
		ServerConfig.values["maintenance_message"] = ""
		if theme == "halloween":
			ServerConfig.values["season"] = {"slug": "halloween-2026", "name": "Halloween Havoc",
				"description": "Spooky arenas and pumpkin taunts in the shop!", "ends_at": _iso_in_days(9)}
		if theme == "winter":
			ServerConfig.values["maintenance_message"] = "Servers restart at 02:00 PHT for 10 minutes."
		await _show(ui, "dashboard", {}, "dash_" + theme, 1.1)
	ServerConfig.values["dashboard_theme"] = "classic"
	ServerConfig.values["season"] = null
	ServerConfig.values["maintenance_message"] = ""

	if _wanted("promotion"):
		ui.show_screen("dashboard")
		await frames(2)
		Profile.pending_promotion = -1
		ui.screen("dashboard").call("_celebrate", 6)
		await _shot("promotion", 1.4)
		ui.close_dialog()

	await _show(ui, "profile", {}, "profile", 0.9)
	if _wanted("hometown"):
		LocationPicker.open(ui)
		await _shot("hometown", 0.9)
		ui.close_dialog()
	if _wanted("share"):
		ShareSheet.open(ui)
		await _shot("share", 0.8)
		ui.close_dialog()
	await _show(ui, "ranks", {}, "ranks", 0.9)
	for tab: String in ["near", "global", "city", "guilds"]:
		await _show(ui, "leaderboard", {"tab": tab}, "lb_" + tab, 1.0)
	await _show(ui, "guild", {"id": 3}, "guild_master", 1.0)

	# A Sergeant without a guild: locked charter, then a Major founding one.
	var rookie := _profile.duplicate(true)
	rookie["rank_tier"] = 1
	rookie["rank_name"] = "Sergeant"
	rookie["rank_xp"] = 100
	rookie["xp"] = 180
	rookie["guild"] = null
	rookie["next_rank"] = {"tier": 2, "name": "Second Lieutenant", "xp": 250, "xp_needed": 70, "tasks": [
		{"key": "wins", "label": "Win 5 online games", "progress": 4, "target": 5, "done": false},
		{"key": "shares", "label": "Share the game on 1 different days", "progress": 0, "target": 1, "done": false}]}
	Profile._set_data(rookie, true)
	await _show(ui, "guilds", {}, "guilds_locked", 1.0)
	await _show(ui, "guild", {"id": 3}, "guild_visitor", 1.0)
	await _show(ui, "dashboard", {}, "dash_rookie", 1.0)
	var major := _profile.duplicate(true)
	major["guild"] = null
	Profile._set_data(major, true)
	await _show(ui, "guilds", {"tab": "rankings"}, "guilds_rankings", 1.0)
	if _wanted("guild_create"):
		ServerConfig.values["shop_test_mode"] = false  # Show the charter price.
		ui.screen("guilds").call("_open_create")
		await _shot("guild_create", 0.9)
		ui.close_dialog()
	var homeless := _profile.duplicate(true)
	for level in ["region", "province", "city"]:
		homeless[level] = null
	Profile._set_data(homeless, true)
	await _show(ui, "leaderboard", {"tab": "near"}, "lb_no_hometown", 0.9)

	ApiManager.token = ""
	ApiManager.user = {}
	print("\n%d screenshots in %s" % [_shots, ProjectSettings.globalize_path(_out)])
	finish()


func _wanted(file: String) -> bool:
	return _only == "" or file.begins_with(_only)


func _show(ui: UIRoot, screen: String, args: Dictionary, file: String, wait: float) -> void:
	if not _wanted(file):
		return
	ui.show_screen(screen, args)
	await _shot(file, wait)
	check(ui.current_name == screen, "%s screen stays open" % screen)


func _shot(file: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	if DisplayServer.get_name() == "headless":
		return  # No frames are drawn headless (frame_post_draw never fires).
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [_out, _prefix, file])
	_shots += 1
	print("saved ", _prefix, file)


# --- Fake server --------------------------------------------------------------------------------

func _mock(method: int, path: String, body: Variant) -> Dictionary:
	var data: Variant = null
	if method == HTTPClient.METHOD_GET:
		if path == "/api/profile":
			data = {"profile": Profile.data}
		elif path.begins_with("/api/progression"):
			data = {"tiers": _fake_tiers()}
		elif path.begins_with("/api/leaderboard/me"):
			data = {"city": {"code": "0105503000", "name": "Alcala", "rank": 3, "total": 41},
				"province": {"code": "0105500000", "name": "Pangasinan", "rank": 18, "total": 655},
				"region": {"code": "0100000000", "name": "Region I (Ilocos Region)", "rank": 64, "total": 2210},
				"country": {"code": "PH", "name": "Philippines", "rank": 512, "total": 38140},
				"global": {"code": null, "name": "Global", "rank": 640, "total": 40211}}
		elif path.begins_with("/api/leaderboard/location"):
			data = _fake_board(_query(path, "level"), int(_query(path, "per_page")), int(_query(path, "page")))
		elif path.begins_with("/api/leaderboard"):
			data = _fake_global()
		elif path.begins_with("/api/guilds/leaderboard") or path.begins_with("/api/guilds?"):
			data = _fake_guilds(path.contains("leaderboard"))
		elif path.begins_with("/api/guilds/"):
			data = {"guild": _fake_guild()}
		elif path.begins_with("/api/locations"):
			data = _fake_locations(_query(path, "level"))
		elif path.begins_with("/api/shop/items"):
			data = {"data": [{"slug": "guild_charter", "type": "guild_charter", "price": 5000}], "test_mode": false}
	elif path == "/api/tasks/share":
		data = {"profile": Profile.data, "xp_awarded": 20}
	if data == null:
		return {"ok": false, "status": 404, "data": {}, "error": "Not in the fake server: " + path}
	return {"ok": true, "status": 200, "data": data, "error": ""}


func _query(path: String, key: String) -> String:
	for part in path.get_slice("?", 1).split("&"):
		if part.begins_with(key + "="):
			return part.trim_prefix(key + "=").uri_decode()
	return ""


func _fake_profile() -> Dictionary:
	return {
		"id": ME, "username": "KapitanTikbalang", "avatar_url": "fake/avatar/0.png",
		"country": {"code": "PH", "name": "Philippines"},
		"region": {"code": "0100000000", "name": "Region I (Ilocos Region)"},
		"province": {"code": "0105500000", "name": "Pangasinan"},
		"city": {"code": "0105503000", "name": "Alcala"},
		"xp": 1820, "rank_tier": 5, "rank_name": "Major", "rank_xp": 1400, "elo": 1342, "credits": 4850,
		"stats": {"wins": 31, "losses": 18, "draws": 0, "games_played": 49, "ranked_wins": 12, "ranked_games": 20},
		"guild": {"id": 3, "name": "Pangasinan Tigers", "tag": "PGT", "logo_url": "fake/logo/3.png", "role": "master"},
		"next_rank": {"tier": 6, "name": "Lieutenant Colonel", "xp": 2100, "xp_needed": 280, "tasks": [
			{"key": "wins", "label": "Win 40 online games", "progress": 31, "target": 40, "done": false},
			{"key": "ranked_wins", "label": "Win 12 ranked matches", "progress": 12, "target": 12, "done": true},
			{"key": "avatar", "label": "Upload a profile photo", "progress": 1, "target": 1, "done": true}]},
	}


func _fake_tiers() -> Array:
	var tasks := [[], [["wins", 3]], [["wins", 5], ["shares", 1]], [["wins", 10], ["location", 1]], [["wins", 18], ["ranked_games", 5]],
		[["wins", 28], ["ranked_wins", 5], ["shares", 3]], [["wins", 40], ["ranked_wins", 12], ["avatar", 1]],
		[["wins", 60], ["ranked_wins", 20]], [["wins", 90], ["ranked_wins", 35], ["shares", 5]], [["wins", 130], ["ranked_wins", 50]],
		[["wins", 180], ["ranked_wins", 75], ["shares", 8]], [["wins", 250], ["ranked_wins", 110]],
		[["wins", 350], ["ranked_wins", 160], ["shares", 12]]]
	var labels := {"wins": "Win %d online games", "ranked_games": "Play %d ranked matches", "ranked_wins": "Win %d ranked matches",
		"shares": "Share the game on %d different days", "location": "Set your hometown on your profile",
		"avatar": "Upload a profile photo"}
	var out := []
	for t in 13:
		var list := []
		for task: Array in tasks[t]:
			var label: String = labels[task[0]]
			list.append({"key": task[0], "label": label % task[1] if label.contains("%d") else label, "target": task[1]})
		out.append({"tier": t, "name": PlayerRanks.name_of(t), "xp": Profile.FALLBACK_TIER_XP[t], "tasks": list})
	return out


func _fake_player(i: int, xp: int, wins: int) -> Dictionary:
	var tier := 0
	for t in 13:
		if xp >= Profile.FALLBACK_TIER_XP[t]:
			tier = t
	return {"user_id": 100 + i, "username": NAMES[i % NAMES.size()], "avatar_url": "fake/avatar/%d.png" % (i % 6) if i % 3 != 2 else null,
		"xp": xp, "rank_tier": tier, "rank_name": PlayerRanks.name_of(tier), "wins": wins}


func _fake_board(level: String, per_page: int, page: int) -> Dictionary:
	var size: int = {"city": 41, "province": 655, "region": 2210, "country": 38140}.get(level, 50)
	var names := {"city": "Alcala", "province": "Pangasinan", "region": "Region I (Ilocos Region)", "country": "Philippines"}
	var my_rank: int = {"city": 3, "province": 18, "region": 64, "country": 512}.get(level, 3)
	per_page = maxi(1, per_page)
	page = maxi(1, page)
	var rows := []
	for i in per_page:
		var rank := (page - 1) * per_page + i + 1
		if rank > size:
			break
		var entry := _fake_player(rank + {"city": 0, "province": 3, "region": 7, "country": 11}.get(level, 0), 14000 / (rank + 3) + 300, 260 / (rank + 2) + 4)
		entry["rank"] = rank
		if rank == my_rank:
			entry.merge({"user_id": ME, "username": "KapitanTikbalang", "avatar_url": "fake/avatar/0.png", "xp": 1820,
				"rank_tier": 5, "rank_name": "Major", "wins": 31}, true)
		rows.append(entry)
	return {"level": level, "code": "x", "name": names.get(level, "?"), "data": rows,
		"meta": {"current_page": page, "last_page": ceili(size / float(per_page)), "per_page": per_page, "total": size}}


func _fake_global() -> Dictionary:
	var rows := []
	for i in 15:
		var entry := _fake_player(i + 2, 12000 / (i + 2) + 500, 300 / (i + 2) + 8)
		entry.merge({"rank": i + 1, "rating": 2140 - i * 37, "losses": 20 + i * 3, "win_ratio": 0.82 - i * 0.025}, true)
		rows.append(entry)
	return {"data": rows, "meta": {"current_page": 1, "last_page": 12, "per_page": 15, "total": 180}}


func _fake_guilds(ranked: bool) -> Dictionary:
	var specs := [["Pangasinan Tigers", "PGT"], ["Ilocos Eagles", "ILE"], ["Manila Mavericks", "MNL"], ["Cebu Sharks", "CEB"],
		["Davao Durians", "DVO"], ["Bicol Volcanoes", "BCL"], ["Iloilo Pirates", "ILO"], ["Baguio Pines", "BAG"]]
	var rows := []
	for i in specs.size():
		var guild := {"id": 3 + i, "name": specs[i][0], "tag": specs[i][1], "logo_url": "fake/logo/%d.png" % (3 + i) if i % 2 == 0 else null,
			"master": {"id": 100 + i, "username": NAMES[i]}, "members_count": 46 - i * 5, "xp_total": 64000 - i * 6100,
			"wins_total": 1900 - i * 170}
		if ranked:
			guild["rank"] = i + 1
		rows.append(guild)
	return {"data": rows, "meta": {"current_page": 1, "last_page": 3, "per_page": 8, "total": 21}}


func _fake_guild() -> Dictionary:
	var members := [{"user_id": ME, "username": "KapitanTikbalang", "avatar_url": "fake/avatar/0.png", "rank_tier": 5,
		"rank_name": "Major", "xp": 1820, "wins": 31, "role": "master"}]
	for i in 7:
		var member := _fake_player(i + 1, 1500 - i * 190, 30 - i * 3)
		member["role"] = "member"
		members.append(member)
	return {"id": 3, "name": "Pangasinan Tigers", "tag": "PGT", "logo_url": "fake/logo/3.png",
		"master": {"id": ME, "username": "KapitanTikbalang"}, "members_count": members.size(), "xp_total": 64000,
		"wins_total": 1900, "members": members}


func _fake_locations(level: String) -> Dictionary:
	var names: Array = {
		"country": ["Philippines", "United States", "United Arab Emirates", "Saudi Arabia", "Japan", "Canada"],
		"region": ["National Capital Region (NCR)", "Cordillera Administrative Region (CAR)", "Region I (Ilocos Region)",
			"Region II (Cagayan Valley)", "Region III (Central Luzon)", "Region IV-A (CALABARZON)", "MIMAROPA Region",
			"Region V (Bicol Region)", "Region VI (Western Visayas)", "Region VII (Central Visayas)"],
		"province": ["Ilocos Norte", "Ilocos Sur", "La Union", "Pangasinan"],
		"city": ["Agno", "Aguilar", "Alaminos City", "Alcala", "Anda", "Asingan", "Balungao", "Bani", "Basista"],
	}.get(level, [])
	var rows := []
	for i in names.size():
		rows.append({"code": "%s%02d" % [level.left(2).to_upper(), i], "name": names[i]})
	return {"data": rows}


## Colourful stand-in photos and logos, so rows show pictures as well as initials.
func _fake_pictures() -> void:
	var palette := [Color("ff9a8b"), Color("7ad3ff"), Color("ffd36b"), Color("9be38f"), Color("c9a2ff"), Color("ffa3d1")]
	for i in 6:
		_cache_picture("fake/avatar/%d.png" % i, palette[i], palette[(i + 2) % palette.size()], false)
	for i in range(3, 11):
		_cache_picture("fake/logo/%d.png" % i, palette[i % palette.size()], AppTheme.INK, true)


func _cache_picture(url: String, a: Color, b: Color, emblem: bool) -> void:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var c := a.lerp(b, y / 96.0)
			var d := Vector2(x - 48, y - (40 if not emblem else 48)).length()
			if not emblem:
				if d < 18 or (y > 64 and absf(x - 48) < 30 - (y - 64) * 0.1):
					c = Color("fff1e0")  # A little head-and-shoulders silhouette.
			elif d < 30 and absi(x - 48) + absi(y - 48) < 34:
				c = Color.WHITE.lerp(a, 0.25)
			image.set_pixel(x, y, c)
	RemoteImage._cache[RemoteImage.absolute(url)] = ImageTexture.create_from_image(image)


func _iso_in_days(days: int) -> String:
	return Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + days * 86400 + 3 * 3600) + "Z"
