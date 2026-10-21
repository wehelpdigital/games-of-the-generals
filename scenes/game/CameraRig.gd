class_name CameraRig
extends Node3D
## Tactical camera orbiting the board centre, with clamped yaw/pitch/zoom/pan and smoothing.
##
## Mouse: left-drag on empty board orbits, right- or middle-drag pans, the wheel zooms toward the
## cursor, double-click on empty board resets the view.
## Touch: the board sticks to the fingers. One finger on empty board pans (small movements stay
## taps), two fingers pinch-zoom, pan and twist all at once (twist within the turn limit), and a
## flick keeps gliding. Double-tap empty board resets.
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
const FLING_FRICTION := 5.5  ## How quickly a flicked board glides to a stop (per second).
const FLING_MIN_SPEED := 0.6  ## Board units per second below which a release doesn't glide.
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
var _press_at := Vector2.ZERO
var _drag_live := false
var _moved := false
var _touches: Dictionary = {}  # index -> current position
var _touch_prev: Dictionary = {}  # index -> position at the last gesture step
var _touch_start: Dictionary = {}  # index -> where the finger went down (dead zone)
var _gesture_live := false  # Fingers are moving the camera (past the dead zone, or two fingers).
var _velocity := Vector2.ZERO  # Pan speed in board units per second, for the glide after a flick.
var _flinging := false

## Returns true while the board holds a piece under the finger (dragging it), so the camera
## leaves that finger alone. Set by Game3D.
var touch_blocked := Callable()
var _trauma := 0.0
var _portrait := false
var _shift := Vector2.ZERO

## Moves the board's picture by a fraction of the screen (x right, y down), e.g. -0.15 to centre
## it in the room left of a side panel. Eased like the rest of the camera.
var screen_shift := Vector2.ZERO

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
	_flinging = false
	_target_yaw = 0.0
	_target_pitch = _home_pitch()
	_target_distance = _home_distance()
	_target_pan = Vector2.ZERO


## Shop preview shots, so each kind of item is seen where it matters: "close" (your pieces up
## close), "toppers" (the spots beside your half), "half" (your half of the board), "sky" (your
## half and the air above it) and "wide" (the whole arena). Ends attract mode; input still works.
func frame(shot: String) -> void:
	attract = false
	_flinging = false
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
	if not attract:
		_step_touch(delta)
		_step_fling(delta)
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
	# The screen shift as a sideways and upward slide of the camera, sized to the view at the pivot.
	_shift = _shift.lerp(screen_shift, w)
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var half := _distance * tan(deg_to_rad(camera.fov) * 0.5)
	var half_w := half * aspect if camera.keep_aspect == Camera3D.KEEP_HEIGHT else half
	var half_h := half if camera.keep_aspect == Camera3D.KEEP_HEIGHT else half / aspect
	camera.h_offset = -_shift.x * 2.0 * half_w + randf_range(-1.0, 1.0) * 0.18 * amount
	camera.v_offset = _shift.y * 2.0 * half_h + randf_range(-1.0, 1.0) * 0.18 * amount


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
		_on_touch(event)
		return
	if event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position
		return

	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # A finger: handled by the touch events above.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_orbiting = event.pressed
				if event.pressed and event.double_click:
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
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if not _drag_live and event.position.distance_to(_press_at) < DEAD_ZONE_PX:
			return  # Small movements stay clicks (select, move) instead of nudging the camera.
		_drag_live = true
		if _orbiting:
			_target_yaw = clampf(_target_yaw - event.relative.x * orbit_sensitivity, -yaw_limit_deg, yaw_limit_deg)
			_target_pitch = clampf(_target_pitch - event.relative.y * orbit_sensitivity, min_pitch_deg, max_pitch_deg)
		elif _panning:
			_pan_by(event.relative)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / event.factor)
	elif event is InputEventPanGesture:
		_pan_by(-event.delta * 8.0)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_touch_prev[event.index] = event.position
		_touch_start[event.index] = event.position
		_flinging = false  # A finger on a gliding board catches it.
		_velocity = Vector2.ZERO
		if _touches.size() >= 2:
			_gesture_live = true  # Two fingers always move the camera.
			_settle()
		elif event.double_tap and not _blocked():
			reset_view()
		return
	_touches.erase(event.index)
	_touch_prev.erase(event.index)
	_touch_start.erase(event.index)
	if _touches.is_empty():
		_flinging = _gesture_live and _velocity.length() > FLING_MIN_SPEED
		_gesture_live = false
	else:
		for index: int in _touches:  # The finger left behind carries on from where it is.
			_touch_prev[index] = _touches[index]


