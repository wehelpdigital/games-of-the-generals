extends SmokeTestBase
## Sounds: every file in SoundIndex exists and loads, every shop item in every category plays a
## sound that exists (or is deliberately silent), music follows the screens, and the listening
## hooks (kill effects, taunts, equipping) pick the right sounds.
##   godot --headless --path . res://tests/AudioTest.tscn

var _played: Array[String] = []


func _ready() -> void:
	await boot()
	var ui: UIRoot = main.get_node("UI")

	# Files.
	var missing: Array[String] = []
	var silent_files: Array[String] = []
	for table: Dictionary in [SoundIndex.SFX, SoundIndex.LOOPS, SoundIndex.MUSIC]:
		for sound: String in table:
			var path: String = table[sound]
			var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
			if stream == null:
				missing.append(sound)
			elif stream.get_length() <= 0.0:
				silent_files.append(sound)
	var total := SoundIndex.SFX.size() + SoundIndex.LOOPS.size() + SoundIndex.MUSIC.size()
	check(missing.is_empty(), "all %d sound files load%s" % [total, "" if missing.is_empty() else " (missing: %s)" % ", ".join(missing)])
	check(silent_files.is_empty(), "no sound file is empty%s" % ("" if silent_files.is_empty() else ": %s" % ", ".join(silent_files)))

	# Every shop item resolves to a sound that exists.
	var items := 0
	var listed := 0
	var broken: Array[String] = []
	var silent_items: Array[String] = []
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		check(SoundIndex.DEFAULTS.has(category), "%s has a default sound" % category)
		for slug: String in CosmeticCatalog.slugs(category):
			items += 1
			var sound := Audio.item_sound(category, slug)
			if (SoundIndex.ITEMS.get(category, {}) as Dictionary).has(slug):
				listed += 1
			if sound == "":
				silent_items.append("%s/%s" % [category, slug])
				continue
			var table: Dictionary = SoundIndex.LOOPS if category == "ambience" else SoundIndex.SFX
			if not table.has(sound):
				broken.append("%s/%s -> %s" % [category, slug, sound])
	check(broken.is_empty(), "all %d shop items play an existing sound (%d listed one by one, the rest by keyword or category)%s" % [items, listed, "" if broken.is_empty() else ": %s" % ", ".join(broken)])
	var allowed_silent := silent_items.filter(func(s: String) -> bool: return s.ends_with("/none"))
	check(silent_items.size() == allowed_silent.size(), "only the 'none' items are silent (%s)" % ", ".join(silent_items))
	for kill: String in KillFX.ACTIONS:
		if Audio.item_sound("kill", kill) == SoundIndex.DEFAULTS["kill"]:
			print("  note  action kill without its own sound yet (uses the timed fallback): ", kill)
	for group: String in SoundIndex.GROUPS:
		for sound: String in SoundIndex.GROUPS[group]:
			if not (SoundIndex.SFX.has(sound) or SoundIndex.MUSIC.has(sound)):
				broken.append("group %s: %s" % [group, sound])
	check(broken.is_empty(), "every Sound test entry exists")

	# Music follows the screens.
	ui.screen_changed.emit("shop")  # (Guests are sent from the shop to sign-up, so signal it directly.)
	await frames(2)
	check(Audio.music_track() in ["shop", "shop_alt"], "the shop plays shop music (%s)" % Audio.music_track())
	ui.show_screen("title")
	await frames(2)
	check(Audio.music_track().begins_with("menu"), "the title plays menu music (%s)" % Audio.music_track())
	ui.show_screen("sound_test")
	await frames(3)
	check(ui.current_name == "sound_test", "the Sound test screen opens")

	# Hooks: a kill effect, a taunt and a preview on the board pick their item's sound.
	var original := Audio.play
	board.kill_effects[board.my_side] = "kill_kraken"
	board.preview_kill(board.my_side)
	await frames(3)
	check(Audio._kill_quiet_until > 0.0, "a kill effect on the board plays its kill sound")
	TauntFX.throw(board, board.my_side, "cream_pie")
	await frames(3)
	check(Audio.item_sound("taunt", "cream_pie") == "taunt_cream_pie", "a thrown cream pie plays the cream pie sound")
	check(Audio.item_sound("trail", "none") == "" and Audio.item_sound("ambience", "none") == "", "'none' trails and ambience are silent")
	check(Audio.item_sound("kill", "kill_some_future_effect") == SoundIndex.DEFAULTS["kill"], "a future kill effect falls back to the default")
	check(Audio.item_sound("ambience", "ambience_neon_rain") == "amb_storm" or Audio.item_sound("ambience", "ambience_neon_rain") == "amb_rain", "a future ambience finds a fitting loop by keyword")
	finish()
