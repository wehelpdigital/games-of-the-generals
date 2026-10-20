class_name SalpakanAI
extends RefCounted
## Offline opponent for practice games. No network, no language model: plain game-tree search.
##
## It plays fair. It knows its own ranks and learns about the player's pieces only the way a human
## would: from clash outcomes (it knows which of its own ranks was involved) and from how pieces
## move. Each enemy piece carries a set of ranks it could still be. To pick a move the AI samples
## complete rank assignments consistent with everything observed, scores every legal move across
## those samples, and on Hard also looks one reply ahead. Work is spread across frames, so the game
## never stalls, even on single-threaded web builds.
##
##     var ai := SalpakanAI.new(Ranks.BLACK, SalpakanAI.Difficulty.HARD)
##     arbiter.deploy(Ranks.BLACK, ai.choose_formation())
##     ai.begin(arbiter.observation(Ranks.BLACK))
##     ai.observe(move_result)                       # after every move, both sides
##     var move := await ai.choose_move(arbiter.observation(Ranks.BLACK))  # {id, from, to}

enum Difficulty { EASY, MEDIUM, HARD }

const LABELS := {Difficulty.EASY: "Rookie", Difficulty.MEDIUM: "Officer", Difficulty.HARD: "General"}
const SETTINGS := {
	Difficulty.EASY: {"samples": 4, "depth": 1, "noise": 3.5, "blunder": 0.25, "smart_setup": false},
	Difficulty.MEDIUM: {"samples": 14, "depth": 1, "noise": 0.8, "blunder": 0.0, "smart_setup": true},
	Difficulty.HARD: {"samples": 24, "depth": 2, "noise": 0.2, "blunder": 0.0, "smart_setup": true, "shortlist": 8},
}

const RANK_COUNT := 15
const FLAG := 14
const ME := 1
const THEM := 2
const ATTACKER_WINS := 0
const DEFENDER_WINS := 1
const BOTH_OUT := 2
const ALL_RANKS := (1 << RANK_COUNT) - 1
const FLAG_BIT := 1 << FLAG

## Material per rank index (G5 … PVT, SPY, FLG). A spy is worth a general: it is the answer to one.
const VALUES: Array[float] = [30.0, 24.0, 19.0, 15.0, 12.0, 10.0, 8.5, 7.0, 5.5, 4.5, 3.5, 2.5, 1.5, 13.0, 0.0]
const WIN := 10000.0
const FLAG_RISK := 60.0      ## Cost of leaving the flag where an enemy could take it.
const RISK_MAIN := 0.75      ## Share of the biggest piece the opponent can win next move.
const RISK_OTHER := 0.15     ## …and of every other piece left en prise.
const GAIN_MAIN := 0.5       ## Share of the best capture available to us next move.
const ADVANCE := 0.06        ## Per row advanced, for pieces other than the flag.
const FLAG_PRESSURE := 2.5   ## Per enemy piece within two steps of our flag.
const GUARD_BONUS := 0.6     ## Per friendly piece beside our flag (up to two).
const HUNT := 0.2            ## Per step between our closest piece and the (sampled) enemy flag.
const SHUFFLE_PENALTY := 0.6 ## Discourages undoing our own previous move.
const FRAME_BUDGET_MS := 6

static var _outcome: PackedInt32Array   # [attacker * 15 + defender] -> who survives
static var _neighbors: Array[PackedInt32Array] = []
static var _counts: PackedInt32Array    # pieces per rank in a full set

var side: String
var difficulty: Difficulty

var _settings: Dictionary
var _my_goal_row: int
var _their_goal_row: int   # Also the row our own flag starts on.
var _progress: PackedInt32Array
var _my_ranks: Dictionary = {}      # my piece id -> rank index
var _enemy_mask: Dictionary = {}    # living enemy id -> bitmask of ranks it could be
var _dead_masks: Array[int] = []    # what each eliminated enemy piece could have been
var _enemy_moved: Dictionary = {}   # enemy id -> true once it has moved
var _enemy_attacked: Dictionary = {}  # enemy id -> true once it has attacked
var _last_move := Vector2i(-1, -1)  # (from cell, to cell) of our previous move


@warning_ignore("integer_division")
func _init(ai_side: String, level: Difficulty = Difficulty.MEDIUM) -> void:
	_build_tables()
	side = ai_side
	difficulty = level
	_settings = SETTINGS[level]
	_my_goal_row = Ranks.goal_row(side)
	_their_goal_row = Ranks.goal_row(Ranks.opponent(side))
	_progress.resize(Ranks.COLS * Ranks.ROWS)
	for cell in _progress.size():
		var row := cell / Ranks.COLS
		_progress[cell] = absi(row - _their_goal_row)


