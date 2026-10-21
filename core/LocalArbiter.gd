class_name LocalArbiter
extends RefCounted
## Full-information referee for offline games: practice against the AI, and AI benchmarks. It
## mirrors the server's rules (docs/API.md and docs/rules.md in the web repo; app/Game/Arbiter,
## Powerups/MatchRules, Powerups/PowerupEngine and MatchPresenter), turn timers and powerups
## included, and produces the same JSON shapes; online matches never use it.
##
## Turn timers are off unless `turn_seconds` > 0. Powerups need set_loadout() per side. Views are
## per viewer so fog of war and every powerup secret hold: view_pieces(), rules_view() and
## observation() only show what that side may know, and redact() conceals a smoke-screened move.
## Effects count turns per side like the server: {type, side, by, from_turn, to_turn, ...}.

const TIMEOUT_FORFEIT := 3       ## Consecutive timeouts by one side that lose the match.
const QUICK_STEP_MAX := 300.0    ## A Quick Step turn shows no clock but still ends after this.
## Effects the opponent can see; the rest stay secret until they trigger.
const VISIBLE_EFFECTS := ["time_extension", "time_squeeze", "quick_step", "freeze", "sabotage",
	"blitz", "time_steal", "roadblock", "haste", "ceasefire"]
## Effects that change a turn's seconds by their `seconds` (Blitz halves it on top).
const CLOCK_EFFECTS := ["time_extension", "time_squeeze", "time_steal"]
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var pieces: Dictionary = {}  # id -> {id, side, rank, x, y}
var turn := Ranks.WHITE
var move_number := 0
var winner := ""
var end_reason := ""
## Every clash with both ranks, for the post-game Battle Recap. Never shown during play.
var clash_log: Array = []

## Turn timer. `clock` returns unix seconds; tests swap in a fake clock.
var turn_seconds := 0             ## Base allotment; 0 = no timers.
var turn_deadline := 0.0          ## When the running turn ends; 0 = no clock.
var turn_paused := false          ## Quick Step: no clock shown (the turn still ends after 5 min).
var turn_allotment := 0           ## Seconds the running turn was given (after modifiers).
var timeouts := {Ranks.WHITE: 0, Ranks.BLACK: 0}
var clock := Callable(Time, "get_unix_time_from_system")

## Powerups each side brought (ids) and which it has used. `powerup_mode` (off, select, random)
## only decides how the hands were dealt (GameSession.start_practice); "off" also refuses any use.
var powerup_mode := PowerupLibrary.MODE_SELECT
var loadouts := {Ranks.WHITE: [], Ranks.BLACK: []}
var used := {Ranks.WHITE: [], Ranks.BLACK: []}
var _used_log := {Ranks.WHITE: [], Ranks.BLACK: []}  # play order, for Recall

var _pending_flag: Dictionary = {}  # {id, side} while a flag waits out the reply on the goal row
var _next_id := 0
var _eliminated: Array = []  # every removed piece {id, side, rank, x, y}
var _turns := {Ranks.WHITE: 0, Ranks.BLACK: 0}  # turns each side has started
var _usage := {"side": "", "turn": 0, "count": 0}
var _effects: Array = []  # {seq, type, side, by, from_turn?, to_turn?, piece_id?, seconds?, fake_rank?}
var _seq := 0
var _revealed := {Ranks.WHITE: [], Ranks.BLACK: []}  # viewer -> [{piece_id, rank|group|is_flag, source, move_number}]
var _intel := {Ranks.WHITE: [], Ranks.BLACK: []}     # viewer -> [{type, officers|x, move_number}]
var _mines := {Ranks.WHITE: [], Ranks.BLACK: []}     # owner -> [{x, y, until_turn, kind}] (mine | quicksand)
var _fog: Dictionary = {}  # {side, pieces, eliminated, until_turn}: what the opponent sees of `side`
var _smoke := ""           # side whose next move will be hidden
var _chaos := ""           # side whose next move the referee picks at random
var _march: Dictionary = {}  # {side, first} while a Double March runs ("" = first move not made)
var _jammed_until := {Ranks.WHITE: 0.0, Ranks.BLACK: 0.0}
var _last_moved := {Ranks.WHITE: "", Ranks.BLACK: ""}


## Places a formation ([{rank, x, y}]). Ids are handed out in shuffled order so they never follow
## rank order.
func deploy(side: String, formation: Array) -> void:
	var shuffled := formation.duplicate()
	shuffled.shuffle()
	for p: Dictionary in shuffled:
		_add_piece(side, str(p["rank"]), Vector2i(int(p["x"]), int(p["y"])))


## Both formations are down: white's first turn (and its clock) begins.
func start() -> void:
	_begin_turn(turn)


func set_loadout(side: String, ids: Array) -> void:
	loadouts[side] = PowerupLibrary.sanitize(ids)
	used[side] = []
	_used_log[side] = []


func is_over() -> bool:
	return winner != ""


func now() -> float:
	return float(clock.call())


func piece_at(cell: Vector2i) -> Dictionary:
	for p: Dictionary in pieces.values():
		if p["x"] == cell.x and p["y"] == cell.y:
			return p
	return {}


## Everything `side` is allowed to know: its own pieces with ranks, enemy positions without (as
## they stood before a smoke-screened move), plus which of its own pieces are frozen.
func observation(side: String) -> Dictionary:
	var mine: Array = []
	var frozen: Array = []
	for p: Dictionary in pieces.values():
		if p["side"] == side:
			mine.append(p.duplicate())
			if is_frozen(side, p["id"]):
				frozen.append(p["id"])
	var enemy: Array = []
	for p: Dictionary in _enemies_seen_by(side):
		enemy.append({"id": p["id"], "x": p["x"], "y": p["y"]})
	return {"mine": mine, "enemy": enemy, "frozen": frozen, "blocked": blocked_cells(),
		"no_attack": in_ceasefire(side)}


## [{id, from, to}] for every legal move of `side` (frozen pieces stay put; the second step of a
## Double March uses another piece and can't attack).
func legal_moves(side: String) -> Array[Dictionary]:
	var occupied: Dictionary = {}
	for p: Dictionary in pieces.values():
		occupied[Vector2i(p["x"], p["y"])] = p["side"]
	var first := _march_first(side)
	var reach := [1, 2] if has_haste(side) else [1]
	var moves: Array[Dictionary] = []
	for p: Dictionary in pieces.values():
		if p["side"] != side or p["id"] == first or is_frozen(side, p["id"]):
			continue
		var from := Vector2i(p["x"], p["y"])
		for dir in DIRECTIONS:
			for steps: int in reach:
				var to := from + dir * steps
				if step_problem(side, from, to) != "":
					continue
				if first != "" and occupied.get(to, "") != "":
					continue
				moves.append({"id": p["id"], "from": from, "to": to})
	return moves


