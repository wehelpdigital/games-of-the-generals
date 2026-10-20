extends Node
## Owns the current match on the client. Online it forwards intents to the API, listens on
## private-game.{id} through ReverbManager (falling back to polling when realtime is unavailable),
## and turns server events into ordered signals for the 3D scene. Offline it runs a practice match
## against a random-move bot using the same MatchView / MoveResult shapes as the server.
##
## Every state change carries a `version`; anything not newer than what we hold is ignored, and a
## gap triggers a full refetch.

signal match_loaded(view: Dictionary)          ## Full (re)load: rebuild the board from view.pieces.
signal move_result(result: Dictionary)         ## A MoveResult to animate (PieceMoved/ClashResolved).
signal move_rejected(piece_id: String, message: String)
signal turn_changed
signal game_over(info: Dictionary)             ## {winner, end_reason, you_won, pieces}
signal status_message(text: String)

enum Kind { NONE, ONLINE, PRACTICE }

const POLL_FAST := 2.5      ## Seconds between polls when realtime is unavailable.
const POLL_SAFETY := 20.0   ## Background resync even when realtime is healthy.
const BOT_DELAY := 0.9

var kind := Kind.NONE
var match_view: Dictionary = {}
var version := 0

var _channel := ""
var _realtime_ok := false
var _poll_timer: Timer
var _busy := false
var _finished_emitted := false
var _practice: Dictionary = {}  # Full-information state for offline practice.


func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)
	ReverbManager.event_received.connect(_on_realtime_event)
	ReverbManager.subscribed.connect(_on_subscribed)
	ReverbManager.subscription_failed.connect(_on_subscription_failed)
	ReverbManager.disconnected.connect(_on_realtime_lost)
	ApiManager.auth_changed.connect(_on_auth_changed)


func _on_auth_changed(logged_in: bool) -> void:
	if not logged_in and kind == Kind.ONLINE:
		leave()


# --- Queries ----------------------------------------------------------------------------------

func match_id() -> int:
	return int(match_view.get("id", 0))


func status() -> String:
	return str(match_view.get("status", ""))


func my_side() -> String:
	return str(match_view.get("your_side", Ranks.WHITE))


func is_my_turn() -> bool:
	return status() == "active" and str(match_view.get("turn", "")) == my_side()


func has_match() -> bool:
	return kind != Kind.NONE


# --- Commands ---------------------------------------------------------------------------------

func find_match() -> void:
	if _busy:
		return
	if not ApiManager.is_logged_in():
		status_message.emit("Log in to play online.")
		return
	leave()
	_busy = true
	status_message.emit("Finding a match...")
	var res := await ApiManager.find_match()
	_busy = false
	if not res.ok:
		status_message.emit(res.error)
		return
	kind = Kind.ONLINE
	_finished_emitted = false
	_load_view(res.data.get("match", {}))
	_start_realtime()


func submit_setup(placements: Array) -> void:
	if kind == Kind.PRACTICE:
		if status() == "setup":
			_practice_start(placements)
		return
	if kind != Kind.ONLINE or _busy:
		return
	if status() != "setup":
		status_message.emit("Waiting for an opponent to join first.")
		return
	_busy = true
	status_message.emit("Submitting formation...")
	var res := await ApiManager.submit_setup(match_id(), placements)
	_busy = false
	if not res.ok:
		status_message.emit(res.error)
		return
	_adopt_view(res.data.get("match", {}), true)
	_announce_status()


func request_move(piece_id: String, from: Vector2i, to: Vector2i) -> void:
	if kind == Kind.PRACTICE:
		_practice_player_move(piece_id, from, to)
		return
	if kind != Kind.ONLINE:
		move_rejected.emit(piece_id, "No active match.")
		return
	var res := await ApiManager.send_move(match_id(), from, to)
	if not res.ok:
		move_rejected.emit(piece_id, res.error)
		status_message.emit(res.error)
		refresh()
		return
	_accept_result(res.data.get("result", {}))
	_adopt_view(res.data.get("match", {}))


