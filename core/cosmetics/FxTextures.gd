class_name FxTextures
extends RefCounted
## Tiny procedural sprites (64×64, white with alpha) and shared particle materials for auras, move
## trails and kill effects. Everything is drawn in code, so no image assets are needed, and every
## texture/material is built once and shared. Particles tint the white sprites with their colour.

const SIZE := 64
const SHAPES := ["dot", "ring", "sparkle", "flame", "heart", "petal", "shard", "snowflake", "bolt", "ghost",
	"bubble", "square", "star", "glow_ring", "puff", "note", "streak", "leaf", "crack", "beam",
	"pumpkin", "bat", "candy_cane", "coin", "sun", "egg", "flower", "gift", "koi", "gear", "rune"]
## Sprites that read wrong when spun (flames lean sideways, hearts and notes tip over).
const UPRIGHT := ["flame", "heart", "ghost", "note", "pumpkin", "bat", "candy_cane", "egg", "gift"]

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _quads: Dictionary = {}


static func texture(shape: String) -> Texture2D:
	if not _textures.has(shape):
		_textures[shape] = _build(shape)
	return _textures[shape]


## Billboard particle material: unshaded, tinted by particle colour, additive for glowing stuff.
static func particle_material(shape: String, additive := false) -> StandardMaterial3D:
	var key := "%s/%s" % [shape, additive]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# Keep the per-particle scale: it carries the size curves, and it is what hides particles
		# that have not spawned yet (zero scale). Without it they show as black quads at the emitter.
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = texture(shape)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 2
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_materials[key] = m
	return _materials[key]


## Flat ground decal material (lies on XZ), e.g. aura rings and shockwaves.
static func decal_material(shape: String, color: Color, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = texture(shape)
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.render_priority = 1
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func quad(size := 1.0) -> QuadMesh:
	if not _quads.has(size):
		var q := QuadMesh.new()
		q.size = Vector2.ONE * size
		_quads[size] = q
	return _quads[size]


## Ready-made CPUParticles3D with the usual one-shot or looping setup.
static func particles(shape: String, additive: bool, amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = quad(size)
	p.material_override = particle_material(shape, additive)
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Random starting rotation, kept near upright for UPRIGHT shapes.
static func random_angle(p: CPUParticles3D, shape: String) -> void:
	var tilt := 12.0 if shape in UPRIGHT else 180.0
	p.angle_min = -tilt
	p.angle_max = tilt


static func gradient(colors: Array, fade_out := true) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(1.0, colors.size() - 1))
		cols.append(colors[i])
	if fade_out:
		cols[cols.size() - 1] = Color(cols[cols.size() - 1], 0.0)
	g.offsets = offsets
	g.colors = cols
	return g


static func rainbow(alpha := 1.0) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0])
	g.colors = PackedColorArray([Color(1, 0.3, 0.35, alpha), Color(1, 0.6, 0.2, alpha), Color(1, 0.92, 0.25, alpha),
		Color(0.35, 0.95, 0.45, alpha), Color(0.3, 0.7, 1, alpha), Color(0.65, 0.4, 1, alpha), Color(1, 0.3, 0.35, alpha)])
	return g


static func curve(points: Array) -> Curve:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	return c


# --- Sprite generation ------------------------------------------------------------------------

