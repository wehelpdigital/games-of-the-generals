class_name BoardGlowFX
extends RefCounted
## Board glow: an effect running along the frame edge of one player's HALF of the board (white =
## rows 0–3 side, black = rows 4–7 side), visible to both players, so each half can glow its own
## way. Each glow is one flared ribbon mesh around the half's three outer edges, drawn by a small
## shader (flame tongues, mist, neon tube, rainbow...), plus at most ~50 particles along the edge.
##
## Style keys: base / tip (ribbon colours bottom → top), height, flare, blend ("mix"/"add"; mix keeps
## its colour on light arenas, add only reads on dark ones),
## tongues (flame-shape amount), freq, speed, pulse, rainbow, band (neon tube), boost (HDR),
## falloff, and the particle set: shape, colors, additive, amount, lifetime, size, rise, gravity,
## spin, flicker, rainbow_particles.

const NONE := "none"
const HALF_X := 5.0     ## Frame half-width (Ranks.COLS * TILE / 2 + Board3D.SLAB_MARGIN).
const HALF_Z := 4.5     ## Frame half-depth (Ranks.ROWS * TILE / 2 + Board3D.SLAB_MARGIN).
const CORNER := 0.5     ## Frame corner radius.

const STYLES := {
	"none": {"name": "No glow", "rarity": "common", "desc": "A plain board edge.",
		"swatch": [Color("e9e4f5"), Color("c9c2dd")]},
	"glow_fire": {"name": "Inferno Edge", "rarity": "rare", "desc": "Flames flicker along your side of the board.",
		"swatch": [Color("ffe14d"), Color("ff7a1a"), Color("e8341c")],
		"base": Color("e8341c"), "tip": Color("ffd23f"), "height": 0.95, "flare": 0.12, "blend": "mix",
		"tongues": 1.0, "freq": 7.0, "speed": 3.2, "falloff": 0.45,
		"shape": "flame", "colors": [Color("fff36b"), Color("ffa21f"), Color("ff3d1f")], "additive": false,
		"amount": 46, "lifetime": 0.8, "size": 0.32, "rise": Vector2(0.4, 0.9), "gravity": 0.6},
	"glow_ghostly": {"name": "Ghostly Mist", "rarity": "epic", "desc": "Pale, cold mist rises from your edge.",
		"swatch": [Color("eef6ff"), Color("b8d4ff"), Color("7f9cd6")],
		"base": Color("b4ceff", 0.8), "tip": Color("eef6ff", 0.0), "height": 0.9, "flare": 0.5, "blend": "mix",
		"tongues": 0.55, "freq": 2.5, "speed": 0.7, "falloff": 1.4, "pulse": 0.6,
		"shape": "puff", "colors": [Color("f2f8ff", 0.0), Color("cfe0ff", 0.6), Color("9ab6ea", 0.0)], "additive": false,
		"amount": 34, "lifetime": 2.6, "size": 0.55, "rise": Vector2(0.1, 0.3), "gravity": 0.05, "spin": 20.0},
	"glow_neon": {"name": "Neon Tube", "rarity": "epic", "desc": "A buzzing neon tube traces your edge.",
		"swatch": [Color("2ef6ff"), Color("ff2bd6"), Color("1a0f33")],
		"base": Color("2ef6ff"), "tip": Color("ff2bd6", 0.0), "height": 0.35, "flare": 0.05, "blend": "mix",
		"band": 0.16, "boost": 2.2, "falloff": 2.2, "pulse": 0.25,
		"shape": "sparkle", "colors": [Color("aef9ff"), Color("2ef6ff"), Color("ff2bd6")], "additive": false,
		"amount": 10, "lifetime": 0.5, "size": 0.14, "rise": Vector2(0.0, 0.1), "gravity": 0.0, "flicker": true},
	"glow_frost": {"name": "Frostbound", "rarity": "rare", "desc": "Ice crystals crown your side.",
		"swatch": [Color("ffffff"), Color("9ee6ff"), Color("3aa7e6")],
		"base": Color("8fd8ff"), "tip": Color("ffffff"), "height": 0.45, "flare": 0.2, "blend": "mix",
		"tongues": 0.9, "freq": 14.0, "speed": 0.0, "falloff": 0.4,
		"shape": "snowflake", "colors": [Color("ffffff"), Color("c8f2ff"), Color("8fd8ff")], "additive": false,
		"amount": 26, "lifetime": 2.4, "size": 0.16, "rise": Vector2(0.05, 0.25), "gravity": -0.06, "spin": 90.0},
	"glow_electric": {"name": "Electric Fence", "rarity": "epic", "desc": "Lightning crackles along your edge.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")],
		"base": Color("4fa8ff"), "tip": Color("aee9ff", 0.0), "height": 0.4, "flare": 0.1, "blend": "mix",
		"band": 0.08, "boost": 1.8, "falloff": 2.5, "pulse": 0.9, "speed": 9.0,
		"shape": "bolt", "colors": [Color("e8fbff"), Color("6fd3ff"), Color("3a5bff")], "additive": false,
		"amount": 18, "lifetime": 0.2, "size": 0.45, "rise": Vector2(0.0, 0.05), "gravity": 0.0, "flicker": true},
	"glow_golden_halo": {"name": "Golden Halo", "rarity": "legendary", "desc": "A warm golden radiance with drifting sparkles.",
		"swatch": [Color("fffbe6"), Color("ffe58a"), Color("ffc93c")],
		"base": Color("ffc93c", 0.9), "tip": Color("fff1b0", 0.0), "height": 0.6, "flare": 0.35, "blend": "mix",
		"boost": 1.3, "falloff": 1.6, "pulse": 0.4,
		"shape": "sparkle", "colors": [Color("fff1b0"), Color("ffd24a"), Color("ffa21f")], "additive": false,
		"amount": 30, "lifetime": 1.8, "size": 0.18, "rise": Vector2(0.15, 0.4), "gravity": 0.0},
	"glow_toxic": {"name": "Toxic Ooze", "rarity": "rare", "desc": "Glowing green goo bubbles over your edge.",
		"swatch": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")],
		"base": Color("5fc41a"), "tip": Color("d4ff3a"), "height": 0.4, "flare": 0.15, "blend": "mix",
		"tongues": 0.6, "freq": 4.0, "speed": 0.8, "falloff": 0.5,
		"shape": "bubble", "colors": [Color("eaff9a"), Color("9cff3a"), Color("4fc41a")], "additive": false,
		"amount": 28, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.2, 0.45), "gravity": 0.1},
	"glow_rainbow": {"name": "Rainbow Rim", "rarity": "legendary", "desc": "A rainbow that flows around your side.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")],
		"base": Color("ffffff"), "tip": Color("ffffff", 0.0), "height": 0.4, "flare": 0.2, "blend": "mix",
		"rainbow": 1.0, "boost": 1.4, "falloff": 1.4, "band": 0.12,
		"shape": "dot", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 30, "lifetime": 1.0, "size": 0.16, "rise": Vector2(0.1, 0.3), "gravity": 0.0, "rainbow_particles": true},
	"glow_starlight": {"name": "Starlight", "rarity": "epic", "desc": "Twinkling stars along a midnight-blue rim.",
		"swatch": [Color("1b1440"), Color("6f8bff"), Color("ffffff")],
		"base": Color("3b4dff", 0.9), "tip": Color("8a6bff", 0.0), "height": 0.45, "flare": 0.3, "blend": "mix",
		"boost": 1.1, "falloff": 1.8, "pulse": 0.3,
		"shape": "star", "colors": [Color("ffffff"), Color("c9b8ff"), Color("6f8bff")], "additive": false,
		"amount": 34, "lifetime": 1.6, "size": 0.16, "rise": Vector2(0.0, 0.15), "gravity": 0.0, "spin": 90.0},
	"glow_lava": {"name": "Lava Flow", "rarity": "legendary", "desc": "Molten rock oozes along your side, spitting embers.",
		"swatch": [Color("2b2121"), Color("ff5a1f"), Color("ffb020")],
		"base": Color("c8240f"), "tip": Color("ff9a1f"), "height": 0.3, "flare": 0.3, "blend": "mix",
		"tongues": 0.7, "freq": 3.0, "speed": 0.6, "falloff": 0.3, "boost": 1.4,
		"shape": "dot", "colors": [Color("ffe14d"), Color("ff8a1f"), Color("e8341c")], "additive": false,
		"amount": 40, "lifetime": 1.1, "size": 0.12, "rise": Vector2(0.6, 1.4), "gravity": -1.2},
	"glow_shadow": {"name": "Shadow Veil", "rarity": "epic", "desc": "Dark smoke curls around your edge.",
		"swatch": [Color("120e1a"), Color("3b2a5a"), Color("8b5cff")],
		"base": Color("1d1530", 0.9), "tip": Color("3b2a5a", 0.0), "height": 0.7, "flare": 0.4, "blend": "mix",
		"tongues": 0.6, "freq": 3.0, "speed": 0.9, "falloff": 1.0,
		"shape": "puff", "colors": [Color("4a3a66", 0.7), Color("2a2236", 0.55), Color("120e1a", 0.0)], "additive": false,
		"amount": 30, "lifetime": 2.0, "size": 0.5, "rise": Vector2(0.1, 0.3), "gravity": 0.05, "spin": 30.0},
	"glow_sakura": {"name": "Sakura Breeze", "rarity": "rare", "desc": "Blossoms drift along your side of the board.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("78c46b")],
		"base": Color("ff9ec7", 0.85), "tip": Color("ffe3ee", 0.0), "height": 0.4, "flare": 0.3, "blend": "mix",
		"falloff": 1.6, "pulse": 0.3,
		"shape": "petal", "colors": [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")], "additive": false,
		"amount": 30, "lifetime": 2.2, "size": 0.15, "rise": Vector2(0.1, 0.35), "gravity": -0.1, "spin": 200.0},
	"glow_christmas_lights": {"name": "Christmas Lights", "rarity": "epic", "season": "christmas", "desc": "A string of twinkling coloured bulbs along your edge.",
		"swatch": [Color("ff4f5a"), Color("ffcf3f"), Color("3ddc84"), Color("3d8bff")],
		"base": Color("1f6b3a"), "tip": Color("2f8f4e", 0.0), "height": 0.25, "flare": 0.05, "blend": "mix",
		"band": 0.12, "boost": 1.2, "falloff": 2.2, "pulse": 0.2,
		"shape": "dot", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 34, "lifetime": 0.9, "size": 0.2, "rise": Vector2(0.0, 0.05), "gravity": 0.0, "rainbow_particles": true, "flicker": true},
}

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## The glow for `side`'s half (board-local, child of the board), or null for "none".
static func create(side: String, style: String, frame_top: float) -> Node3D:
	if style == NONE or not STYLES.has(style):
		return null
	var s: Dictionary = STYLES[style]
	var root := Node3D.new()
	root.name = "BoardGlow_%s" % side
	var path := _path(side)

	var ribbon := MeshInstance3D.new()
	ribbon.mesh = _ribbon(side, s.get("height", 0.4), s.get("flare", 0.2), frame_top)
	ribbon.material_override = _material(style)
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ribbon)

	var p := FxTextures.particles(s["shape"], s.get("additive", false), s.get("amount", 30), s.get("lifetime", 1.0), s.get("size", 0.18))
	p.local_coords = true
	p.preprocess = s.get("lifetime", 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var points := PackedVector3Array()
	for i in range(0, path.size(), 3):
		var at: Vector2 = path[i][0] + path[i][1] * 0.1
		points.append(Vector3(at.x, frame_top + 0.05, at.y))
	p.emission_points = points
	p.direction = Vector3.UP
	p.spread = 25.0
	var rise: Vector2 = s.get("rise", Vector2(0.2, 0.4))
	p.initial_velocity_min = rise.x
	p.initial_velocity_max = rise.y
	p.gravity = Vector3(0.0, s.get("gravity", 0.0), 0.0)
	FxTextures.random_angle(p, s["shape"])
	var spin: float = s.get("spin", 0.0)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.3), Vector2(0.2, 1.0), Vector2(0.8, 0.9), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(s["colors"])
	if s.get("rainbow_particles", false):
		p.color_initial_ramp = FxTextures.rainbow()
	if s.get("flicker", false):
		p.randomness = 1.0
		p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.7)])
	root.add_child(p)
	return root


