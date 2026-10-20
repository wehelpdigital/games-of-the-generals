class_name CartoonFighter
extends Node2D
## A paper-cutout cartoon soldier drawn entirely in code (no image assets): rounded parts with
## bold ink outlines, posed through a handful of joint angles that the battle clip tweens. The
## origin is between the feet; the character faces +x (flip with scale.x = -1). About 300 px tall.
##
## Looks come from FighterLooks.for_rank(). Faces: neutral, angry, happy, shock, ko, smug.

const INK := Color("1d1736")
const INK_W := 5.0
const HIP_Y := -112.0
const LEG_LEN := 92.0
const LEG_W := 28.0
const ARM_LEN := 78.0
const ARM_W := 24.0
const SHOULDER := Vector2(6, -90)   ## Torso-local (origin at the hip, up is -y).
const HEAD := Vector2(10, -148)
const HEAD_R := 46.0
const GOLD := Color("ffc93c")
const BOOT := Color("2b2233")

var look: Dictionary = {}:
	set(v):
		look = v
		queue_redraw()
var lean := 0.0:  ## Degrees; the upper body tips forward (+) or back (-) around the hip.
	set(v):
		lean = v
		queue_redraw()
var arm_front := 10.0:  ## Degrees from hanging straight down; 90 points forward, 180 straight up.
	set(v):
		arm_front = v
		queue_redraw()
var arm_back := -10.0:
	set(v):
		arm_back = v
		queue_redraw()
var leg_front := 6.0:
	set(v):
		leg_front = v
		queue_redraw()
var leg_back := -6.0:
	set(v):
		leg_back = v
		queue_redraw()
var hop := 0.0:
	set(v):
		hop = v
		queue_redraw()
var ko_spin := 0.0:
	set(v):
		ko_spin = v
		queue_redraw()
var cape_wave := 0.0:
	set(v):
		cape_wave = v
		queue_redraw()
var prop_out := false:
	set(v):
		prop_out = v
		queue_redraw()
var face := "neutral":
	set(v):
		face = v
		queue_redraw()

var _t := Transform2D()  # Torso transform for the frame being drawn.


func _draw() -> void:
	if look.is_empty():
		return
	var shadow_look: bool = look.get("shadow", false)
	if absf(rotation) < 0.3:  # Lying fighters would drag their ground shadow upright with them.
		_ellipse(Vector2(0, 2), 62, 12, Color(INK, 0.22), false)
	var hip := Vector2(0, HIP_Y - hop)
	_t = Transform2D(deg_to_rad(lean), hip)

	if look.get("cape", false):
		var cape := PackedVector2Array([Vector2(-24, -98), Vector2(20, -98), Vector2(-4, 12 + cape_wave),
			Vector2(-64 - cape_wave, 6 + cape_wave * 0.6)])
		_poly(_xf(_smooth(cape, 2)), Color("c8243c"))

	_limb(hip + Vector2(-8, 0), leg_back, LEG_LEN, LEG_W, Color(look["trousers"]).darkened(0.15), true)
	_arm(arm_back, true)
	_torso()
	_limb(hip + Vector2(8, 0), leg_front, LEG_LEN, LEG_W, look["trousers"], true)
	_head()
	_arm(arm_front, false)
	if shadow_look:
		var font := AppTheme.heading_font()
		var at := _t * (HEAD + Vector2(-26, -72))
		draw_string_outline(font, at, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, 14, INK)
		draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Color.WHITE)
	if face == "ko":
		_ko_stars()


# --- Body parts -------------------------------------------------------------------------------

func _torso() -> void:
	var b: float = look.get("belly", 0.0)
	var body := PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(38 + b * 20, -36), Vector2(34 + b * 10, -80),
		Vector2(24, -102), Vector2(-22, -102), Vector2(-32, -80), Vector2(-36 - b * 8, -36)])
	var uniform: Color = look["uniform"]
	_poly(_xf(_smooth(body, 2)), uniform)
	if look.get("shadow", false):
		return
	if look.get("coat", false):
		# Trench coat: dark lapels, a belt with a buckle, and a turned-up collar.
		_poly(_xf(PackedVector2Array([Vector2(-4, -100), Vector2(18, -100), Vector2(8, -62)])), uniform.darkened(0.35))
		_poly(_xf(PackedVector2Array([Vector2(-20, -40), Vector2(36 + b * 18, -40), Vector2(36 + b * 18, -30), Vector2(-20, -30)])), Color("5a4630"))
		_poly(_xf(PackedVector2Array([Vector2(-22, -104), Vector2(-6, -118), Vector2(26, -116), Vector2(28, -100)])), uniform.darkened(0.15))
	else:
		_poly(_xf(PackedVector2Array([Vector2(-34, -24), Vector2(38 + b * 18, -24), Vector2(38 + b * 18, -14), Vector2(-34, -14)])), uniform.darkened(0.35))
		_poly(_xf(_box(Vector2(6, -19), Vector2(8, 6))), GOLD)
		for i in 3:
			draw_circle(_t * Vector2(20 + b * 8, -38 - i * 18), 3.5, GOLD)
	var insignia: String = look.get("insignia", "")
	var marks: int = look.get("marks", 0)
	if look.get("hat") == "peaked":
		# Generals: gold epaulettes and a few medals.
		_poly(_xf(_smooth(_box(Vector2(4, -98), Vector2(22, 7)), 1)), GOLD)
		for i in mini(3, marks):
			var at := Vector2(-14 + i * 11, -70)
			_poly(_xf(_box(at + Vector2(0, -8), Vector2(4, 5))), [Color("e8475f"), Color("3d8bff"), Color("27c98f")][i])
			draw_circle(_t * (at + Vector2(0, 2)), 4.5, GOLD)
	elif insignia != "":
		for i in marks:
			_insignia_torso(insignia, Vector2(-10 + i * 14 - (marks - 1) * 2, -82), 6.5)


