class_name AuraFX
extends RefCounted
## Auras: a persistent effect around every piece of one side, visible to both players. Each aura
## is a pulsing glow ring on the stand plus a handful of particles (at most 8 per piece) drawn with
## FxTextures sprites, so 42 auras stay cheap on mobile WebGL. The aura node is a child of the
## piece's rig, so it follows lifts and slides and disappears with the piece.
##
## Style keys: glow (ring colour), glow_mix (darken instead of add), shape, colors (over life),
## additive, amount, lifetime, size, rise (speed range), gravity, radius, height, spin,
## rainbow, flicker.

const NONE := "none"

const STYLES := {
	"none": {"name": "No aura", "rarity": "common", "desc": "Just your pieces.",
		"swatch": [Color("e9e4f5"), Color("c9c2dd")]},
	"aura_flame": {"name": "Fire", "rarity": "rare", "desc": "Cartoon flames lick up around every piece.",
		"swatch": [Color("ffd23f"), Color("ff7a1a"), Color("e8341c")],
		"glow": Color("ff6a1a"), "shape": "flame", "colors": [Color("ffe14d"), Color("ff8a1f"), Color("ff3d1f")],
		"additive": false, "amount": 8, "lifetime": 0.75, "size": 0.34, "rise": Vector2(0.35, 0.65), "gravity": 0.5,
		"radius": 0.44, "height": 0.06},
	"aura_ghostly": {"name": "Ghostly", "rarity": "epic", "desc": "Pale wisps of mist and a cold, eerie glow.",
		"swatch": [Color("eef6ff"), Color("b8d4ff"), Color("7f9cd6")],
		"glow": Color("b8dcff"), "shape": "puff", "colors": [Color("f2f8ff", 0.0), Color("dcebff", 0.55), Color("a9c4f0", 0.0)],
		"additive": true, "amount": 8, "lifetime": 2.2, "size": 0.47, "rise": Vector2(0.08, 0.22), "gravity": 0.04,
		"radius": 0.4, "height": 0.1, "spin": 25.0},
	"aura_neon": {"name": "Neon", "rarity": "epic", "desc": "A crisp neon ring that scans up and down your pieces.",
		"swatch": [Color("ff2bd6"), Color("2ef6ff"), Color("1a0f33")],
		"glow": Color("ff2bd6"), "ring_shape": "ring", "ring_boost": 2.4, "scan": 0.7, "shape": "sparkle",
		"colors": [Color("ffffff"), Color("ff8ff0"), Color("ff2bd6")],
		"additive": true, "amount": 4, "lifetime": 0.9, "size": 0.16, "rise": Vector2(0.1, 0.3), "gravity": 0.0,
		"radius": 0.48, "height": 0.3},
	"aura_frost": {"name": "Frost", "rarity": "rare", "desc": "Snowflakes drift around an icy ring.",
		"swatch": [Color("e6faff"), Color("9ee6ff"), Color("4fb3ff")],
		"glow": Color("8fe6ff"), "shape": "snowflake", "colors": [Color("ffffff"), Color("c8f2ff"), Color("8fd8ff")],
		"additive": false, "amount": 7, "lifetime": 2.2, "size": 0.18, "rise": Vector2(0.05, 0.2), "gravity": -0.05,
		"radius": 0.48, "height": 0.6, "spin": 90.0},
	"aura_lightning": {"name": "Lightning", "rarity": "epic", "desc": "Crackling electric arcs.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")],
		"glow": Color("5fc8ff"), "shape": "bolt", "colors": [Color("ffffff"), Color("aee9ff"), Color("4fa8ff")],
		"additive": true, "amount": 5, "lifetime": 0.22, "size": 0.42, "rise": Vector2(0.0, 0.05), "gravity": 0.0,
		"radius": 0.46, "height": 0.4, "flicker": true},
	"aura_holy_light": {"name": "Holy Light", "rarity": "epic", "desc": "A warm golden glow with rising sparkles.",
		"swatch": [Color("fffbe6"), Color("ffe58a"), Color("ffc93c")],
		"glow": Color("ffe58a"), "shape": "sparkle", "colors": [Color("ffffff"), Color("fff1b0"), Color("ffd24a")],
		"additive": true, "amount": 7, "lifetime": 1.6, "size": 0.21, "rise": Vector2(0.25, 0.5), "gravity": 0.0,
		"radius": 0.38, "height": 0.1},
	"aura_shadow_smoke": {"name": "Shadow Smoke", "rarity": "epic", "desc": "Dark smoke curls around your army.",
		"swatch": [Color("2a2236"), Color("5a3d7a"), Color("8b5cff")],
		"glow": Color("3b2a5a"), "glow_mix": true, "shape": "puff", "colors": [Color("4a3a66", 0.75), Color("2a2236", 0.6), Color("120e1a", 0.3)],
		"additive": false, "amount": 7, "lifetime": 1.8, "size": 0.42, "rise": Vector2(0.1, 0.3), "gravity": 0.08,
		"radius": 0.44, "height": 0.08, "spin": 40.0},
	"aura_sakura": {"name": "Sakura Petals", "rarity": "rare", "desc": "Cherry-blossom petals swirl down.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("ff6f9f")],
		"glow": Color("ff9ec7"), "shape": "petal", "colors": [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")],
		"additive": false, "amount": 7, "lifetime": 2.0, "size": 0.17, "rise": Vector2(0.0, 0.15), "gravity": -0.12,
		"radius": 0.5, "height": 0.75, "spin": 160.0},
	"aura_galaxy": {"name": "Galaxy", "rarity": "legendary", "desc": "A swirl of tiny stars and nebula light.",
		"swatch": [Color("1b1440"), Color("5d7bff"), Color("b05cff"), Color("ffffff")],
		"glow": Color("8a6bff"), "shape": "star", "colors": [Color("ffffff"), Color("c9b8ff"), Color("6f8bff")],
		"additive": true, "amount": 8, "lifetime": 1.8, "size": 0.16, "rise": Vector2(0.05, 0.25), "gravity": 0.05,
		"radius": 0.5, "height": 0.4, "spin": 120.0, "rainbow_ring": 0.35},
	"aura_toxic": {"name": "Toxic", "rarity": "rare", "desc": "Bubbling green fumes.",
		"swatch": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")],
		"glow": Color("9cff3a"), "shape": "bubble", "colors": [Color("eaff9a"), Color("9cff3a"), Color("4fc41a")],
		"additive": true, "amount": 7, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.25, 0.5), "gravity": 0.1,
		"radius": 0.4, "height": 0.06},
	"aura_rainbow": {"name": "Rainbow", "rarity": "legendary", "desc": "A colour-cycling ring with rainbow sparkles.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")],
		"glow": Color("ffffff"), "shape": "sparkle", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")],
		"additive": true, "amount": 8, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.2, 0.45), "gravity": 0.0,
		"radius": 0.42, "height": 0.1, "rainbow": true, "rainbow_ring": 1.0},
	"aura_hearts": {"name": "Hearts", "rarity": "common", "desc": "Little hearts float up. Aww.",
		"swatch": [Color("ffd1e1"), Color("ff6f9f"), Color("ff3b6e")],
		"glow": Color("ff6f9f"), "shape": "heart", "colors": [Color("ffc2d8"), Color("ff6f9f"), Color("ff3b6e")],
		"additive": false, "amount": 6, "lifetime": 1.6, "size": 0.18, "rise": Vector2(0.25, 0.45), "gravity": 0.0,
		"radius": 0.38, "height": 0.15},
	"aura_music": {"name": "Rhythm", "rarity": "rare", "desc": "Music notes bounce around your pieces.",
		"swatch": [Color("ffffff"), Color("7fd6ff"), Color("b05cff")],
		"glow": Color("7fd6ff"), "shape": "note", "colors": [Color("ffffff"), Color("b8e6ff"), Color("c9a0ff")],
		"additive": false, "amount": 5, "lifetime": 1.6, "size": 0.21, "rise": Vector2(0.25, 0.45), "gravity": 0.0,
		"radius": 0.46, "height": 0.2, "spin": 30.0},
	"aura_witch_wisps": {"name": "Witch's Wisps", "rarity": "epic", "season": "halloween", "desc": "Green and purple witch-fire flickers around every piece.",
		"swatch": [Color("7dff5a"), Color("8b5cf6"), Color("2b1740")],
		"glow": Color("7dff5a"), "shape": "flame", "colors": [Color("d8ff8a"), Color("7dff5a"), Color("8b5cf6")],
		"additive": false, "amount": 8, "lifetime": 0.85, "size": 0.3, "rise": Vector2(0.3, 0.6), "gravity": 0.45,
		"radius": 0.44, "height": 0.06},
}