## "" when a piece of `side` may step from `from` to `to` right now (MoveRules on the server): one
## square orthogonally, or a 2-square straight dash under Haste (never over a piece or a
## Roadblock); never onto its own piece or a Roadblock, and no attacks during a Ceasefire.
func step_problem(side: String, from: Vector2i, to: Vector2i) -> String:
	if not Ranks.in_bounds(to):
		return "That square is off the board."
	var delta := to - from
	var dash := (absi(delta.x) == 2 and delta.y == 0) or (absi(delta.y) == 2 and delta.x == 0)
	if absi(delta.x) + absi(delta.y) != 1 and not (dash and has_haste(side)):
		return "Pieces move one square forward, back or sideways."
	if dash:
		var middle := from + delta / 2
		if not piece_at(middle).is_empty() or is_blocked(middle):
			return "Haste can't jump over pieces or roadblocks."
	var target := piece_at(to)
	if not target.is_empty() and target["side"] == side:
		return "You can't capture your own piece."
	if is_blocked(to):
		return "A roadblock stands on that square."
	if not target.is_empty() and in_ceasefire(side):
		return "Ceasefire: you can't attack this turn."
	return ""


## "" when legal, otherwise the reason it isn't.
func validate(side: String, piece_id: String, from: Vector2i, to: Vector2i) -> String:
	if is_over():
		return "The game is over."
	if turn != side:
		return "Not your turn."
	var piece: Dictionary = pieces.get(piece_id, {})
	if piece.is_empty() or piece["side"] != side or Vector2i(piece["x"], piece["y"]) != from:
		return "That piece can't move."
	var problem := step_problem(side, from, to)
	if problem != "":
		return problem
	var target := piece_at(to)
	if is_frozen(side, piece_id):
		return "That piece is frozen."
	var first := _march_first(side)
	if first != "":
		if piece_id == first:
			return "Double March: move a different piece."
		if not target.is_empty():
			return "Double March: the second move can't be an attack."
	return ""


## Applies a validated move and returns its MoveResult (the caller stamps the version). `auto` is
## "" for a player's own move, "timeout" or "chaos" for one the referee played.
func apply(piece_id: String, to: Vector2i, auto := "") -> Dictionary:
	var piece: Dictionary = pieces[piece_id]
	var side: String = piece["side"]
	var from := Vector2i(piece["x"], piece["y"])
	var target := piece_at(to)
	if auto == "":
		timeouts[side] = 0
	var hidden := hides_moves_of(side)
	if absi(to.x - from.x) + absi(to.y - from.y) == 2:
		_consume("haste", side)
	if _smoke == side:
		# The opponent keeps seeing this army as it stands now until their turn ends.
		_smoke = ""
		_start_fog(side)
	move_number += 1

	var clash: Variant = null
	var removed: Array = []
	if target.is_empty():
		_place(piece, to)
	else:
		var fight := _clash(piece, target, to)
		clash = fight[0]
		removed = fight[1]
	var tripped := _trip_mine(side, piece_id, to, clash, removed)
	clash = tripped[0]
	removed = tripped[1]
	var stuck: Variant = tripped[2]
	_eliminated.append_array(removed)
	_last_moved[side] = piece_id

	var fog_lifted := false
	_victory(side, piece_id, removed)
	if not is_over():
		if not _march.is_empty() and _march["side"] == side and _march["first"] == "":
			_march["first"] = piece_id
			if legal_moves(side).is_empty():
				fog_lifted = _end_turn(side)
		else:
			fog_lifted = _end_turn(side)

	var result := {
		"match_id": 0, "move_number": move_number, "type": "move" if clash == null else "clash", "side": side,
		"piece_id": piece_id, "from": {"x": from.x, "y": from.y}, "to": {"x": to.x, "y": to.y}, "clash": clash,
		"turn": null if is_over() else turn, "timer": timer(),
	}
	if auto != "":
		result["auto"] = true
		result[auto] = true
	if stuck != null:
		result["quicksand"] = stuck
	if hidden:
		result["hidden_from_opponent"] = true
	if fog_lifted:
		result["fog_lifted"] = true
	return result


func resign(side: String) -> void:
	_finish(Ranks.opponent(side), "resignation")


## The move result as `viewer` may see it (MatchPresenter::concealed): an enemy move behind a
## smoke screen loses its piece and squares; a clash only shows which of `viewer`'s pieces fell,
## and `viewer`'s own Fortify or Mine going off.
static func redact(result: Dictionary, viewer: String) -> Dictionary:
	if not result.get("hidden_from_opponent", false) or result.get("side") == viewer:
		return result
	var concealed := {}
	for key: String in result:
		if not key in ["piece_id", "from", "to", "clash", "hidden_from_opponent", "quicksand"]:
			concealed[key] = result[key]
	if result.get("quicksand") is Dictionary:  # The trap's owner learns it caught something, not what.
		concealed["quicksand"] = {"x": result["quicksand"]["x"], "y": result["quicksand"]["y"], "turns": result["quicksand"]["turns"]}
	var clash: Variant = result.get("clash")
	if clash is Dictionary:
		var defender: Variant = clash.get("defender_id")
		var view := {"defender_id": defender,
			"eliminated": clash.get("eliminated", []).filter(func(id: Variant) -> bool: return id == defender)}
		if str(clash.get("outcome")) in ["bounce", "mine"]:
			view["outcome"] = clash["outcome"]
		if clash.has("mine"):
			view["mine"] = clash["mine"]
		if defender != null and clash.get("saved", []).has(defender):
			view["saved"] = [defender]
		clash = view
	concealed["clash"] = clash
	concealed["hidden"] = true
	return concealed


## Pieces as a MatchView list for `viewer`: enemy ranks hidden until the game is over (unless
## learned through powerups), the enemy army as it stood before a smoke-screened move.
func view_pieces(viewer: String) -> Array:
	var list: Array = []
	for p: Dictionary in pieces.values():
		if p["side"] == viewer:
			list.append(p.duplicate())
	if is_over():
		for p: Dictionary in pieces.values():
			if p["side"] != viewer:
				list.append(p.duplicate())
		return list
	for p: Dictionary in _enemies_seen_by(viewer):
		var shown: Dictionary = p.duplicate()
		var known := known_rank(viewer, p["id"])
		shown["rank"] = known if known != "" else null
		list.append(shown)
	return list


# --- Turn timer -----------------------------------------------------------------------------------

## The running turn's clock, shaped like MatchPresenter::timer().
func timer() -> Dictionary:
	var active := not is_over() and turn != "" and turn_deadline > 0.0
	var shown := active and not turn_paused
	var at := now()
	return {
		"turn": turn if active else null,
		"deadline": _iso(turn_deadline) if shown else null,
		"deadline_ms": int(turn_deadline * 1000.0) if shown else null,
		"remaining_ms": maxi(0, int((turn_deadline - at) * 1000.0)) if shown else null,
		"seconds": turn_allotment if shown else null,
		"paused": active and turn_paused,
		"server_time": _iso(at),
		"server_time_ms": int(at * 1000.0),
	}


## Seconds left on the running turn's clock, or INF without one.
func time_left() -> float:
	if turn_deadline <= 0.0 or is_over():
		return INF
	return turn_deadline - now()


## Call regularly: once the running turn's clock has run out, plays a random legal move for that
## side (both steps of a Double March), a pass if nothing can move, or forfeits on its third
## timeout in a row. Returns the results in order (empty when the clock hasn't run out).
func check_timeout() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if is_over() or turn_deadline <= 0.0 or now() < turn_deadline:
		return results
	var side := turn
	timeouts[side] += 1
	if timeouts[side] >= TIMEOUT_FORFEIT:
		_finish(Ranks.opponent(side), "timeout")
		results.append({"type": "forfeit", "side": side, "timeout": true, "turn": null, "timer": timer()})
		return results
	return auto_move(side, "timeout")


