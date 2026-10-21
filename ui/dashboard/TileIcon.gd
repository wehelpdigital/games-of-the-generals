class_name TileIcon
extends Control
## Small vector icons for dashboard tiles and buttons (no emoji: web builds have no emoji font).
## White shapes with a plum outline, drawn in a unit box scaled to the control.
##
## Names: cart, bolt, trophy, shield, person, ranks, share, logout, swords, users, robot, globe,
## pin, camera, lock, check, crown, star.

var icon := ""
var fill := Color.WHITE
var ink := AppTheme.INK


func _init(icon_name := "", icon_size := Vector2(40, 40)) -> void:
	icon = icon_name
	custom_minimum_size = icon_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_icon(icon_name: String) -> void:
	icon = icon_name
	queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) / 2.0
	var line := maxf(1.5, side * 0.07)
	match icon:
		"cart":
			_shape([Vector2(0.14, 0.24), Vector2(0.9, 0.24), Vector2(0.8, 0.62), Vector2(0.26, 0.62)], origin, side, line)
			_stroke([Vector2(0.02, 0.12), Vector2(0.14, 0.12), Vector2(0.26, 0.62)], origin, side, line)
			_dot(Vector2(0.32, 0.8), 0.09, origin, side, line)
			_dot(Vector2(0.74, 0.8), 0.09, origin, side, line)
		"bolt":
			_shape([Vector2(0.58, 0.04), Vector2(0.18, 0.56), Vector2(0.46, 0.56), Vector2(0.36, 0.96),
				Vector2(0.84, 0.4), Vector2(0.56, 0.4), Vector2(0.7, 0.04)], origin, side, line)
		"trophy":
			_arc(Vector2(0.22, 0.32), 0.14, origin, side, line)
			_arc(Vector2(0.78, 0.32), 0.14, origin, side, line)
			_shape([Vector2(0.24, 0.1), Vector2(0.76, 0.1), Vector2(0.72, 0.42), Vector2(0.58, 0.56), Vector2(0.56, 0.7),
				Vector2(0.7, 0.78), Vector2(0.7, 0.92), Vector2(0.3, 0.92), Vector2(0.3, 0.78), Vector2(0.44, 0.7),
				Vector2(0.42, 0.56), Vector2(0.28, 0.42)], origin, side, line)
		"shield":
			_shape([Vector2(0.5, 0.04), Vector2(0.88, 0.17), Vector2(0.84, 0.56), Vector2(0.5, 0.96),
				Vector2(0.16, 0.56), Vector2(0.12, 0.17)], origin, side, line)
			_shape(_star(Vector2(0.5, 0.46), 0.2, 0.09, 5), origin, side, line * 0.6, AppTheme.GOLD)
		"person":
			_shape(_ellipse(Vector2(0.5, 0.92), Vector2(0.34, 0.34), PI, TAU), origin, side, line)
			_dot(Vector2(0.5, 0.32), 0.19, origin, side, line)
		"ranks":
			for i in 3:
				var y := 0.22 + i * 0.24
				_shape([Vector2(0.14, y), Vector2(0.5, y + 0.2), Vector2(0.86, y), Vector2(0.86, y + 0.12),
					Vector2(0.5, y + 0.32), Vector2(0.14, y + 0.12)], origin, side, line)
		"share":
			_stroke([Vector2(0.72, 0.2), Vector2(0.28, 0.5), Vector2(0.72, 0.8)], origin, side, line * 1.4)
			_dot(Vector2(0.72, 0.2), 0.15, origin, side, line)
			_dot(Vector2(0.28, 0.5), 0.15, origin, side, line)
			_dot(Vector2(0.72, 0.8), 0.15, origin, side, line)
		"logout":
			_shape([Vector2(0.12, 0.1), Vector2(0.56, 0.1), Vector2(0.56, 0.9), Vector2(0.12, 0.9)], origin, side, line)
			_shape([Vector2(0.42, 0.42), Vector2(0.7, 0.42), Vector2(0.7, 0.28), Vector2(0.94, 0.5), Vector2(0.7, 0.72),
				Vector2(0.7, 0.58), Vector2(0.42, 0.58)], origin, side, line, AppTheme.YELLOW)
		"swords":
			for flip: float in [1.0, -1.0]:
				var a := Vector2(0.5 - 0.36 * flip, 0.1)
				var b := Vector2(0.5 + 0.3 * flip, 0.82)
				_blade(a, b, origin, side, line)
		"users":
			_shape(_ellipse(Vector2(0.66, 0.9), Vector2(0.28, 0.28), PI, TAU), origin, side, line, AppTheme.SILVER)
			_dot(Vector2(0.66, 0.38), 0.15, origin, side, line, AppTheme.SILVER)
			_shape(_ellipse(Vector2(0.36, 0.94), Vector2(0.3, 0.3), PI, TAU), origin, side, line)
			_dot(Vector2(0.36, 0.42), 0.16, origin, side, line)
		"robot":
			_stroke([Vector2(0.5, 0.2), Vector2(0.5, 0.08)], origin, side, line)
			_dot(Vector2(0.5, 0.07), 0.06, origin, side, line * 0.8, AppTheme.RED)
			_shape([Vector2(0.16, 0.22), Vector2(0.84, 0.22), Vector2(0.84, 0.74), Vector2(0.16, 0.74)], origin, side, line)
			_dot(Vector2(0.36, 0.46), 0.08, origin, side, line * 0.6, AppTheme.BLUE)
			_dot(Vector2(0.64, 0.46), 0.08, origin, side, line * 0.6, AppTheme.BLUE)
			_shape([Vector2(0.3, 0.8), Vector2(0.7, 0.8), Vector2(0.7, 0.94), Vector2(0.3, 0.94)], origin, side, line)
		"globe":
			_dot(Vector2(0.5, 0.5), 0.42, origin, side, line, Color("7fd3ff"))
			_stroke(_ellipse(Vector2(0.5, 0.5), Vector2(0.18, 0.42), 0.0, TAU), origin, side, line * 0.8)
			_stroke([Vector2(0.08, 0.5), Vector2(0.92, 0.5)], origin, side, line * 0.8)
		"pin":
			_shape([Vector2(0.5, 0.96)] + _ellipse(Vector2(0.5, 0.38), Vector2(0.32, 0.32), PI * 0.8, PI * 2.2),
				origin, side, line, AppTheme.RED)
			_dot(Vector2(0.5, 0.38), 0.12, origin, side, line * 0.6)
		"camera":
			_shape([Vector2(0.08, 0.3), Vector2(0.3, 0.3), Vector2(0.38, 0.16), Vector2(0.62, 0.16), Vector2(0.7, 0.3),
				Vector2(0.92, 0.3), Vector2(0.92, 0.84), Vector2(0.08, 0.84)], origin, side, line)
			_dot(Vector2(0.5, 0.56), 0.18, origin, side, line, AppTheme.BLUE)
		"lock":
			_arc(Vector2(0.5, 0.42), 0.2, origin, side, line * 1.6, PI, TAU)
			_shape([Vector2(0.18, 0.42), Vector2(0.82, 0.42), Vector2(0.82, 0.92), Vector2(0.18, 0.92)], origin, side, line, AppTheme.GOLD)
		"check":
			_shape([Vector2(0.08, 0.52), Vector2(0.24, 0.36), Vector2(0.4, 0.54), Vector2(0.78, 0.14), Vector2(0.94, 0.3),
				Vector2(0.4, 0.86)], origin, side, line)
		"crown":
			_shape([Vector2(0.08, 0.3), Vector2(0.3, 0.52), Vector2(0.5, 0.18), Vector2(0.7, 0.52), Vector2(0.92, 0.3),
				Vector2(0.84, 0.82), Vector2(0.16, 0.82)], origin, side, line, AppTheme.GOLD)
		"star":
			_shape(_star(Vector2(0.5, 0.54), 0.46, 0.2, 5), origin, side, line, AppTheme.GOLD)


