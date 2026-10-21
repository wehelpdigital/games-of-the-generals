class_name XpBar
extends Control
## Rounded progress bar (XP toward the next rank, task progress) with an optional caption drawn
## inside. Animates to new values.
##
##     var bar := XpBar.new(24)
##     bar.set_progress(1240 - 900, 1400 - 900, "1,240 / 1,400 XP")

var ratio := 0.0
var fill_color := AppTheme.PINK
var track_color := Color.WHITE
var caption := ""

var _tween: Tween


func _init(height := 22.0, color := AppTheme.PINK) -> void:
	custom_minimum_size = Vector2(80, height)
	fill_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_progress(value: float, max_value: float, text := "", animate := true) -> void:
	caption = text
	var target := clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 1.0
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_ratio, ratio, target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_ratio(target)
	queue_redraw()


func set_color(color: Color) -> void:
	fill_color = color
	queue_redraw()


func _set_ratio(value: float) -> void:
	ratio = value
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var radius := int(h / 2.0)
	var border := 2 if h < 18 else 3
	var track := ProfileUi.box(track_color, radius, border)
	track.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if ratio > 0.001:
		var inset := float(border) + 1.0
		var inner := Rect2(Vector2(inset, inset), Vector2(size.x - inset * 2.0, h - inset * 2.0))
		var width := maxf(inner.size.y, inner.size.x * ratio)
		var fill := ProfileUi.box(fill_color, int(inner.size.y / 2.0), 0)
		fill.draw(get_canvas_item(), Rect2(inner.position, Vector2(width, inner.size.y)))
		# Glossy highlight along the top of the fill.
		var shine := ProfileUi.box(Color(1, 1, 1, 0.35), int(inner.size.y / 4.0), 0)
		shine.draw(get_canvas_item(), Rect2(inner.position + Vector2(inner.size.y * 0.3, inner.size.y * 0.14),
			Vector2(maxf(0.0, width - inner.size.y * 0.6), inner.size.y * 0.26)))
	if caption != "":
		var font := AppTheme.heading_font()
		var font_size := int(clampf(h * 0.62, 11.0, 20.0))
		var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := (h + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		var pos := Vector2((size.x - text_size.x) / 2.0, baseline)
		draw_string_outline(font, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, AppTheme.INK)
		draw_string(font, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
