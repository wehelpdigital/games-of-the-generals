class_name ClashFX
extends Node3D
## One-shot clash burst: sparks, a dust puff, a shockwave ring and a flash of light. Uses
## CPUParticles3D so it behaves the same on WebGL 2, Android and iOS. Frees itself when done.

const LIFETIME := 1.2


static func burst(parent: Node3D, at: Vector3, color: Color, strength := 1.0) -> void:
	var fx := ClashFX.new()
	parent.add_child(fx)
	fx.position = at
	fx._play(color, strength)


func _play(color: Color, strength: float) -> void:
	add_child(_sparks(color, strength))
	add_child(_dust(strength))
	_shockwave(color, strength)
	_flash(color, strength)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _sparks(color: Color, strength: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = int(40 * strength) + 8
	p.lifetime = 0.6
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _glow_material(color, 4.0)
	p.mesh = mesh
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.0 * strength
	p.initial_velocity_max = 4.5 * strength
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_curve = _fade_curve()
	p.emitting = true
	return p


func _dust(strength: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 0.9
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.28)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	mesh.material = m
	p.mesh = mesh
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1 * strength
	p.gravity = Vector3(0.0, 0.3, 0.0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.8, 0.72, 0.55))
	ramp.set_color(1, Color(0.6, 0.58, 0.55, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	return p


func _shockwave(color: Color, strength: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var m := _glow_material(color, 2.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(0.2, 0.05, 0.2)
	ring.position.y = -0.3
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(1.6, 0.05, 1.6) * strength, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 0.45)


func _flash(color: Color, strength: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0 * strength
	light.omni_range = 3.0
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _soft_dot() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex
