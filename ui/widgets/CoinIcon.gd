class_name CoinIcon
extends Control
## A chunky gold credit coin (drawn, no texture): ink rim, inner ring and a star.

func _init(diameter := 28.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var d := minf(size.x, size.y)
	var c := size / 2.0
	var r := d / 2.0
	draw_circle(c + Vector2(0, r * 0.08), r, AppTheme.INK, true, -1.0, true)
	draw_circle(c, r, AppTheme.INK, true, -1.0, true)
	draw_circle(c, r * 0.86, AppTheme.GOLD, true, -1.0, true)
	draw_circle(c, r * 0.64, Color("ffd25e"), true, -1.0, true)
	draw_arc(c, r * 0.64, 0.0, TAU, 32, Color(AppTheme.INK, 0.35), maxf(1.0, d * 0.05), true)
	var star := PackedVector2Array()
	for i in 10:
		var radius := r * (0.42 if i % 2 == 0 else 0.19)
		star.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * radius)
	draw_colored_polygon(star, Color("fff3c4"))
	draw_polyline(star + PackedVector2Array([star[0]]), Color(AppTheme.INK, 0.5), maxf(1.0, d * 0.035), true)