func _head() -> void:
	var c := _t * HEAD
	var skin: Color = look["skin_color"]
	_circle(c, HEAD_R, skin)
	if look.get("shadow", false):
		_hat()
		return
	_face(skin)
	_hat()


func _face(skin: Color) -> void:
	var eyes := [Vector2(6, -6), Vector2(28, -6)]
	match face:
		"ko":
			for e: Vector2 in eyes:
				_line([_hp(e + Vector2(-6, -6)), _hp(e + Vector2(6, 6))], 4)
				_line([_hp(e + Vector2(-6, 6)), _hp(e + Vector2(6, -6))], 4)
		"happy":
			for e: Vector2 in eyes:
				_line([_hp(e + Vector2(-7, 2)), _hp(e + Vector2(0, -5)), _hp(e + Vector2(7, 2))], 4)
		_:
			if look.get("shades", false):
				_poly(_hpts(_smooth(PackedVector2Array([Vector2(-6, -16), Vector2(42, -16), Vector2(40, 0), Vector2(26, 2), Vector2(18, -6),
					Vector2(10, 2), Vector2(-4, 0)]), 1)), Color("15131f"))
				_line([_hp(Vector2(2, -11)), _hp(Vector2(12, -11))], 3, Color(1, 1, 1, 0.8))
			else:
				var big := face == "shock"
				for e: Vector2 in eyes:
					_ellipse(_hp(e), 8.5 if not big else 10.5, 11.5 if not big else 13.5, Color.WHITE)
					draw_circle(_hp(e + Vector2(3, 1)), 3.0 if big else 4.6, INK)
	# Brows.
	if face == "angry" or face == "smug":
		_line([_hp(Vector2(-2, -26)), _hp(Vector2(14, -19))], 5)
		if face == "angry":
			_line([_hp(Vector2(36, -26)), _hp(Vector2(22, -19))], 5)
		else:
			_line([_hp(Vector2(22, -24)), _hp(Vector2(36, -28))], 5)
	elif face != "ko":
		_line([_hp(Vector2(0, -24)), _hp(Vector2(13, -26))], 4)
		_line([_hp(Vector2(22, -26)), _hp(Vector2(35, -24))], 4)
	# Nose.
	_circle(_hp(Vector2(44, 6)), 8.0, skin.darkened(0.08))
	# Mouth.
	match face:
		"happy":
			_poly(_hpts(PackedVector2Array([Vector2(12, 18), Vector2(40, 16), Vector2(34, 32), Vector2(18, 32)])), Color("8a2a45"))
		"angry":
			_poly(_hpts(PackedVector2Array([Vector2(14, 20), Vector2(38, 18), Vector2(38, 28), Vector2(14, 28)])), Color.WHITE)
			_line([_hp(Vector2(14, 24)), _hp(Vector2(38, 23))], 2)
		"shock":
			_ellipse(_hp(Vector2(26, 24)), 7, 9, Color("8a2a45"))
		"ko":
			_line([_hp(Vector2(12, 24)), _hp(Vector2(18, 20)), _hp(Vector2(24, 26)), _hp(Vector2(30, 20)), _hp(Vector2(36, 24))], 4)
			_ellipse(_hp(Vector2(30, 31)), 5, 7, Color("ff7a9a"))
		"smug":
			_line([_hp(Vector2(16, 24)), _hp(Vector2(28, 25)), _hp(Vector2(38, 18))], 4)
		_:
			_line([_hp(Vector2(16, 22)), _hp(Vector2(26, 26)), _hp(Vector2(36, 21))], 4)
	# Mustache.
	match look.get("mustache", ""):
		"bushy":
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(8, 10), Vector2(44, 8), Vector2(58, 18), Vector2(40, 22), Vector2(26, 16),
				Vector2(10, 22), Vector2(-4, 18)]), 2)), Color("e9e6f0"))
		"handlebar":
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(14, 12), Vector2(40, 10), Vector2(56, 4), Vector2(50, 16), Vector2(28, 18),
				Vector2(6, 16), Vector2(0, 6)]), 2)), Color("3a2a1f"))
		"thin":
			_line([_hp(Vector2(16, 13)), _hp(Vector2(40, 12))], 4, Color("3a2a1f"))