## Chaos Order: true when the side to move must have its move played for it right now.
func forced_move_pending() -> bool:
	return not is_over() and _chaos != "" and _chaos == turn


func play_forced() -> Array[Dictionary]:
	_chaos = ""
	return auto_move(turn, "chaos")


## The referee plays `side`'s turn: a random legal move (both steps of a Double March), or a pass.
func auto_move(side: String, flag: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var move := random_move(side)
	if move.is_empty():
		results.append(pass_turn(side, flag))
		return results
	results.append(apply(move["id"], move["to"], flag))
	if not is_over() and turn == side:
		results.append_array(auto_move(side, flag))
	return results


## Nothing can move (everything frozen): the turn passes. A TurnPassed payload.
func pass_turn(side: String, flag := "") -> Dictionary:
	var lifted := _end_turn(side)
	var result := {"type": "pass", "side": side, "reason": "no_legal_moves", "turn": null if is_over() else turn,
		"move_number": move_number, "timer": timer()}
	if flag != "":
		result["auto"] = true
		result[flag] = true
	if lifted:
		result["fog_lifted"] = true
	return result


## Any legal move at random, preferring pieces other than the Flag and never sending the Flag into
## an attack (RandomMover::pick).
func random_move(side: String) -> Dictionary:
	var moves := legal_moves(side)
	var pool := moves.filter(func(m: Dictionary) -> bool: return pieces[m["id"]]["rank"] != "FLG")
	if pool.is_empty():
		pool = moves.filter(func(m: Dictionary) -> bool: return piece_at(m["to"]).is_empty())
	if pool.is_empty():
		pool = moves
	return pool.pick_random() if not pool.is_empty() else {}


func jammed(side: String) -> bool:
	return now() < float(_jammed_until[side])


# --- Powerups -----------------------------------------------------------------------------------

## Uses powerup `id` for `side` (target: {piece_id?, piece_ids?, x?, y?}). Returns {ok, error,
## result: {id, private}, event: PowerupUsed payload (no version), ends_turn, forget}. `private`
## is only for `side`; `event.public` is what both players are told; `forget` lists the pieces
## whose secrets the opponent just lost (Shuffle), so an AI opponent can forget them too.
func use_powerup(side: String, id: String, target := {}) -> Dictionary:
	if is_over():
		return _fail("The match is not in progress.")
	if turn != side:
		return _fail("Powerups can only be used on your turn.")
	if powerup_mode == PowerupLibrary.MODE_OFF:
		return _fail("Powerups are off in this match.")
	if not loadouts[side].has(id):
		return _fail("You didn't bring that powerup to this match.")
	if used[side].has(id):
		return _fail("You already used that powerup in this match.")
	if is_sabotaged(side):
		return _fail("Sabotaged! You can't use powerups this turn.")
	if used_this_turn(side) >= PowerupLibrary.MAX_PER_TURN:
		return _fail("You can't use another powerup this turn.")
	# An opponent's Counterspell eats the card: spent, no effect, the turn goes on.
	var countered := _consume("counterspell", side)
	var outcome := {"private": {"countered": true}, "public": {"countered": true}} if countered else _apply_powerup(id, side, target)
	if outcome.has("error"):
		return _fail(outcome["error"])

	used[side].append(id)
	_used_log[side].append(id)
	_usage = {"side": side, "turn": _turns[side], "count": used_this_turn(side) + 1}
	var ends_turn := PowerupLibrary.consumes_turn(id) and not countered
	var lifted := false
	if ends_turn:
		move_number += 1
		timeouts[side] = 0
		lifted = _end_turn(side)
	var event := {"match_id": 0, "side": side, "id": id, "name": PowerupLibrary.display_name(id),
		"public": outcome.get("public", {}), "ends_turn": ends_turn, "turn": null if is_over() else turn, "timer": timer()}
	if lifted:
		event["fog_lifted"] = true
	if countered:
		event["countered"] = true
	return {"ok": true, "error": "", "result": {"id": id, "private": outcome.get("private", {})}, "event": event,
		"ends_turn": ends_turn, "forget": outcome.get("forget", [])}


func can_use_powerup(side: String, id: String) -> bool:
	return not is_over() and turn == side and loadouts[side].has(id) and not used[side].has(id) \
		and not is_sabotaged(side) and used_this_turn(side) < PowerupLibrary.MAX_PER_TURN


func used_this_turn(side: String) -> int:
	return int(_usage["count"]) if _usage["side"] == side and _usage["turn"] == _turns[side] else 0


func is_frozen(side: String, piece_id: String) -> bool:
	return not _effect("freeze", side, piece_id, _turns[side]).is_empty()


func is_sabotaged(side: String) -> bool:
	return not _effect("sabotage", side, "", _turns[side]).is_empty()


## Haste: this turn the side may dash one piece 2 squares in a straight line.
func has_haste(side: String) -> bool:
	return not _effect("haste", side, "", _turns[side]).is_empty()


## Ceasefire: the side may not attack during its current turn.
func in_ceasefire(side: String) -> bool:
	return not _effect("ceasefire", side, "", _turns[side]).is_empty()


## A Roadblock stands on the square: no piece may enter it.
func is_blocked(cell: Vector2i) -> bool:
	for e: Dictionary in _effects:
		if e["type"] == "roadblock" and e["x"] == cell.x and e["y"] == cell.y:
			return true
	return false


## Every square a Roadblock bars.
func blocked_cells() -> Array:
	var cells: Array = []
	for e: Dictionary in _effects:
		if e["type"] == "roadblock":
			cells.append(Vector2i(e["x"], e["y"]))
	return cells


## True while `side`'s moves are announced without positions (armed smoke or its fog).
func hides_moves_of(side: String) -> bool:
	return _smoke == side or _fog.get("side", "") == side


## The rank `viewer` has learned for an enemy piece ("" if none). Decoys make it a lie.
func known_rank(viewer: String, piece_id: String) -> String:
	var rank := ""
	for entry: Dictionary in _revealed[viewer]:
		if entry["piece_id"] == piece_id and entry.has("rank"):
			rank = entry["rank"]
	return rank


## Boot Camp: lets `viewer` see an enemy piece's real rank (the drills before Fog of War show
## their targets).
func reveal_to(viewer: String, piece_id: String) -> void:
	var piece: Dictionary = pieces.get(piece_id, {})
	if not piece.is_empty() and piece["side"] != viewer:
		_reveal(viewer, {"piece_id": piece_id, "rank": piece["rank"], "source": "tutorial"})


## Rule state for `viewer`, merged into its MatchView next to `pieces` (MatchPresenter::forSide).
func rules_view(viewer: String) -> Dictionary:
	var enemy := Ranks.opponent(viewer)
	var clock_view := timer()
	var shown_ids: Array = _enemies_seen_by(viewer).map(func(p: Dictionary) -> String: return p["id"])
	var mines: Array = []
	for m: Dictionary in _mines[viewer]:
		mines.append({"x": m["x"], "y": m["y"], "kind": m.get("kind", "mine"),
			"turns_left": _turns_left({"side": viewer, "from_turn": m.get("from_turn", 0), "to_turn": m["until_turn"]})})
	var slots: Array = []
	for id: String in loadouts[viewer]:
		slots.append({"id": id, "used": used[viewer].has(id)})
	var my_turn := turn == viewer and not is_over()
	var next_turn: int = _turns[viewer] if my_turn else _turns[viewer] + 1
	var sabotage := _effect("sabotage", viewer, "", -1)
	var eliminated := {Ranks.WHITE: 0, Ranks.BLACK: 0}
	for gone: Dictionary in _eliminated:
		eliminated[gone["side"]] += 1
	if fog_against(viewer):
		eliminated[enemy] = _fog["eliminated"]
	return {
		"eliminated": eliminated,
		"turn_deadline": clock_view["deadline"],
		"turn_seconds": clock_view["seconds"],
		"base_turn_seconds": turn_seconds if turn_seconds > 0 else null,
		"server_time": clock_view["server_time"],
		"timer": clock_view,
		"powerup_mode": powerup_mode,
		"powerups": {"mine": slots, "opponent_used": used[enemy].duplicate(), "turn_number": _turns[viewer],
			"used_this_turn": used_this_turn(viewer) if my_turn else 0, "per_turn": PowerupLibrary.MAX_PER_TURN,
			"blocked": not _effect("sabotage", viewer, "", next_turn).is_empty(),
			"blocked_until_turn": sabotage.get("to_turn")},
		"revealed": _revealed[viewer].filter(func(e: Dictionary) -> bool: return is_over() or shown_ids.has(e["piece_id"])),
		"intel": _intel[viewer].duplicate(true),
		"effects": _effects_view(viewer),
		"fog": fog_against(viewer) and not is_over(),
		"mines": mines,
		"jammed_until": {Ranks.WHITE: _iso(_jammed_until[Ranks.WHITE]) if jammed(Ranks.WHITE) else null,
			Ranks.BLACK: _iso(_jammed_until[Ranks.BLACK]) if jammed(Ranks.BLACK) else null},
	}


## Smoke cast by `viewer`'s opponent is hiding their army from `viewer`.
func fog_against(viewer: String) -> bool:
	return not _fog.is_empty() and _fog["side"] == Ranks.opponent(viewer)


static func is_own_half(side: String, cell: Vector2i) -> bool:
	if not Ranks.in_bounds(cell):
		return false
	return cell.y * 2 < Ranks.ROWS if side == Ranks.WHITE else cell.y * 2 >= Ranks.ROWS


static func back_row(side: String) -> int:
	return 0 if side == Ranks.WHITE else Ranks.ROWS - 1


# --- Powerup effects (PowerupEngine) --------------------------------------------------------------

## {private, public, forget} on success, {error} when the target doesn't fit.
func _apply_powerup(id: String, side: String, target: Dictionary) -> Dictionary:
	var enemy := Ranks.opponent(side)
	var now_turn: int = _turns[side]
	var next: int = _turns[enemy] + 1
	match id:
		"time_extension":
			return _window(id, side, side, now_turn + 1, PowerupLibrary.BUFF_TURNS, PowerupLibrary.TIME_BONUS)
		"time_squeeze":
			return _window(id, enemy, side, next, PowerupLibrary.BUFF_TURNS, -PowerupLibrary.TIME_PENALTY)
		"quick_step":
			return _window(id, side, side, now_turn + 1, 1)
		"sabotage":
			return _window(id, enemy, side, next, PowerupLibrary.SABOTAGE_TURNS)
		"freeze":
			var victim := _enemy_piece(side, target)
			if victim.is_empty():
				return {"error": "Pick one of the enemy's pieces."}
			_add_effect("freeze", enemy, side, {"piece_id": victim["id"], "from_turn": next, "to_turn": next + PowerupLibrary.FREEZE_TURNS - 1})
			var frozen := {"piece_id": victim["id"], "turns": PowerupLibrary.FREEZE_TURNS}
			return {"private": frozen, "public": frozen}
		"fortify":
			var guarded := _own_piece(side, target)
			if guarded.is_empty():
				return {"error": "Pick one of your pieces."}
			_add_effect("fortify", side, side, {"piece_id": guarded["id"], "from_turn": now_turn, "to_turn": now_turn + PowerupLibrary.FORTIFY_TURNS})
			return {"private": {"piece_id": guarded["id"], "turns": PowerupLibrary.FORTIFY_TURNS}}
		"decoy":
			var disguised := _own_piece(side, target)
			if disguised.is_empty():
				return {"error": "Pick one of your pieces."}
			var fake := _fake_rank(disguised)
			_add_effect("decoy", side, side, {"piece_id": disguised["id"], "fake_rank": fake})
			return {"private": {"piece_id": disguised["id"], "fake_rank": fake}}
		"second_chance", "rally_cry":
			_add_effect(id, side, side, {})
			return {}
		"spy_card":
			var hidden: Array = _side_pieces(enemy).filter(func(p: Dictionary) -> bool: return known_rank(side, p["id"]) == "")
			if hidden.is_empty():
				return {"error": "Every enemy piece is already revealed."}
			var spied: Dictionary = hidden.pick_random()
			var rank := _apparent_rank(spied)
			_reveal(side, {"piece_id": spied["id"], "rank": rank, "source": "spy_card"})
			return {"private": {"piece_id": spied["id"], "rank": rank}}
		"insight":
			var officers := 0
			for p: Dictionary in _side_pieces(enemy):
				if int(Ranks.INFO[p["rank"]]["power"]) >= int(Ranks.INFO["SGT"]["power"]):
					officers += 1
			_intel[side].append({"type": "insight", "officers": officers, "move_number": move_number})
			return {"private": {"officers": officers}}
		"intel_leak":
			var last: String = _last_moved[enemy]
			if last == "":
				return {"error": "The enemy hasn't moved yet."}
			if not pieces.has(last):
				return {"error": "The last enemy piece to move is no longer on the board."}
			var rank := _apparent_rank(pieces[last])
			_reveal(side, {"piece_id": last, "rank": rank, "source": "intel_leak"})
			return {"private": {"piece_id": last, "rank": rank}}
		"recon_drone":
			var scanned := _enemy_piece(side, target)
			if scanned.is_empty():
				return {"error": "Pick one of the enemy's pieces."}
			var is_flag := _apparent_rank(scanned) == "FLG"
			_reveal(side, {"piece_id": scanned["id"], "is_flag": is_flag, "source": "recon_drone"})
			return {"private": {"piece_id": scanned["id"], "is_flag": is_flag}}
		"scout_report":
			var hidden: Array = _side_pieces(enemy).filter(func(p: Dictionary) -> bool: return not _knows_group(side, p["id"]))
			if hidden.is_empty():
				return {"error": "No hidden enemy pieces are left to scout."}
			hidden.shuffle()
			var report: Array = []
			for scouted: Dictionary in hidden.slice(0, PowerupLibrary.SCOUT_COUNT):
				var group := PowerupLibrary.group_of(_apparent_rank(scouted))
				_reveal(side, {"piece_id": scouted["id"], "group": group, "source": "scout_report"})
				report.append({"piece_id": scouted["id"], "group": group})
			return {"private": {"pieces": report}, "public": {"count": report.size()}}
		"flag_hunter":
			var flag := {}
			for p: Dictionary in _side_pieces(enemy):
				if p["rank"] == "FLG":
					flag = p
			if flag.is_empty():
				return {"error": "The enemy Flag is not on the board."}
			for seen: Dictionary in _enemies_seen_by(side):  # Behind smoke, read the board you can see.
				if seen["id"] == flag["id"]:
					flag = seen
			_intel[side].append({"type": "flag_hunter", "x": flag["x"], "move_number": move_number})
			return {"private": {"x": flag["x"]}}
		"swap":
			var ids: Variant = target.get("piece_ids")
			if not ids is Array or ids.size() != 2 or not ids[0] is String or not ids[1] is String or ids[0] == ids[1]:
				return {"error": "Pick two of your pieces."}
			var a := _own_piece(side, {"piece_id": ids[0]})
			var b := _own_piece(side, {"piece_id": ids[1]})
			if a.is_empty() or b.is_empty():
				return {"error": "Pick two of your pieces."}
			if is_frozen(side, a["id"]) or is_frozen(side, b["id"]):
				return {"error": "That piece is frozen."}
			if (a["rank"] == "FLG" and b["y"] == Ranks.goal_row(side)) or (b["rank"] == "FLG" and a["y"] == Ranks.goal_row(side)):
				return {"error": "The Flag can't be swapped onto the enemy's back row."}
			var cell_a := Vector2i(a["x"], a["y"])
			var cell_b := Vector2i(b["x"], b["y"])
			_place(a, cell_b)
			_place(b, cell_a)
			_drop_pending_flag([a["id"], b["id"]])
			var info := {"pieces": [{"id": a["id"], "x": cell_b.x, "y": cell_b.y}, {"id": b["id"], "x": cell_a.x, "y": cell_a.y}]}
			return {"private": info, "public": info}
		"teleport":
			var jumper := _own_piece(side, target)
			if jumper.is_empty():
				return {"error": "Pick one of your pieces."}
			if is_frozen(side, jumper["id"]):
				return {"error": "That piece is frozen."}
			var cell := _cell(target)
			if cell == Vector2i(-1, -1):
				return {"error": "Pick a square on the board."}
			if not Ranks.is_home_cell(side, cell) or not piece_at(cell).is_empty() or is_blocked(cell):
				return {"error": "Pick an empty square in your three home rows."}
			var info := {"piece_id": jumper["id"], "from": {"x": jumper["x"], "y": jumper["y"]}, "to": {"x": cell.x, "y": cell.y}}
			_place(jumper, cell)
			_drop_pending_flag([jumper["id"]])
			return {"private": info, "public": info}
		"mine_field":
			var cell := _cell(target)
			if cell == Vector2i(-1, -1):
				return {"error": "Pick a square on the board."}
			if not is_own_half(side, cell) or not piece_at(cell).is_empty() or _mine_index(side, cell) >= 0 or is_blocked(cell):
				return {"error": "Pick an empty square on your half of the board."}
			_mines[side].append({"x": cell.x, "y": cell.y, "from_turn": now_turn + 1, "until_turn": now_turn + PowerupLibrary.MINE_TURNS, "kind": "mine"})
			return {"private": {"x": cell.x, "y": cell.y, "turns": PowerupLibrary.MINE_TURNS}}
		"reinforcement":
			var cell := _cell(target)
			if cell == Vector2i(-1, -1):
				return {"error": "Pick a square on the board."}
			if cell.y != back_row(side) or not piece_at(cell).is_empty() or is_blocked(cell):
				return {"error": "Pick an empty square on your back row."}
			var index := -1
			for i in _eliminated.size():
				if _eliminated[i]["side"] == side and _eliminated[i]["rank"] == "PVT":
					index = i
					break
			if index < 0:
				return {"error": "None of your Privates has been eliminated."}
			_eliminated.remove_at(index)
			var recruit := _add_piece(side, "PVT", cell)
			# The rules say what came back, so the opponent knows it is a Private.
			_reveal(enemy, {"piece_id": recruit["id"], "rank": "PVT", "source": "reinforcement"})
			return {"private": {"piece": {"id": recruit["id"], "x": cell.x, "y": cell.y, "rank": "PVT"}},
				"public": {"piece": {"id": recruit["id"], "x": cell.x, "y": cell.y}}}
		"shuffle":
			var pending: String = _pending_flag.get("id", "")
			var hidden: Array = _side_pieces(side).filter(func(p: Dictionary) -> bool:
				return p["id"] != pending and known_rank(enemy, p["id"]) == "")
			var pairs: Array = []
			for i in hidden.size():
				for j in range(i + 1, hidden.size()):
					var a: Dictionary = hidden[i]
					var b: Dictionary = hidden[j]
					var flag_onto_goal: bool = (a["rank"] == "FLG" and b["y"] == Ranks.goal_row(side)) \
						or (b["rank"] == "FLG" and a["y"] == Ranks.goal_row(side))
					if a["rank"] != b["rank"] and not flag_onto_goal:
						pairs.append([a, b])
			if pairs.is_empty():
				return {"error": "You have no hidden pieces to shuffle."}
			var pair: Array = pairs.pick_random()
			var rank: String = pair[0]["rank"]
			pair[0]["rank"] = pair[1]["rank"]
			pair[1]["rank"] = rank
			var ids: Array = [pair[0]["id"], pair[1]["id"]]
			_revealed[enemy] = _revealed[enemy].filter(func(e: Dictionary) -> bool: return not ids.has(e["piece_id"]))
			return {"private": {"piece_ids": ids}, "forget": ids}
		"smoke_screen":
			_smoke = side
			return {}
		"chaos_order":
			_chaos = enemy
			return {}
		"double_march":
			_march = {"side": side, "first": ""}
			return {}
		"jammer":
			_jammed_until[enemy] = now() + PowerupLibrary.JAM_SECONDS
			var info := {"side": enemy, "jammed_until": _iso(_jammed_until[enemy])}
			return {"private": info, "public": info}
		"blitz":
			_add_effect("blitz", side, side, {"from_turn": now_turn + 1, "to_turn": now_turn + PowerupLibrary.BLITZ_TURNS})
			_add_effect("blitz", enemy, side, {"from_turn": next, "to_turn": next + PowerupLibrary.BLITZ_TURNS - 1})
			return {"private": {"turns": PowerupLibrary.BLITZ_TURNS}, "public": {"turns": PowerupLibrary.BLITZ_TURNS}}
		"time_steal":
			var turns := PowerupLibrary.STEAL_TURNS
			_add_effect("time_steal", side, side, {"from_turn": now_turn + 1, "to_turn": now_turn + turns, "seconds": PowerupLibrary.STEAL_SECONDS})
			_add_effect("time_steal", enemy, side, {"from_turn": next, "to_turn": next + turns - 1, "seconds": -PowerupLibrary.STEAL_SECONDS})
			var stolen := {"turns": turns, "seconds": PowerupLibrary.STEAL_SECONDS}
			return {"private": stolen, "public": stolen}
		"sonar_ping":
			var count := 0
			for seen: Dictionary in _enemies_seen_by(side):
				if is_own_half(side, Vector2i(seen["x"], seen["y"])):
					count += 1
			_intel[side].append({"type": "sonar_ping", "count": count, "move_number": move_number})
			return {"private": {"count": count}}
		"spy_alarm":
			var alarm := false
			for seen: Dictionary in _enemies_seen_by(side):
				if not pieces.has(seen["id"]) or _apparent_rank(pieces[seen["id"]]) != "SPY":
					continue
				for p: Dictionary in _side_pieces(side):
					if absi(p["x"] - seen["x"]) + absi(p["y"] - seen["y"]) == 1:
						alarm = true
			_intel[side].append({"type": "spy_alarm", "alarm": alarm, "move_number": move_number})
			return {"private": {"alarm": alarm}}
		"radar_sweep":
			var center := _cell(target)
			if center == Vector2i(-1, -1):
				return {"error": "Pick a square on the board."}
			var found := false
			for seen: Dictionary in _enemies_seen_by(side):
				if pieces.has(seen["id"]) and absi(seen["x"] - center.x) <= 1 and absi(seen["y"] - center.y) <= 1 \
						and PowerupLibrary.group_of(_apparent_rank(pieces[seen["id"]])) == "general":
					found = true
			_intel[side].append({"type": "radar_sweep", "x": center.x, "y": center.y, "found": found, "move_number": move_number})
			return {"private": {"x": center.x, "y": center.y, "found": found}}
		"code_breaker":
			var cards: Array = loadouts[enemy].filter(func(card: String) -> bool: return not used[enemy].has(card))
			_intel[side].append({"type": "code_breaker", "cards": cards.duplicate(), "move_number": move_number})
			return {"private": {"cards": cards}}
		"interrogation":
			var suspect := _enemy_piece(side, target)
			if suspect.is_empty():
				return {"error": "Pick one of the enemy's pieces."}
			var seen_at := Vector2i(suspect["x"], suspect["y"])
			for seen: Dictionary in _enemies_seen_by(side):
				if seen["id"] == suspect["id"]:
					seen_at = Vector2i(seen["x"], seen["y"])
			var adjacent := false
			for p: Dictionary in _side_pieces(side):
				if absi(p["x"] - seen_at.x) + absi(p["y"] - seen_at.y) == 1:
					adjacent = true
			if not adjacent:
				return {"error": "Pick an enemy piece standing next to one of yours."}
			var told := _apparent_rank(suspect)
			_reveal(side, {"piece_id": suspect["id"], "rank": told, "source": "interrogation"})
			return {"private": {"piece_id": suspect["id"], "rank": told}}
		"retreat":
			var runner := _own_piece(side, target)
			if runner.is_empty():
				return {"error": "Pick one of your pieces."}
			if is_frozen(side, runner["id"]):
				return {"error": "That piece is frozen."}
			var step := -1 if side == Ranks.WHITE else 1
			var start := Vector2i(runner["x"], runner["y"])
			var dest := start
			for i in PowerupLibrary.RETREAT_SQUARES:
				var further := dest + Vector2i(0, step)
				if not Ranks.in_bounds(further) or not piece_at(further).is_empty() or is_blocked(further):
					break
				dest = further
			if dest == start:
				return {"error": "That piece has no room to fall back."}
			_place(runner, dest)
			_drop_pending_flag([runner["id"]])
			var moved := {"piece_id": runner["id"], "from": {"x": start.x, "y": start.y}, "to": {"x": dest.x, "y": dest.y}}
			return {"private": moved, "public": moved}
		"haste":
			return _window(id, side, side, now_turn, 1)
		"roadblock":
			var spot := _cell(target)
			if spot == Vector2i(-1, -1):
				return {"error": "Pick a square on the board."}
			if not piece_at(spot).is_empty() or is_blocked(spot):
				return {"error": "Pick an empty square."}
			_add_effect("roadblock", enemy, side, {"x": spot.x, "y": spot.y, "from_turn": next, "to_turn": next + PowerupLibrary.ROADBLOCK_TURNS - 1})
			var barred := {"x": spot.x, "y": spot.y, "turns": PowerupLibrary.ROADBLOCK_TURNS}
			return {"private": barred, "public": barred}
		"quicksand":
			var pit := _cell(target)
			if pit == Vector2i(-1, -1):
				return {"error": "Pick a square on the board."}
			if not is_own_half(side, pit) or not piece_at(pit).is_empty() or _mine_index(side, pit) >= 0 or is_blocked(pit):
				return {"error": "Pick an empty square on your half of the board."}
			_mines[side].append({"x": pit.x, "y": pit.y, "from_turn": now_turn + 1, "until_turn": now_turn + PowerupLibrary.QUICKSAND_TURNS, "kind": "quicksand"})
			return {"private": {"x": pit.x, "y": pit.y, "turns": PowerupLibrary.QUICKSAND_TURNS}}
		"counterspell":
			_add_effect("counterspell", enemy, side, {})
			return {}
		"trench":
			var dug := _own_piece(side, target)
			if dug.is_empty():
				return {"error": "Pick one of your pieces."}
			_add_effect("trench", side, side, {"piece_id": dug["id"], "from_turn": now_turn + 1, "to_turn": now_turn + PowerupLibrary.TRENCH_TURNS})
			return {"private": {"piece_id": dug["id"], "turns": PowerupLibrary.TRENCH_TURNS}}
		"ceasefire":
			return _window(id, enemy, side, next, PowerupLibrary.CEASEFIRE_TURNS)
		"counter_intel":
			var wiped: Array = []
			for entry: Dictionary in _revealed[enemy]:
				if not wiped.has(entry["piece_id"]):
					wiped.append(entry["piece_id"])
			_revealed[enemy] = []
			return {"private": {"wiped": wiped.size()}, "public": {"wiped": wiped.size()}, "forget": wiped}
		"promotion":
			var recruit := _own_piece(side, target)
			if recruit.is_empty() or recruit["rank"] != "PVT":
				return {"error": "Pick one of your Privates."}
			recruit["rank"] = "SGT"
			_revealed[enemy] = _revealed[enemy].filter(func(e: Dictionary) -> bool: return e["piece_id"] != recruit["id"])
			return {"private": {"piece_id": recruit["id"], "rank": "SGT"}, "forget": [recruit["id"]]}
		"recall":
			var back := ""
			for i in range(_used_log[side].size() - 1, -1, -1):
				var card: String = _used_log[side][i]
				if card != "recall" and used[side].has(card):
					back = card
					break
			if back == "":
				return {"error": "You haven't played another powerup yet."}
			used[side].erase(back)
			return {"private": {"recalled": back}, "public": {"recalled": back}}
	return {"error": "That powerup does not exist."}


## A turn-window effect: Time Extension, Time Squeeze, Quick Step, Sabotage.
func _window(type: String, side: String, by: String, from: int, turns: int, seconds := 0) -> Dictionary:
	var extra := {"from_turn": from, "to_turn": from + turns - 1}
	var info := {"turns": turns}
	if seconds != 0:
		extra["seconds"] = seconds
		info["seconds"] = seconds
	_add_effect(type, side, by, extra)
	return {"private": info, "public": info}


func _add_effect(type: String, side: String, by: String, extra: Dictionary) -> void:
	_seq += 1
	var effect := {"seq": _seq, "type": type, "side": side, "by": by}
	effect.merge(extra)
	_effects.append(effect)


## The first matching effect; with `at_turn` >= 0 a window effect only counts when that turn of its
## side falls inside the window.
func _effect(type: String, side: String, piece_id := "", at_turn := -1) -> Dictionary:
	for e: Dictionary in _effects:
		if e["type"] != type or e["side"] != side:
			continue
		if piece_id != "" and e.get("piece_id", "") != piece_id:
			continue
		if at_turn >= 0 and (at_turn < int(e.get("from_turn", -999999)) or at_turn > int(e.get("to_turn", 999999))):
			continue
		return e
	return {}


## Uses up a one-shot effect (Fortify, Second Chance, Rally Cry). True if there was one.
func _consume(type: String, side: String, piece_id := "") -> bool:
	var e := _effect(type, side, piece_id)
	if e.is_empty():
		return false
	_effects.erase(e)
	return true


## Turns of the effect's side still covered, counting the running turn if it is that side's.
func _turns_left(effect: Dictionary) -> Variant:
	if not effect.has("to_turn"):
		return null
	var side: String = effect["side"]
	var current: int = _turns[side] if turn == side else _turns[side] + 1
	return maxi(0, int(effect["to_turn"]) - maxi(int(effect.get("from_turn", current)), current) + 1)


## `mine`: effects the viewer created (secrets included); `opponent`: the opponent's effects the
## viewer may see. Plus armed Smoke/Chaos, an active fog, a Double March and Jammers.
func _effects_view(viewer: String) -> Dictionary:
	var enemy := Ranks.opponent(viewer)
	var mine: Array = []
	var theirs: Array = []
	for e: Dictionary in _effects:
		var shown := {"type": e["type"], "side": e["side"]}
		for key: String in ["piece_id", "seconds", "x", "y"]:
			if e.has(key):
				shown[key] = e[key]
		if e.has("to_turn"):
			shown["turns_left"] = _turns_left(e)
		if e["by"] == viewer:
			if e.has("fake_rank"):
				shown["fake_rank"] = e["fake_rank"]
			mine.append(shown)
		elif e["type"] in VISIBLE_EFFECTS:
			theirs.append(shown)
	var armed := {"smoke_screen": _smoke, "chaos_order": Ranks.opponent(_chaos) if _chaos != "" else ""}
	for type: String in armed:
		var by: String = armed[type]
		if by == viewer:
			mine.append({"type": type, "side": enemy if type == "chaos_order" else viewer, "armed": true})
		elif by == enemy:
			theirs.append({"type": type, "side": viewer if type == "chaos_order" else enemy, "armed": true})
	if fog_against(enemy):
		mine.append({"type": "smoke_screen", "side": viewer, "active": true})
	elif fog_against(viewer):
		theirs.append({"type": "smoke_screen", "side": enemy, "active": true})
	if not _march.is_empty() and _march["side"] == viewer:
		mine.append({"type": "double_march", "side": viewer, "first_piece_id": _march["first"] if _march["first"] != "" else null})
	elif not _march.is_empty() and _march["side"] == enemy:
		theirs.append({"type": "double_march", "side": enemy, "moves_left": 2 if _march["first"] == "" else 1})
	if jammed(enemy):
		mine.append({"type": "jammer", "side": enemy, "until": _iso(_jammed_until[enemy])})
	if jammed(viewer):
		theirs.append({"type": "jammer", "side": viewer, "until": _iso(_jammed_until[viewer])})
	return {"mine": mine, "opponent": theirs}


func _reveal(viewer: String, entry: Dictionary) -> void:
	entry["move_number"] = move_number
	_revealed[viewer].append(entry)


func _knows_group(viewer: String, piece_id: String) -> bool:
	for entry: Dictionary in _revealed[viewer]:
		if entry["piece_id"] == piece_id and (entry.has("rank") or entry.has("group")):
			return true
	return false


## What enemy intel reports for a piece: the truth, or its Decoy's lie (a fresh lie if a Shuffle
## turned the old one into the truth).
func _apparent_rank(piece: Dictionary) -> String:
	var decoy := _effect("decoy", piece["side"], piece["id"])
	if decoy.is_empty():
		return piece["rank"]
	if decoy["fake_rank"] == piece["rank"]:
		decoy["fake_rank"] = _fake_rank(piece)
	return decoy["fake_rank"]


func _fake_rank(piece: Dictionary) -> String:
	var options: Array = []
	for p: Dictionary in _side_pieces(piece["side"]):
		if p["rank"] != piece["rank"] and not options.has(p["rank"]):
			options.append(p["rank"])
	if options.is_empty():
		options = Ranks.INFO.keys().filter(func(code: String) -> bool: return code != piece["rank"])
	return options.pick_random()


# --- Internals ----------------------------------------------------------------------------------

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "result": {}, "event": {}, "ends_turn": false, "forget": []}