static func label(level: Difficulty) -> String:
	return LABELS[level]


# --- Setup ------------------------------------------------------------------------------------

## A formation for our home rows: the flag on the back row with guards beside it, a spy close by
## to punish generals hunting the flag, privates and a top general up front. Easy just shuffles.
@warning_ignore("integer_division")
func choose_formation() -> Array[Dictionary]:
	var back := _their_goal_row
	var step := 1 if back == 0 else -1
	var mid := back + step
	var front := back + step * 2
	if not _settings["smart_setup"]:
		return _random_formation_with_back_flag(back)

	var pool := Ranks.full_set()
	var free := {back: _row_cells(back), mid: _row_cells(mid), front: _row_cells(front)}
	var placed: Array[Dictionary] = []
	var put := func(rank: String, cell: Vector2i) -> void:
		pool.erase(rank)
		free[cell.y].erase(cell)
		placed.append({"rank": rank, "x": cell.x, "y": cell.y})

	var flag_x: int = randi_range(1, 7) if randf() < 0.8 else [0, 8].pick_random()
	put.call("FLG", Vector2i(flag_x, back))
	var guard_cells: Array = [Vector2i(flag_x - 1, back), Vector2i(flag_x + 1, back), Vector2i(flag_x, mid)] \
		.filter(func(c: Vector2i) -> bool: return Ranks.in_bounds(c))
	guard_cells.shuffle()
	var guard_ranks: Array = ["SPY", "PVT", ["COL", "G1", "LTC"].pick_random()]
	guard_ranks.shuffle()
	for i in mini(guard_cells.size(), guard_ranks.size()):
		put.call(guard_ranks[i], guard_cells[i])
	if pool.has("SPY"):
		put.call("SPY", free[mid].pick_random())
	put.call(["G5", "G4"].pick_random(), free[front].pick_random())
	for i in 3:
		put.call("PVT", free[front].pick_random())
	# Officers fill the front and middle first; privates and the rest go anywhere.
	for rank: String in pool.duplicate():
		var rows: Array = [front, mid] if rank != "PVT" else [front, mid, back]
		var options: Array = []
		for row: int in rows:
			options.append_array(free[row])
		if options.is_empty():
			options = free[back]
		put.call(rank, options.pick_random())
	return placed


## Call once both formations are on the board.
func begin(observation: Dictionary) -> void:
	_my_ranks.clear()
	for p: Dictionary in observation["mine"]:
		_my_ranks[p["id"]] = _rank_index(p["rank"])
	_enemy_mask.clear()
	for e: Dictionary in observation["enemy"]:
		_enemy_mask[e["id"]] = ALL_RANKS
	_dead_masks.clear()
	_enemy_moved.clear()
	_enemy_attacked.clear()
	_last_move = Vector2i(-1, -1)


# --- Learning from the arbiter's announcements -----------------------------------------------

## Feed every MoveResult (ours and theirs). Clashes narrow down the enemy piece's rank because we
## know the rank of our own piece in the fight.
func observe(result: Dictionary) -> void:
	var mover := str(result.get("piece_id", ""))
	var mover_is_mine := _my_ranks.has(mover)
	if not mover_is_mine:
		_enemy_moved[mover] = true
	var clash: Variant = result.get("clash")
	if not clash is Dictionary:
		return

	var defender := str(clash["defender_id"])
	var mine_id := mover if mover_is_mine else defender
	var enemy_id := defender if mover_is_mine else mover
	var outcome: int = {"attacker": ATTACKER_WINS, "defender": DEFENDER_WINS}.get(clash["outcome"], BOTH_OUT)
	if _my_ranks.has(mine_id) and _enemy_mask.has(enemy_id):
		var mine: int = _my_ranks[mine_id]
		var allowed := 0
		for r in RANK_COUNT:
			var code := _outcome[mine * RANK_COUNT + r] if mover_is_mine else _outcome[r * RANK_COUNT + mine]
			if code == outcome:
				allowed |= 1 << r
		var narrowed: int = _enemy_mask[enemy_id] & allowed
		_enemy_mask[enemy_id] = narrowed if narrowed != 0 else allowed
		if not mover_is_mine:
			_enemy_attacked[enemy_id] = true

	for id: Variant in clash.get("eliminated", []):
		var key := str(id)
		if _my_ranks.has(key):
			_my_ranks.erase(key)
		elif _enemy_mask.has(key):
			# The game goes on, so whatever died was not their flag.
			var mask: int = _enemy_mask[key] & ~FLAG_BIT
			_dead_masks.append(mask if mask != 0 else ALL_RANKS & ~FLAG_BIT)
			_enemy_mask.erase(key)


