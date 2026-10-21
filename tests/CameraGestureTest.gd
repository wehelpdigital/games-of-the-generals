extends SmokeTestBase
## Board camera gestures: wheel zoom toward the cursor, right-drag pan, a finger pan that keeps the
## board under the finger (with a tap dead zone and a glide after a flick), pinch + twist + pan at
## once, piece drags leaving the camera alone, double-tap reset, clamps, a Reset view button, and
## the view staying put across match refreshes but resetting at game over.
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

	# One finger on empty board: a tiny wiggle is a tap; a real drag pans and the board point
	# under the finger stays under it.
	var empty := center + Vector2(0, -get_viewport().get_visible_rect().size.y * 0.30)
	await _touch(0, true, empty)
	await _drag(0, empty + Vector2(5, 0), Vector2(5, 0))
	check((rig.get("_target_pan") as Vector2).length() < 0.001, "a small finger wiggle doesn't move the camera")
	await _drag(0, empty + Vector2(20, 0), Vector2(15, 0))  # Past the dead zone: the pan starts here.
	var grabbed: Vector3 = rig.call("_ground", empty + Vector2(20, 0))
	for i in 4:
		await _drag(0, empty + Vector2(20 + 15 * (i + 1), 6 * (i + 1)), Vector2(15, 6))
	var under: Vector3 = rig.call("_ground", empty + Vector2(80, 24))
	check(grabbed.distance_to(under) < 0.05, "the board stays under the finger while panning (off by %.3f)" % grabbed.distance_to(under))
	check(absf(rig.get("_target_yaw")) < 0.01, "a one-finger drag doesn't orbit")
	# A flick keeps gliding after the finger lifts.
	for i in 3:
		await _drag(0, empty + Vector2(80 + 40 * (i + 1), 24), Vector2(40, 0))
	await _touch(0, false, empty + Vector2(200, 24))
	var released: Vector2 = rig.get("_pan")
	await frames(6)
	check(((rig.get("_pan") as Vector2) - released).length() > 0.01, "a flicked board glides on after release")
	await get_tree().create_timer(2.0).timeout
	check(not rig.get("_flinging"), "the glide comes to a stop")

	# Two fingers at once: pinch, twist and pan together, and the board stays under the fingers.
	rig.reset_view()
	await get_tree().create_timer(0.8).timeout
	distance = rig.get("_target_distance")
	await _touch(0, true, center + Vector2(-60, 0))
	await _touch(1, true, center + Vector2(60, 0))
	var mid: Vector3 = rig.call("_ground", center)
	for i in 5:
		var step := float(i + 1)
		await _drag(0, center + Vector2(-60 - 12 * step, 10 * step + 6 * step), Vector2(-12, 16))
		await _drag(1, center + Vector2(60 + 12 * step, -10 * step + 6 * step), Vector2(12, -4))
	var centroid := center + Vector2(0, 30)
	check(rig.get("_target_distance") < distance, "pinching out zooms in")
	check(absf(rig.get("_target_yaw")) > 1.0 and absf(rig.get("_target_yaw")) <= rig.yaw_limit_deg, "a twist turns the board, within the limit")
	var mid_now: Vector3 = rig.call("_ground", centroid)
	check(mid.distance_to(mid_now) < 0.08, "the point between the fingers stays between them (off by %.3f)" % mid.distance_to(mid_now))
	await _touch(1, false, center + Vector2(120, -20))
	await _touch(0, false, center + Vector2(-120, 80))
	await get_tree().create_timer(0.8).timeout

	# A finger holding a piece doesn't move the camera.
	rig.reset_view()
	await get_tree().create_timer(0.8).timeout
	rig.touch_blocked = func() -> bool: return true
	await _touch(0, true, empty)
	for i in 5:
		await _drag(0, empty + Vector2(30 * (i + 1), 0), Vector2(30, 0))
	await _touch(0, false, empty + Vector2(150, 0))
	check((rig.get("_target_pan") as Vector2).length() < 0.001, "dragging a piece leaves the camera alone")
	rig.touch_blocked = (main.get_node("Game3D") as Game3D).board.is_holding_piece

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