func resign() -> void:
	if kind == Kind.PRACTICE:
		_practice_finish(Ranks.opponent(my_side()), "resignation")
		return
	if kind != Kind.ONLINE:
		return
	var res := await ApiManager.resign(match_id())
	if res.ok:
		_adopt_view(res.data.get("match", {}), true)
		_announce_status()
	else:
		status_message.emit(res.error)


func refresh() -> void:
	if kind != Kind.ONLINE or match_id() == 0:
		return
	var res := await ApiManager.get_match(match_id())
	if res.ok:
		_adopt_view(res.data.get("match", {}))


func leave() -> void:
	if _channel != "":
		ReverbManager.unsubscribe(_channel)
	_channel = ""
	_poll_timer.stop()
	kind = Kind.NONE
	match_view = {}
	version = 0
	_practice = {}
	_finished_emitted = false


# --- Online state handling --------------------------------------------------------------------

func _load_view(view: Dictionary) -> void:
	match_view = view
	version = int(view.get("version", 0))
	match_loaded.emit(view)
	turn_changed.emit()
	_announce_status()
	if status() == "finished":
		_emit_finished_from_view(view)


## Adopts a MatchView from an HTTP response or poll. If exactly one move is missing and it is the
## view's last_move, animate it; otherwise rebuild the board.
func _adopt_view(view: Dictionary, force_reload := false) -> void:
	if view.is_empty():
		return
	var v := int(view.get("version", 0))
	if v < version:
		return
	if v == version and not force_reload:
		match_view = view
		return

	var previous_status := status()
	var last_move: Variant = view.get("last_move")
	var can_animate: bool = not force_reload and previous_status == "active" \
		and last_move is Dictionary and int(last_move.get("version", -1)) == version + 1
	if can_animate:
		_accept_result(last_move)
		match_view = view
		version = v
		turn_changed.emit()
		if status() != previous_status:
			_announce_status()
		if status() == "finished":
			_emit_finished_from_view(view)
	else:
		_load_view(view)


func _accept_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var v := int(result.get("version", 0))
	if v <= version:
		return
	if v > version + 1:
		refresh()
		return
	version = v
	match_view["turn"] = result.get("turn")
	match_view["move_number"] = result.get("move_number", match_view.get("move_number", 0))
	match_view["last_move"] = result
	move_result.emit(result)
	turn_changed.emit()
	_announce_status()


func _on_realtime_event(channel: String, event: String, data: Dictionary) -> void:
	if channel != _channel:
		return
	var v := int(data.get("version", 0))
	match event:
		"PieceMoved", "ClashResolved":
			_accept_result(data)
		"GameOver":
			if v <= version:
				return
			if v > version + 1:
				refresh()
				return
			version = v
			match_view["status"] = "finished"
			match_view["winner"] = data.get("winner")
			match_view["end_reason"] = data.get("end_reason")
			match_view["turn"] = null
			_emit_finished(data)
		_:
			# PlayerJoined, SetupReady, GameStarted, MatchCancelled: fetch our own fog-of-war view.
			if v > version:
				refresh()


func _emit_finished_from_view(view: Dictionary) -> void:
	_emit_finished({"winner": view.get("winner"), "end_reason": view.get("end_reason"), "pieces": view.get("pieces", [])})


func _emit_finished(data: Dictionary) -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	_poll_timer.stop()
	var winner: Variant = data.get("winner")
	var info := {
		"winner": winner,
		"end_reason": data.get("end_reason"),
		"you_won": winner == my_side(),
		"pieces": data.get("pieces", []),
		"rating": data.get("rating", {}),
	}
	game_over.emit(info)
	_announce_status()


# --- Realtime / polling -----------------------------------------------------------------------

func _start_realtime() -> void:
	_channel = "private-game.%d" % match_id()
	_realtime_ok = ReverbManager.is_subscribed(_channel)
	_restart_poll()
	if not ReverbManager.is_connected_to_server():
		var res := await ApiManager.realtime_config()
		if not res.ok or res.data.get("key") == null:
			status_message.emit("Realtime unavailable; syncing by polling.")
			return
		ReverbManager.connect_to_server(res.data)
	ReverbManager.subscribe(_channel)