func _add_piece(side: String, rank: String, cell: Vector2i) -> Dictionary:
	var id := "p%02d" % _next_id
	_next_id += 1
	pieces[id] = {"id": id, "side": side, "rank": rank, "x": cell.x, "y": cell.y}
	return pieces[id]


func _place(piece: Dictionary, cell: Vector2i) -> void:
	piece["x"] = cell.x
	piece["y"] = cell.y


func _side_pieces(side: String) -> Array:
	return pieces.values().filter(func(p: Dictionary) -> bool: return p["side"] == side)


## The enemy army as `viewer` sees it: as it stood before a smoke-screened move while the fog lasts.
func _enemies_seen_by(viewer: String) -> Array:
	if fog_against(viewer) and not is_over():
		return _fog["pieces"]
	return _side_pieces(Ranks.opponent(viewer))


func _march_first(side: String) -> String:
	return str(_march["first"]) if not _march.is_empty() and _march["side"] == side else ""


## Resolve an attack. Fortify bounces it; Rally Cry turns a tie into a win; Second Chance saves a
## piece that would fall (it stays where it stood, so the attacker only advances onto a square that
## emptied). Returns [clash payload, removed pieces].
func _clash(attacker: Dictionary, defender: Dictionary, to: Vector2i) -> Array:
	var attacker_side: String = attacker["side"]
	var defender_side: String = defender["side"]
	if _consume("fortify", defender_side, defender["id"]):
		return [{"defender_id": defender["id"], "outcome": "bounce", "eliminated": []}, []]
	var outcome := Ranks.resolve_clash(attacker["rank"], defender["rank"])
	var rally := ""
	var trench := false
	if outcome == "both" and _consume("trench", defender_side, defender["id"]):
		outcome = "defender"
		trench = true
	if outcome == "both":
		var attacker_rally := _consume("rally_cry", attacker_side)
		var defender_rally := _consume("rally_cry", defender_side)
		if attacker_rally != defender_rally:
			rally = attacker_side if attacker_rally else defender_side
			outcome = "attacker" if attacker_rally else "defender"
	var doomed: Array = {"attacker": [defender], "defender": [attacker], "both": [defender, attacker]}[outcome]
	var removed: Array = []
	var saved: Array = []
	for piece: Dictionary in doomed:
		if _consume("second_chance", piece["side"]):
			saved.append(piece["id"])
		else:
			pieces.erase(piece["id"])
			removed.append(piece.duplicate())
	if outcome == "attacker" and not pieces.has(defender["id"]) and pieces.has(attacker["id"]):
		_place(attacker, to)
	clash_log.append({
		"move_number": move_number, "outcome": outcome,
		"attacker": {"id": attacker["id"], "side": attacker_side, "rank": attacker["rank"]},
		"defender": {"id": defender["id"], "side": defender_side, "rank": defender["rank"]},
	})
	var clash := {"defender_id": defender["id"], "outcome": outcome, "eliminated": removed.map(func(p: Dictionary) -> String: return p["id"])}
	if not saved.is_empty():
		clash["saved"] = saved
	if rally != "":
		clash["rally"] = rally
	if trench:
		clash["trench"] = defender_side
	return [clash, removed]


