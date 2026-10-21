extends SmokeTestBase
## Default cartoon avatars where players see them: a photo-less player's dashboard header and
## profile. Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/AvatarShots.tscn -- --out=<dir>
## Phone: --resolution 390x844 and add --device=phone_portrait after `--`.

var _out := "user://avatar_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	ApiManager.base_url = "http://127.0.0.1:9"  # Nothing real answers: requests fail fast.
	ApiManager.token = "fake-token"
	ApiManager.user = {"id": 42, "username": "LakanDiwa", "credits": 1200}
	Profile.mock = func(_method: int, _path: String, _body: Variant) -> Dictionary:
		return {"ok": false, "status": 0, "data": {}, "error": "offline"}
	Profile._set_data({"id": 42, "username": "LakanDiwa", "avatar_url": null, "rank_tier": 2,
		"rank_name": "Second Lieutenant", "xp": 320, "credits": 1200, "guild": null,
		"stats": {"wins": 12, "losses": 7, "games_played": 19, "ranked_wins": 3}}, true)
	var prefix := "phone_" if get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x else ""
	for screen: String in ["dashboard", "profile"]:
		ui.show_screen(screen)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("%savatar_%s.png" % [prefix, screen]))
		print("shot ", screen)
	check(AvatarView.default_for(Profile.data) != null, "the player has a cartoon avatar")
	finish()