static func _build(shape: String) -> ImageTexture:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for py in SIZE:
		for px in SIZE:
			# p in [-1, 1], y up.
			var p := Vector2((px + 0.5) / SIZE * 2.0 - 1.0, 1.0 - (py + 0.5) / SIZE * 2.0)
			image.set_pixel(px, py, _shade(shape, p))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _shade(shape: String, p: Vector2) -> Color:
	var r := p.length()
	var a := 0.0
	var v := 1.0
	match shape:
		"dot":
			a = pow(clampf(1.0 - r, 0.0, 1.0), 1.6)
		"puff":
			a = clampf(1.0 - r, 0.0, 1.0)
			a = smoothstep(0.0, 0.6, a) * (0.85 + 0.15 * sin(p.x * 9.0) * sin(p.y * 7.0))
		"ring":
			a = 1.0 - smoothstep(0.08, 0.18, absf(r - 0.72))
		"glow_ring":
			a = (1.0 - smoothstep(0.0, 0.32, absf(r - 0.7))) * 0.9 + clampf(0.5 - r, 0.0, 1.0) * 0.2
		"bubble":
			a = (1.0 - smoothstep(0.06, 0.14, absf(r - 0.78))) + clampf(0.25 - (p - Vector2(-0.3, 0.32)).length(), 0.0, 1.0) * 4.0
			a = clampf(a + 0.12 * clampf(0.78 - r, 0.0, 1.0), 0.0, 1.0)
		"sparkle":
			var s := sqrt(absf(p.x)) + sqrt(absf(p.y))
			a = 1.0 - smoothstep(0.72, 0.95, s)
			a = maxf(a, pow(clampf(1.0 - r * 1.6, 0.0, 1.0), 2.0))
		"star":
			a = _inside(_star_dist(p, 5, 0.92, 0.42))
		"flame":
			# Cartoon flame: round bottom, curling pointed tip, and a lighter core in its lower part
			# so the tinted sprite reads as two tones instead of a flat drop.
			var q := Vector2(p.x - 0.12 * maxf(p.y, 0.0) * sin(p.y * 4.0), p.y)
			a = 1.0 - smoothstep(-0.08, 0.04, absf(q.x) - _flame_half(q.y))
			var core := 1.0 - smoothstep(-0.05, 0.05, absf(q.x) - _flame_half((q.y + 0.61) / 0.62 - 0.61) * 0.62)
			v = lerpf(0.62, 1.0, core)
		"heart":
			var q := Vector2(p.x * 1.25, p.y * 1.25 + 0.2)
			var f := pow(q.x * q.x + q.y * q.y - 1.0, 3.0) - q.x * q.x * q.y * q.y * q.y
			a = 1.0 - smoothstep(-0.02, 0.02, f)
		"petal":
			var q := Vector2(p.x / 0.5, (p.y + 0.05) / 0.9)
			var notch := 1.0 - smoothstep(0.0, 0.12, (p - Vector2(0, 0.86)).length() - 0.1)
			a = (1.0 - smoothstep(0.9, 1.0, q.length())) * (1.0 - notch)
			v = lerpf(0.82, 1.0, clampf(1.0 - absf(p.x) * 1.5, 0.0, 1.0))
		"shard":
			a = 1.0 - smoothstep(0.92, 1.0, absf(p.x) / 0.42 + absf(p.y) / 0.95)
			v = 0.78 + 0.22 * clampf(p.x * 2.0 + 0.5, 0.0, 1.0)
		"snowflake":
			# Six arms (every 60°), each with a cross bar, around a small hub.
			var ang := fposmod(atan2(p.y, p.x) + PI / 6.0, PI / 3.0) - PI / 6.0
			var along := r * cos(ang)
			var across := absf(r * sin(ang))
			a = (1.0 - smoothstep(0.05, 0.1, across)) * (1.0 - smoothstep(0.84, 0.94, r))
			var bar := (1.0 - smoothstep(0.04, 0.08, absf(along - 0.56))) * (1.0 - smoothstep(0.18, 0.24, across))
			a = maxf(maxf(a, bar), 1.0 - smoothstep(0.12, 0.18, r))
		"bolt":
			var pts := [Vector2(-0.18, 0.95), Vector2(0.22, 0.18), Vector2(-0.12, 0.08), Vector2(0.24, -0.95)]
			var d := 9.0
			for i in 3:
				d = minf(d, _segment_dist(p, pts[i], pts[i + 1]))
			a = (1.0 - smoothstep(0.06, 0.13, d)) + (1.0 - smoothstep(0.0, 0.35, d)) * 0.35
			a = clampf(a, 0.0, 1.0)
		"ghost":
			var body := false
			if p.y > 0.0:
				body = (p - Vector2(0, 0.0)).length() < 0.66
			else:
				body = absf(p.x) < 0.66 and p.y > -0.78 + 0.13 * sin(p.x * 14.0)
			a = 1.0 if body else 0.0
			var eye := minf((p - Vector2(-0.22, 0.12)).length(), (p - Vector2(0.22, 0.12)).length())
			if body and eye < 0.12:
				v = 0.12
			var mouth := (p - Vector2(0, -0.14)).length()
			if body and mouth < 0.09:
				v = 0.2
		"square":
			a = 1.0 - smoothstep(0.86, 0.9, maxf(absf(p.x), absf(p.y)))
			v = 0.82 if maxf(absf(p.x), absf(p.y)) > 0.7 else 1.0
		"streak":
			# Soft vertical line (rain, speed lines); stretch the quad for longer streaks.
			a = (1.0 - smoothstep(0.3, 0.95, absf(p.x))) * (1.0 - smoothstep(0.45, 1.0, absf(p.y)))
		"leaf":
			# Pointed leaf with a darker midrib.
			var half := 0.52 * pow(clampf(1.0 - p.y * p.y, 0.0, 1.0), 0.75)
			a = 1.0 - smoothstep(-0.04, 0.03, absf(p.x) - half)
			a *= 1.0 - smoothstep(0.9, 0.98, absf(p.y))
			v = 0.7 if absf(p.x) < 0.05 else lerpf(0.86, 1.0, clampf(absf(p.x) / 0.5, 0.0, 1.0))
		"crack":
			# Jagged fissures radiating from a dark centre (earth effects, craters).
			var ang := atan2(p.y, p.x)
			var d := 9.0
			for k in 7:
				var ray := k * TAU / 7.0 + 0.35 * sin(k * 2.3)
				var wobble := 0.09 * sin(r * 19.0 + k * 1.7)
				d = minf(d, absf(wrapf(ang - ray - wobble, -PI, PI)) * r)
			a = (1.0 - smoothstep(0.02, 0.06, d)) * (1.0 - smoothstep(0.85, 0.98, r))
			a = maxf(a, 1.0 - smoothstep(0.14, 0.22, r))
			v = 0.15
		"beam":
			# Bright vertical column with soft sides (lasers, tractor beams).
			a = pow(clampf(1.0 - absf(p.x), 0.0, 1.0), 2.2) * (1.0 - smoothstep(0.85, 1.0, absf(p.y)) * 0.6)
		"pumpkin":
			# Ribbed pumpkin with a stubby stem; the grooves shade darker.
			var body := Vector2(p.x / 0.92, (p.y + 0.08) / 0.72).length()
			a = 1.0 - smoothstep(0.96, 1.02, body)
			v = 0.72 + 0.28 * absf(cos(p.x * PI * 1.6))
			if absf(p.x) < 0.09 and p.y > 0.5 and p.y < 0.9:
				a = 1.0
				v = 0.42
		"bat":
			var head := Vector2(p.x / 0.17, (p.y - 0.12) / 0.3).length() < 1.0
			var ears := absf(p.x) > 0.04 and absf(p.x) < 0.14 and p.y > 0.3 and p.y < 0.5 - absf(absf(p.x) - 0.09) * 1.5
			var ax := absf(p.x)
			var top := 0.36 - 0.3 * ax
			var bottom := -0.12 - 0.12 * ax + 0.16 * absf(sin(ax * PI * 2.4))
			var wing := ax > 0.12 and ax < 0.98 and p.y < top and p.y > bottom
			a = 1.0 if head or ears or wing else 0.0
		"candy_cane":
			var stick := absf(p.x - 0.22) < 0.13 and p.y > -0.92 and p.y < 0.38
			var arc_r := Vector2(p.x + 0.12, p.y - 0.38).length()
			var hook := p.y >= 0.38 and absf(arc_r - 0.34) < 0.13
			var tip := absf(p.x + 0.46) < 0.13 and p.y > 0.2 and p.y < 0.4
			a = 1.0 if stick or hook or tip else 0.0
			v = 1.0 if fposmod((p.x + p.y) * 3.2, 1.0) < 0.5 else 0.55
		"coin":
			var hole := absf(p.x) < 0.2 and absf(p.y) < 0.2
			a = (1.0 - smoothstep(0.86, 0.94, r)) * (0.0 if hole else 1.0)
			v = 0.78 if r > 0.72 or (absf(p.x) < 0.3 and absf(p.y) < 0.3) else 1.0
		"sun":
			# Disc with eight rays.
			var ang := fposmod(atan2(p.y, p.x), TAU / 8.0) - TAU / 16.0
			var ray := absf(ang) < 0.2 * (1.0 - r) + 0.02 and r < 0.96
			a = 1.0 if r < 0.4 or ray else 0.0
			v = 1.0 if r < 0.4 else 0.85
		"egg":
			var q := Vector2(p.x / 0.64, (p.y + 0.08) / (0.86 - 0.12 * p.y))
			a = 1.0 - smoothstep(0.95, 1.02, q.length())
			var zig := absf(p.y - 0.06 * sin(p.x * 18.0)) < 0.09
			v = 0.62 if zig else (0.85 if absf(p.y + 0.36) < 0.05 else 1.0)
		"flower":
			var ang := atan2(p.y, p.x)
			var petal := r < 0.5 + 0.42 * absf(cos(ang * 2.5))
			a = 1.0 if petal and r < 0.95 else 0.0
			v = 0.62 if r < 0.24 else 1.0
		"gift":
			var box := absf(p.x) < 0.72 and p.y > -0.8 and p.y < 0.42
			var bow := Vector2((absf(p.x) - 0.24) / 0.24, (p.y - 0.58) / 0.16).length() < 1.0
			a = 1.0 if box or bow else 0.0
			v = 0.6 if absf(p.x) < 0.12 or absf(p.y + 0.18) < 0.1 or bow else 1.0
		"koi":
			# A little fish swimming right: an oval body, a forked tail and two dark patches.
			var body := Vector2((p.x - 0.12) / 0.6, p.y / 0.3).length() < 1.0
			var tail := p.x < -0.4 and p.x > -0.95 and absf(p.y) < (-0.4 - p.x) * 0.9 and absf(p.y) > (-0.4 - p.x) * 0.25 - 0.06
			var fin := absf(p.x - 0.05) < 0.12 and p.y > 0.2 and p.y < 0.42 - absf(p.x - 0.05)
			a = 1.0 if body or tail or fin else 0.0
			var patch := Vector2(p.x - 0.28, p.y - 0.06).length() < 0.15 or Vector2(p.x + 0.12, p.y + 0.05).length() < 0.12
			v = 0.55 if patch else 1.0
			if Vector2(p.x - 0.52, p.y - 0.06).length() < 0.05:
				v = 0.15
		"gear":
			var ang := atan2(p.y, p.x)
			var teeth := 0.66 + (0.18 if cos(ang * 8.0) > 0.0 else 0.0)
			a = 1.0 if r < teeth and r > 0.24 else 0.0
			v = 0.8 if r < 0.42 else 1.0
		"rune":
			# An angular rune-like glyph (an original mark, not a real letter).
			var d := minf(_segment_dist(p, Vector2(-0.1, -0.85), Vector2(-0.1, 0.85)),
				minf(_segment_dist(p, Vector2(-0.1, 0.55), Vector2(0.45, 0.15)), _segment_dist(p, Vector2(-0.1, 0.05), Vector2(0.45, -0.35))))
			a = 1.0 - smoothstep(0.1, 0.16, d)
		"note":
			var head := (Vector2((p.x + 0.28) / 1.2, p.y + 0.45)).length() < 0.24
			var stem := absf(p.x - 0.0) < 0.07 and p.y > -0.45 and p.y < 0.75
			var flag := p.x > 0.0 and p.x < 0.36 and p.y > 0.45 - p.x * 0.6 and p.y < 0.75 - p.x * 0.6
			a = 1.0 if head or stem or flag else 0.0
	return Color(v, v, v, clampf(a, 0.0, 1.0))


## Half-width of the teardrop flame at height y (round bottom near y = -0.6, tip near y = 0.95).
static func _flame_half(y: float) -> float:
	if y < -0.15:
		return sqrt(maxf(0.0, 0.58 * 0.58 - (y + 0.15) * (y + 0.15) * 1.6))
	return 0.58 * pow(clampf(1.0 - (y + 0.15) / 1.1, 0.0, 1.0), 1.3)


static func _inside(d: float) -> float:
	return 1.0 - smoothstep(-0.04, 0.04, d)


static func _star_dist(p: Vector2, points: int, outer: float, inner: float) -> float:
	# Approximate signed distance via a polygon test against the star outline.
	var poly := PackedVector2Array()
	for i in points * 2:
		var ang := PI / 2.0 + i * PI / points
		poly.append(Vector2(cos(ang), sin(ang)) * (outer if i % 2 == 0 else inner))
	var inside := Geometry2D.is_point_in_polygon(p, poly)
	var d := 9.0
	for i in poly.size():
		d = minf(d, _segment_dist(p, poly[i], poly[(i + 1) % poly.size()]))
	return -d if inside else d


static func _segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()