## One gesture step per frame, from every finger's movement since the last step, so pinch, pan
## and twist combine smoothly instead of reacting to each finger's events in turn.
func _step_touch(delta: float) -> void:
	if _touches.is_empty():
		return
	var ids: Array = _touches.keys()
	if _blocked():
		_gesture_live = false
		for index: int in ids:
			_touch_prev[index] = _touches[index]
		return
	if ids.size() == 1:
		var only: int = ids[0]
		if not _gesture_live:
			if (_touches[only] as Vector2).distance_to(_touch_start[only]) < DEAD_ZONE_PX:
				return  # Still a tap.
			_gesture_live = true
			_settle()
			_touch_prev[only] = _touches[only]  # Start from here, so the board doesn't jump.
			return
		_drag_points(_touch_prev[only], _touches[only], 1.0, 0.0, delta)
	else:
		var a0: Vector2 = _touch_prev[ids[0]]
		var b0: Vector2 = _touch_prev[ids[1]]
		var a1: Vector2 = _touches[ids[0]]
		var b1: Vector2 = _touches[ids[1]]
		var zoom := 1.0
		if a0.distance_to(b0) > 1.0 and a1.distance_to(b1) > 1.0:
			zoom = a0.distance_to(b0) / a1.distance_to(b1)
		var turn := rad_to_deg(wrapf((b1 - a1).angle() - (b0 - a0).angle(), -PI, PI))
		_drag_points((a0 + b0) * 0.5, (a1 + b1) * 0.5, zoom, turn, delta)
	for index: int in ids:
		_touch_prev[index] = _touches[index]


## Moves the camera so the board point that was under `from` ends up under `to`, after zooming by
## `zoom` and turning by `turn` degrees. Applied at once (no smoothing): the board follows the
## fingers exactly.
func _drag_points(from: Vector2, to: Vector2, zoom: float, turn: float, delta: float) -> void:
	var anchor: Variant = _ground(from)
	_distance = clampf(_distance * zoom, min_distance, max_distance)
	_yaw = clampf(_yaw - turn, -yaw_limit_deg, yaw_limit_deg)
	_target_distance = _distance
	_target_yaw = _yaw
	_apply(0.0)
	var landed: Variant = _ground(to)
	if anchor == null or landed == null:
		return
	var before := _pan
	_pan = _clamp_pan(_pan + _to_pan((anchor as Vector3) - (landed as Vector3)))
	_target_pan = _pan
	_apply(0.0)
	if delta > 0.0:  # Smoothed speed for the glide after release.
		_velocity = _velocity.lerp((_pan - before) / delta, 0.35)


## A flicked board glides on and slows down.
func _step_fling(delta: float) -> void:
	if not _flinging:
		return
	var before := _pan
	_pan = _clamp_pan(_pan + _velocity * delta)
	_target_pan = _pan
	_velocity *= exp(-FLING_FRICTION * delta)
	if (_pan - before).length() < 0.0005 or _velocity.length() < 0.05:
		_flinging = false


## The board point (on the table plane, in rig space) under a screen position, or null.
func _ground(screen_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return null
	var hit := from + dir * (-from.y / dir.y)
	return global_transform.affine_inverse() * hit


## A board-space shift as a change of the pan offset (which is measured along the view's yaw).
func _to_pan(shift: Vector3) -> Vector2:
	var local := shift.rotated(Vector3.UP, -deg_to_rad(_base_yaw + _yaw))
	return Vector2(local.x, local.z)


func _clamp_pan(pan: Vector2) -> Vector2:
	return Vector2(clampf(pan.x, -pan_limit.x, pan_limit.x), clampf(pan.y, -pan_limit.y, pan_limit.y))


## Catches up with any smoothing still in flight, so touch steps start from what's on screen.
func _settle() -> void:
	_target_yaw = _yaw
	_target_pitch = _pitch
	_target_distance = _distance
	_target_pan = _pan


func _blocked() -> bool:
	return touch_blocked.is_valid() and bool(touch_blocked.call())


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