func _map(points: Array, origin: Vector2, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(origin + p * side)
	return out


func _shape(points: Array, origin: Vector2, side: float, line: float, color := Color(0, 0, 0, 0)) -> void:
	var poly := _map(points, origin, side)
	draw_colored_polygon(poly, fill if color.a == 0.0 else color)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, ink, line, true)


func _stroke(points: Array, origin: Vector2, side: float, line: float) -> void:
	draw_polyline(_map(points, origin, side), ink, line, true)


func _dot(center: Vector2, radius: float, origin: Vector2, side: float, line: float, color := Color(0, 0, 0, 0)) -> void:
	_shape(_ellipse(center, Vector2(radius, radius), 0.0, TAU), origin, side, line, color)


func _arc(center: Vector2, radius: float, origin: Vector2, side: float, line: float, from := 0.0, to := TAU) -> void:
	draw_arc(origin + center * side, radius * side, from, to, 24, ink, line, true)


func _blade(a: Vector2, b: Vector2, origin: Vector2, side: float, line: float) -> void:
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var w := 0.06
	_shape([a, a + dir * 0.6 + normal * w, a + dir * 0.6 - normal * w], origin, side, line)
	var guard := a + dir * 0.62
	_stroke([guard + normal * 0.14, guard - normal * 0.14], origin, side, line * 1.6)
	_stroke([guard, b], origin, side, line * 1.6)


static func _ellipse(center: Vector2, radius: Vector2, from: float, to: float, steps := 20) -> Array:
	var out := []
	var full := absf(to - from - TAU) < 0.001  # A closed circle must not repeat its first point.
	for i in (steps if full else steps + 1):
		var a := lerpf(from, to, i / float(steps))
		out.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return out


static func _star(center: Vector2, outer: float, inner: float, points: int) -> Array:
	var out := []
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		out.append(center + Vector2.from_angle(-PI / 2.0 + PI * i / points) * r)
	return out
