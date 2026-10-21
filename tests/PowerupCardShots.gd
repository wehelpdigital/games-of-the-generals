extends Node
## Renders the powerup cards for review: every card in the library, then sizes and states (face
## down, selected, used, compact). Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1600x900 res://tests/PowerupCardShots.tscn -- --out=<dir>

var _out := "user://powerup_cards"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = AppTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("f1d6b8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var ids := PowerupLibrary.ids()
	var page := 0
	while page * 14 < ids.size():
		var grid := GridContainer.new()
		grid.columns = 7
		grid.position = Vector2(24, 24)
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 18)
		root.add_child(grid)
		for id in ids.slice(page * 14, page * 14 + 14):
			grid.add_child(PowerupCard.new(id, 200))
		await _shot("library_%d" % page)
		grid.queue_free()
		page += 1

	var row := HBoxContainer.new()
	row.position = Vector2(24, 20)
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	var big := PowerupCard.new("counterspell", 240)
	row.add_child(big)
	var picked := PowerupCard.new("flag_hunter", 180)
	row.add_child(picked)
	picked.selected = true
	var spent := PowerupCard.new("spy_card", 180)
	row.add_child(spent)
	spent.used = true
	row.add_child(PowerupCard.new("haste", 180, true))
	var smalls := VBoxContainer.new()
	smalls.add_theme_constant_override("separation", 12)
	row.add_child(smalls)
	for id in ["time_steal", "radar_sweep", "trench"]:
		smalls.add_child(PowerupCard.new(id, 80))
	var tiny := HBoxContainer.new()
	tiny.add_theme_constant_override("separation", 8)
	tiny.position = Vector2(24, 420)
	root.add_child(tiny)
	for id in ["blitz", "interrogation", "roadblock", "quicksand", "promotion", "recall", "ceasefire"]:
		tiny.add_child(PowerupCard.new(id, 64 + 8 * (tiny.get_child_count() % 3)))
	await get_tree().create_timer(0.6).timeout
	await _shot("states")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name + ".png"))
	print("shot ", file_name)
