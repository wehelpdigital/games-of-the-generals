class_name KillFX
extends Node3D
## Kill effects: what plays where a piece is eliminated, in the style of the side that won the
## clash. "classic" is the comic burst (ClashFX). Every effect is built from FxTextures sprites,
## simple meshes, CPUParticles3D and tweens (WebGL 2 safe), and frees itself when done.

const LIFETIME := 1.6

const STYLES := {
	"classic": {"name": "Comic Burst", "rarity": "common", "desc": "The classic POW! burst.",
		"swatch": [Color("ffe066"), Color("ffffff"), Color("1d1736")]},
	"kill_fire_explosion": {"name": "Fire Explosion", "rarity": "rare", "desc": "A fireball and a puff of smoke.",
		"swatch": [Color("fff3a8"), Color("ff7a1a"), Color("e8341c"), Color("4a3a3a")]},
	"kill_ice_shatter": {"name": "Ice Shatter", "rarity": "rare", "desc": "The loser freezes and shatters into shards.",
		"swatch": [Color("ffffff"), Color("9ee6ff"), Color("3aa7e6")]},
	"kill_pixel_burst": {"name": "8-Bit Burst", "rarity": "common", "desc": "Retro pixels explode everywhere.",
		"swatch": [Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f")]},
	"kill_confetti": {"name": "Party Confetti", "rarity": "common", "desc": "Celebrate with a confetti cannon.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("b05cff")]},
	"kill_lightning_strike": {"name": "Lightning Strike", "rarity": "epic", "desc": "A bolt from the sky.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")]},
	"kill_black_hole": {"name": "Black Hole", "rarity": "legendary", "desc": "Sucked into a swirling void.",
		"swatch": [Color("0d0a18"), Color("6a3cff"), Color("ff5cd6")]},
	"kill_sakura_burst": {"name": "Sakura Storm", "rarity": "epic", "desc": "A whirl of cherry-blossom petals.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("ff6f9f")]},
	"kill_ghost": {"name": "Spooky Ghost", "rarity": "rare", "desc": "The fallen piece floats away as a ghost.",
		"swatch": [Color("ffffff"), Color("b8c6ff"), Color("6a5acd")]},
	"kill_toxic_splat": {"name": "Toxic Splat", "rarity": "rare", "desc": "Splash of bubbling green goo.",
		"swatch": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")]},
	"kill_star_shower": {"name": "Star Shower", "rarity": "epic", "desc": "A fountain of golden stars.",
		"swatch": [Color("fff1b0"), Color("ffc93c"), Color("ff9f1c")]},
}

var _strength := 1.0


## Plays `style` at board-local `at` under `parent`. `color` tints the classic burst.
static func play(parent: Node3D, at: Vector3, style: String, color := Color(1.0, 0.7, 0.25), strength := 1.0) -> void:
	if style == "classic" or not STYLES.has(style):
		ClashFX.burst(parent, at, color, strength)
		return
	var fx := KillFX.new()
	parent.add_child(fx)
	fx.position = at
	fx._strength = strength
	match style:
		"kill_fire_explosion":
			fx._fire()
		"kill_ice_shatter":
			fx._ice()
		"kill_pixel_burst":
			fx._pixels()
		"kill_confetti":
			fx._confetti()
		"kill_lightning_strike":
			fx._lightning()
		"kill_black_hole":
			fx._black_hole()
		"kill_sakura_burst":
			fx._sakura()
		"kill_ghost":
			fx._ghost()
		"kill_toxic_splat":
			fx._toxic()
		"kill_star_shower":
			fx._stars()
	fx.get_tree().create_timer(LIFETIME).timeout.connect(fx.queue_free)


# --- Styles -----------------------------------------------------------------------------------

func _fire() -> void:
	var ball := _sphere(Color("ff5a1a"), 0.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE * 2.2 * _strength, 0.35).from(Vector3.ONE * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ball.material_override, "albedo_color:a", 0.0, 0.45).set_delay(0.08)
	var core := _sphere(Color("ffc23a"), 0.2)
	t.tween_property(core, "scale", Vector3.ONE * 1.6, 0.25).from(Vector3.ONE * 0.2)
	t.tween_property(core.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.05)
	_burst("flame", false, 26, 0.7, 0.34, [Color("ffe14d"), Color("ff8a1f"), Color("e8341c")], 2.5, 4.5, Vector3(0, 2.0, 0))
	# Smoke fades in, so it rises out of the fireball instead of sitting in front of it.
	var smoke := _burst("puff", false, 10, 1.3, 0.45, [Color("6a5a5a", 0.0), Color("6a5a5a", 0.8), Color("4a3a3a", 0.5), Color("2a2222", 0.0)], 0.6, 1.4, Vector3(0, 1.0, 0))
	smoke.position.y = 0.2
	_flash(Color("ff9a3a"), 2.5)
	_ground_ring(Color("ff6a1a"), 2.4)


func _ice() -> void:
	var block := _sphere(Color("bfefff"), 0.32, false)
	var t := create_tween()
	t.tween_property(block, "scale", Vector3.ONE * 1.2, 0.12).from(Vector3.ONE * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.08)
	t.tween_property(block, "scale", Vector3.ONE * 0.01, 0.06)
	var shards := _burst("shard", false, 24, 1.1, 0.24, [Color("ffffff"), Color("c8f2ff"), Color("6fc3ff")], 2.0, 4.5, Vector3(0, -9.0, 0), 0.18)
	shards.angular_velocity_min = -540.0
	shards.angular_velocity_max = 540.0
	_burst("snowflake", true, 10, 1.0, 0.16, [Color("ffffff"), Color("aee9ff"), Color("6fc3ff")], 0.8, 1.8, Vector3(0, -0.5, 0), 0.18)
	_flash(Color("aee9ff"), 1.5)
	_ground_ring(Color("5fc8ff"), 2.8)


func _pixels() -> void:
	var p := _burst("square", false, 40, 1.0, 0.16, [Color.WHITE, Color.WHITE, Color.WHITE], 2.5, 5.0, Vector3(0, -8.0, 0), 0.12)
	var palette := Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	palette.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	palette.colors = PackedColorArray([Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f"), Color("ffffff")])
	p.color_initial_ramp = palette
	p.angle_min = 0.0
	p.angle_max = 0.0
	var big := _burst("square", false, 8, 0.6, 0.26, [Color("ffffff"), Color("ffd23f"), Color("ff4d6d")], 1.5, 2.5, Vector3.ZERO, 0.05)
	big.angle_min = 0.0
	big.angle_max = 0.0
	_flash(Color("ffffff"), 3.0)


func _confetti() -> void:
	var p := _burst("square", false, 46, 1.5, 0.14, [Color.WHITE, Color.WHITE, Color.WHITE], 2.5, 5.0, Vector3(0, -4.0, 0), 0.1)
	p.color_initial_ramp = FxTextures.rainbow()
	p.direction = Vector3.UP
	p.spread = 70.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)])
	_burst("sparkle", true, 12, 0.7, 0.2, [Color("ffffff"), Color("fff1b0"), Color("ffc93c")], 1.0, 2.5, Vector3.ZERO, 0.1)
	_flash(Color("fff1b0"), 2.5)


func _lightning() -> void:
	# Two crossed billboard bolts from the sky down to the piece, flickering, then a spark shower.
	for i in 2:
		var bolt := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 5.0)
		bolt.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.albedo_texture = FxTextures.texture("bolt")
		m.albedo_color = Color("dff6ff") if i == 0 else Color("6fb8ff")
		m.render_priority = 3
		bolt.material_override = m
		bolt.position = Vector3(0.0, 2.4, 0.0)
		bolt.scale = Vector3(1.0 + i * 0.4, 1.0, 1.0)
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bolt)
		var t := create_tween()
		for k in 4:
			t.tween_property(m, "albedo_color:a", 0.15, 0.04)
			t.tween_property(m, "albedo_color:a", 1.0, 0.04)
		t.tween_property(m, "albedo_color:a", 0.0, 0.25)
	_burst("sparkle", true, 26, 0.6, 0.2, [Color("ffffff"), Color("aee9ff"), Color("4fa8ff")], 2.5, 5.0, Vector3(0, -6.0, 0), 0.1)
	_flash(Color("cfefff"), 3.0)
	_ground_ring(Color("4fa8ff"), 2.2)