## A piece that ended its step on an enemy Mine Field square is eliminated (a clash with outcome
## "mine"), unless Second Chance saves it. Quicksand instead sticks it (frozen) for its owner's next
## turns. Returns [clash, removed, quicksand {x, y, piece_id, turns} or null].
func _trip_mine(side: String, piece_id: String, cell: Vector2i, clash: Variant, removed: Array) -> Array:
	var piece: Dictionary = pieces.get(piece_id, {})
	var enemy := Ranks.opponent(side)
	if piece.is_empty() or Vector2i(piece["x"], piece["y"]) != cell or _mine_index(enemy, cell) < 0:
		return [clash, removed, null]
	var trap: Dictionary = _mines[enemy][_mine_index(enemy, cell)]
	_mines[enemy].remove_at(_mine_index(enemy, cell))
	if trap.get("kind", "mine") == "quicksand":
		var next: int = _turns[side] + 1
		_add_effect("freeze", side, enemy, {"piece_id": piece_id, "from_turn": next, "to_turn": next + PowerupLibrary.QUICKSAND_STUCK_TURNS - 1})
		return [clash, removed, {"x": cell.x, "y": cell.y, "piece_id": piece_id, "turns": PowerupLibrary.QUICKSAND_STUCK_TURNS}]
	if clash == null:
		clash = {"defender_id": null, "outcome": "mine", "eliminated": []}
	clash["mine"] = {"x": cell.x, "y": cell.y}
	if _consume("second_chance", side):
		clash["saved"] = clash.get("saved", []) + [piece_id]
	else:
		pieces.erase(piece_id)
		removed.append(piece.duplicate())
		clash["eliminated"].append(piece_id)
	return [clash, removed, null]