func _hat() -> void:
	var color: Color = look.get("hat_color", INK)
	match look.get("hat", ""):
		"peaked":
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(-42, -28), Vector2(-48, -60), Vector2(-6, -78), Vector2(44, -70),
				Vector2(56, -46), Vector2(48, -28)]), 2)), color)
			_poly(_hpts(PackedVector2Array([Vector2(-42, -40), Vector2(50, -40), Vector2(50, -28), Vector2(-42, -28)])), GOLD)
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(8, -30), Vector2(70, -26), Vector2(62, -16), Vector2(6, -22)]), 1)), Color("15131f"))
			var marks: int = look.get("marks", 1)
			for i in marks:
				_insignia_head("star", Vector2(-14 + i * 15 - (marks - 1) * 3.5, -56), 7.0)
		"beret":
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(-50, -20), Vector2(-46, -58), Vector2(6, -76), Vector2(54, -58),
				Vector2(58, -36), Vector2(14, -28)]), 2)), color)
			_insignia_head("sun", Vector2(30, -48), 9.0)
		"side_cap":
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(-46, -30), Vector2(-30, -62), Vector2(32, -56), Vector2(50, -32)]), 1)), color)
			var marks: int = look.get("marks", 1)
			for i in marks:
				_insignia_head("triangle", Vector2(12 + i * 12, -42), 6.0)
		"helmet":
			var big: bool = look.get("big_helmet", false)
			var s := 1.22 if big else 1.0
			var drop := 10.0 if big else 0.0
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(Vector2(cos(a) * 54 * s + 4, sin(a) * 50 * s - 12 + drop))
			_poly(_hpts(dome), color)
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(-60 * s, -14 + drop), Vector2(66 * s, -14 + drop),
				Vector2(66 * s, -4 + drop), Vector2(-60 * s, -4 + drop)]), 1)), color.darkened(0.2))
			if not look.get("shadow", false):
				for i in 3:
					draw_circle(_hp(Vector2(-20 + i * 22, -42 * s + drop)), 3.5, color.darkened(0.25))
		"fedora":
			_ellipse(_hp(Vector2(4, -32)), 70, 11, color.darkened(0.15))
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(-36, -32), Vector2(-32, -74), Vector2(2, -64), Vector2(34, -76),
				Vector2(40, -32)]), 2)), color)
			_poly(_hpts(PackedVector2Array([Vector2(-36, -46), Vector2(40, -46), Vector2(40, -34), Vector2(-36, -34)])), Color("e2475f"))
		"bandana":
			_poly(_hpts(_smooth(PackedVector2Array([Vector2(-46, -34), Vector2(-28, -52), Vector2(30, -50), Vector2(48, -30),
				Vector2(44, -20), Vector2(-46, -22)]), 1)), color)
			_poly(_hpts(PackedVector2Array([Vector2(-44, -30), Vector2(-74, -40), Vector2(-70, -20)])), color.darkened(0.15))


func _arm(angle: float, back: bool) -> void:
	var shoulder := _t * (SHOULDER + Vector2(-6 if back else 6, 0))
	var dir := _t.basis_xform(Vector2(sin(deg_to_rad(angle)), cos(deg_to_rad(angle)))).normalized()
	var hand := shoulder + dir * ARM_LEN
	var sleeve: Color = look["uniform"]
	if back:
		sleeve = sleeve.darkened(0.2)
	if not back and prop_out:
		_prop(hand, dir)
	_capsule(shoulder, hand, ARM_W, sleeve)
	if look.get("insignia") == "chevron" and not back and not look.get("shadow", false):
		var mid := shoulder.lerp(hand, 0.32)
		var marks: int = look.get("marks", 1)
		for i in marks:
			_insignia_at("chevron", mid + dir * (i * 7.0), 6.0, GOLD)
	var hand_r := 15.0 if look.get("move") == "punch" else 13.0
	_circle(hand, hand_r, look["skin_color"] if not look.get("shadow", false) else look["uniform"])


func _limb(from: Vector2, angle: float, length: float, width: float, color: Color, boot: bool) -> void:
	var dir := Vector2(sin(deg_to_rad(angle)), cos(deg_to_rad(angle)))
	var end := from + dir * length
	_capsule(from, end, width, color)
	if boot:
		_ellipse(end + Vector2(10, 4), 22, 11, BOOT if not look.get("shadow", false) else look["uniform"])


