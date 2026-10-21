extends Node
## Renders every arena from the in-game camera, the menu's wide orbit and a low hero angle.
## Needs a real renderer (not --headless):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/ArenaShots.tscn -- --out=<dir> [--only=<slug>,<slug>...]

var out_dir := ""
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("arenas")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var game: Node3D = load("res://scenes/game/Game3D.tscn").instantiate()
	add_child(game)
	await _wait(1.0)
	var arena: Arena3D = game.get_node("Arena3D")
	var rig: CameraRig = game.get_node("CameraRig")
	var cam: Camera3D = rig.camera
	# Older boards drew their own floor; hide it so the arena ground shows.
	var board: Node = game.get_node("Board3D")
	var old_floor: Variant = board.get("_floor")
	if old_floor is MeshInstance3D:
		old_floor.visible = false

	for slug: String in ArenaLibrary.ARENAS:
		if only != "" and not (slug in only.split(",")):
			continue
		arena.set_arena(slug)
		rig.set_process(true)
		rig.attract = false
		rig.set_side(Ranks.WHITE)
		rig.reset_view()
		await _wait(1.2)
		await _shot("%s_game" % slug)
		rig.attract = true
		await _wait(1.4)
		await _shot("%s_wide" % slug)
		rig.set_process(false)
		cam.position = Vector3(0.0, 5.5, 17.0)
		cam.look_at(Vector3(0.0, 0.5, -6.0))
		await _wait(0.3)
		await _shot("%s_hero" % slug)
		print("shot ", slug)
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