## What the AI currently believes a piece can be (for debugging or a "scouting report" UI).
func possible_ranks(enemy_id: String) -> Array[String]:
	var result: Array[String] = []
	var mask: int = _enemy_mask.get(enemy_id, 0)
	var codes: Array = Ranks.INFO.keys()
	for r in RANK_COUNT:
		if mask & (1 << r):
			result.append(codes[r])
	return result


# --- Choosing a move --------------------------------------------------------------------------

## Coroutine: returns {id, from: Vector2i, to: Vector2i}, or {} when no move exists.
func choose_move(observation: Dictionary) -> Dictionary:
	var cells := Ranks.COLS * Ranks.ROWS
	var sides := PackedInt32Array()
	sides.resize(cells)
	var ranks := PackedInt32Array()
	ranks.resize(cells)
	ranks.fill(-1)
	var my_ids: Dictionary = {}
	for p: Dictionary in observation["mine"]:
		var c := _cell(p["x"], p["y"])
		sides[c] = ME
		ranks[c] = _rank_index(p["rank"])
		my_ids[c] = p["id"]
		_my_ranks[p["id"]] = ranks[c]
	var enemy_ids: Array[String] = []
	var enemy_cells := PackedInt32Array()
	for e: Dictionary in observation["enemy"]:
		var c := _cell(e["x"], e["y"])
		sides[c] = THEM
		enemy_ids.append(e["id"])
		enemy_cells.append(c)
		if not _enemy_mask.has(e["id"]):
			_enemy_mask[e["id"]] = ALL_RANKS

	var moves := _moves(sides, ME)
	if moves.is_empty():
		return {}
	var chosen := -1
	if randf() < _settings["blunder"]:
		chosen = randi() % moves.size()
	else:
		chosen = await _search(sides, ranks, moves, enemy_ids, enemy_cells)
	var move := moves[chosen]
	_last_move = move
	return {"id": my_ids[move.x], "from": _vec(move.x), "to": _vec(move.y)}


func _search(sides: PackedInt32Array, ranks: PackedInt32Array, moves: Array[Vector2i],
		enemy_ids: Array[String], enemy_cells: PackedInt32Array) -> int:
	var sample_count: int = _settings["samples"]
	var worlds: Array[PackedInt32Array] = []
	for i in sample_count:
		var world := ranks.duplicate()
		var assignment := _sample(enemy_ids, enemy_cells)
		for k in enemy_cells.size():
			world[enemy_cells[k]] = assignment[k]
		worlds.append(world)

	var clock := Time.get_ticks_msec()
	var scores := PackedFloat32Array()
	scores.resize(moves.size())
	for i in moves.size():
		var total := 0.0
		for world in worlds:
			var s := sides.duplicate()
			var r := world.duplicate()
			_apply(s, r, moves[i].x, moves[i].y)
			total += _evaluate(s, r, true)
		scores[i] = total / sample_count - (SHUFFLE_PENALTY if _reverses(moves[i]) else 0.0)
		if Time.get_ticks_msec() - clock > FRAME_BUDGET_MS:
			await Engine.get_main_loop().process_frame
			clock = Time.get_ticks_msec()

	var candidates: Array = range(moves.size())
	if _settings["depth"] >= 2:
		candidates.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
		candidates = candidates.slice(0, _settings["shortlist"])
		for i: int in candidates:
			var total := 0.0
			for world in worlds:
				total += _reply_value(sides, world, moves[i])
				if Time.get_ticks_msec() - clock > FRAME_BUDGET_MS:
					await Engine.get_main_loop().process_frame
					clock = Time.get_ticks_msec()
			scores[i] = total / sample_count - (SHUFFLE_PENALTY if _reverses(moves[i]) else 0.0)

	var noise: float = _settings["noise"]
	var best := -1
	var best_score := -INF
	for i: int in candidates:
		var score := scores[i] + randfn(0.0, noise)
		if score > best_score:
			best_score = score
			best = i
	return best


