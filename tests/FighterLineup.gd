extends SceneTree
## Renders every cartoon battle-clip fighter in a few poses to one PNG (needs a real renderer):
##   godot --path . --rendering-driver opengl3 --resolution 1600x900 -s res://tests/FighterLineup.gd -- --out=<png>

const ORDER := ["G5", "G4", "G3", "G2", "G1", "COL", "LTC", "MAJ", "CPT", "1LT", "2LT", "SGT", "PVT", "SPY", "FLG", "UNKNOWN"]
const FACES := ["angry", "neutral", "happy", "smug", "shock", "angry", "neutral", "happy", "angry", "shock", "happy", "angry", "shock", "smug", "happy", "neutral"]


func _initialize() -> void:
	var out := "user://fighters.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var bg := ColorRect.new()
	bg.color = Color("cfe9ff")
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	for i in ORDER.size():
		var f := CartoonFighter.new()
		f.look = FighterLooks.for_rank(ORDER[i])
		f.face = FACES[i]
		f.position = Vector2(66 + (i % 8) * 142, 296 + (i / 8) * 316)
		f.scale = Vector2.ONE * 0.62
		if i % 4 == 1:
			f.arm_front = 100.0
			f.prop_out = true
		elif i % 4 == 2:
			f.arm_front = 160.0
			f.prop_out = true
			f.lean = 10.0
		elif i % 4 == 3:
			f.leg_front = 30.0
			f.leg_back = -24.0
			f.prop_out = true
			f.arm_front = 60.0
		root.add_child(f)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
