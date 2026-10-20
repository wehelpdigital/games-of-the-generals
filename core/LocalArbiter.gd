class_name LocalArbiter
extends RefCounted
## Full-information referee for offline games: practice against the AI, and AI benchmarks. It
## mirrors the server's rules (docs/API.md in the web repo); online matches never use it.

var pieces: Dictionary = {}  # id -> {id, side, rank, x, y}
var turn := Ranks.WHITE
var move_number := 0
var winner := ""
var end_reason := ""

var _pending_flag: Dictionary = {}  # {id, side} while a flag waits out the reply on the goal row
var _next_id := 0


## Places a formation ([{rank, x, y}]). Ids are handed out in shuffled order so they never follow
## rank order.
func deploy(side: String, formation: Array) -> void:
	var shuffled := formation.duplicate()
	shuffled.shuffle()
	for p: Dictionary in shuffled:
		var id := "p%02d" % _next_id
		_next_id += 1
		pieces[id] = {"id": id, "side": side, "rank": str(p["rank"]), "x": int(p["x"]), "y": int(p["y"])}


func is_over() -> bool:
	return winner != ""


func piece_at(cell: Vector2i) -> Dictionary:
	for p: Dictionary in pieces.values():
		if p["x"] == cell.x and p["y"] == cell.y:
			return p
	return {}


## Everything `side` is allowed to know: its own pieces with ranks, enemy positions without.
func observation(side: String) -> Dictionary:
	var mine: Array = []
	var enemy: Array = []
	for p: Dictionary in pieces.values():
		if p["side"] == side:
			mine.append(p.duplicate())
		else:
			enemy.append({"id": p["id"], "x": p["x"], "y": p["y"]})
	return {"mine": mine, "enemy": enemy}


## [{id, from, to}] for every legal move of `side`.
func legal_moves(side: String) -> Array[Dictionary]:
	var occupied: Dictionary = {}
	for p: Dictionary in pieces.values():
		occupied[Vector2i(p["x"], p["y"])] = p["side"]
	var moves: Array[Dictionary] = []
	for p: Dictionary in pieces.values():
		if p["side"] != side:
			continue
		var from := Vector2i(p["x"], p["y"])
		for to in Ranks.neighbors(from):
			if occupied.get(to, "") != side:
				moves.append({"id": p["id"], "from": from, "to": to})
	return moves


## "" when legal, otherwise the reason it isn't.
func validate(side: String, piece_id: String, from: Vector2i, to: Vector2i) -> String:
	if is_over():
		return "The game is over."
	if turn != side:
		return "Not your turn."
	var piece: Dictionary = pieces.get(piece_id, {})
	if piece.is_empty() or piece["side"] != side or Vector2i(piece["x"], piece["y"]) != from:
		return "That piece can't move."
	if not Ranks.in_bounds(to) or absi(to.x - from.x) + absi(to.y - from.y) != 1:
		return "Pieces move one square forward, back or sideways."
	var target := piece_at(to)
	if not target.is_empty() and target["side"] == side:
		return "You can't capture your own piece."
	return ""


## Applies a validated move and returns its MoveResult (the caller stamps the version).
func apply(piece_id: String, to: Vector2i) -> Dictionary:
	var piece: Dictionary = pieces[piece_id]
	var side: String = piece["side"]
	var from := Vector2i(piece["x"], piece["y"])
	var defender := piece_at(to)
	move_number += 1
	var result := {
		"match_id": 0, "move_number": move_number, "type": "move", "side": side, "piece_id": piece_id,
		"from": {"x": from.x, "y": from.y}, "to": {"x": to.x, "y": to.y}, "clash": null,
	}

	if defender.is_empty():
		piece["x"] = to.x
		piece["y"] = to.y
	else:
		var outcome := Ranks.resolve_clash(piece["rank"], defender["rank"])
		var eliminated: Array = []
		if outcome != "attacker":
			eliminated.append(piece_id)
		if outcome != "defender":
			eliminated.append(defender["id"])
		for id: String in eliminated:
			if pieces[id]["rank"] == "FLG":
				_finish(Ranks.opponent(pieces[id]["side"]), "flag_captured")
			pieces.erase(id)
		if outcome == "attacker":
			piece["x"] = to.x
			piece["y"] = to.y
		result["type"] = "clash"
		result["clash"] = {"defender_id": defender["id"], "outcome": outcome, "eliminated": eliminated}

	# A flag held back on the goal row wins if it survived the opponent's reply.
	if not _pending_flag.is_empty() and _pending_flag["side"] != side:
		if not is_over() and pieces.has(_pending_flag["id"]):
			_finish(_pending_flag["side"], "flag_reached")
		_pending_flag = {}
	if not is_over() and pieces.has(piece_id) and piece["rank"] == "FLG" and piece["y"] == Ranks.goal_row(side):
		if _enemy_adjacent(to, side):
			_pending_flag = {"id": piece_id, "side": side}
		else:
			_finish(side, "flag_reached")

	if not is_over():
		turn = Ranks.opponent(side)
		if legal_moves(turn).is_empty():
			_finish(side, "no_moves")
	result["turn"] = null if is_over() else turn
	return result


func resign(side: String) -> void:
	_finish(Ranks.opponent(side), "resignation")


## Pieces as a MatchView list for `viewer`; enemy ranks are hidden until the game is over.
func view_pieces(viewer: String) -> Array:
	var list: Array = []
	for p: Dictionary in pieces.values():
		var shown := p.duplicate()
		if p["side"] != viewer and not is_over():
			shown["rank"] = null
		list.append(shown)
	return list


func _finish(side: String, reason: String) -> void:
	if winner == "":
		winner = side
		end_reason = reason
		turn = ""


func _enemy_adjacent(cell: Vector2i, side: String) -> bool:
	for n in Ranks.neighbors(cell):
		var p := piece_at(n)
		if not p.is_empty() and p["side"] != side:
			return true
	return false
