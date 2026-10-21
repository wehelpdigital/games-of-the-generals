class_name DashboardAmbient
extends Control
## Light, CPU-cheap 2D decoration drifting over the dashboard: confetti, fireflies, petals, a neon
## grid, leaves, snow, bats, twinkling lights or summer sun rays. A few dozen shapes drawn per
## frame, only while visible.

const COUNTS := {"confetti": 22, "fireflies": 26, "petals": 26, "neon": 14, "leaves": 18, "snow": 44,
	"bats": 6, "lights": 30, "sun": 14}

var style := "confetti"
var accent := AppTheme.PINK
var accent2 := AppTheme.BLUE

var _bits: Array[Dictionary] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7


func set_style(deco: String, color_a: Color, color_b: Color) -> void:
	style = deco
	accent = color_a
	accent2 = color_b
	_bits.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or size.x < 2.0:
		return
	_time += delta
	if _bits.is_empty():
		_seed_bits()
	for bit in _bits:
		_step(bit, delta)
	queue_redraw()


func _seed_bits() -> void:
	for i in COUNTS.get(style, 20):
		var bit := {}
		_respawn(bit, true)
		_bits.append(bit)


func _respawn(bit: Dictionary, anywhere: bool) -> void:
	var w := size.x
	var h := size.y
	bit["phase"] = _rng.randf() * TAU
	bit["rot"] = _rng.randf() * TAU
	bit["spin"] = _rng.randf_range(-1.6, 1.6)
	match style:
		"fireflies":
			bit["pos"] = Vector2(_rng.randf() * w, _rng.randf_range(0.2, 1.0) * h)
			bit["vel"] = Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-18, -6))
			bit["size"] = _rng.randf_range(2.0, 4.5)
			bit["color"] = accent2
		"neon":
			bit["pos"] = Vector2(_rng.randf() * w, (_rng.randf() if anywhere else 1.05) * h)
			bit["vel"] = Vector2(0, _rng.randf_range(-26, -12))
			bit["size"] = _rng.randf_range(6, 16)
			bit["color"] = accent if _rng.randf() < 0.5 else accent2
		"bats":
			bit["pos"] = Vector2((_rng.randf() if anywhere else -0.1) * w, _rng.randf_range(0.06, 0.55) * h)
			bit["vel"] = Vector2(_rng.randf_range(40, 90), 0)
			bit["size"] = _rng.randf_range(12, 24)
			bit["color"] = Color("1a0f2e")
		"sun":
			bit["pos"] = Vector2(_rng.randf() * w, (_rng.randf() if anywhere else 1.05) * h)
			bit["vel"] = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-40, -16))
			bit["size"] = _rng.randf_range(4, 11)
			bit["color"] = Color(1, 1, 1, 0.55)
		_:
			# Falling things: confetti, petals, leaves, snow (and snow under the Christmas lights).
			bit["pos"] = Vector2(_rng.randf() * w, (_rng.randf() if anywhere else -0.05) * h)
			var fall := {"confetti": 34.0, "petals": 30.0, "leaves": 38.0}.get(style, 24.0) as float
			bit["vel"] = Vector2(_rng.randf_range(-10, 14), fall * _rng.randf_range(0.7, 1.35))
			match style:
				"confetti":
					bit["size"] = _rng.randf_range(5, 9)
					bit["color"] = [AppTheme.PINK, AppTheme.BLUE, AppTheme.YELLOW, AppTheme.MINT, AppTheme.PURPLE][_rng.randi() % 5]
				"petals":
					bit["size"] = _rng.randf_range(6, 11)
					bit["color"] = [Color("ffb3cf"), Color("ff8fbc"), Color("ffd3e4")][_rng.randi() % 3]
				"leaves":
					bit["size"] = _rng.randf_range(9, 15)
					bit["color"] = [Color("3fbf5f"), Color("8fd14f"), Color("2e9e57"), Color("d9b43a")][_rng.randi() % 4]
				_:
					bit["size"] = _rng.randf_range(1.6, 4.2)
					bit["color"] = Color(1, 1, 1, _rng.randf_range(0.6, 0.95))


func _step(bit: Dictionary, delta: float) -> void:
	var pos: Vector2 = bit["pos"]
	var vel: Vector2 = bit["vel"]
	var sway := sin(_time * 1.3 + float(bit["phase"])) * (22.0 if style in ["petals", "leaves"] else 8.0)
	pos += (vel + Vector2(sway if style != "bats" else 0.0, 0.0)) * delta
	bit["rot"] = float(bit["rot"]) + float(bit["spin"]) * delta
	bit["pos"] = pos
	var out := pos.y > size.y + 30.0 or pos.y < -40.0 or pos.x > size.x + 40.0 or pos.x < -60.0
	if out:
		_respawn(bit, false)


