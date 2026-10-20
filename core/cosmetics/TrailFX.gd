class_name TrailFX
extends RefCounted
## Move trails: particles left behind in world space while one of a side's pieces slides to a new
## tile. A short-lived CPUParticles3D is parented to the moving piece's rig (so it starts at the
## piece's height) but simulates in world space, so the particles stay where they were dropped.
##
## Style keys: shape, colors (over life), additive, amount, lifetime, size, velocity, gravity,
## spin, rainbow, flicker.

const NONE := "none"

const STYLES := {
	"none": {"name": "No trail", "rarity": "common", "desc": "Pieces move without a trace.",
		"swatch": [Color("e9e4f5"), Color("c9c2dd")]},
	"trail_sparkle": {"name": "Sparkle", "rarity": "common", "desc": "A twinkle of golden sparkles.",
		"swatch": [Color("ffffff"), Color("ffe58a"), Color("ffc93c")],
		"shape": "sparkle", "colors": [Color("fff6c8"), Color("ffd24a"), Color("ffa21f")], "additive": false,
		"amount": 26, "lifetime": 0.7, "size": 0.26, "velocity": 0.3, "gravity": -0.3},
	"trail_fire": {"name": "Fire Streak", "rarity": "rare", "desc": "Your pieces leave flames behind.",
		"swatch": [Color("fff3a8"), Color("ff7a1a"), Color("e8341c")],
		"shape": "flame", "colors": [Color("ffe14d"), Color("ff8a1f"), Color("e8341c")], "additive": false,
		"amount": 30, "lifetime": 0.6, "size": 0.38, "velocity": 0.25, "gravity": 1.2},
	"trail_smoke": {"name": "Smoke", "rarity": "common", "desc": "A puffy cartoon smoke trail.",
		"swatch": [Color("f4f1ff"), Color("c9c2dd"), Color("8f88a6")],
		"shape": "puff", "colors": [Color("ffffff", 0.9), Color("d9d4e8", 0.7), Color("a49dba", 0.4)], "additive": false,
		"amount": 20, "lifetime": 0.9, "size": 0.42, "velocity": 0.15, "gravity": 0.3, "spin": 60.0},
	"trail_stardust": {"name": "Stardust", "rarity": "epic", "desc": "Cosmic stars and blue dust.",
		"swatch": [Color("1b1440"), Color("6f8bff"), Color("c9b8ff")],
		"shape": "star", "colors": [Color("e9e2ff"), Color("a58bff"), Color("4f6bff")], "additive": false,
		"amount": 28, "lifetime": 0.9, "size": 0.22, "velocity": 0.4, "gravity": -0.2, "spin": 180.0},
	"trail_petals": {"name": "Petal Drift", "rarity": "rare", "desc": "Cherry-blossom petals scatter behind.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("ff6f9f")],
		"shape": "petal", "colors": [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")], "additive": false,
		"amount": 22, "lifetime": 1.0, "size": 0.22, "velocity": 0.4, "gravity": -0.6, "spin": 220.0},
	"trail_bubbles": {"name": "Bubbles", "rarity": "common", "desc": "A stream of soapy bubbles.",
		"swatch": [Color("e6faff"), Color("9ee6ff"), Color("ff9ec7")],
		"shape": "bubble", "colors": [Color("ffffff"), Color("c8f2ff"), Color("ffc2e0")], "additive": false,
		"amount": 18, "lifetime": 1.0, "size": 0.26, "velocity": 0.25, "gravity": 0.5},
	"trail_lightning": {"name": "Lightning Dash", "rarity": "epic", "desc": "Electric bolts crackle in your wake.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")],
		"shape": "bolt", "colors": [Color("e8fbff"), Color("6fd3ff"), Color("3a5bff")], "additive": false,
		"amount": 16, "lifetime": 0.3, "size": 0.46, "velocity": 0.1, "gravity": 0.0, "flicker": true},
	"trail_rainbow": {"name": "Rainbow Road", "rarity": "legendary", "desc": "A rainbow ribbon of glowing dots.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")],
		"shape": "dot", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 36, "lifetime": 0.8, "size": 0.26, "velocity": 0.05, "gravity": 0.0, "rainbow": true},
	"trail_hearts": {"name": "Love Trail", "rarity": "rare", "desc": "Hearts pop out behind every step.",
		"swatch": [Color("ffd1e1"), Color("ff6f9f"), Color("ff3b6e")],
		"shape": "heart", "colors": [Color("ffc2d8"), Color("ff6f9f"), Color("ff3b6e")], "additive": false,
		"amount": 16, "lifetime": 0.9, "size": 0.22, "velocity": 0.35, "gravity": 0.6},
	"trail_pixels": {"name": "8-Bit Dash", "rarity": "rare", "desc": "Retro pixels pop behind your pieces.",
		"swatch": [Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f")],
		"shape": "square", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 24, "lifetime": 0.6, "size": 0.14, "velocity": 0.4, "gravity": -1.5, "pixels": true},
}


## Starts a trail on `parent` (a moving piece's rig) for `duration` seconds.
static func emit(parent: Node3D, style: String, duration: float) -> void:
	if style == NONE or not STYLES.has(style) or not parent.is_inside_tree():
		return
	var s: Dictionary = STYLES[style]
	var lifetime: float = s.get("lifetime", 0.7)
	var p := FxTextures.particles(s["shape"], s.get("additive", false), s.get("amount", 20), lifetime, s.get("size", 0.15))
	p.local_coords = false
	p.position.y = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = s.get("velocity", 0.3)
	p.gravity = Vector3(0.0, s.get("gravity", 0.0), 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	FxTextures.random_angle(p, s["shape"])
	var spin: float = s.get("spin", 0.0)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.6, 0.85), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(s["colors"])
	if s.get("rainbow", false):
		p.color_initial_ramp = FxTextures.rainbow()
	if s.get("pixels", false):
		var palette := Gradient.new()
		palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		palette.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
		palette.colors = PackedColorArray([Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f")])
		p.color_initial_ramp = palette
		p.angle_min = 0.0
		p.angle_max = 0.0
	if s.get("flicker", false):
		p.randomness = 1.0
	p.emitting = true
	parent.add_child(p)
	var tree := parent.get_tree()
	# Bind the instance id, not the node: the piece (and its trail) may be freed first.
	var id := p.get_instance_id()
	tree.create_timer(maxf(duration, 0.1)).timeout.connect(_stop.bind(id))
	tree.create_timer(maxf(duration, 0.1) + lifetime + 0.2).timeout.connect(_free.bind(id))


static func _stop(id: int) -> void:
	var p := instance_from_id(id) as CPUParticles3D
	if p != null:
		p.emitting = false


static func _free(id: int) -> void:
	var p := instance_from_id(id) as CPUParticles3D
	if p != null:
		p.queue_free()
