class_name CameraRig
extends Node3D
## Tactical camera orbiting the board centre, with clamped yaw/pitch/zoom/pan and smoothing.
##
## Mouse: drag (left on empty board, or right) to orbit, middle-drag to pan, wheel to zoom.
## Touch: one finger on empty board orbits (via emulated mouse), two fingers pinch-zoom and pan.
## Board3D sees input first and consumes it when the pointer grabs a piece.

@export var camera: Camera3D
@export_range(-85.0, -20.0) var pitch_deg := -58.0
@export var min_pitch_deg := -82.0
@export var max_pitch_deg := -32.0
@export var yaw_limit_deg := 30.0          ## Orbit range around the player's own side.
@export var distance := 11.0
@export var min_distance := 6.5
@export var max_distance := 17.0
@export var pan_limit := Vector2(3.0, 2.5)
@export var orbit_sensitivity := 0.25      ## Degrees per pixel.
@export var smoothing := 12.0

var _base_yaw := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _distance := 0.0
var _pan := Vector2.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _target_distance := 0.0
var _target_pan := Vector2.ZERO
var _orbiting := false
var _panning := false
var _touches: Dictionary = {}  # index -> position
var _trauma := 0.0


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D")
	_target_pitch = pitch_deg
	_target_distance = distance
	_pitch = _target_pitch
	_distance = _target_distance
	get_viewport().size_changed.connect(_fit_aspect)
	_fit_aspect()
	_apply(0.0)


## White looks up the board from +Z, black from -Z.
func set_side(side: String) -> void:
	_base_yaw = 0.0 if side == Ranks.WHITE else 180.0
	_target_yaw = 0.0
	_target_pan = Vector2.ZERO
	_yaw = _target_yaw


func reset_view() -> void:
	_target_yaw = 0.0
	_target_pitch = pitch_deg
	_target_distance = distance
	_target_pan = Vector2.ZERO


## Trauma-based shake; stacks up to 1.0 and decays.
func shake(strength := 0.5) -> void:
	_trauma = minf(1.0, _trauma + strength)


func _process(delta: float) -> void:
	_apply(delta)


func _apply(delta: float) -> void:
	var w := 1.0 if delta <= 0.0 else 1.0 - exp(-smoothing * delta)
	_yaw = lerpf(_yaw, _target_yaw, w)
	_pitch = lerpf(_pitch, _target_pitch, w)
	_distance = lerpf(_distance, _target_distance, w)
	_pan = _pan.lerp(_target_pan, w)

	var yaw := deg_to_rad(_base_yaw + _yaw)
	var pivot := Vector3(_pan.x, 0.0, _pan.y).rotated(Vector3.UP, yaw)
	var offset := Vector3(0.0, 0.0, _distance)
	offset = offset.rotated(Vector3.RIGHT, deg_to_rad(_pitch)).rotated(Vector3.UP, yaw)
	camera.position = pivot + offset
	camera.look_at(global_transform * pivot, Vector3.UP)

	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var amount := _trauma * _trauma
	camera.h_offset = randf_range(-1.0, 1.0) * 0.18 * amount
	camera.v_offset = randf_range(-1.0, 1.0) * 0.18 * amount


## Portrait screens (phones) fit the board's width instead of its height.
func _fit_aspect() -> void:
	var size := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH if size.x < size.y else Camera3D.KEEP_HEIGHT


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		return
	if event is InputEventScreenDrag:
		_on_touch_drag(event)
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				_orbiting = event.pressed and _touches.size() < 2
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.1)
	elif event is InputEventMouseMotion:
		if _touches.size() >= 2:
			return
		if _orbiting:
			_target_yaw = clampf(_target_yaw - event.relative.x * orbit_sensitivity, -yaw_limit_deg, yaw_limit_deg)
			_target_pitch = clampf(_target_pitch - event.relative.y * orbit_sensitivity, min_pitch_deg, max_pitch_deg)
		elif _panning:
			_pan_by(event.relative)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / event.factor)
	elif event is InputEventPanGesture:
		_pan_by(-event.delta * 8.0)


func _on_touch_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Vector2 = _touches[event.index]
	_touches[event.index] = event.position
	if _touches.size() != 2:
		return
	_orbiting = false
	var other_index: int = _touches.keys().filter(func(i: int) -> bool: return i != event.index)[0]
	var other: Vector2 = _touches[other_index]
	var before := previous.distance_to(other)
	var after := event.position.distance_to(other)
	if before > 1.0 and after > 1.0:
		_zoom(before / after)
	_pan_by(event.relative * 0.5)


func _zoom(factor: float) -> void:
	_target_distance = clampf(_target_distance * factor, min_distance, max_distance)


func _pan_by(relative: Vector2) -> void:
	var units_per_pixel := _distance * 0.0016
	_target_pan.x = clampf(_target_pan.x - relative.x * units_per_pixel, -pan_limit.x, pan_limit.x)
	_target_pan.y = clampf(_target_pan.y - relative.y * units_per_pixel, -pan_limit.y, pan_limit.y)
