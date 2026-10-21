extends Node
## Screenshots of every seasonal shop item worn on the player's half (or played, for kills, trails
## and taunts). Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/HolidayShots.tscn -- --out=<dir> [--season=slug] [--category=key]

var _out := "user://holiday_shots"
var _season := ""
var _category := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--season="):
			_season = arg.trim_prefix("--season=")
		elif arg.begins_with("--category="):
			_category = arg.trim_prefix("--category=")
	DirAccess.make_dir_recursive_absolute(_out)
	var game: Game3D = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rig.attract = false
	var plain := Loadout.complete({})
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		if _category != "" and category != _category:
			continue
		for slug: String in CosmeticCatalog.slugs(category):
			var season := str(CosmeticCatalog.info(category, slug).get("season", ""))
			if season == "" or (_season != "" and season != _season):
				continue
			var look := plain.duplicate(true)
			if category == "topper":
				look["toppers"] = {"slots": [{"kind": ToppersLibrary.kind_of(slug), "slug": slug}]}
			elif category != "taunt":
				look[category] = slug
			look = CosmeticCatalog.dress_with_pair(look, category, slug)
			game.set_showcase(look, plain)
			game.show_attract()
			game.rig.attract = false
			game.set_showcase(look, plain)
			game.rig.frame(Game3D.PREVIEW_SHOTS.get(category, "half"))
			await get_tree().create_timer(0.6).timeout
			var wait := 1.4
			match category:
				"kill", "trail":
					game.preview_effect(category)
					wait = 0.9 if category == "kill" else 0.35
				"taunt":
					game.throw_taunt(Ranks.BLACK, slug)
					wait = 1.25
			await get_tree().create_timer(wait).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out.path_join("%s__%s__%s.png" % [season, category, slug]))
			print("shot ", season, " ", category, " ", slug)
			if category == "kill":
				while game.board.is_animating():
					await get_tree().process_frame
	get_tree().quit()
