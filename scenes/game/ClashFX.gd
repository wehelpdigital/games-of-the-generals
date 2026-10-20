class_name ClashFX
extends Node3D
## Anime-style clash: a white impact-frame pop, a comic burst star with an ink outline, speed
## lines, star-shaped sparks and a shockwave ring on the board. Overlay pieces ignore depth so the
## hit reads like a comic panel. Meshes, tweens and CPUParticles3D only, so it looks the same on
## WebGL 2, Android and iOS. Frees itself when done.

const LIFETIME := 1.1

static var _star_mesh: ArrayMesh
static var _burst_fill: ArrayMesh
static var _burst_ink: ArrayMesh
static var _disc: ArrayMesh


static func burst(parent: Node3D, at: Vector3, color: Color, strength := 1.0) -> void:
	var fx := ClashFX.new()
	parent.add_child(fx)
	fx.position = at
	fx._play(color, strength)


func _play(color: Color, strength: float) -> void:
	_build_meshes()
	_impact_pop(strength)
	_comic_burst(color, strength)
	_speed_lines(strength)
	add_child(_sparks(color, strength))
	_shockwave(color, strength)
	_flash(color, strength)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


## A white disc that blinks out almost immediately: the "impact frame".
func _impact_pop(strength: float) -> void:
	var pop := _overlay(_disc, Color(1, 1, 1, 0.95), 9)
	pop.scale = Vector3.ONE * 0.3
	var t := create_tween().set_parallel(true)
	t.tween_property(pop, "scale", Vector3.ONE * 1.5 * strength, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(pop.material_override, "albedo_color:a", 0.0, 0.16).set_delay(0.04)


## Spiky comic "BAM" star: pops in with overshoot, holds, then shrinks away.
func _comic_burst(color: Color, strength: float) -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 0.15
	add_child(holder)
	var ink := _overlay(_burst_ink, Color(CosmeticLibrary.INK, 1.0), 5, holder)
	var fill := _overlay(_burst_fill, Color("ffe45c").lerp(color, 0.3), 6, holder)
	var core := _overlay(_burst_fill, Color(1, 1, 1, 1), 7, holder)
	core.scale = Vector3.ONE * 0.5
	core.rotation.z = 0.2
	var size := 0.85 * strength
	var t := create_tween()
	t.tween_property(holder, "scale", Vector3.ONE * size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.14)
	t.tween_property(holder, "scale", Vector3.ONE * size * 0.2, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for part: MeshInstance3D in [ink, fill, core]:
		t.parallel().tween_property(part.material_override, "albedo_color:a", 0.0, 0.2)


func _speed_lines(strength: float) -> void:
	var lines := _overlay(InsigniaFactory.speed_lines_mesh(16, 0.5, 1.3, 0.05), Color(1, 1, 1, 0.95), 8)
	lines.scale = Vector3.ONE * 0.6 * strength
	var t := create_tween().set_parallel(true)
	t.tween_property(lines, "scale", Vector3.ONE * 1.35 * strength, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(lines.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.08)


func _sparks(color: Color, strength: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = int(18 * strength) + 6
	p.lifetime = 0.75
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var star := _star_mesh.duplicate() as ArrayMesh
	star.surface_set_material(0, m)
	p.mesh = star
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.2 * strength
	p.initial_velocity_max = 4.2 * strength
	p.gravity = Vector3(0.0, -8.0, 0.0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.13
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var palette := Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	palette.offsets = PackedFloat32Array([0.0, 0.4, 0.7])
	palette.colors = PackedColorArray([Color("ffe066"), Color.WHITE, color.lightened(0.2)])
	p.color_initial_ramp = palette
	p.emitting = true
	return p


func _shockwave(color: Color, strength: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.5
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color.lightened(0.35)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(0.3, 0.05, 0.3)
	ring.position.y = -0.4
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(1.9, 0.05, 1.9) * strength, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 0.45)


func _flash(color: Color, strength: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color.lightened(0.3)
	light.light_energy = 2.5 * strength
	light.omni_range = 3.0
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Camera-facing, depth-test-free flat mesh with its own fadeable material.
func _overlay(mesh: Mesh, color: Color, priority: int, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = priority
	m.albedo_color = color
	instance.material_override = m
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _build_meshes() -> void:
	if _disc != null:
		return
	_disc = InsigniaFactory.flat_mesh(InsigniaFactory.outline("disc"))
	_star_mesh = InsigniaFactory.flat_mesh(InsigniaFactory.outline("star"))
	var burst := InsigniaFactory.outline("burst")
	_burst_fill = InsigniaFactory.flat_mesh(burst)
	_burst_ink = InsigniaFactory.flat_mesh(InsigniaFactory.offset(burst, 0.06))
