extends Node
## Owns the current match on the client. Online it forwards intents to the API, listens on
## private-game.{id} through ReverbManager (falling back to polling when realtime is unavailable),
## and turns server events into ordered signals for the 3D scene. Offline it runs a practice match
## against SalpakanAI on a LocalArbiter that produces the same MatchView / MoveResult shapes as the
## server, turn timers and powerups included (docs/rules.md in the web repo).
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
signal timer_changed                           ## The turn clock was set: see time_left(), turn_total().
signal rules_changed                           ## Powerup slots, effects, intel, fog or mines changed.
signal powerup_result(result: Dictionary)      ## Our own powerup worked: {id, private}.
signal powerup_used(event: Dictionary)         ## Either side used one: PowerupUsed payload + {mine: bool}.
## Board moments for the rules visuals: {kind: "bounce"|"mine"|"saved"|"rally"|"hidden"|"auto"|"pass",
## side, cell?, from?, piece_ids?, chaos?, timeout?}.
signal rule_event(event: Dictionary)

enum Kind { NONE, ONLINE, PRACTICE }

const POLL_FAST := 2.5      ## Seconds between polls when realtime is unavailable.
const POLL_SAFETY := 20.0   ## Background resync even when realtime is healthy.
const AI_MIN_THINK := 0.7  ## Seconds the practice AI appears to think, at least.
const TAUNT_COOLDOWN := 3.0  ## Seconds between taunts (the server enforces the same).
const TIMEOUT_GRACE := 2.0  ## The server settles a turn only this long after its deadline.

var kind := Kind.NONE
var practice_level := SalpakanAI.Difficulty.MEDIUM  ## Last AI difficulty, for "Play again".
var practice_mode := PowerupLibrary.MODE_SELECT     ## Last practice powerup mode, for "Play again".
var ai_loadout: Dictionary = {}  ## The practice AI's random cosmetics, so you see what opponents see.
var match_view: Dictionary = {}
var version := 0
var powerups: PowerupLoadout  ## The player's 5 picks for Select games, and what their rank unlocked.
var deadline := 0.0  ## Local unix time the running turn's clock runs out; 0 = no clock.

var _last_taunt_ms := -100000
var _channel := ""
var _realtime_ok := false
var _poll_timer: Timer
var _rules_timer: Timer  # Coalesces rule refreshes after realtime moves.
var _busy := false
var _finished_emitted := false
var _clock_skew := 0.0  # server clock - local clock, from the last timer we got
var _turn_total := 0.0
var _next_timeout_claim := 0.0
var _arbiter: LocalArbiter  # Offline practice: full-information referee.
var _ai: SalpakanAI         # Offline practice: the opponent.
var _ai_arbiter: LocalArbiter  # The practice game whose AI turn is being played right now.


func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)
	_rules_timer = Timer.new()
	_rules_timer.one_shot = true
	_rules_timer.timeout.connect(refresh)
	add_child(_rules_timer)
	powerups = PowerupLoadout.new()
	powerups.name = "Powerups"
	add_child(powerups)
	ReverbManager.event_received.connect(_on_realtime_event)
	ReverbManager.subscribed.connect(_on_subscribed)
	ReverbManager.subscription_failed.connect(_on_subscription_failed)
	ReverbManager.disconnected.connect(_on_realtime_lost)
	ApiManager.auth_changed.connect(_on_auth_changed)
	_register_ui()


## The powerup library screen, the dashboard card and the in-match clock and powerup bar.
func _register_ui() -> void:
	if ResourceLoader.exists("res://ui/screens/PowerupsScreen.gd"):
		ScreenRegistry.register("powerups", load("res://ui/screens/PowerupsScreen.gd"))
	if ResourceLoader.exists("res://ui/dashboard/PowerupLoadoutCard.gd"):
		DashboardRegistry.register(load("res://ui/dashboard/PowerupLoadoutCard.gd"), "main", 20)
	if ResourceLoader.exists("res://ui/hud/TurnTimer.gd"):
		HudRegistry.register(load("res://ui/hud/TurnTimer.gd"), "top_center")
	if ResourceLoader.exists("res://ui/hud/PowerupBar.gd"):
		HudRegistry.register(load("res://ui/hud/PowerupBar.gd"), "left")


