extends SmokeTestBase
## Offline practice match driven through pointer input (no server needed).
##   godot --headless --path . res://tests/PracticeSmokeTest.tscn


func _ready() -> void:
	await boot()
	check(board.pieces.size() == 42, "attract board shows both armies")

	GameSession.start_practice()
	await frames(5)
	check(board.mode == Board3D.Mode.SETUP, "practice starts in setup mode")
	check(board.get_setup_placements().size() == 21, "21-piece formation dealt")

	# Swap two pieces by tapping one, then the other.
	var placements := board.get_setup_placements()
	var a := Vector2i(placements[0]["x"], placements[0]["y"])
	var b := Vector2i(placements[1]["x"], placements[1]["y"])
	var rank_a: String = placements[0]["rank"]
	await tap_move(a, b)
	await wait_until(func() -> bool: return board.piece_at(b) != null and board.piece_at(b).rank == rank_a)
	check(board.piece_at(b).rank == rank_a, "setup tap swaps two pieces")

	GameSession.submit_setup(board.get_setup_placements())
	await wait_until(func() -> bool: return GameSession.status() == "active" and not board._busy)
	check(GameSession.status() == "active", "match becomes active after Ready")
	check(board.pieces.size() == 42, "42 pieces on the board")
	check(board.mode == Board3D.Mode.PLAY and board.can_act, "white may move first")

	var hidden := board.pieces.values().filter(func(p: Piece3D) -> bool: return p.side == Ranks.BLACK and p.rank == "")
	check(hidden.size() == 21, "enemy ranks are hidden (fog of war)")

	var start_pieces := board.pieces.size()
	for turn in 24:
		var ready := await wait_until(func() -> bool: return GameSession.is_my_turn() and board._can_interact(), 25.0)
		if not ready:
			check(GameSession.status() == "finished", "turn %d: board ready for input" % turn)
			break
		var move := find_legal_move(turn >= 2)
		var before := GameSession.version
		if turn % 2 == 0:
			await tap_move(move["from"], move["to"])
		else:
			await drag_move(move["from"], move["to"])
		var moved := await wait_until(func() -> bool: return GameSession.version > before)
		check(moved, "turn %d: %s %s -> %s accepted" % [turn, "tap" if turn % 2 == 0 else "drag", move["from"], move["to"]])
		if GameSession.status() == "finished":
			break

	await wait_until(func() -> bool: return not board._busy, 5.0)
	check(board.pieces.size() < start_pieces, "clashes eliminated pieces (%d left)" % board.pieces.size())
	var on_board := 0
	for child in board.get_node("Pieces").get_children():
		if not child.is_queued_for_deletion():
			on_board += 1
	check(on_board == board.pieces.size(), "scene nodes match board state")

	GameSession.resign()
	await wait_until(func() -> bool: return GameSession.status() == "finished", 3.0)
	check(GameSession.status() == "finished", "resigning ends the practice match")
	await wait_until(func() -> bool: return not board._busy, 5.0)
	var revealed := board.pieces.values().filter(func(p: Piece3D) -> bool: return p.rank != "")
	check(revealed.size() == board.pieces.size(), "all ranks revealed after the match")
	finish()
