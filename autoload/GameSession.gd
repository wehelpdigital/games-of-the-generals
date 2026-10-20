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
signal taunt_received(side: String, slug: String)  ## Animate a taunt thrown by `side` (either player).

enum Kind { NONE, ONLINE, PRACTICE }

const POLL_FAST := 2.5      ## Seconds between polls when realtime is unavailable.
const POLL_SAFETY := 20.0   ## Background resync even when realtime is healthy.
const AI_MIN_THINK := 0.7  ## Seconds the practice AI appears to think, at least.
const TAUNT_COOLDOWN := 3.0  ## Seconds between taunts (the server enforces the same).

var kind := Kind.NONE
var practice_level := SalpakanAI.Difficulty.MEDIUM  ## Last AI difficulty, for "Play again".
var ai_loadout: Dictionary = {}  ## The practice AI's random cosmetics, so you see what opponents see.
var _last_taunt_ms := -100000
var match_view: Dictionary = {}
var version := 0

var _channel := ""
var _realtime_ok := false
var _poll_timer: Timer
var _busy := false
var _finished_emitted := false
var _arbiter: LocalArbiter  # Offline practice: full-information referee.
var _ai: SalpakanAI         # Offline practice: the opponent.


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

## Quick match: resume your open match, join the oldest waiting one, or host a new one.
func find_match() -> Dictionary:
	return await _online_request(ApiManager.find_match)


## Host a match that shows up in the lobby. A 409 carries `match_id` of the match you're already in.
func create_match() -> Dictionary:
	return await _online_request(ApiManager.create_match)


func join_match(id: int) -> Dictionary:
	return await _online_request(ApiManager.join_match.bind(id))


## Re-enter a match you're already part of (from the lobby's "Resume").
func open_match(id: int) -> Dictionary:
	return await _online_request(ApiManager.get_match.bind(id))


## Connects to Reverb if the server has it configured. False means "use polling".
func ensure_realtime() -> bool:
	if ReverbManager.is_connected_to_server():
		return true
	var res := await ApiManager.realtime_config()
	if not res.ok or res.data.get("key") == null:
		return false
	ReverbManager.connect_to_server(res.data)
	return true


func _online_request(request_fn: Callable) -> Dictionary:
	if _busy:
		return {"ok": false, "status": 0, "data": {}, "error": "Busy, try again."}
	if not ApiManager.is_logged_in():
		return {"ok": false, "status": 401, "data": {}, "error": "Log in to play online."}
	_busy = true
	var res: Dictionary = await request_fn.call()
	_busy = false
	if res.ok:
		leave()
		kind = Kind.ONLINE
		_load_view(res.data.get("match", {}))
		_start_realtime()
	return res


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
		_practice_resign()
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
	_arbiter = null
	_ai = null
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
		"Taunt":
			# Our own throws were already shown when sent.
			if str(data.get("side", "")) != my_side():
				taunt_received.emit(str(data.get("side", "")), str(data.get("taunt", "")))
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
	_emit_finished({"winner": view.get("winner"), "end_reason": view.get("end_reason"), "pieces": view.get("pieces", []),
		"clashes": view.get("clashes", [])})


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
		"clashes": data.get("clashes", []),
	}
	game_over.emit(info)
	_announce_status()


# --- Realtime / polling -----------------------------------------------------------------------

func _start_realtime() -> void:
	_channel = "private-game.%d" % match_id()
	_realtime_ok = ReverbManager.is_subscribed(_channel)
	_restart_poll()
	if await ensure_realtime():
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


# --- Offline practice against the AI (local arbiter, no server) -------------------------------

## The player is white and moves first; the AI plays black.
func start_practice(level: SalpakanAI.Difficulty = SalpakanAI.Difficulty.MEDIUM) -> void:
	leave()
	kind = Kind.PRACTICE
	practice_level = level
	ai_loadout = Loadout.random_loadout()
	_ai = SalpakanAI.new(Ranks.BLACK, level)
	_arbiter = LocalArbiter.new()
	_practice_load("setup", 1)


func _practice_start(placements: Array) -> void:
	_arbiter.deploy(Ranks.WHITE, placements)
	_arbiter.deploy(Ranks.BLACK, _ai.choose_formation())
	_ai.begin(_arbiter.observation(Ranks.BLACK))
	_practice_load("active", version + 1)


