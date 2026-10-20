extends SmokeTestBase
## Films the cartoon battle clip through the real UI: grabs frames at fixed times for a few
## matchups (needs a real renderer):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/ClipFrames.tscn -- --out=<dir>

const SCENARIOS := [
	{"name": "spy_vs_g5", "outcome": "attacker", "reveal": true,
		"attacker": {"side": "white", "rank": "SPY"}, "defender": {"side": "black", "rank": "G5"}},
	{"name": "g5_vs_sgt", "outcome": "attacker", "reveal": true,
		"attacker": {"side": "black", "rank": "G5"}, "defender": {"side": "white", "rank": "SGT"}},
	{"name": "live_unknown_vs_pvt", "outcome": "attacker", "reveal": false,
		"attacker": {"side": "black", "rank": ""}, "defender": {"side": "white", "rank": "PVT"}},
	{"name": "maj_vs_col_blocked", "outcome": "defender", "reveal": true,
		"attacker": {"side": "white", "rank": "MAJ"}, "defender": {"side": "black", "rank": "COL"}},
	{"name": "live_tie_cpt", "outcome": "both", "reveal": false,
		"attacker": {"side": "white", "rank": "CPT"}, "defender": {"side": "black", "rank": ""}},
]
const TIMES := [0.6, 1.25, 1.7, 2.1, 2.6, 3.3]


func _ready() -> void:
	var out := "user://clips"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	for s: Dictionary in SCENARIOS:
		var data := s.duplicate()
		data["viewer"] = "white"
		var start := Time.get_ticks_msec()
		ui.play_clash(data)
		for t: float in TIMES:
			while (Time.get_ticks_msec() - start) / 1000.0 < t:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%.1f.png" % [out, s["name"], t])
		await get_tree().create_timer(1.5).timeout
		print("filmed ", s["name"])
	get_tree().quit()
