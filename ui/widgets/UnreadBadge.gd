class_name UnreadBadge
extends Control
## A red notification bubble with a count ("9+" past nine), pinned over the top-right corner of
## its parent (a chat button). Hidden at zero; pops each time the count goes up.
##
##     var badge := UnreadBadge.new()
##     chat_button.add_child(badge)
##     badge.set_count(3)

const SIZE := Vector2(30, 26)

var count := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE.x * 0.7
	offset_right = SIZE.x * 0.3
	offset_top = -SIZE.y * 0.35
	offset_bottom = SIZE.y * 0.65
	pivot_offset = SIZE / 2.0


func set_count(value: int) -> void:
	var grew := value > count
	count = maxi(value, 0)
	visible = count > 0
	queue_redraw()
	if grew and visible and is_inside_tree():
		scale = Vector2(1.6, 1.6)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func text() -> String:
	return "9+" if count > 9 else str(count)


func _draw() -> void:
	var font := AppTheme.heading_font()
	var font_size := 15
	var label := text()
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := maxf(SIZE.y, text_width + 14.0)
	var rect := Rect2(Vector2((SIZE.x - width) / 2.0, 0), Vector2(width, SIZE.y))
	var pill := StyleBoxFlat.new()
	pill.bg_color = AppTheme.RED
	pill.set_corner_radius_all(int(SIZE.y / 2.0))
	pill.set_border_width_all(3)
	pill.border_color = Color.WHITE
	pill.anti_aliasing = true
	draw_style_box(pill, rect)
	var baseline := (SIZE.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(font, Vector2(rect.position.x + (width - text_width) / 2.0, baseline), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
