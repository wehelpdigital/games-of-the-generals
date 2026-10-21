class_name PowerupBrain
extends RefCounted
## How the practice AI plays its 5 powerups: a few rules of thumb, at most one per turn, decided
## before it moves. It only looks at what its side may know (observation, its own rules view and
## its rank beliefs). Rookie keeps it simple: intel only, and only now and then.

## Powerups the AI can make use of. Clock ones are pointless for a bot that answers in a second,
## and the multi-step board tricks (swap, teleport, double march) are left to humans.
const POOL := ["spy_card", "intel_leak", "recon_drone", "fortify", "scout_report", "smoke_screen", "jammer",
	"freeze", "decoy", "chaos_order", "flag_hunter", "second_chance", "sabotage", "mine_field", "rally_cry",
	"reinforcement", "shuffle", "time_squeeze"]

const HIGH_RANKS := ["G5", "G4", "G3", "G2", "G1", "COL", "SPY"]
const ROOKIE_CHANCE := 0.2  ## Rookie only reaches for a powerup on about one turn in five.


## The practice AI's hand of 5: Rookie is dealt from the rank-0 basics like a new player, the
## Officer and General from the pool above.
static func pick_loadout(rookie := false) -> Array[String]:
	if rookie:
		return PowerupLibrary.deal(0)
	var pool := POOL.duplicate()
	pool.shuffle()
	var picked: Array[String] = []
	for id: String in pool.slice(0, PowerupLibrary.MAX_SLOTS):
		picked.append(id)
	return picked


## {id, target} to use this turn, or {} to just move.
static func choose(arbiter: LocalArbiter, side: String, ai: SalpakanAI) -> Dictionary:
	var available: Array = arbiter.loadouts[side].filter(func(id: String) -> bool: return arbiter.can_use_powerup(side, id))
	if available.is_empty():
		return {}
	if ai != null and ai.difficulty == SalpakanAI.Difficulty.EASY and randf() > ROOKIE_CHANCE:
		return {}
	available.shuffle()
	var seen := arbiter.observation(side)
	var mine: Array = seen["mine"]
	var enemy: Array = seen["enemy"]
	var flag := {}
	for p: Dictionary in mine:
		if p["rank"] == "FLG":
			flag = p
	var turn := arbiter.move_number
	for id: String in available:
		var plan := _plan(id, arbiter, side, ai, mine, enemy, flag, turn)
		if not plan.is_empty():
			return plan
	return {}


static func _plan(id: String, arbiter: LocalArbiter, side: String, ai: SalpakanAI, mine: Array, enemy: Array,
		flag: Dictionary, turn: int) -> Dictionary:
	match id:
		"decoy":
			if not flag.is_empty():
				return {"id": id, "target": {"piece_id": flag["id"]}}
		"second_chance", "rally_cry":
			if turn >= 4 and randf() < 0.35:
				return {"id": id}
		"time_squeeze":
			if turn >= 2 and randf() < 0.3:
				return {"id": id}
		"jammer":
			if turn >= 6 and randf() < 0.15:
				return {"id": id}
		"spy_card", "intel_leak":
			if turn >= 6 and randf() < 0.3:
				return {"id": id}
		"scout_report":
			if turn >= 8 and randf() < 0.3:
				return {"id": id}
		"flag_hunter":
			if turn >= 12 and randf() < 0.3:
				return {"id": id}
		"smoke_screen", "chaos_order":
			if turn >= 8 and randf() < 0.2:
				return {"id": id}
		"sabotage":
			if turn >= 4 and randf() < 0.25:
				return {"id": id}
		"shuffle":
			if turn >= 10 and randf() < 0.2:
				return {"id": id}
		"recon_drone":
			# Probe an unmoved piece on their back row that could still be the flag.
			if turn >= 10 and randf() < 0.4:
				var back := LocalArbiter.back_row(Ranks.opponent(side))
				var suspects := enemy.filter(func(e: Dictionary) -> bool:
					return e["y"] == back and not ai.has_moved(e["id"]) and ai.enemy_mask(e["id"]) & SalpakanAI.FLAG_BIT)
				if not suspects.is_empty():
					return {"id": id, "target": {"piece_id": suspects.pick_random()["id"]}}
		"fortify":
			# Shield a valuable piece (or the flag) that an enemy is touching.
			for p: Dictionary in mine:
				if (p["rank"] in HIGH_RANKS or p["rank"] == "FLG") and _touching(p, enemy):
					return {"id": id, "target": {"piece_id": p["id"]}}
		"freeze":
			# Ice the enemy piece closest to our flag once it gets near.
			if not flag.is_empty():
				for e: Dictionary in enemy:
					if absi(e["x"] - flag["x"]) + absi(e["y"] - flag["y"]) <= 2:
						return {"id": id, "target": {"piece_id": e["id"]}}
		"mine_field":
			# Bury a mine on an empty square next to our flag.
			if turn >= 4 and not flag.is_empty() and randf() < 0.4:
				for cell in Ranks.neighbors(Vector2i(flag["x"], flag["y"])):
					if LocalArbiter.is_own_half(side, cell) and arbiter.piece_at(cell).is_empty():
						return {"id": id, "target": {"x": cell.x, "y": cell.y}}
		"reinforcement":
			if randf() < 0.3:
				var row := LocalArbiter.back_row(side)
				for x in Ranks.COLS:
					if arbiter.piece_at(Vector2i(x, row)).is_empty():
						var plan := {"id": id, "target": {"x": x, "y": row}}
						return plan if _fallen_private(arbiter, side) else {}
	return {}


static func _touching(piece: Dictionary, enemy: Array) -> bool:
	for e: Dictionary in enemy:
		if absi(e["x"] - piece["x"]) + absi(e["y"] - piece["y"]) == 1:
			return true
	return false


static func _fallen_private(arbiter: LocalArbiter, side: String) -> bool:
	var alive := 0
	for p: Dictionary in arbiter.pieces.values():
		if p["side"] == side and p["rank"] == "PVT":
			alive += 1
	return alive < int(Ranks.INFO["PVT"]["count"])
