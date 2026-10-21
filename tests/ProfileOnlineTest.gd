extends SmokeTestBase
## Account features against a running backend: profile, hometown, photo upload, sharing,
## hometown leaderboards, guild rules, shop purchases (test mode), the cosmetic loadout with chip
## shape and a picture flag, and the powerup loadout.
##   godot --headless --path . res://tests/ProfileOnlineTest.tscn -- --api-url=http://127.0.0.1:8077


func _ready() -> void:
	print("API: ", ApiManager.base_url)
	await boot()
	var stamp := str(Time.get_ticks_usec()).right(6)
	var reg := await ApiManager.register("pa" + stamp, "pa%s@example.test" % stamp, "password123", "password123")
	check(reg.ok, "player registered")

	await Profile.refresh()
	check(Profile.data.get("rank_name", "") == "Private" and Profile.tier() == 0, "new players start as Private")
	check(Profile.next_rank().get("name", "") != "", "the next rank and its tasks are known")

	# Hometown: Region I -> Pangasinan -> Alcala.
	var region := _named(await Profile.locations("region"), "Ilocos")
	check(not region.is_empty(), "regions load (Ilocos found)")
	var province := _named(await Profile.locations("province", str(region.get("code", ""))), "Pangasinan")
	check(not province.is_empty(), "provinces load (Pangasinan found)")
	var city := _named(await Profile.locations("city", str(province.get("code", ""))), "Alcala")
	check(not city.is_empty(), "towns load (Alcala found)")
	var moved := await Profile.set_location({"country": "PH", "region": region.get("code"),
		"province": province.get("code"), "city": city.get("code")})
	check(moved.ok and str(Profile.place("city").get("name", "")) == "Alcala", "hometown set to Alcala, Pangasinan")

	# Photo.
	var photo := Image.create(96, 96, false, Image.FORMAT_RGB8)
	photo.fill(Color("ff4f8b"))
	var uploaded := await Profile.upload_avatar(photo)
	check(uploaded.ok and Profile.avatar_url() != "", "profile photo uploaded")
	var texture := await _fetch_texture(Profile.avatar_url())
	check(texture != null and texture.get_width() > 0, "the photo downloads back as a texture")

	# Sharing task.
	var shared := await Profile.record_share("copy_link")
	check(shared.ok, "share recorded")

	# Hometown leaderboards.
	var board := await Profile.location_leaderboard("city", str(city.get("code", "")))
	check(board.get("ok", false), "Alcala leaderboard loads")
	var me := await Profile.my_positions()
	check(me.get("city") is Dictionary, "my position per level loads")

	# Guilds: founding needs a higher rank.
	var founded := await Profile.create_guild("Tikbalang Squad " + stamp, "T" + stamp.right(3))
	check(not founded.get("ok", true) and str(founded.get("error", "")) != "", "a Private can't found a guild (explained)")
	var listed := await Profile.guilds()
	check(listed.get("ok", false), "guild list loads")

	# Shop (test mode: free).
	await Loadout.refresh_shop()
	var bought := await Loadout.buy("arena", "lava_pit")
	check(bought.get("ok", false), "buying an arena works in test mode")
	check(Loadout.owns("taunt", "cream_pie"), "starter taunt owned")

	# Cosmetic loadout with a chip shape and a picture flag.
	var flag_pic := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	flag_pic.fill(Color("3d8bff"))
	var media := await ApiManager.request(HTTPClient.METHOD_POST, "/api/media",
		FilePicker.to_upload(flag_pic, true).merged({"purpose": "flag"}))
	check(media.ok and media.data.get("id") != null, "flag picture uploaded")
	var payload: Dictionary = Loadout.items.duplicate(true)
	payload["shape"] = "shape_wish_orb"
	payload["toppers"] = {"slots": [
		{"kind": "flag", "slug": "topper_flag_gold", "flag": {"shape": "swallowtail", "color": "#e8344e",
			"color2": "#ffd23f", "pattern": "stripes_h", "emblem": "star", "image_media_id": media.data.get("id"),
			"use_guild_logo": false}},
		{"kind": "object", "slug": "topper_cactus"},
	]}
	var saved := await ApiManager.save_loadout(payload)
	check(saved.ok, "loadout with chip shape and picture flag accepted")
	var user := await ApiManager.fetch_user()
	var stored: Dictionary = user.get("data", {}).get("user", user.get("data", {})).get("loadout", {})
	check(str(stored.get("shape", "")) == "shape_wish_orb" and stored.get("toppers") is Dictionary, "the server kept the shape and toppers")

	# Powerups.
	var picked := await GameSession.powerups.save(["time_extension", "spy_card", "insight", "intel_leak", "time_squeeze"])
	check(picked == "", "powerup loadout saved")

	await ApiManager.logout()
	finish()


func _named(rows: Array, needle: String) -> Dictionary:
	for row: Variant in rows:
		if row is Dictionary and str(row.get("name", "")).contains(needle):
			return row
	return {}


func _fetch_texture(url: String) -> Texture2D:
	var result: Array = [null, false]
	RemoteImage.fetch(url, func(texture: Texture2D) -> void:
		result[0] = texture
		result[1] = true)
	while not result[1]:
		await get_tree().process_frame
	return result[0]