static var _ring_materials: Dictionary = {}
static var _ring_mesh: PlaneMesh


## A ready-to-attach aura node for `style`, or null for "none"/unknown styles.
static func create(style: String) -> Node3D:
	if style == NONE or not STYLES.has(style):
		return null
	var s: Dictionary = STYLES[style]
	var root := Node3D.new()
	root.name = "Aura"

	var ring := MeshInstance3D.new()
	ring.mesh = _ring()
	ring.material_override = _ring_material(style, false)
	ring.position.y = 0.012
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	if s.get("scan", 0.0) > 0.0:
		# A second ring that the shader sweeps up and down the piece (neon scanner).
		var scan := MeshInstance3D.new()
		scan.mesh = _ring()
		scan.material_override = _ring_material(style, true)
		scan.position.y = 0.05
		scan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(scan)

	var p := FxTextures.particles(s["shape"], s.get("additive", false), s.get("amount", 6), s.get("lifetime", 1.0), s.get("size", 0.15))
	p.local_coords = true
	p.preprocess = s.get("lifetime", 1.0)
	p.position.y = s.get("height", 0.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = s.get("radius", 0.42)
	p.emission_ring_inner_radius = s.get("radius", 0.42) * 0.7
	p.emission_ring_height = 0.15
	p.direction = Vector3.UP
	p.spread = 20.0
	var rise: Vector2 = s.get("rise", Vector2(0.2, 0.4))
	p.initial_velocity_min = rise.x
	p.initial_velocity_max = rise.y
	p.gravity = Vector3(0.0, s.get("gravity", 0.0), 0.0)
	FxTextures.random_angle(p, s["shape"])
	var spin: float = s.get("spin", 0.0)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.3), Vector2(0.2, 1.0), Vector2(0.8, 0.9), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(s["colors"])
	if s.get("rainbow", false):
		p.color_initial_ramp = FxTextures.rainbow()
	if s.get("flicker", false):
		p.explosiveness = 0.0
		p.randomness = 1.0
		p.emission_ring_height = 0.6
		p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.5, 1.1), Vector2(1.0, 0.6)])
	root.add_child(p)
	return root