func _black_hole() -> void:
	var hole := _sphere(Color("0d0a18"), 0.28, false)
	hole.material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.56
	torus.rings = 40
	torus.ring_segments = 8
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.6, 0.6, 2.2, 1.0)
	ring.material_override = rm
	ring.rotation.x = 0.35
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(hole, "scale", Vector3.ONE * 1.6, 0.3).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "scale", Vector3.ONE * 1.8, 0.3).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "rotation:y", TAU * 2.0, 1.2)
	t.chain().tween_property(hole, "scale", Vector3.ONE * 0.01, 0.25).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ring, "scale", Vector3.ONE * 0.01, 0.25).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rm, "albedo_color:a", 0.0, 0.25).set_delay(0.6)
	# Debris spiralling inward.
	var suck := FxTextures.particles("star", true, 30, 0.8, 0.14)
	suck.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	suck.emission_sphere_radius = 1.4
	suck.initial_velocity_min = 0.0
	suck.initial_velocity_max = 0.0
	suck.radial_accel_min = -6.0
	suck.radial_accel_max = -4.0
	suck.tangential_accel_min = 3.0
	suck.tangential_accel_max = 5.0
	suck.gravity = Vector3.ZERO
	suck.color_ramp = FxTextures.gradient([Color("ffffff"), Color("ff5cd6"), Color("6a3cff")])
	suck.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.1)])
	suck.lifetime = 0.8
	suck.one_shot = false
	suck.emitting = true
	add_child(suck)
	get_tree().create_timer(0.7).timeout.connect(_stop_emitting.bind(suck.get_instance_id()))
	_flash(Color("8a5cff"), 3.0)


