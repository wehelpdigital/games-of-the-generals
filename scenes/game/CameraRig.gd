class_name CameraRig
extends Node3D
## Tactical camera orbiting the board centre, with clamped yaw/pitch/zoom/pan and smoothing.
##
## Mouse: left-drag on empty board orbits, right- or middle-drag pans, the wheel zooms toward the
## cursor, double-click on empty board resets the view.
## Touch: one finger on empty board pans (small movements stay taps), two fingers pinch-zoom, pan
## and twist (limited turn), double-tap empty board resets.
## Board3D sees input first and consumes it when the pointer grabs a piece, so dragging your own
## pieces during setup still moves them.

signal view_moved(moved: bool)  ## The player moved the view away from (or back to) the standard shot.

@export var camera: Camera3D
@export_range(-85.0, -20.0) var pitch_deg := -58.0
@export var min_pitch_deg := -82.0
@export var max_pitch_deg := -32.0
@export var yaw_limit_deg := 30.0          ## Orbit range around the player's own side.
@export var distance := 12.6
@export var min_distance := 6.5
@export var max_distance := 19.0
@export var pan_limit := Vector2(3.0, 2.5)
@export var orbit_sensitivity := 0.25      ## Degrees per pixel.
@export var smoothing := 12.0

const DEAD_ZONE_PX := 12.0  ## A press must travel this far before it moves the camera.
const PORTRAIT_DISTANCE := 1.32  ## How much further back the camera sits on portrait screens.
const PORTRAIT_PITCH := -64.0

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
var _touch_pan := false  # A one-finger (emulated mouse) drag that pans once it passes the dead zone.
var _press_at := Vector2.ZERO
var _drag_live := false
var _moved := false
var _touches: Dictionary = {}  # index -> position
var _trauma := 0.0
var _portrait := false

## Menu backdrop: a slow cinematic orbit that ignores player input.
var attract := false:
	set(value):
		attract = value
		if not value:
			_yaw = wrapf(_yaw, -180.0, 180.0)
			reset_view()


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
	_target_pitch = _home_pitch()
	_target_distance = _home_distance()
	_target_pan = Vector2.ZERO


## Shop preview shots, so each kind of item is seen where it matters: "close" (your pieces up
## close), "toppers" (the spots beside your half), "half" (your half of the board), "sky" (your
## half and the air above it) and "wide" (the whole arena). Ends attract mode; input still works.
func frame(shot: String) -> void:
	attract = false
	match shot:
		"close":
			_target_pitch = -34.0
			_target_distance = 7.6
			_target_pan = Vector2(0.0, 2.7)
		"toppers":
			_target_pitch = -32.0
			_target_distance = 12.5
			_target_pan = Vector2(0.0, 2.4)
		"sky":
			_target_pitch = -30.0
			_target_distance = 14.5
			_target_pan = Vector2(0.0, 0.8)
		"wide":
			_target_pitch = -27.0
			_target_distance = 17.5
			_target_pan = Vector2.ZERO
		_:
			_target_pitch = -50.0
			_target_distance = 12.0
			_target_pan = Vector2(0.0, 1.8)
	# Portrait screens fit the board's width, so step back for the same framing.
	if _portrait:
		_target_distance *= 1.45
		_target_pitch = minf(_target_pitch, -40.0)


## Trauma-based shake; stacks up to 1.0 and decays.
func shake(strength := 0.5) -> void:
	_trauma = minf(1.0, _trauma + strength)


func _process(delta: float) -> void:
	_update_moved()
	if attract:
		_target_yaw += delta * 7.0
		_target_pitch = -40.0
		_target_distance = distance * 1.12 * (PORTRAIT_DISTANCE if _portrait else 1.0)
		_target_pan = Vector2.ZERO
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


## Portrait screens (phones) fit the board's width instead of its height, from further back and
## a little more overhead so the whole board fits between the HUD's top and bottom bars.
func _fit_aspect() -> void:
	var size := get_viewport().get_visible_rect().size
	var was_portrait := _portrait
	_portrait = size.x < size.y
	camera.keep_aspect = Camera3D.KEEP_WIDTH if _portrait else Camera3D.KEEP_HEIGHT
	if _portrait != was_portrait and not attract:
		reset_view()


