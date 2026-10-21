class_name FogOverlay
extends Node3D
## Smoke Screen fog over one half of the board: drifting cartoon smoke puffs and a soft mist sheet.
## Shown while the opponent's smoke hides their army from you (GameSession.has_fog()).

const TINT := Color(0.86, 0.84, 0.95)

var _puffs: CPUParticles3D
var _mist: MeshInstance3D
var _mist_material: StandardMaterial3D
var _active := false
var _fade: Tween


func _ready() -> void:
	_mist_material = StandardMaterial3D.new()
	_mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mist_material.albedo_color = Color(TINT, 0.0)
	_mist_material.render_priority = 3
	var plane := PlaneMesh.new()
	plane.size = Vector2(Ranks.COLS * Board3D.TILE + 0.6, Ranks.ROWS * 0.5 * Board3D.TILE + 0.4)
	_mist = MeshInstance3D.new()
	_mist.mesh = plane
	_mist.material_override = _mist_material
	_mist.position.y = 0.9
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mist)

	_puffs = CPUParticles3D.new()
	_puffs.emitting = false
	_puffs.amount = 70
	_puffs.lifetime = 4.5
	_puffs.preprocess = 4.0
	_puffs.mesh = _puff_quad()
	_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_puffs.emission_box_extents = Vector3(Ranks.COLS * 0.45, 0.15, Ranks.ROWS * 0.22)
	_puffs.direction = Vector3(1, 0.05, 0)
	_puffs.spread = 180.0
	_puffs.gravity = Vector3.ZERO
	_puffs.initial_velocity_min = 0.05
	_puffs.initial_velocity_max = 0.25
	_puffs.angular_velocity_min = -12.0
	_puffs.angular_velocity_max = 12.0
	_puffs.scale_amount_min = 0.9
	_puffs.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.1))
	_puffs.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(TINT, 0.0))
	ramp.add_point(0.2, Color(TINT, 0.85))
	ramp.add_point(0.8, Color(TINT.darkened(0.08), 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(TINT, 0.0))
	_puffs.color_ramp = ramp
	_puffs.position.y = 0.6
	add_child(_puffs)
	visible = false


## Covers `side`'s half of the board (or clears the fog).
func set_fog(active: bool, side := Ranks.BLACK) -> void:
	var z := Board3D.cell_to_local(Vector2i(0, 1 if side == Ranks.WHITE else Ranks.ROWS - 2)).z
	z += 0.5 * Board3D.TILE * (1.0 if side == Ranks.WHITE else -1.0)
	_mist.position.z = z
	_puffs.position.z = z
	if active == _active:
		return
	_active = active
	if _fade:
		_fade.kill()
	if active:
		visible = true
		_puffs.restart()
		_puffs.emitting = true
	else:
		_puffs.emitting = false
	_fade = create_tween()
	_fade.tween_property(_mist_material, "albedo_color:a", 0.42 if active else 0.0, 0.6)
	if not active:
		_fade.tween_interval(_puffs.lifetime)
		_fade.tween_callback(func() -> void: visible = _active)


func is_active() -> bool:
	return _active


func _puff_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = FxTextures.particle_material("puff")
	return quad