## Whether the step that just happened ends the game at once. A Flag that reaches the back row next
## to an enemy is held back until the reply (settled in _end_turn).
func _victory(side: String, moved_id: String, removed: Array) -> void:
	for gone: Dictionary in removed:
		if gone["rank"] == "FLG":
			_finish(Ranks.opponent(gone["side"]), "flag_captured")
			return
	var flag: Dictionary = pieces.get(moved_id, {})
	if flag.is_empty() or flag["rank"] != "FLG" or flag["y"] != Ranks.goal_row(side):
		return
	if _enemy_adjacent(Vector2i(flag["x"], flag["y"]), side):
		_pending_flag = {"id": moved_id, "side": side}
	else:
		_finish(side, "flag_reached")


## The side's turn is over: a Flag still waiting on its back row after this reply wins, fog that
## lasted for this turn lifts, the opponent's turn starts. Returns whether fog lifted.
func _end_turn(side: String) -> bool:
	_march = {}
	if not _pending_flag.is_empty() and _pending_flag["side"] != side:
		var pending := _pending_flag
		_pending_flag = {}
		if pieces.has(pending["id"]):
			_finish(pending["side"], "flag_reached")
			return false
	var lifted := false
	if not _fog.is_empty() and _fog["side"] != side and _turns[side] >= int(_fog["until_turn"]):
		_fog = {}
		lifted = true
	turn = Ranks.opponent(side)
	if _stuck(turn):
		_finish(side, "no_moves")  # Offline shortcut: nothing could ever move again.
	else:
		_begin_turn(turn)
	return lifted