func _practice_load(practice_status: String, new_version: int) -> void:
	var view := {
		"id": 0, "status": practice_status, "your_side": Ranks.WHITE,
		"turn": _arbiter.turn if practice_status == "active" else null,
		"move_number": _arbiter.move_number, "version": new_version,
		"players": {"white": {"username": "You"}, "black": {"username": "AI (%s)" % SalpakanAI.label(_ai.difficulty), "loadout": ai_loadout}},
		"setup_ready": {"white": practice_status != "setup", "black": true},
		"pieces": _arbiter.view_pieces(Ranks.WHITE),
		"winner": _arbiter.winner if _arbiter.is_over() else null,
		"end_reason": _arbiter.end_reason if _arbiter.is_over() else null,
		"clashes": _arbiter.clash_log if _arbiter.is_over() else [],
	}
	_load_view(view)


func _practice_player_move(piece_id: String, from: Vector2i, to: Vector2i) -> void:
	var error := _arbiter.validate(Ranks.WHITE, piece_id, from, to)
	if error != "":
		move_rejected.emit(piece_id, error)
		status_message.emit(error)
		return
	if _practice_play(piece_id, to):
		return

	# The AI thinks in frame-sized slices; pad short searches so its reply doesn't feel instant.
	var ai := _ai
	var started := Time.get_ticks_msec()
	var choice: Dictionary = await ai.choose_move(_arbiter.observation(Ranks.BLACK))
	var remaining := AI_MIN_THINK - (Time.get_ticks_msec() - started) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
	if kind != Kind.PRACTICE or _ai != ai or _arbiter.is_over():
		return  # The player resigned or left while the AI was thinking.
	if choice.is_empty() or _arbiter.validate(Ranks.BLACK, choice["id"], choice["from"], choice["to"]) != "":
		push_warning("AI produced no legal move: %s" % choice)
		_arbiter.resign(Ranks.BLACK)
		_practice_load("finished", version + 1)
		return
	_practice_play(choice["id"], choice["to"])


## Applies a move through the local arbiter, tells the AI, animates it. True if the game ended.
func _practice_play(piece_id: String, to: Vector2i) -> bool:
	var result := _arbiter.apply(piece_id, to)
	result["version"] = version + 1
	_ai.observe(result)
	if _ai_won_clash(result) and randf() < 0.25:
		_ai_taunt(1.4)
	_accept_result(result)
	if _arbiter.is_over():
		_practice_load("finished", version + 1)
		return true
	return false


func _practice_resign() -> void:
	if _arbiter == null or _arbiter.is_over():
		return
	_arbiter.resign(Ranks.WHITE)
	_practice_load("finished", version + 1)



# --- Taunts (cosmetic, not game state) ----------------------------------------------------------

## Throws a taunt at the opponent's half. Returns "" when thrown, otherwise why not.
func send_taunt(slug: String) -> String:
	if not has_match() or not (status() in ["setup", "active"]):
		return "Taunts work during a match."
	var wait := TAUNT_COOLDOWN - (Time.get_ticks_msec() - _last_taunt_ms) / 1000.0
	if wait > 0.0:
		return "Wait %d s" % ceili(wait)
	_last_taunt_ms = Time.get_ticks_msec()
	taunt_received.emit(my_side(), slug)  # Show our own throw at once.
	if kind == Kind.ONLINE:
		var res := await ApiManager.taunt(match_id(), slug)
		return "" if res.ok else res.error
	if kind == Kind.PRACTICE and randf() < 0.4:
		_ai_taunt(randf_range(1.0, 2.0))  # The AI sometimes throws one back.
	return ""


func taunt_cooldown_left() -> float:
	return maxf(0.0, TAUNT_COOLDOWN - (Time.get_ticks_msec() - _last_taunt_ms) / 1000.0)


func _ai_taunt(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if kind != Kind.PRACTICE or not (status() in ["setup", "active"]):
		return
	var options: Array = CosmeticCatalog.items("taunt").keys()
	if not options.is_empty():
		taunt_received.emit(Ranks.opponent(my_side()), options.pick_random())


func _ai_won_clash(result: Dictionary) -> bool:
	var clash: Variant = result.get("clash")
	if not clash is Dictionary:
		return false
	var ai_side := Ranks.opponent(my_side())
	match str(clash.get("outcome")):
		"attacker":
			return result.get("side") == ai_side
		"defender":
			return result.get("side") != ai_side
	return false
