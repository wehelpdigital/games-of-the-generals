extends Node
## The guest title screen: no shop button, and the feature showcase dressing the 3D board slide by
## slide. Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/TitleShowcaseShots.tscn -- --out=<dir>

var _out := "user://title_showcase"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	if ApiManager.is_logged_in():
		await ApiManager.logout()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	var ui: UIRoot = main.get_node("UI")
	ui.home()
	for i in 4:
		await get_tree().create_timer(5.0 if i > 0 else 2.0).timeout
		await _shot("wide_slide_%d" % i)
	DisplayServer.window_set_size(Vector2i(390, 844))
	await get_tree().create_timer(2.5).timeout
	await _shot("phone")
	DisplayServer.window_set_size(Vector2i(900, 700))
	await get_tree().create_timer(1.5).timeout
	await _shot("narrow")
	ui.show_screen("shop")
	await get_tree().create_timer(1.0).timeout
	await _shot("shop_as_guest")
	print("current screen: ", ui.current_name)
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name + ".png"))
	print("shot ", file_name)
