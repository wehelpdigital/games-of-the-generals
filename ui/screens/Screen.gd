class_name Screen
extends Control
## Base for full-screen UI states (title, lobby, HUD...). UIRoot calls open()/close() when it
## switches screens; the 3D game keeps running underneath.

var ui: UIRoot


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called every time the screen is shown. `args` come from UIRoot.show_screen().
func open(_args: Dictionary) -> void:
	pass


func close() -> void:
	pass