func _on_subscribed(channel: String) -> void:
	if channel != _channel:
		return
	_realtime_ok = true
	_restart_poll()
	refresh()  # Catch anything that happened before the subscription landed.


func _on_subscription_failed(channel: String, message: String) -> void:
	if channel == _channel:
		push_warning("Realtime subscription failed: %s" % message)
		_on_realtime_lost()


func _on_realtime_lost() -> void:
	_realtime_ok = false
	_restart_poll()


func _restart_poll() -> void:
	if kind != Kind.ONLINE or status() in ["finished", "cancelled"]:
		_poll_timer.stop()
		return
	_poll_timer.start(POLL_SAFETY if _realtime_ok else POLL_FAST)


func _poll() -> void:
	if kind != Kind.ONLINE or status() in ["finished", "cancelled"]:
		_poll_timer.stop()
		return
	refresh()


func _announce_status() -> void:
	var text := ""
	match status():
		"waiting":
			text = "Waiting for an opponent. Arrange your pieces meanwhile."
		"setup":
			var ready: Dictionary = match_view.get("setup_ready", {})
			if ready.get(my_side(), false):
				text = "Formation locked in. Waiting for your opponent."
			else:
				text = "Arrange your formation, then press Ready."
		"active":
			text = "Your move." if is_my_turn() else "Opponent is thinking..."
		"finished":
			var winner: Variant = match_view.get("winner")
			var reason := str(match_view.get("end_reason", "")).replace("_", " ")
			text = ("Victory" if winner == my_side() else "Defeat") + " (%s)." % reason
		"cancelled":
			text = "Match cancelled."
	if text != "":
		status_message.emit(text)


# --- Offline practice (local arbiter + random bot) --------------------------------------------

func start_practice() -> void:
	leave()
	kind = Kind.PRACTICE
	_finished_emitted = false
	_practice = {"pieces": {}, "pending_flag": {}}
	_practice_load({"status": "setup", "turn": null, "version": 1})


func _practice_start(placements: Array) -> void:
	var pieces: Dictionary = {}
	var next_id := 0
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		var formation: Array = placements if side == Ranks.WHITE else Ranks.random_formation(side)
		for p: Dictionary in formation:
			var id := "pc%02d" % next_id
			next_id += 1
			pieces[id] = {"id": id, "side": side, "rank": p["rank"], "x": int(p["x"]), "y": int(p["y"])}
	_practice["pieces"] = pieces
	_practice_load({"status": "active", "turn": Ranks.WHITE, "version": version + 1})


func _practice_load(fields: Dictionary) -> void:
	var finished: bool = fields["status"] == "finished"
	var pieces: Array = []
	for p: Dictionary in _practice["pieces"].values():
		var shown := p.duplicate()
		if p["side"] != Ranks.WHITE and not finished:
			shown["rank"] = null
		pieces.append(shown)
	var view := {
		"id": 0, "status": fields["status"], "your_side": Ranks.WHITE, "turn": fields["turn"],
		"is_your_turn": fields["turn"] == Ranks.WHITE, "move_number": 0, "version": fields["version"],
		"players": {"white": {"username": "You"}, "black": {"username": "Practice Bot"}},
		"setup_ready": {"white": fields["status"] != "setup", "black": true},
		"pieces": pieces, "winner": fields.get("winner"), "end_reason": fields.get("end_reason"),
	}
	_load_view(view)


func _practice_player_move(piece_id: String, from: Vector2i, to: Vector2i) -> void:
	var error := _practice_validate(Ranks.WHITE, piece_id, from, to)
	if error != "":
		move_rejected.emit(piece_id, error)
		status_message.emit(error)
		return
	if _practice_apply(piece_id, to):
		return
	await get_tree().create_timer(BOT_DELAY).timeout
	if kind != Kind.PRACTICE or status() != "active":
		return
	var bot_move := _practice_bot_choice()
	if bot_move.is_empty():
		_practice_finish(Ranks.WHITE, "no_moves")
		return
	_practice_apply(bot_move["id"], bot_move["to"])