## Our move, then the opponent's reply in one sampled world. The opponent is modelled as mostly,
## not perfectly, choosing what hurts us most: it doesn't really know our ranks either.
func _reply_value(sides: PackedInt32Array, world: PackedInt32Array, move: Vector2i) -> float:
	var s := sides.duplicate()
	var r := world.duplicate()
	_apply(s, r, move.x, move.y)
	var after := _evaluate(s, r, true)
	if absf(after) >= WIN * 0.5:
		return after
	var replies := _moves(s, THEM)
	if replies.is_empty():
		return WIN
	var worst := INF
	var sum := 0.0
	for reply in replies:
		var s2 := s.duplicate()
		var r2 := r.duplicate()
		_apply(s2, r2, reply.x, reply.y)
		var value := _evaluate(s2, r2, false)
		worst = minf(worst, value)
		sum += value
	return worst * 0.6 + (sum / replies.size()) * 0.4


## Assigns a rank to every enemy piece, living and dead, so the totals match the 21-piece set and
## every observed constraint holds. Most-constrained pieces first; the flag is weighted toward
## pieces that never moved and sit on their back row.
@warning_ignore("integer_division")
func _sample(enemy_ids: Array[String], enemy_cells: PackedInt32Array) -> PackedInt32Array:
	var masks: Array[int] = []
	var flag_weight: Array[float] = []
	for k in enemy_ids.size():
		var id := enemy_ids[k]
		masks.append(_enemy_mask[id])
		var weight := 1.0
		if _enemy_attacked.has(id):
			weight = 0.02
		elif _enemy_moved.has(id):
			weight = 0.15
		elif enemy_cells[k] / Ranks.COLS == _my_goal_row:
			weight = 4.0
		flag_weight.append(weight)
	for mask in _dead_masks:
		masks.append(mask)
		flag_weight.append(0.0)

	var n := masks.size()
	for attempt in 30:
		var remaining := _counts.duplicate()
		var order: Array = range(n)
		var keys: Array[float] = []
		for i in n:
			keys.append(_bit_count(masks[i]) + randf() * 0.5)
		order.sort_custom(func(a: int, b: int) -> bool: return keys[a] < keys[b])
		var assignment := PackedInt32Array()
		assignment.resize(n)
		var ok := true
		for i: int in order:
			var total := 0.0
			for r in RANK_COUNT:
				if masks[i] & (1 << r) and remaining[r] > 0:
					total += remaining[r] * (flag_weight[i] if r == FLAG else 1.0)
			if total <= 0.0:
				ok = false
				break
			var pick := randf() * total
			for r in RANK_COUNT:
				if masks[i] & (1 << r) and remaining[r] > 0:
					pick -= remaining[r] * (flag_weight[i] if r == FLAG else 1.0)
					if pick <= 0.0:
						assignment[i] = r
						remaining[r] -= 1
						break
		if ok:
			return assignment.slice(0, enemy_ids.size())

	# Observations contradict each other (shouldn't happen): fall back to an unconstrained deal.
	var pool: Array[int] = []
	for r in RANK_COUNT:
		for i in _counts[r]:
			pool.append(r)
	pool.shuffle()
	var fallback := PackedInt32Array()
	for k in enemy_ids.size():
		fallback.append(pool[k])
	return fallback


# --- Position evaluation (from our side's point of view) -------------------------------------

@warning_ignore("integer_division")
func _evaluate(sides: PackedInt32Array, ranks: PackedInt32Array, opponent_to_move: bool) -> float:
	var score := 0.0
	var my_flag := -1
	var their_flag := -1
	var mine := PackedInt32Array()
	var theirs := PackedInt32Array()
	for c in sides.size():
		var owner := sides[c]
		if owner == 0:
			continue
		var r := ranks[c]
		if owner == ME:
			mine.append(c)
			score += VALUES[r]
			if r == FLAG:
				my_flag = c
			else:
				score += ADVANCE * _progress[c]
		else:
			theirs.append(c)
			score -= VALUES[r]
			if r == FLAG:
				their_flag = c
	if my_flag < 0:
		return -WIN
	if their_flag < 0:
		return WIN
	if my_flag / Ranks.COLS == _my_goal_row and not _touches(sides, my_flag, THEM):
		return WIN * 0.9
	if their_flag / Ranks.COLS == _their_goal_row and (opponent_to_move or not _touches(sides, their_flag, ME)):
		return -WIN * 0.9

	# Captures available to whoever moves next.
	var best := 0.0
	var rest := 0.0
	if opponent_to_move:
		for c in mine:
			var r := ranks[c]
			for n in _neighbors[c]:
				if sides[n] == THEM and _outcome[ranks[n] * RANK_COUNT + r] == ATTACKER_WINS:
					var loss := FLAG_RISK if r == FLAG else VALUES[r]
					rest += loss
					best = maxf(best, loss)
					break
		score -= best * RISK_MAIN + (rest - best) * RISK_OTHER
	else:
		for c in theirs:
			var e := ranks[c]
			for n in _neighbors[c]:
				if sides[n] == ME and _outcome[ranks[n] * RANK_COUNT + e] == ATTACKER_WINS:
					best = maxf(best, WIN * 0.5 if e == FLAG else VALUES[e])
					break
		score += best * GAIN_MAIN

	# Keep our flag covered; hunt theirs.
	for c in theirs:
		var d := _distance(c, my_flag)
		if d <= 2:
			score -= (3 - d) * FLAG_PRESSURE
	var guards := 0
	for n in _neighbors[my_flag]:
		if sides[n] == ME:
			guards += 1
	score += mini(guards, 2) * GUARD_BONUS
	var nearest := 99
	for c in mine:
		if ranks[c] != FLAG:
			nearest = mini(nearest, _distance(c, their_flag))
	return score - nearest * HUNT