## Points along the outside of the frame for one half: [[position (x, z), outward normal, distance]].
static func _path(side: String) -> Array:
	var key := "path/" + side
	if _meshes.has(key):
		return _meshes[key]
	var flip := 1.0 if side == Ranks.WHITE else -1.0
	var pts: Array = []
	var step := 0.1
	var add := func(at: Vector2, normal: Vector2) -> void:
		pts.append([Vector2(at.x, at.y * flip), Vector2(normal.x, normal.y * flip)])
	# Left edge, from the centre line out to the corner.
	var z := 0.0
	while z < HALF_Z - CORNER:
		add.call(Vector2(-HALF_X, z), Vector2(-1, 0))
		z += step
	for i in 9:
		var a := PI - (PI / 2.0) * i / 8.0
		var n := Vector2(cos(a), sin(a))
		add.call(Vector2(-HALF_X + CORNER, HALF_Z - CORNER) + n * CORNER, n)
	var x := -HALF_X + CORNER + step
	while x < HALF_X - CORNER:
		add.call(Vector2(x, HALF_Z), Vector2(0, 1))
		x += step
	for i in 9:
		var a := PI / 2.0 - (PI / 2.0) * i / 8.0
		var n := Vector2(cos(a), sin(a))
		add.call(Vector2(HALF_X - CORNER, HALF_Z - CORNER) + n * CORNER, n)
	z = HALF_Z - CORNER - step
	while z >= 0.0:
		add.call(Vector2(HALF_X, z), Vector2(1, 0))
		z -= step
	# Running distance for the shader's U coordinate.
	var dist := 0.0
	for i in pts.size():
		if i > 0:
			dist += (pts[i][0] - pts[i - 1][0]).length()
		pts[i].append(dist)
	_meshes[key] = pts
	return pts