func _on_auth_changed(logged_in: bool) -> void:
	if not logged_in and kind == Kind.ONLINE:
		leave()


func _process(_delta: float) -> void:
	if kind == Kind.PRACTICE:
		_practice_tick()
	elif kind == Kind.ONLINE:
		_online_tick()


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


static func now_unix() -> float:
	return Time.get_unix_time_from_system()


## Seconds left on the running turn's clock, or INF when there is none.
func time_left() -> float:
	if deadline <= 0.0 or status() != "active":
		return INF
	return deadline - now_unix()


## Seconds the running turn was given (after Time Extension / Squeeze), for drawing the clock.
func turn_total() -> float:
	return maxf(_turn_total, 1.0)


## Quick Step: this turn shows no clock.
func clock_paused() -> bool:
	var t: Variant = match_view.get("timer")
	return status() == "active" and t is Dictionary and bool(t.get("paused", false))


## Labels for the running turn's clock: "+20s", "-15s" or "no clock".
func turn_modifiers() -> Array[String]:
	var labels: Array[String] = []
	if clock_paused():
		labels.append("no clock")
		return labels
	var t: Variant = match_view.get("timer")
	var base: Variant = match_view.get("base_turn_seconds")
	if t is Dictionary and t.get("seconds") != null and base != null:
		var diff := int(t["seconds"]) - int(base)
		if diff != 0:
			labels.append("%+ds" % diff)
	return labels


## Our powerup slots this match: [{id, used}].
func powerup_slots() -> Array:
	var p: Variant = match_view.get("powerups")
	return p.get("mine", []) if p is Dictionary else []


## "" when powerup `id` can be used right now, otherwise why not.
func powerup_problem(id: String) -> String:
	if status() != "active":
		return "Powerups work once the battle starts."
	if not is_my_turn():
		return "Powerups can only be used on your turn."
	var slot: Array = powerup_slots().filter(func(s: Dictionary) -> bool: return s.get("id") == id)
	if slot.is_empty():
		return "You didn't bring that powerup."
	if slot[0].get("used", false):
		return "Already used this match."
	var p: Dictionary = match_view.get("powerups", {})
	if p.get("blocked", false):
		return "Sabotaged! No powerups this turn."
	if int(p.get("used_this_turn", 0)) >= int(p.get("per_turn", PowerupLibrary.MAX_PER_TURN)):
		return "No more powerups this turn."
	return ""


func revealed() -> Array:
	return match_view.get("revealed", []) if match_view.get("revealed") is Array else []


func intel() -> Array:
	return match_view.get("intel", []) if match_view.get("intel") is Array else []


func effects() -> Dictionary:
	return match_view.get("effects", {}) if match_view.get("effects") is Dictionary else {}


func my_mines() -> Array:
	return match_view.get("mines", []) if match_view.get("mines") is Array else []


## The opponent cast smoke: their army shows as it stood before the hidden move.
func has_fog() -> bool:
	return bool(match_view.get("fog", false)) and status() == "active"


## Seconds until `side`'s Jammer ends (0 when not jammed).
func jammed_left(side := "") -> float:
	var until: Variant = match_view.get("jammed_until", {}).get(side if side != "" else my_side()) \
		if match_view.get("jammed_until") is Dictionary else null
	if until == null or status() != "active":
		return 0.0
	return maxf(0.0, parse_time(until) - _clock_skew - now_unix())