static func _ring() -> PlaneMesh:
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2(1.3, 1.3)
	return _ring_mesh


## One shader material per style, shared by every piece. The pulse phase comes from the piece's
## world position so neighbouring rings don't throb in lockstep.
static func _ring_material(style: String, scanning: bool) -> ShaderMaterial:
	var key := "%s/%s" % [style, scanning]
	if _ring_materials.has(key):
		return _ring_materials[key]
	var s: Dictionary = STYLES[style]
	var mix: bool = s.get("glow_mix", false)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D ring_tex : source_color, filter_linear_mipmap;
uniform float rainbow = 0.0;
uniform float boost = 1.0;
uniform float scan = 0.0;
varying float phase;
varying float sweep;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void vertex() {
	phase = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
	sweep = 0.5 + 0.5 * sin(TIME * 1.8 + phase);
	VERTEX.y += sweep * scan;
	VERTEX.xz *= 1.0 - 0.3 * sweep * step(0.001, scan);
}
void fragment() {
	vec4 t = texture(ring_tex, UV);
	float pulse = 0.72 + 0.28 * sin(TIME * 2.6 + phase);
	float ang = atan(UV.y - 0.5, UV.x - 0.5) / 6.2832;
	vec3 c = mix(tint.rgb, hue(fract(TIME * 0.3 + ang + phase * 0.05)), rainbow);
	ALBEDO = c * boost;
	ALPHA = t.a * tint.a * pulse * (scan > 0.0 ? 1.0 - 0.5 * sweep : 1.0);
}
""" % ("blend_mix" if mix else "blend_add")
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", Color(s["glow"], 0.8 if mix else 0.95))
	m.set_shader_parameter("ring_tex", FxTextures.texture(s.get("ring_shape", "glow_ring")))
	m.set_shader_parameter("rainbow", s.get("rainbow_ring", 0.0))
	m.set_shader_parameter("boost", s.get("ring_boost", 1.0))
	m.set_shader_parameter("scan", s.get("scan", 0.0) if scanning else 0.0)
	m.render_priority = 1
	_ring_materials[key] = m
	return m