## A ribbon standing on the frame edge and flaring outward, so it reads from above too.
static func _ribbon(side: String, height: float, flare: float, frame_top: float) -> ArrayMesh:
	var key := "ribbon/%s/%s/%s/%s" % [side, height, flare, frame_top]
	if _meshes.has(key):
		return _meshes[key]
	var path := _path(side)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in path.size() - 1:
		var a: Array = path[i]
		var b: Array = path[i + 1]
		var a0 := Vector3(a[0].x, frame_top, a[0].y) + Vector3(a[1].x, 0, a[1].y) * 0.04
		var b0 := Vector3(b[0].x, frame_top, b[0].y) + Vector3(b[1].x, 0, b[1].y) * 0.04
		var a1 := a0 + Vector3(a[1].x * flare, height, a[1].y * flare)
		var b1 := b0 + Vector3(b[1].x * flare, height, b[1].y * flare)
		var ua: float = a[2]
		var ub: float = b[2]
		for v: Array in [[a0, Vector2(ua, 0)], [b0, Vector2(ub, 0)], [b1, Vector2(ub, 1)],
				[a0, Vector2(ua, 0)], [b1, Vector2(ub, 1)], [a1, Vector2(ua, 1)]]:
			st.set_uv(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _material(style: String) -> ShaderMaterial:
	if _materials.has(style):
		return _materials[style]
	var s: Dictionary = STYLES[style]
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 tip_color : source_color = vec4(1.0);
uniform float tongues = 0.0;
uniform float freq = 6.0;
uniform float speed = 1.5;
uniform float pulse = 0.0;
uniform float rainbow = 0.0;
uniform float band = 0.0;
uniform float boost = 1.0;
uniform float falloff = 1.5;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
float wave(float x) { return sin(x) * 0.5 + 0.5; }
void fragment() {
	float x = UV.x;
	float y = UV.y;
	// Flame / mist tongues: how high the effect reaches at this point of the edge.
	float reach = wave(x * freq + TIME * speed) * 0.6 + wave(x * freq * 2.3 - TIME * speed * 1.7) * 0.4;
	reach = mix(1.0, 0.25 + 0.75 * reach, tongues);
	float h = clamp(y / max(reach, 0.05), 0.0, 1.0);
	float a = pow(1.0 - h, falloff) * step(y, reach + 0.001);
	a *= 1.0 - pulse * 0.45 * (0.5 + 0.5 * sin(TIME * 3.0 + x * 2.0));
	vec3 c = mix(base_color.rgb, tip_color.rgb, h);
	c = mix(c, hue(fract(x * 0.12 - TIME * 0.25)), rainbow);
	float tube = band > 0.0 ? 1.0 - smoothstep(band * 0.35, band, abs(y - band * 0.6)) : 0.0;
	ALBEDO = mix(c * boost, base_color.rgb * boost + vec3(0.35), tube);
	ALPHA = clamp(a * mix(base_color.a, tip_color.a, h) + tube * 0.9, 0.0, 1.0);
}
""" % ("blend_mix" if s.get("blend", "add") == "mix" else "blend_add")
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color", s.get("base", Color.WHITE))
	m.set_shader_parameter("tip_color", s.get("tip", Color.WHITE))
	m.set_shader_parameter("tongues", s.get("tongues", 0.0))
	m.set_shader_parameter("freq", s.get("freq", 6.0))
	m.set_shader_parameter("speed", s.get("speed", 1.5))
	m.set_shader_parameter("pulse", s.get("pulse", 0.0))
	m.set_shader_parameter("rainbow", s.get("rainbow", 0.0))
	m.set_shader_parameter("band", s.get("band", 0.0))
	m.set_shader_parameter("boost", s.get("boost", 1.0))
	m.set_shader_parameter("falloff", s.get("falloff", 1.5))
	m.render_priority = 1
	_materials[style] = m
	return m