func _draw() -> void:
	match style:
		"neon":
			_draw_neon_grid()
		"lights":
			_draw_light_string()
		"sun":
			_draw_sun_rays()
	for bit in _bits:
		var pos: Vector2 = bit["pos"]
		var s: float = bit["size"]
		var color: Color = bit["color"]
		var rot: float = bit["rot"]
		match style:
			"confetti":
				_quad(pos, Vector2(s, s * 0.55), rot, color)
			"petals":
				_leaf(pos, s, rot, color, false)
			"leaves":
				_leaf(pos, s, rot, color, true)
			"fireflies":
				var glow := 0.5 + 0.5 * sin(_time * 2.4 + float(bit["phase"]))
				draw_circle(pos, s * 3.2, Color(color, 0.12 * glow))
				draw_circle(pos, s, Color(color, 0.35 + 0.6 * glow))
			"neon":
				var rect := Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s))
				draw_rect(rect.grow(3), Color(color, 0.18), false, 3.0)
				draw_rect(rect, Color(color, 0.8), false, 1.5)
			"bats":
				_bat(pos, s, color, sin(_time * 14.0 + float(bit["phase"])))
			"sun":
				draw_arc(pos, s, 0.0, TAU, 16, color, 1.5, true)
				draw_circle(pos + Vector2(-s, -s) * 0.3, s * 0.2, Color(1, 1, 1, 0.7))
			_:
				draw_circle(pos, s, color)


func _quad(pos: Vector2, half: Vector2, rot: float, color: Color) -> void:
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(pos + (corner * half).rotated(rot))
	draw_colored_polygon(points, color)


func _leaf(pos: Vector2, s: float, rot: float, color: Color, vein: bool) -> void:
	var points := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		# A pointed ellipse: narrower towards both tips.
		var r := Vector2(cos(a) * s, sin(a) * s * (0.42 if vein else 0.6) * (1.0 - 0.3 * absf(cos(a))))
		points.append(pos + r.rotated(rot))
	draw_colored_polygon(points, color)
	if vein:
		draw_line(pos + Vector2(-s, 0).rotated(rot), pos + Vector2(s, 0).rotated(rot), color.darkened(0.3), 1.2, true)


func _bat(pos: Vector2, s: float, color: Color, flap: float) -> void:
	var wing := s * (0.35 + 0.35 * flap)
	var points := PackedVector2Array([
		pos + Vector2(-s, -wing), pos + Vector2(-s * 0.55, -wing * 0.2 + s * 0.12), pos + Vector2(-s * 0.3, s * 0.05),
		pos + Vector2(0, -s * 0.18), pos + Vector2(s * 0.3, s * 0.05), pos + Vector2(s * 0.55, -wing * 0.2 + s * 0.12),
		pos + Vector2(s, -wing), pos + Vector2(s * 0.45, s * 0.34), pos + Vector2(0, s * 0.22), pos + Vector2(-s * 0.45, s * 0.34),
	])
	draw_colored_polygon(points, color)
	draw_circle(pos + Vector2(-s * 0.08, -s * 0.02), s * 0.05, Color("ffcf3f"))
	draw_circle(pos + Vector2(s * 0.08, -s * 0.02), s * 0.05, Color("ffcf3f"))


## Retro perspective grid glowing along the bottom of the screen, scrolling toward the viewer.
func _draw_neon_grid() -> void:
	var horizon := size.y * 0.66
	var bottom := size.y
	var center := size.x / 2.0
	for i in range(-12, 13):
		var x_far := center + i * size.x * 0.03
		var x_near := center + i * size.x * 0.16
		draw_line(Vector2(x_far, horizon), Vector2(x_near, bottom), Color(accent2, 0.22), 2.0, true)
	var scroll := fmod(_time * 0.35, 1.0)
	for j in 9:
		var t := (j + scroll) / 9.0
		var y := horizon + (bottom - horizon) * t * t
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(accent, 0.12 + 0.3 * t), 2.0, true)
	draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color(accent, 0.55), 3.0, true)


## A swag of twinkling bulbs across the top, over falling snow.
func _draw_light_string() -> void:
	var colors := [Color("ff4f5a"), Color("ffcf3f"), Color("3ddc84"), Color("3d8bff"), Color("ff8fd8")]
	var count := int(size.x / 46.0)
	var previous := Vector2.ZERO
	for i in count + 1:
		var x := i * size.x / count
		var y := 14.0 + sin(i * 0.9) * 2.0 + 16.0 * absf(sin(i * PI / 6.0))
		var p := Vector2(x, y)
		if i > 0:
			draw_line(previous, p, Color("1d3b2a"), 2.0, true)
		previous = p
		var c: Color = colors[i % colors.size()]
		var twinkle := 0.55 + 0.45 * sin(_time * 3.0 + i * 1.7)
		draw_circle(p + Vector2(0, 9), 13.0, Color(c, 0.18 * twinkle))
		draw_circle(p + Vector2(0, 9), 5.5, Color(c, 0.5 + 0.5 * twinkle))


## Slowly turning sun rays from the top-right corner.
func _draw_sun_rays() -> void:
	var origin := Vector2(size.x * 0.92, -size.y * 0.04)
	var reach := size.length()
	for i in 10:
		var a := _time * 0.05 + i * TAU / 10.0
		var points := PackedVector2Array([origin, origin + Vector2.from_angle(a - 0.08) * reach,
			origin + Vector2.from_angle(a + 0.08) * reach])
		draw_colored_polygon(points, Color(1.0, 0.95, 0.6, 0.09))
	draw_circle(origin, 120.0, Color(1.0, 0.86, 0.35, 0.35))
	draw_circle(origin, 80.0, Color(1.0, 0.9, 0.45, 0.55))