## True when `side` has no piece with anywhere to go, frozen or not.
func _stuck(side: String) -> bool:
	for p: Dictionary in pieces.values():
		if p["side"] != side:
			continue
		for to in Ranks.neighbors(Vector2i(p["x"], p["y"])):
			var other := piece_at(to)
			if other.is_empty() or other["side"] != side:
				return false
	return true


## Count the new turn, drop expired effects and mines, and set the clock: the base allotment
## adjusted by Time Extension / Time Squeeze; a Quick Step turn shows no clock.
func _begin_turn(side: String) -> void:
	_turns[side] += 1
	var t: int = _turns[side]
	_effects = _effects.filter(func(e: Dictionary) -> bool:
		return e["side"] != side or not e.has("to_turn") or int(e["to_turn"]) >= t)
	_mines[side] = _mines[side].filter(func(m: Dictionary) -> bool: return int(m["until_turn"]) >= t)
	if turn_seconds <= 0 or is_over():
		turn_deadline = 0.0
		turn_paused = false
		turn_allotment = 0
		return
	var seconds := turn_seconds
	for type: String in CLOCK_EFFECTS:
		seconds += int(_effect(type, side, "", t).get("seconds", 0))
	if not _effect("blitz", side, "", t).is_empty():
		seconds = ceili(seconds / 2.0)
	if seconds < turn_seconds:
		seconds = maxi(mini(turn_seconds, PowerupLibrary.MIN_TURN_SECONDS), seconds)
	turn_paused = not _effect("quick_step", side, "", t).is_empty()
	turn_allotment = seconds
	turn_deadline = now() + (QUICK_STEP_MAX if turn_paused else float(seconds))