## ISO-8601 (with optional fraction and offset) or unix seconds -> unix seconds; 0 if unreadable.
static func parse_time(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	var text := str(value).strip_edges() if value != null else ""
	if text.length() < 19:
		return 0.0
	var seconds := float(Time.get_unix_time_from_datetime_string(text.substr(0, 19)))
	var rest := text.substr(19)
	if rest.begins_with("."):
		var digits := ""
		for ch in rest.substr(1):
			if not ch.is_valid_int():
				break
			digits += ch
		if digits != "":
			seconds += float("0." + digits)
		rest = rest.substr(1 + digits.length())
	if rest.length() >= 6 and (rest[0] == "+" or rest[0] == "-"):
		var offset := int(rest.substr(1, 2)) * 3600 + int(rest.substr(4, 2)) * 60
		seconds -= offset if rest[0] == "+" else -offset
	return seconds


# --- Commands ---------------------------------------------------------------------------------

## Quick match: resume your open match, join the oldest waiting one with the same powerup mode
## (off, select, random), or host a new one.
func find_match(mode := PowerupLibrary.MODE_SELECT) -> Dictionary:
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/games", {"powerup_mode": mode})
	return await _online_request(request)


## Host a match that shows up in the lobby. A 409 carries `match_id` of the match you're already in.
func create_match(mode := PowerupLibrary.MODE_SELECT) -> Dictionary:
	var request := func() -> Dictionary: return await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/create", {"powerup_mode": mode})
	return await _online_request(request)


## This match's powerup mode: "off", "select" or "random".
func powerup_mode() -> String:
	return str(match_view.get("powerup_mode", PowerupLibrary.MODE_SELECT))


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


## Runs a request that answers with {match} (rooms, ranked queue...) and takes that match over.
func online_request(request_fn: Callable) -> Dictionary:
	return await _online_request(request_fn)


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
	var resync := _present_result(res.data.get("result", {}))
	_adopt_view(res.data.get("match", {}), resync)


## Coroutine: uses powerup `id` this turn. `target`: {piece_id?, piece_ids?, x?, y?}. Returns
## {ok, error, result: {id, private}}; on success powerup_result and powerup_used fire too.
func use_powerup(id: String, target := {}) -> Dictionary:
	var problem := powerup_problem(id)
	if problem != "":
		return {"ok": false, "error": problem, "result": {}}
	if kind == Kind.PRACTICE:
		return _practice_use_powerup(id, target)
	if kind != Kind.ONLINE or _busy:
		return {"ok": false, "error": "Busy, try again.", "result": {}}
	var body := {"id": id}
	if not target.is_empty():
		body["target"] = _clean_target(target)
	_busy = true
	var res := await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/powerups" % match_id(), body)
	_busy = false
	if not res.ok:
		return {"ok": false, "error": res.error, "result": {}}
	var result: Dictionary = res.data.get("result", {}) if res.data.get("result") is Dictionary else {}
	if not result.get("private") is Dictionary:
		result["private"] = {}
	powerup_result.emit(result)
	powerup_used.emit({"side": my_side(), "id": id, "name": PowerupLibrary.display_name(id), "public": {}, "mine": true})
	_adopt_view(res.data.get("match", {}), true)
	return {"ok": true, "error": "", "result": result}


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


## Refetch and rebuild the board even if nothing new happened (fog lifted, a hidden move, a mine).
func force_refresh() -> void:
	if kind != Kind.ONLINE or match_id() == 0:
		return
	var res := await ApiManager.get_match(match_id())
	if res.ok:
		_adopt_view(res.data.get("match", {}), true)


func leave() -> void:
	if _channel != "":
		ReverbManager.unsubscribe(_channel)
	_channel = ""
	_poll_timer.stop()
	_rules_timer.stop()
	kind = Kind.NONE
	match_view = {}
	version = 0
	deadline = 0.0
	_arbiter = null
	_ai = null
	_finished_emitted = false
	timer_changed.emit()


# --- Online state handling --------------------------------------------------------------------

func _load_view(view: Dictionary) -> void:
	match_view = view
	version = int(view.get("version", 0))
	match_loaded.emit(view)
	_view_rules_changed()
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
		_view_rules_changed()
		return

	var previous_status := status()
	var last_move: Variant = view.get("last_move")
	var can_animate: bool = not force_reload and previous_status == "active" and v == version + 1 \
		and last_move is Dictionary and int(last_move.get("version", -1)) == version + 1
	if can_animate:
		var resync := _present_result(last_move)
		match_view = view
		version = v
		if resync:
			_load_view(view)
			return
		_view_rules_changed()
		turn_changed.emit()
		if status() != previous_status:
			_announce_status()
		if status() == "finished":
			_emit_finished_from_view(view)
	else:
		_load_view(view)


## Hands a MoveResult (as this player may see it) to the board, turning the powerup twists into
## something the board can animate. Returns true when the board must be rebuilt afterwards (a
## hidden move, a mine, a saved piece, lifted fog).
func _present_result(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	var side := str(result.get("side", ""))
	var clash: Variant = result.get("clash")
	var outcome := str(clash.get("outcome", "")) if clash is Dictionary else ""
	var resync: bool = result.get("fog_lifted", false)
	if result.get("auto", false):
		rule_event.emit({"kind": "auto", "side": side, "chaos": result.get("chaos", false), "timeout": result.get("timeout", false)})
		var whose := "you" if side == my_side() else "your opponent"
		if result.get("chaos", false):
			status_message.emit("Chaos Order! A random move was forced on %s." % whose)
		else:
			status_message.emit("Time's up! A random move was played for %s." % whose)
	if str(result.get("type", "")) in ["pass", "forfeit"] or str(result.get("reason", "")) == "no_legal_moves":
		rule_event.emit({"kind": "pass", "side": side})
		_accept_result(result, false)
		return resync
	if result.get("hidden", false):
		# Smoke: no piece or squares. Rebuild to drop our losses (or, for our own side, to see it).
		rule_event.emit({"kind": "hidden", "side": side, "clash": clash})
		_accept_result(result, false)
		return true
	var shown := result
	if outcome == "bounce":
		shown = result.duplicate()
		shown["to"] = result.get("from")
		shown["clash"] = null
		shown["type"] = "move"
		rule_event.emit({"kind": "bounce", "side": side, "cell": result.get("to"), "from": result.get("from"),
			"piece_id": clash.get("defender_id")})
	elif clash is Dictionary and clash.get("mine") is Dictionary:
		if outcome == "mine":
			shown = result.duplicate()
			shown["clash"] = null
			shown["type"] = "move"
		rule_event.emit({"kind": "mine", "side": side, "cell": clash["mine"], "saved": clash.get("saved", []).has(result.get("piece_id"))})
		resync = true
	if clash is Dictionary and not clash.get("saved", []).is_empty():
		rule_event.emit({"kind": "saved", "side": side, "piece_ids": clash["saved"]})
		resync = true
	if clash is Dictionary and clash.get("rally") != null:
		rule_event.emit({"kind": "rally", "side": str(clash["rally"]), "cell": result.get("to")})
	_accept_result(shown)
	return resync


func _accept_result(result: Dictionary, animate := true) -> void:
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
	if animate:
		match_view["last_move"] = result
		move_result.emit(result)
	if result.get("timer") is Dictionary:
		_apply_timer(result["timer"])
	turn_changed.emit()
	_announce_status()


func _view_rules_changed() -> void:
	var t: Variant = match_view.get("timer")
	if t is Dictionary:
		_apply_timer(t)
	else:
		# Older servers: just the ISO fields.
		_apply_timer({"deadline": match_view.get("turn_deadline"), "seconds": match_view.get("turn_seconds"),
			"server_time": match_view.get("server_time")})
	rules_changed.emit()


## Sets the local deadline from a `timer` object, correcting for the server's clock.
func _apply_timer(t: Dictionary) -> void:
	match_view["timer"] = t
	var server_now := float(t["server_time_ms"]) / 1000.0 if t.get("server_time_ms") != null else parse_time(t.get("server_time"))
	if server_now > 0.0:
		_clock_skew = server_now - now_unix()
	var server_deadline := float(t["deadline_ms"]) / 1000.0 if t.get("deadline_ms") != null else parse_time(t.get("deadline"))
	deadline = server_deadline - _clock_skew if server_deadline > 0.0 else 0.0
	_turn_total = float(t["seconds"]) if t.get("seconds") != null else maxf(time_left(), 1.0)
	timer_changed.emit()


func _on_realtime_event(channel: String, event: String, data: Dictionary) -> void:
	if channel != _channel:
		return
	var v := int(data.get("version", 0))
	match event:
		"Taunt":
			# Our own throws were already shown when sent.
			if str(data.get("side", "")) != my_side():
				taunt_received.emit(str(data.get("side", "")), str(data.get("taunt", "")))
		"PieceMoved", "ClashResolved", "TurnPassed":
			if v <= version:
				return  # Our own move, already applied from the HTTP response.
			if v > version + 1:
				refresh()
				return
			var result := data.duplicate()
			if event == "TurnPassed":
				result["type"] = "pass"
			if result.get("hidden", false) and str(result.get("side")) == my_side():
				_accept_result(result, false)  # A timeout move of ours behind our own smoke.
				force_refresh()
				return
			if _present_result(result):
				force_refresh()
			else:
				_rules_timer.start(0.4)  # Turn-based rule state (slots per turn, effects) moved on.
		"PowerupUsed":
			if v <= version:
				return
			if str(data.get("side", "")) != my_side():
				var announced := data.duplicate()
				announced["mine"] = false
				powerup_used.emit(announced)
			refresh()  # Powerups can move pieces or change what we may see: take the new view.
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
			deadline = 0.0
			timer_changed.emit()
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


## Either player may settle a turn whose clock ran out; the server answers 409 + retry_after if
## it's too early.
func _online_tick() -> void:
	if status() != "active" or deadline <= 0.0 or _busy:
		return
	var now := now_unix()
	if now < deadline + TIMEOUT_GRACE + 0.5 or now < _next_timeout_claim:
		return
	_next_timeout_claim = now + 5.0
	_claim_timeout()


func _claim_timeout() -> void:
	var id := match_id()
	var res := await ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/timeout" % id)
	if kind != Kind.ONLINE or match_id() != id:
		return
	if res.ok:
		_adopt_view(res.data.get("match", {}))
	elif res.status == 409 and res.data.get("retry_after") != null:
		_next_timeout_claim = now_unix() + maxf(1.0, float(res.data["retry_after"]))
	else:
		refresh()


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
			if has_fog():
				text += " (Smoke over their army!)"
		"finished":
			var winner: Variant = match_view.get("winner")
			var reason := str(match_view.get("end_reason", "")).replace("_", " ")
			text = ("Victory" if winner == my_side() else "Defeat") + " (%s)." % reason
		"cancelled":
			text = "Match cancelled."
	if text != "":
		status_message.emit(text)


func _clean_target(target: Dictionary) -> Dictionary:
	var clean := {}
	for key: String in target:
		var value: Variant = target[key]
		clean[key] = int(value) if key in ["x", "y"] else value
	return clean


# --- Offline practice against the AI (local arbiter, no server) -------------------------------

## The player is white and moves first; the AI plays black. Same clock and powerups as online.
## Offline game against the AI. `mode` is the powerup mode chosen before the game: "off" (none
## for either side), "select" (your 5 picks) or "random" (5 dealt from what you've unlocked). With
## powerups on, the AI always gets 5 random ones.
func start_practice(level: SalpakanAI.Difficulty = SalpakanAI.Difficulty.MEDIUM, mode := "") -> void:
	if mode == "":
		mode = practice_mode
	leave()
	kind = Kind.PRACTICE
	practice_level = level
	practice_mode = mode
	ai_loadout = Loadout.random_loadout()
	_ai = SalpakanAI.new(Ranks.BLACK, level)
	_arbiter = LocalArbiter.new()
	_arbiter.turn_seconds = maxi(PowerupLibrary.MIN_TURN_SECONDS, int(ServerConfig.get_value("turn_seconds", 45)))
	_arbiter.powerup_mode = mode
	match mode:
		PowerupLibrary.MODE_OFF:
			_arbiter.set_loadout(Ranks.WHITE, [])
			_arbiter.set_loadout(Ranks.BLACK, [])
		PowerupLibrary.MODE_RANDOM:
			_arbiter.set_loadout(Ranks.WHITE, _deal_from(powerups.unlocked_ids()))
			_arbiter.set_loadout(Ranks.BLACK, PowerupBrain.pick_loadout(level == SalpakanAI.Difficulty.EASY))
		_:
			_arbiter.set_loadout(Ranks.WHITE, powerups.active_slots())
			_arbiter.set_loadout(Ranks.BLACK, PowerupBrain.pick_loadout(level == SalpakanAI.Difficulty.EASY))
	_practice_load("setup", 1)


## Random mode offline: 5 distinct ids from `pool`.
func _deal_from(pool: Array[String]) -> Array[String]:
	var left := pool.duplicate()
	left.shuffle()
	return left.slice(0, PowerupLibrary.MAX_SLOTS)


func _practice_start(placements: Array) -> void:
	_arbiter.deploy(Ranks.WHITE, placements)
	_arbiter.deploy(Ranks.BLACK, _ai.choose_formation())
	_ai.begin(_arbiter.observation(Ranks.BLACK))
	_arbiter.start()
	_practice_load("active", version + 1)


func _practice_view(practice_status: String, new_version: int) -> Dictionary:
	var view := {
		"id": 0, "status": practice_status, "your_side": Ranks.WHITE,
		"turn": _arbiter.turn if practice_status == "active" else null,
		"move_number": _arbiter.move_number, "version": new_version,
		"powerup_mode": _arbiter.powerup_mode,
		"players": {"white": {"username": "You"}, "black": {"username": "AI (%s)" % SalpakanAI.label(_ai.difficulty), "loadout": ai_loadout}},
		"setup_ready": {"white": practice_status != "setup", "black": true},
		"pieces": _arbiter.view_pieces(Ranks.WHITE),
		"winner": _arbiter.winner if _arbiter.is_over() else null,
		"end_reason": _arbiter.end_reason if _arbiter.is_over() else null,
		"clashes": _arbiter.clash_log if _arbiter.is_over() else [],
	}
	if practice_status != "setup":
		view.merge(_arbiter.rules_view(Ranks.WHITE), true)
	return view


func _practice_load(practice_status: String, new_version: int) -> void:
	_load_view(_practice_view(practice_status, new_version))


## After a practice event that didn't rebuild the board: take the arbiter's new rule state.
func _practice_sync_rules() -> void:
	var rules := _arbiter.rules_view(Ranks.WHITE)
	for key: String in rules:
		match_view[key] = rules[key]
	_view_rules_changed()


func _practice_tick() -> void:
	if _arbiter == null or _arbiter.is_over() or status() != "active" or _arbiter.turn != Ranks.WHITE \
			or _ai_arbiter == _arbiter or _arbiter.now() < _arbiter.turn_deadline + TIMEOUT_GRACE:
		return
	var arbiter := _arbiter
	for result in arbiter.check_timeout():
		_practice_emit(result)
	if arbiter == _arbiter and not arbiter.is_over():
		_practice_continue()


func _practice_player_move(piece_id: String, from: Vector2i, to: Vector2i) -> void:
	var error := _arbiter.validate(Ranks.WHITE, piece_id, from, to) if _ai_arbiter != _arbiter else "Not your turn."
	if error != "":
		move_rejected.emit(piece_id, error)
		status_message.emit(error)
		return
	_practice_emit(_arbiter.apply(piece_id, to))
	_practice_continue()


## Announces one practice MoveResult: the AI learns what black may see, the board shows what white
## may see, and the view is rebuilt when the board can't simply animate it.
func _practice_emit(full: Dictionary) -> void:
	var arbiter := _arbiter
	full["version"] = version + 1
	if str(full.get("type", "")) in ["move", "clash"]:
		_ai.observe(LocalArbiter.redact(full, Ranks.BLACK))
		if _ai_won_clash(full) and randf() < 0.25 and not arbiter.jammed(Ranks.BLACK):
			_ai_taunt(1.4)
	var resync := _present_result(LocalArbiter.redact(full, Ranks.WHITE))
	if arbiter != _arbiter:
		return
	if arbiter.is_over():
		_practice_load("finished", version + 1)
	elif resync:
		_practice_load("active", version)
	else:
		_practice_sync_rules()


## Plays everything that isn't the player's to play: Chaos Order moves and the AI's turns.
func _practice_continue() -> void:
	if _arbiter == null or _ai_arbiter == _arbiter:
		return
	var arbiter := _arbiter
	_ai_arbiter = arbiter
	while kind == Kind.PRACTICE and arbiter == _arbiter and not arbiter.is_over():
		if arbiter.forced_move_pending():
			await get_tree().create_timer(0.7).timeout
			if arbiter != _arbiter or arbiter.is_over():
				break
			for result in arbiter.play_forced():
				_practice_emit(result)
			continue
		if arbiter.turn != Ranks.BLACK:
			break
		await _ai_take_turn(arbiter)
	if _ai_arbiter == arbiter:
		_ai_arbiter = null


func _ai_take_turn(arbiter: LocalArbiter) -> void:
	var ai := _ai
	var started := Time.get_ticks_msec()
	var plan := PowerupBrain.choose(arbiter, Ranks.BLACK, ai)
	if not plan.is_empty():
		await get_tree().create_timer(0.5).timeout
		if arbiter != _arbiter or arbiter.is_over():
			return
		var used := arbiter.use_powerup(Ranks.BLACK, plan["id"], plan.get("target", {}))
		if used["ok"]:
			_ai_learn(arbiter, used)
			var announced: Dictionary = used["event"].duplicate()
			announced["version"] = version + 1
			announced["mine"] = false
			powerup_used.emit(announced)
			_practice_load("finished" if arbiter.is_over() else "active", version + 1)
			if used["ends_turn"] or arbiter.is_over() or arbiter.turn != Ranks.BLACK:
				return
	if arbiter.legal_moves(Ranks.BLACK).is_empty():
		_practice_emit(arbiter.pass_turn(Ranks.BLACK))
		return
	# The AI thinks in frame-sized slices; pad short searches so its reply doesn't feel instant.
	var choice: Dictionary = await ai.choose_move(arbiter.observation(Ranks.BLACK))
	var remaining := AI_MIN_THINK - (Time.get_ticks_msec() - started) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
	if kind != Kind.PRACTICE or _ai != ai or arbiter != _arbiter or arbiter.is_over():
		return  # The player resigned or left while the AI was thinking.
	if choice.is_empty() or arbiter.validate(Ranks.BLACK, choice["id"], choice["from"], choice["to"]) != "":
		push_warning("AI produced no legal move: %s" % choice)
		arbiter.resign(Ranks.BLACK)
		_practice_load("finished", version + 1)
		return
	_practice_emit(arbiter.apply(choice["id"], choice["to"]))


## The AI takes in what its own powerup told it (only what black may know).
func _ai_learn(arbiter: LocalArbiter, used: Dictionary) -> void:
	var private: Dictionary = used["result"]["private"]
	match str(used["result"]["id"]):
		"spy_card", "intel_leak":
			_ai.learn(private["piece_id"], {"rank": private["rank"]})
		"recon_drone":
			_ai.learn(private["piece_id"], {"is_flag": private["is_flag"]})
		"scout_report":
			for entry: Dictionary in private["pieces"]:
				_ai.learn(entry["piece_id"], {"group": entry["group"]})
		"flag_hunter":
			var columns := {}
			for e: Dictionary in arbiter.observation(Ranks.BLACK)["enemy"]:
				columns[e["id"]] = e["x"]
			_ai.learn_flag_column(int(private["x"]), columns)
		"shuffle", "reinforcement", "swap", "teleport":
			_ai.sync_own(arbiter.observation(Ranks.BLACK))


func _practice_use_powerup(id: String, target: Dictionary) -> Dictionary:
	if _ai_arbiter == _arbiter:
		return {"ok": false, "error": "Powerups can only be used on your turn.", "result": {}}
	var used := _arbiter.use_powerup(Ranks.WHITE, id, _clean_target(target))
	if not used["ok"]:
		return {"ok": false, "error": used["error"], "result": {}}
	# What black is told: the public part, and that its knowledge of shuffled pieces is gone.
	match id:
		"shuffle":
			_ai.forget(used["forget"])
		"reinforcement":
			_ai.enemy_reinforced(str(used["event"]["public"]["piece"]["id"]))
	powerup_result.emit(used["result"])
	var announced: Dictionary = used["event"].duplicate()
	announced["version"] = version + 1
	announced["mine"] = true
	powerup_used.emit(announced)
	_practice_load("finished" if _arbiter.is_over() else "active", version + 1)
	if not _arbiter.is_over() and (used["ends_turn"] or _arbiter.forced_move_pending()):
		_practice_continue()
	return {"ok": true, "error": "", "result": used["result"]}


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
	var jam := jammed_left()
	if jam > 0.0:
		return "Jammed! %d s" % ceili(jam)
	var wait := TAUNT_COOLDOWN - (Time.get_ticks_msec() - _last_taunt_ms) / 1000.0
	if wait > 0.0:
		return "Wait %d s" % ceili(wait)
	_last_taunt_ms = Time.get_ticks_msec()
	taunt_received.emit(my_side(), slug)  # Show our own throw at once.
	if kind == Kind.ONLINE:
		var res := await ApiManager.taunt(match_id(), slug)
		return "" if res.ok else res.error
	if kind == Kind.PRACTICE and randf() < 0.4 and not _arbiter.jammed(Ranks.BLACK):
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