# --- Board helpers ----------------------------------------------------------------------------

## All (from, to) moves for `owner` as Vector2i(from cell, to cell).
func _moves(sides: PackedInt32Array, owner: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in sides.size():
		if sides[c] != owner:
			continue
		for n in _neighbors[c]:
			if sides[n] != owner:
				result.append(Vector2i(c, n))
	return result


func _apply(sides: PackedInt32Array, ranks: PackedInt32Array, from: int, to: int) -> void:
	var owner := sides[from]
	var rank := ranks[from]
	sides[from] = 0
	ranks[from] = -1
	if sides[to] == 0:
		sides[to] = owner
		ranks[to] = rank
		return
	match _outcome[rank * RANK_COUNT + ranks[to]]:
		ATTACKER_WINS:
			sides[to] = owner
			ranks[to] = rank
		BOTH_OUT:
			sides[to] = 0
			ranks[to] = -1


func _touches(sides: PackedInt32Array, cell: int, owner: int) -> bool:
	for n in _neighbors[cell]:
		if sides[n] == owner:
			return true
	return false


func _reverses(move: Vector2i) -> bool:
	return move.x == _last_move.y and move.y == _last_move.x


@warning_ignore("integer_division")
func _distance(a: int, b: int) -> int:
	return absi(a % Ranks.COLS - b % Ranks.COLS) + absi(a / Ranks.COLS - b / Ranks.COLS)


func _cell(x: Variant, y: Variant) -> int:
	return int(y) * Ranks.COLS + int(x)


@warning_ignore("integer_division")
func _vec(cell: int) -> Vector2i:
	return Vector2i(cell % Ranks.COLS, cell / Ranks.COLS)


func _row_cells(row: int) -> Array:
	var cells: Array = []
	for x in Ranks.COLS:
		cells.append(Vector2i(x, row))
	return cells


func _random_formation_with_back_flag(back_row: int) -> Array[Dictionary]:
	var formation := Ranks.random_formation(side)
	var flag := formation.find_custom(func(p: Dictionary) -> bool: return p["rank"] == "FLG")
	if formation[flag]["y"] != back_row:
		var backs := range(formation.size()).filter(func(i: int) -> bool: return formation[i]["y"] == back_row)
		if not backs.is_empty():
			var other: int = backs.pick_random()
			formation[flag]["rank"] = formation[other]["rank"]
			formation[other]["rank"] = "FLG"
	return formation


static func _rank_index(code: Variant) -> int:
	return Ranks.INFO.keys().find(str(code))


static func _bit_count(mask: int) -> int:
	var count := 0
	while mask:
		mask &= mask - 1
		count += 1
	return count


@warning_ignore("integer_division")
static func _build_tables() -> void:
	if not _outcome.is_empty():
		return
	var codes: Array = Ranks.INFO.keys()
	_outcome.resize(RANK_COUNT * RANK_COUNT)
	for a in RANK_COUNT:
		for d in RANK_COUNT:
			var who := Ranks.resolve_clash(codes[a], codes[d])
			_outcome[a * RANK_COUNT + d] = ATTACKER_WINS if who == "attacker" else (DEFENDER_WINS if who == "defender" else BOTH_OUT)
	_counts.resize(RANK_COUNT)
	for r in RANK_COUNT:
		_counts[r] = Ranks.INFO[codes[r]]["count"]
	for c in Ranks.COLS * Ranks.ROWS:
		var list := PackedInt32Array()
		for n in Ranks.neighbors(Vector2i(c % Ranks.COLS, c / Ranks.COLS)):
			list.append(n.y * Ranks.COLS + n.x)
		_neighbors.append(list)