func _start_fog(side: String) -> void:
	if _fog.get("side", "") == side:
		return
	var enemy := Ranks.opponent(side)
	var lost := 0
	for gone: Dictionary in _eliminated:
		if gone["side"] == side:
			lost += 1
	var snapshot: Array = []
	for p: Dictionary in _side_pieces(side):
		snapshot.append(p.duplicate())
	_fog = {"side": side, "pieces": snapshot, "eliminated": lost, "until_turn": _turns[enemy] + 1}


func _drop_pending_flag(moved: Array) -> void:
	if not _pending_flag.is_empty() and moved.has(_pending_flag["id"]):
		_pending_flag = {}


func _finish(side: String, reason: String) -> void:
	if winner == "":
		winner = side
		end_reason = reason
		turn = ""
		turn_deadline = 0.0


func _enemy_adjacent(cell: Vector2i, side: String) -> bool:
	for n in Ranks.neighbors(cell):
		var p := piece_at(n)
		if not p.is_empty() and p["side"] != side:
			return true
	return false


func _mine_index(owner: String, cell: Vector2i) -> int:
	for i in _mines[owner].size():
		var m: Dictionary = _mines[owner][i]
		if m["x"] == cell.x and m["y"] == cell.y:
			return i
	return -1


func _own_piece(side: String, target: Dictionary) -> Dictionary:
	var piece: Dictionary = pieces.get(str(target.get("piece_id", "")), {})
	return piece if not piece.is_empty() and piece["side"] == side else {}


func _enemy_piece(side: String, target: Dictionary) -> Dictionary:
	var piece: Dictionary = pieces.get(str(target.get("piece_id", "")), {})
	return piece if not piece.is_empty() and piece["side"] != side else {}


func _cell(target: Dictionary) -> Vector2i:
	var x: Variant = target.get("x")
	var y: Variant = target.get("y")
	if not (x is int or x is float) or not (y is int or y is float):
		return Vector2i(-1, -1)
	var cell := Vector2i(int(x), int(y))
	return cell if Ranks.in_bounds(cell) else Vector2i(-1, -1)


static func _iso(unix: float) -> String:
	var whole := floori(unix)
	return "%s.%03dZ" % [Time.get_datetime_string_from_unix_time(whole), int((unix - whole) * 1000.0)]