func _prop(hand: Vector2, dir: Vector2) -> void:
	var forward := Vector2(1, 0)
	match look.get("move", ""):
		"megaphone":
			var base := hand + Vector2(4, -6)
			_poly(PackedVector2Array([base + Vector2(0, -9), base + Vector2(52, -26), base + Vector2(52, 22), base + Vector2(0, 9)]), Color("ff5a5f"))
			_ellipse(base + Vector2(52, -2), 8, 24, Color.WHITE)
		"saber":
			var tip := hand + dir.rotated(-0.25) * 104
			var mid := hand.lerp(tip, 0.5) + dir.orthogonal() * 10
			_line([hand, mid, tip], 14, INK)
			_line([hand, mid, tip], 7, Color("e9eef7"))
			_capsule(hand - dir.orthogonal() * 12, hand + dir.orthogonal() * 12, 7, GOLD)
		"baton":
			_capsule(hand, hand + dir * 58, 11, Color("6b4a2b"))
		"rifle":
			var tip := hand + dir * 118
			_capsule(hand - dir * 24, hand + dir * 40, 16, Color("8a5a2b"))
			_capsule(hand + dir * 30, tip, 8, Color("3b3852"))
		"flag":
			var top := hand + dir * 130
			_capsule(hand - dir * 20, top, 7, GOLD)
			var side := forward * 66
			_poly(PackedVector2Array([top, top + side + Vector2(0, 6), top + side * 0.8 + Vector2(0, 24), top + side + Vector2(0, 44), top + Vector2(0, 40)]), Color("ef4a68"))


func _ko_stars() -> void:
	var c := _t * (HEAD + Vector2(0, -64))
	for i in 3:
		var a := deg_to_rad(ko_spin + i * 120.0)
		_insignia_at("star", c + Vector2(cos(a) * 44, sin(a) * 12), 9.0, GOLD)


# --- Insignia (original simple shapes) --------------------------------------------------------

func _insignia_torso(kind: String, torso_point: Vector2, size: float) -> void:
	_insignia_at(kind, _t * torso_point, size, GOLD)


func _insignia_head(kind: String, head_offset: Vector2, size: float) -> void:
	_insignia_at(kind, _hp(head_offset), size, GOLD)


func _insignia_at(kind: String, at: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array()
	match kind:
		"star":
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(at + Vector2(cos(a), sin(a)) * (size if i % 2 == 0 else size * 0.45))
		"sun":
			for i in 16:
				var a := -PI / 2 + i * PI / 8
				pts.append(at + Vector2(cos(a), sin(a)) * (size if i % 2 == 0 else size * 0.55))
		"triangle":
			pts = PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.95, size * 0.65), at + Vector2(-size * 0.95, size * 0.65)])
		"chevron":
			pts = PackedVector2Array([at + Vector2(-size, size * 0.2), at + Vector2(0, -size * 0.6), at + Vector2(size, size * 0.2),
				at + Vector2(size, size * 0.75), at + Vector2(0, 0), at + Vector2(-size, size * 0.75)])
	_poly(pts, color, 2.5)


# --- Drawing helpers --------------------------------------------------------------------------

func _hp(offset: Vector2) -> Vector2:
	return _t * (HEAD + offset)


func _hpts(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_hp(p))
	return out


func _xf(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_t * p)
	return out


func _poly(points: PackedVector2Array, fill: Color, width := INK_W) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, INK, width, true)


func _circle(c: Vector2, r: float, fill: Color) -> void:
	draw_circle(c, r + INK_W * 0.5, INK)
	draw_circle(c, r - INK_W * 0.5, fill)


func _ellipse(c: Vector2, rx: float, ry: float, fill: Color, outlined := true) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if outlined:
		_poly(pts, fill, 3.5)
	else:
		draw_colored_polygon(pts, fill)


func _capsule(a: Vector2, b: Vector2, width: float, fill: Color) -> void:
	draw_line(a, b, INK, width + INK_W * 2.0, true)
	draw_circle(a, width * 0.5 + INK_W, INK)
	draw_circle(b, width * 0.5 + INK_W, INK)
	draw_line(a, b, fill, width, true)
	draw_circle(a, width * 0.5, fill)
	draw_circle(b, width * 0.5, fill)


func _line(points: Array, width: float, color := INK) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)


static func _box(center: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y), center + Vector2(-half.x, half.y)])


## Chaikin corner cutting: turns a rough outline into a soft cartoon shape.
static func _smooth(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var p := points
	for it in iterations:
		var q := PackedVector2Array()
		for i in p.size():
			var a := p[i]
			var b := p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p
