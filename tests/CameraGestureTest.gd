extends SmokeTestBase
## Board camera gestures: wheel zoom toward the cursor, right-drag pan, finger pan with a tap dead
## zone, pinch zoom and twist, double-tap reset, clamps, a Reset view button, and the view
## staying put across match refreshes but resetting at game over.
##   godot --headless --path . res://tests/CameraGestureTest.tscn

var rig: CameraRig


func _ready() -> void:
	await boot()
	var ui: UIRoot = main.get_node("UI")
	rig = (main.get_node("Game3D") as Game3D).rig
	GameSession.start_practice(SalpakanAI.Difficulty.EASY)
	await frames(20)
	check(not rig.attract and not rig.is_moved(), "a new match starts in the standard view")
	var hud: Screen = ui.screen("hud")
	var reset_button: Button = hud.get("_reset_view")
	check(not reset_button.visible, "no Reset view button at first")

	var center := get_viewport().get_visible_rect().size * 0.5
	var distance: float = rig.get("_target_distance")
	await _wheel(MOUSE_BUTTON_WHEEL_UP, center + Vector2(200, 0))
	check(rig.get("_target_distance") < distance, "the wheel zooms in")
	check((rig.get("_target_pan") as Vector2).x > 0.01, "zooming toward a point right of centre shifts the view right")
	await frames(3)
	check(rig.is_moved() and reset_button.visible, "the Reset view button appears once the view moves")

	rig.reset_view()
	await frames(3)
	check(not rig.is_moved() and not reset_button.visible, "Reset view brings the standard shot back")

	# Right-drag pans.
	await _button(MOUSE_BUTTON_RIGHT, true, center, 0)
	for i in 6:
		await _motion(center + Vector2(0, 20 * (i + 1)), Vector2(0, 20), 0)
	await _button(MOUSE_BUTTON_RIGHT, false, center + Vector2(0, 120), 0)
	check((rig.get("_target_pan") as Vector2).length() > 0.2, "right-drag pans the board")
	rig.reset_view()

	# A finger (emulated mouse) on empty board: a tiny wiggle is a tap, a real drag pans.
	var empty := center + Vector2(0, -get_viewport().get_visible_rect().size.y * 0.42)
	await _button(MOUSE_BUTTON_LEFT, true, empty, InputEvent.DEVICE_ID_EMULATION)
	await _motion(empty + Vector2(5, 0), Vector2(5, 0), InputEvent.DEVICE_ID_EMULATION)
	check((rig.get("_target_pan") as Vector2).length() < 0.001, "a small finger wiggle doesn't move the camera")
	for i in 6:
		await _motion(empty + Vector2(5 + 25 * (i + 1), 0), Vector2(25, 0), InputEvent.DEVICE_ID_EMULATION)
	await _button(MOUSE_BUTTON_LEFT, false, empty + Vector2(155, 0), InputEvent.DEVICE_ID_EMULATION)
	check((rig.get("_target_pan") as Vector2).length() > 0.2, "a one-finger drag pans")
	check(absf(rig.get("_target_yaw")) < 0.01, "a one-finger drag doesn't orbit")

	# Two fingers: pinch out zooms in, a twist turns (within the limit).
	rig.reset_view()
	distance = rig.get("_target_distance")
	await _touch(0, true, center + Vector2(-60, 0))
	await _touch(1, true, center + Vector2(60, 0))
	for i in 5:
		await _drag(1, center + Vector2(60 + 20 * (i + 1), -8 * (i + 1)), Vector2(20, -8))
	check(rig.get("_target_distance") < distance, "pinching out zooms in")
	check(absf(rig.get("_target_yaw")) > 1.0 and absf(rig.get("_target_yaw")) <= rig.yaw_limit_deg, "a twist turns the board, within the limit")
	await _touch(1, false, center + Vector2(160, -40))
	await _touch(0, false, center + Vector2(-60, 0))

	# Clamps.
	for i in 40:
		await _wheel(MOUSE_BUTTON_WHEEL_UP, center)
	check(rig.get("_target_distance") >= rig.min_distance - 0.001, "zoom stops at the closest distance")
	for i in 60:
		await _wheel(MOUSE_BUTTON_WHEEL_DOWN, center)
	check(rig.get("_target_distance") <= rig.max_distance + 0.001, "zoom stops at the furthest distance")

	# Double-tap on empty board resets.
	await _touch(0, true, empty, true)
	await _touch(0, false, empty)
	check(not rig.is_moved(), "a double tap on empty board resets the view")

	# A refresh of the same match keeps the player's view; the game's end resets it.
	await _wheel(MOUSE_BUTTON_WHEEL_UP, center)
	await GameSession.refresh()
	await frames(3)
	check(rig.is_moved(), "a match refresh keeps the player's zoom")
	GameSession.resign()
	await frames(10)
	check(not rig.is_moved(), "the view resets when the game ends")
	finish()


func _wheel(button: MouseButton, at: Vector2) -> void:
	await _button(button, true, at, 0)
	await _button(button, false, at, 0)


func _button(button: MouseButton, pressed: bool, at: Vector2, device: int, double := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.device = device
	event.double_click = double
	get_viewport().push_input(event, true)
	await frames(1)


func _motion(at: Vector2, relative: Vector2, device: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.device = device
	get_viewport().push_input(event, true)
	await frames(1)


func _touch(index: int, pressed: bool, at: Vector2, double := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = at
	event.double_tap = double
	get_viewport().push_input(event, true)
	await frames(1)


func _drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	get_viewport().push_input(event, true)
	await frames(1)
