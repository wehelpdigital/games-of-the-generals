class_name SmokeTestBase
extends Node
## Helpers for headless smoke tests: boots Main.tscn and drives the board with simulated pointer
## events, so raycast picking, tweens and the session are exercised exactly as a player would.

var main: Node
var board: Board3D
var failures := 0


func boot() -> void:
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	board = (main.get_node("Game3D") as Game3D).board
	await frames(10)


func finish() -> void:
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func check(condition: bool, what: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + what)
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func wait_until(condition: Callable, timeout := 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func screen_of(cell: Vector2i, height := 0.0) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(board.to_global(Board3D.cell_to_local(cell) + Vector3(0.0, height, 0.0)))


func pointer(screen_pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = screen_pos
	event.global_position = screen_pos
	get_viewport().push_input(event, true)
	await frames(2)


func pointer_motion(screen_pos: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = screen_pos
	event.global_position = screen_pos
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)
	await frames(1)


## Tap the piece's plaque, then tap the destination tile.
func tap_move(from: Vector2i, to: Vector2i) -> void:
	var start := screen_of(from, 0.4)
	await pointer(start, true)
	await pointer(start, false)
	var target := screen_of(to)
	await pointer(target, true)
	await pointer(target, false)


## Press on the piece, drag across the board in small steps, release over the destination.
func drag_move(from: Vector2i, to: Vector2i) -> void:
	var start := screen_of(from, 0.4)
	var end := screen_of(to, Piece3D.LIFT_HEIGHT)
	await pointer(start, true)
	var previous := start
	for i in range(1, 11):
		var point := start.lerp(end, i / 10.0)
		await pointer_motion(point, point - previous)
		previous = point
	await pointer(end, false)


## A legal move for one of my pieces: an attack if one exists and `aggressive`, else an advance
## toward the enemy, else any quiet move. Returns {from, to} or {}.
func find_legal_move(aggressive := false) -> Dictionary:
	var forward := 1 if board.my_side == Ranks.WHITE else -1
	# In practice the arbiter knows what powerups forbid (frozen pieces, roadblocks, a ceasefire).
	var allowed := {}
	var arbiter: Variant = GameSession.get("_arbiter")
	if arbiter is LocalArbiter:
		for legal: Dictionary in (arbiter as LocalArbiter).legal_moves(board.my_side):
			allowed[[legal["from"], legal["to"]]] = true
	# Squares under the powerup hand can't be tapped (a player would pan the camera first).
	var covered: Array[Rect2] = []
	for node in get_tree().root.find_children("*", "VBoxContainer", true, false):
		if node.has_method("_activate") and (node as Control).is_visible_in_tree():
			covered.append((node as Control).get_global_rect().grow(12.0))
	var attacks: Array = []
	var advances: Array = []
	var quiet: Array = []
	for piece: Piece3D in board.pieces.values():
		if piece.side != board.my_side or piece.rank == "FLG":
			continue
		for cell in Ranks.neighbors(piece.cell):
			if not allowed.is_empty() and not allowed.has([piece.cell, cell]):
				continue
			if covered.any(func(r: Rect2) -> bool: return r.has_point(screen_of(piece.cell, 0.4)) or r.has_point(screen_of(cell)) 					or r.has_point(screen_of(cell, Piece3D.LIFT_HEIGHT))):
				continue
			var occupant := board.piece_at(cell)
			var move := {"from": piece.cell, "to": cell}
			if occupant != null and occupant.side != piece.side:
				attacks.append(move)
			elif occupant == null:
				(advances if cell.y - piece.cell.y == forward else quiet).append(move)
	if aggressive and not attacks.is_empty():
		return attacks.pick_random()
	if aggressive and not advances.is_empty():
		return advances.pick_random()
	for options: Array in [quiet, advances, attacks]:
		if not options.is_empty():
			return options.pick_random()
	return {}
