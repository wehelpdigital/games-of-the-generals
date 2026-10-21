extends Node
## Plays whole games between AIs (and a random mover) on the local arbiter, with no board or
## animation, to check that the AI is actually good and fast enough.
##   godot --headless --path . res://tests/AiBenchmark.tscn [-- --games=8]

const MAX_PLIES := 400

var failures := 0
var _only := ""  ## Run just the matchups whose title contains this (e.g. --only="Hard vs Medium").


func _ready() -> void:
	var games := 8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")

	var easy := await _matchup("Easy vs Random", SalpakanAI.Difficulty.EASY, -1, games)
	var medium := await _matchup("Medium vs Random", SalpakanAI.Difficulty.MEDIUM, -1, games)
	var hard := await _matchup("Hard vs Random", SalpakanAI.Difficulty.HARD, -1, games)
	var hard_vs_easy := await _matchup("Hard vs Easy", SalpakanAI.Difficulty.HARD, SalpakanAI.Difficulty.EASY, games)
	await _matchup("Hard vs Medium", SalpakanAI.Difficulty.HARD, SalpakanAI.Difficulty.MEDIUM, games)

	if _only != "":
		print("
%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
		get_tree().quit(0 if failures == 0 else 1)
		return
	_check(medium["win_rate"] >= 0.75, "Medium beats a random mover (%d%%)" % roundi(medium["win_rate"] * 100))
	_check(hard["win_rate"] >= 0.8, "Hard beats a random mover (%d%%)" % roundi(hard["win_rate"] * 100))
	_check(hard_vs_easy["win_rate"] >= 0.6, "Hard beats Easy (%d%%)" % roundi(hard_vs_easy["win_rate"] * 100))
	_check(easy["win_rate"] >= 0.5, "Easy still beats a random mover (%d%%)" % roundi(easy["win_rate"] * 100))
	_check(hard["avg_ms"] < 600.0, "Hard thinks %.0f ms per move on average" % hard["avg_ms"])
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


## `hero` plays a random colour each game against `rival` (-1 = random mover).
func _matchup(title: String, hero: int, rival: int, games: int) -> Dictionary:
	if _only != "" and not title.contains(_only):
		return {"win_rate": 1.0, "avg_ms": 0.0}
	var wins := 0
	var draws := 0
	var plies := 0
	var think_ms := 0
	var moves := 0
	var reasons: Dictionary = {}
	for g in games:
		var hero_side := Ranks.WHITE if g % 2 == 0 else Ranks.BLACK
		var arbiter := LocalArbiter.new()
		var agents: Dictionary = {}
		for side: String in [Ranks.WHITE, Ranks.BLACK]:
			var level := hero if side == hero_side else rival
			agents[side] = SalpakanAI.new(side, level) if level >= 0 else null
			var formation: Array = agents[side].choose_formation() if agents[side] else Ranks.random_formation(side)
			arbiter.deploy(side, formation)
		for side: String in agents:
			if agents[side]:
				agents[side].begin(arbiter.observation(side))

		while not arbiter.is_over() and arbiter.move_number < MAX_PLIES:
			var side := arbiter.turn
			var move: Dictionary
			if agents[side]:
				var started := Time.get_ticks_msec()
				move = await agents[side].choose_move(arbiter.observation(side))
				if side == hero_side:
					think_ms += Time.get_ticks_msec() - started
					moves += 1
			else:
				move = arbiter.legal_moves(side).pick_random()
			if move.is_empty() or arbiter.validate(side, move["id"], move["from"], move["to"]) != "":
				push_error("%s produced an illegal move %s" % [side, move])
				failures += 1
				break
			var result := arbiter.apply(move["id"], move["to"])
			for agent: Variant in agents.values():
				if agent:
					agent.observe(result)

		plies += arbiter.move_number
		print("  %s game %d: %s (%s) after %d plies, hero %s" % [title, g + 1, arbiter.winner if arbiter.is_over() else "unfinished",
			arbiter.end_reason, arbiter.move_number, hero_side])
		if arbiter.winner == hero_side:
			wins += 1
			reasons[arbiter.end_reason] = reasons.get(arbiter.end_reason, 0) + 1
		elif not arbiter.is_over():
			draws += 1

	var summary := {"win_rate": float(wins) / games, "avg_ms": float(think_ms) / maxi(moves, 1)}
	print("%-18s %d/%d won, %d unfinished, %.0f plies/game, %.0f ms/move  %s" % [
		title, wins, games, draws, float(plies) / games, summary["avg_ms"], reasons])
	return summary


func _check(condition: bool, what: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + what)
	if not condition:
		failures += 1