func _practice_validate(side: String, piece_id: String, from: Vector2i, to: Vector2i) -> String:
	if status() != "active" or match_view.get("turn") != side:
		return "Not your turn."
	var piece: Dictionary = _practice["pieces"].get(piece_id, {})
	if piece.is_empty() or piece["side"] != side or Vector2i(piece["x"], piece["y"]) != from:
		return "That piece can't move."
	if not Ranks.in_bounds(to) or absi(to.x - from.x) + absi(to.y - from.y) != 1:
		return "Pieces move one square forward, back or sideways."
	var target := _practice_piece_at(to)
	if not target.is_empty() and target["side"] == side:
		return "You can't capture your own piece."
	return ""


## Applies a validated move, emits its MoveResult, and returns true if the game ended.
func _practice_apply(piece_id: String, to: Vector2i) -> bool:
	var pieces: Dictionary = _practice["pieces"]
	var piece: Dictionary = pieces[piece_id]
	var side: String = piece["side"]
	var from := Vector2i(piece["x"], piece["y"])
	var defender := _practice_piece_at(to)
	var result := {
		"match_id": 0, "version": version + 1, "move_number": int(match_view.get("move_number", 0)) + 1,
		"type": "move", "side": side, "piece_id": piece_id,
		"from": {"x": from.x, "y": from.y}, "to": {"x": to.x, "y": to.y},
		"clash": null, "turn": Ranks.opponent(side),
	}
	var winner := ""
	var reason := ""
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
				winner = Ranks.opponent(pieces[id]["side"])
				reason = "flag_captured"
			pieces.erase(id)
		if outcome == "attacker":
			piece["x"] = to.x
			piece["y"] = to.y
		result["type"] = "clash"
		result["clash"] = {"defender_id": defender["id"], "outcome": outcome, "eliminated": eliminated}

	# A pending flag that survived the opponent's reply wins.
	var pending: Dictionary = _practice["pending_flag"]
	if winner == "" and not pending.is_empty() and pending["side"] != side:
		if pieces.has(pending["id"]):
			winner = pending["side"]
			reason = "flag_reached"
		_practice["pending_flag"] = {}
	if winner == "" and pieces.has(piece_id) and piece["rank"] == "FLG" and piece["y"] == Ranks.goal_row(side):
		if _practice_enemy_adjacent(to, side):
			_practice["pending_flag"] = {"id": piece_id, "side": side}
		else:
			winner = side
			reason = "flag_reached"

	if winner != "":
		result["turn"] = null
	_accept_result(result)
	if winner != "":
		_practice_finish(winner, reason)
		return true
	return false


func _practice_finish(winner: String, reason: String) -> void:
	_practice_load({"status": "finished", "turn": null, "version": version + 1, "winner": winner, "end_reason": reason})


func _practice_bot_choice() -> Dictionary:
	var attacks: Array = []
	var moves: Array = []
	for p: Dictionary in _practice["pieces"].values():
		if p["side"] != Ranks.BLACK:
			continue
		for cell in Ranks.neighbors(Vector2i(p["x"], p["y"])):
			var target := _practice_piece_at(cell)
			if target.is_empty():
				moves.append({"id": p["id"], "to": cell})
			elif target["side"] != Ranks.BLACK:
				attacks.append({"id": p["id"], "to": cell})
	if not attacks.is_empty() and (moves.is_empty() or randf() < 0.45):
		return attacks.pick_random()
	return moves.pick_random() if not moves.is_empty() else {}


func _practice_piece_at(cell: Vector2i) -> Dictionary:
	for p: Dictionary in _practice["pieces"].values():
		if p["x"] == cell.x and p["y"] == cell.y:
			return p
	return {}


func _practice_enemy_adjacent(cell: Vector2i, side: String) -> bool:
	for n in Ranks.neighbors(cell):
		var p := _practice_piece_at(n)
		if not p.is_empty() and p["side"] != side:
			return true
	return false