func _home_distance() -> float:
	return distance * (PORTRAIT_DISTANCE if _portrait else 1.0)


func _home_pitch() -> float:
	return PORTRAIT_PITCH if _portrait else pitch_deg


func _unhandled_input(event: InputEvent) -> void:
	if attract:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if event.double_tap and _touches.size() == 1:
				reset_view()
		else:
			_touches.erase(event.index)
		return
	if event is InputEventScreenDrag:
		_on_touch_drag(event)
		return

	if event is InputEventMouseButton:
		var touch: bool = event.device == InputEvent.DEVICE_ID_EMULATION  # A finger, not a mouse.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_orbiting = event.pressed and _touches.size() < 2 and not touch
				_touch_pan = event.pressed and touch
				if event.pressed and event.double_click and not touch:
					reset_view()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(0.9, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(1.1, event.position)
		if event.pressed:
			_press_at = event.position
			_drag_live = false
	elif event is InputEventMouseMotion:
		if _touches.size() >= 2:
			return
		if not _drag_live and event.position.distance_to(_press_at) < DEAD_ZONE_PX:
			return  # Small movements stay taps (select, move) instead of nudging the camera.
		_drag_live = true
		if _orbiting:
			_target_yaw = clampf(_target_yaw - event.relative.x * orbit_sensitivity, -yaw_limit_deg, yaw_limit_deg)
			_target_pitch = clampf(_target_pitch - event.relative.y * orbit_sensitivity, min_pitch_deg, max_pitch_deg)
		elif _panning or _touch_pan:
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
	_touch_pan = false
	var other_index: int = _touches.keys().filter(func(i: int) -> bool: return i != event.index)[0]
	var other: Vector2 = _touches[other_index]
	var before := previous.distance_to(other)
	var after := event.position.distance_to(other)
	if before > 1.0 and after > 1.0:
		_zoom_at(before / after, (event.position + other) * 0.5)
		# Twist: turning two fingers turns the board a little (clamped like the mouse orbit).
		var turn := rad_to_deg(wrapf((event.position - other).angle() - (previous - other).angle(), -PI, PI))
		_target_yaw = clampf(_target_yaw - turn, -yaw_limit_deg, yaw_limit_deg)
	_pan_by(event.relative * 0.5)


func _zoom(factor: float) -> void:
	_target_distance = clampf(_target_distance * factor, min_distance, max_distance)


## Zooms toward the board point under `screen_pos`, so it stays under the cursor (or fingers).
func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := _target_distance
	_zoom(factor)
	var applied := _target_distance / before
	if is_equal_approx(applied, 1.0):
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return
	var hit := from + dir * (-from.y / dir.y)
	var local := global_transform.affine_inverse() * hit
	var yaw := deg_to_rad(_base_yaw + _yaw)
	var pivot := Vector3(_target_pan.x, 0.0, _target_pan.y).rotated(Vector3.UP, yaw)
	var shift := ((local - pivot) * (1.0 - applied)).rotated(Vector3.UP, -yaw)
	_target_pan.x = clampf(_target_pan.x + shift.x, -pan_limit.x, pan_limit.x)
	_target_pan.y = clampf(_target_pan.y + shift.z, -pan_limit.y, pan_limit.y)


## Whether the view is away from the standard shot (for the HUD's Reset view button).
func is_moved() -> bool:
	return _moved


func _update_moved() -> void:
	var moved := not attract and (absf(_target_yaw) > 2.0 or absf(_target_pitch - _home_pitch()) > 2.0
		or absf(_target_distance - _home_distance()) > 0.3 or _target_pan.length() > 0.2)
	if moved != _moved:
		_moved = moved
		view_moved.emit(moved)


func _pan_by(relative: Vector2) -> void:
	var units_per_pixel := _distance * 0.0016
	_target_pan.x = clampf(_target_pan.x - relative.x * units_per_pixel, -pan_limit.x, pan_limit.x)
	_target_pan.y = clampf(_target_pan.y - relative.y * units_per_pixel, -pan_limit.y, pan_limit.y)
