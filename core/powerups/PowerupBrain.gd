class_name PowerupBrain
extends RefCounted
## How the practice AI plays its 5 powerups: a few rules of thumb, at most one per turn, decided
## before it moves. It only looks at what its side may know (observation, its own rules view and
## its rank beliefs). Rookie keeps it simple: intel only, and only now and then.

## Powerups the AI can make use of. Clock ones that only help the clock are pointless for a bot
## that answers in a second, the multi-step board tricks (swap, teleport, double march, haste) are
## left to humans, and so is intel the AI's beliefs can't use (sonar, radar, spy alarm, codes).
const POOL := ["spy_card", "intel_leak", "recon_drone", "fortify", "scout_report", "smoke_screen", "jammer",
	"freeze", "decoy", "chaos_order", "flag_hunter", "second_chance", "sabotage", "mine_field", "rally_cry",
	"reinforcement", "shuffle", "time_squeeze", "time_steal", "interrogation", "retreat", "roadblock",
	"quicksand", "counterspell", "trench", "ceasefire", "counter_intel", "promotion", "recall"]
## What a Rookie may be dealt: the simple common cards.
const ROOKIE_POOL := ["time_extension", "time_squeeze", "spy_card", "insight", "intel_leak", "sonar_ping",
	"spy_alarm", "jammer", "roadblock", "retreat"]

const HIGH_RANKS := ["G5", "G4", "G3", "G2", "G1", "COL", "SPY"]
const ROOKIE_CHANCE := 0.2  ## Rookie only reaches for a powerup on about one turn in five.


## The practice AI's hand of 5: Rookie is dealt simple common cards, the Officer and General draw
## from the pool above.
static func pick_loadout(rookie := false) -> Array[String]:
	var pool := (ROOKIE_POOL if rookie else POOL).duplicate()
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
		"time_steal":
			if turn >= 2 and randf() < 0.3:
				return {"id": id}
		"counterspell":
			if turn >= 3 and randf() < 0.3:
				return {"id": id}
		"interrogation":
			# Question an unidentified enemy piece standing next to one of ours.
			for e: Dictionary in enemy:
				if _touching(e, mine) and _bits(ai.enemy_mask(e["id"])) > 1:
					return {"id": id, "target": {"piece_id": e["id"]}}
		"trench":
			for p: Dictionary in mine:
				if (p["rank"] in HIGH_RANKS or p["rank"] == "FLG") and _touching(p, enemy):
					return {"id": id, "target": {"piece_id": p["id"]}}
		"retreat":
			# Pull a valuable piece back out of reach.
			for p: Dictionary in mine:
				if p["rank"] in HIGH_RANKS and _touching(p, enemy) and randf() < 0.5:
					return {"id": id, "target": {"piece_id": p["id"]}}
		"ceasefire":
			if not flag.is_empty() and _touching(flag, enemy):
				return {"id": id}
			for p: Dictionary in mine:
				if p["rank"] in ["G5", "G4", "SPY"] and _touching(p, enemy) and randf() < 0.5:
					return {"id": id}
		"roadblock", "quicksand":
			# Bar (or bog down) an empty square next to our flag.
			if turn >= 4 and not flag.is_empty() and randf() < 0.4:
				for cell in Ranks.neighbors(Vector2i(flag["x"], flag["y"])):
					var own_half := LocalArbiter.is_own_half(side, cell)
					if arbiter.piece_at(cell).is_empty() and not arbiter.is_blocked(cell) and (id == "roadblock" or own_half):
						return {"id": id, "target": {"x": cell.x, "y": cell.y}}
		"counter_intel":
			var known: Array = arbiter.rules_view(Ranks.opponent(side))["revealed"]
			if known.size() >= 2:
				return {"id": id}
		"promotion":
			if turn >= 6 and randf() < 0.3:
				var privates := mine.filter(func(p: Dictionary) -> bool: return p["rank"] == "PVT")
				if not privates.is_empty():
					return {"id": id, "target": {"piece_id": privates.pick_random()["id"]}}
		"recall":
			if randf() < 0.4:
				for card: String in arbiter.used[side]:
					if card in ["fortify", "freeze", "spy_card", "second_chance", "mine_field", "chaos_order"]:
						return {"id": id}
		"reinforcement":
			if randf() < 0.3:
				var row := LocalArbiter.back_row(side)
				for x in Ranks.COLS:
					if arbiter.piece_at(Vector2i(x, row)).is_empty():
						var plan := {"id": id, "target": {"x": x, "y": row}}
						return plan if _fallen_private(arbiter, side) else {}
	return {}


static func _bits(mask: int) -> int:
	var count := 0
	while mask != 0:
		count += mask & 1
		mask >>= 1
	return count


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