func _sakura() -> void:
	var p := _burst("petal", false, 34, 1.5, 0.22, [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")], 1.5, 3.5, Vector3(0, -1.2, 0), 0.15)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.tangential_accel_min = 2.0
	p.tangential_accel_max = 4.0
	_burst("sparkle", true, 10, 0.8, 0.16, [Color("ffffff"), Color("ffd6e6"), Color("ff9ec7")], 0.8, 1.6, Vector3.ZERO, 0.1)
	_flash(Color("ffb3d1"), 2.0)
	_ground_ring(Color("ff9ec7"), 2.2)


func _ghost() -> void:
	var ghost := MeshInstance3D.new()
	ghost.mesh = FxTextures.quad(0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = FxTextures.texture("ghost")
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	m.render_priority = 3
	ghost.material_override = m
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	var t := create_tween().set_parallel(true)
	t.tween_property(m, "albedo_color:a", 0.92, 0.2)
	t.tween_property(ghost, "position:y", 1.5, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 0.4).set_delay(1.0)
	var wobble := create_tween().set_loops(3)
	wobble.tween_property(ghost, "position:x", 0.18, 0.22).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(ghost, "position:x", -0.18, 0.22).set_trans(Tween.TRANS_SINE)
	var wisps := _burst("dot", true, 16, 1.0, 0.14, [Color("e6ecff"), Color("b8c6ff"), Color("6a5acd")], 0.3, 0.9, Vector3(0, 0.8, 0), 0.25)
	wisps.explosiveness = 0.4
	_flash(Color("b8c6ff"), 1.5)


func _toxic() -> void:
	var splash := _burst("dot", false, 30, 0.9, 0.22, [Color("eaff9a"), Color("8be03a"), Color("3a8a1f")], 2.0, 3.8, Vector3(0, -9.0, 0), 0.12)
	splash.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.7, 0.8), Vector2(1.0, 0.2)])
	_burst("bubble", true, 12, 1.4, 0.2, [Color("eaff9a"), Color("9cff3a"), Color("4fc41a")], 0.3, 0.9, Vector3(0, 0.6, 0), 0.3)
	var puddle := _ground_ring(Color("7ddc3a"), 2.0, "puff", false)
	puddle.material_override.albedo_color = Color("6fc42e", 0.9)
	_flash(Color("b6ff3a"), 2.5)


func _stars() -> void:
	var p := _burst("star", false, 30, 1.3, 0.28, [Color("fff1b0"), Color("ffd24a"), Color("ff9f1c")], 2.5, 4.5, Vector3(0, -6.0, 0), 0.1)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	_burst("sparkle", true, 12, 0.6, 0.3, [Color("ffffff"), Color("fff1b0"), Color("ffc93c")], 0.5, 1.5, Vector3.ZERO, 0.05)
	_flash(Color("ffe066"), 3.5)
	_ground_ring(Color("ffc93c"), 2.4)


# --- Building blocks --------------------------------------------------------------------------

## One-shot omnidirectional burst.
func _burst(shape: String, additive: bool, amount: int, lifetime: float, size: float, colors: Array,
		speed_min: float, speed_max: float, gravity: Vector3, radius := 0.1) -> CPUParticles3D:
	var p := FxTextures.particles(shape, additive, int(amount * clampf(_strength, 0.6, 1.4)), lifetime, size)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed_min * _strength
	p.initial_velocity_max = speed_max * _strength
	p.gravity = gravity
	FxTextures.random_angle(p, shape)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.7, 0.8), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(colors)
	p.emitting = true
	add_child(p)
	return p


func _sphere(color: Color, radius: float, glow := true) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	s.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r * (1.6 if glow else 1.0), color.g * (1.6 if glow else 1.0), color.b * (1.6 if glow else 1.0), 0.95)
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	return s


## Expanding decal ring on the board under the effect. Alpha-blended, so it keeps its colour on
## light boards instead of washing out to white.
func _ground_ring(color: Color, reach: float, shape := "glow_ring", additive := false) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	ring.mesh = plane
	ring.material_override = FxTextures.decal_material(shape, Color(color, 0.95), additive)
	ring.position.y = -position.y + 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(reach, 1.0, reach) * _strength, 0.5).from(Vector3(0.2, 1.0, 0.2)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.6).set_delay(0.3)
	return ring


func _flash(color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy * _strength
	light.omni_range = 3.2
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _stop_emitting(id: int) -> void:
	var p := instance_from_id(id) as CPUParticles3D
	if p != null:
		p.emitting = false
