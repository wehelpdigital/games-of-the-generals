extends Node
## Offline rules for turn timers and every powerup (LocalArbiter), including what each side may
## see. No board or server needed:
##   godot --headless --path . res://tests/PowerupTest.tscn

const W := Ranks.WHITE
const B := Ranks.BLACK

var failures := 0
var _now := 1000.0


func _ready() -> void:
	_test_timer_and_timeouts()
	_test_clock_powerups()
	_test_intel_powerups()
	_test_decoy()
	_test_fortify_second_chance_rally()
	_test_smoke_screen()
	_test_freeze_sabotage_jammer_chaos()
	_test_double_march()
	_test_board_powerups()
	_test_mines()
	_test_shuffle_and_reinforcement()
	_test_limits()
	_test_secrecy()
	_test_brain_and_ai()
	_test_modes()
	_test_new_cards()
	_test_third_wave_clock()
	_test_third_wave_intel()
	_test_third_wave_tactics()
	_test_third_wave_traps()
	_test_third_wave_support()
	_test_third_wave_secrecy()
	_test_brain_soak()
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func check(condition: bool, what: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + what)
	if not condition:
		failures += 1


## A small position: white near row 0-3, black near row 4-7. Each entry is [rank, Vector2i].
## Every powerup is in both loadouts.
func board(white: Array, black: Array, seconds := 0) -> LocalArbiter:
	_now = 1000.0
	var a := LocalArbiter.new()
	a.clock = func() -> float: return _now
	a.turn_seconds = seconds
	for p: Array in white:
		a._add_piece(W, p[0], p[1])
	for p: Array in black:
		a._add_piece(B, p[0], p[1])
	for side: String in [W, B]:
		a.loadouts[side] = PowerupLibrary.ids()
	a.start()
	return a


func id_at(a: LocalArbiter, cell: Vector2i) -> String:
	return str(a.piece_at(cell).get("id", ""))


func move(a: LocalArbiter, from: Vector2i, to: Vector2i) -> Dictionary:
	var id := id_at(a, from)
	var problem := a.validate(a.turn, id, from, to)
	if problem != "":
		push_error("illegal test move %s -> %s: %s" % [from, to, problem])
		return {}
	return a.apply(id, to)


func _test_modes() -> void:
	print("Powerup modes")
	check(PowerupLibrary.ids().size() >= 40 and GameSession.powerups.unlocked_ids().size() == PowerupLibrary.ids().size(),
		"every one of the 40+ powerups is open to every player")
	for id in PowerupLibrary.ids():
		var card := PowerupLibrary.info(id)
		if not (str(card.get("kind")) in PowerupLibrary.KINDS and str(card.get("rarity")) in PowerupLibrary.RARITIES):
			check(false, "%s has a card type and rarity" % id)
	check(PowerupLibrary.DEFAULT_LOADOUT.size() == PowerupLibrary.MAX_SLOTS and PowerupLibrary.MAX_SLOTS == 5, "the starter hand holds 5")
	var hand := PowerupLibrary.deal()
	var distinct := {}
	for id in hand:
		distinct[id] = true
	check(hand.size() == 5 and distinct.size() == 5 and hand.all(func(id: String) -> bool: return PowerupLibrary.has(id)),
		"a random hand is 5 distinct powerups from the whole library")

	var off := standard()
	off.powerup_mode = PowerupLibrary.MODE_OFF
	off.set_loadout(W, [])
	var tried := off.use_powerup(W, "spy_card")
	check(not tried["ok"] and str(tried["error"]) == "Powerups are off in this match.", "powerups off refuses any use")
	check(off.rules_view(W)["powerups"]["mine"].is_empty() and off.rules_view(W)["powerup_mode"] == "off", "powerups off: no slots in the view")

	# GameSession deals practice hands by mode.
	GameSession.start_practice(SalpakanAI.Difficulty.MEDIUM, PowerupLibrary.MODE_OFF)
	check(GameSession.powerup_mode() == "off" and GameSession._arbiter.loadouts[W].is_empty() and GameSession._arbiter.loadouts[B].is_empty(),
		"practice with powerups off: nobody brings any")
	GameSession.start_practice(SalpakanAI.Difficulty.EASY, PowerupLibrary.MODE_RANDOM)
	var mine: Array = GameSession._arbiter.loadouts[W]
	check(mine.size() == 5 and mine.all(func(id: String) -> bool: return GameSession.powerups.is_unlocked(id)), "practice Random: you get 5 unlocked")
	check(GameSession._arbiter.loadouts[B].size() == 5, "practice Random: the AI gets 5")
	GameSession.start_practice(SalpakanAI.Difficulty.HARD, PowerupLibrary.MODE_SELECT)
	check(GameSession._arbiter.loadouts[W] == GameSession.powerups.active_slots() and GameSession._arbiter.loadouts[W].size() == 5,
		"practice Select: you bring your 5 picks")
	GameSession.start_practice(SalpakanAI.Difficulty.HARD)
	check(GameSession.powerup_mode() == "select", "Play again keeps the last mode")
	GameSession.leave()


## The standard little armies used by most tests.
func standard(seconds := 0) -> LocalArbiter:
	return board(
		[["FLG", Vector2i(0, 0)], ["PVT", Vector2i(1, 1)], ["PVT", Vector2i(2, 1)], ["G5", Vector2i(3, 2)], ["SPY", Vector2i(5, 2)], ["CPT", Vector2i(7, 3)], ["SGT", Vector2i(8, 1)]],
		[["FLG", Vector2i(8, 7)], ["PVT", Vector2i(1, 6)], ["COL", Vector2i(3, 4)], ["G1", Vector2i(5, 5)], ["CPT", Vector2i(7, 4)], ["SPY", Vector2i(0, 5)]],
		seconds)


# --- Timers -------------------------------------------------------------------------------------

func _test_timer_and_timeouts() -> void:
	print("Turn timer")
	var a := standard(45)
	check(is_equal_approx(a.time_left(), 45.0), "white's first turn has 45 s")
	check(a.timer()["seconds"] == 45 and a.timer()["deadline"] != null, "timer view shows seconds and an ISO deadline")
	_now += 30.0
	check(a.check_timeout().is_empty(), "no timeout before the deadline")
	_now += 16.0
	var results := a.check_timeout()
	check(results.size() == 1 and results[0].get("auto", false) and results[0].get("timeout", false), "timeout plays one random move flagged auto/timeout")
	check(a.turn == B and a.timeouts[W] == 1, "turn passes to black, white has 1 timeout")
	var moved: Dictionary = a.pieces.get(results[0]["piece_id"], {})
	for gone: Dictionary in a._eliminated:  # The random move may have been an attack that lost.
		if gone["id"] == results[0]["piece_id"]:
			moved = gone
	check(moved.get("rank") != "FLG", "the random move avoids the flag")
	var black_move: Dictionary = a.legal_moves(B).filter(func(m: Dictionary) -> bool: return a.piece_at(m["to"]).is_empty())[0]
	a.apply(black_move["id"], black_move["to"])
	_now += 50.0
	a.check_timeout()
	black_move = a.legal_moves(B).filter(func(m: Dictionary) -> bool: return a.piece_at(m["to"]).is_empty())[0]
	a.apply(black_move["id"], black_move["to"])
	check(a.timeouts[W] == 2, "second consecutive white timeout counted")
	_now += 50.0
	results = a.check_timeout()
	check(a.is_over() and a.winner == B and a.end_reason == "timeout", "third timeout in a row forfeits")
	check(results.size() == 1 and results[0]["type"] == "forfeit", "forfeit reported")

	a = standard(45)
	_now += 50.0
	a.check_timeout()
	var quiet: Dictionary = a.legal_moves(B).filter(func(m: Dictionary) -> bool: return a.piece_at(m["to"]).is_empty())[0]
	a.apply(quiet["id"], quiet["to"])
	var own: Dictionary = a.legal_moves(W).filter(func(m: Dictionary) -> bool: return a.piece_at(m["to"]).is_empty())[0]
	a.apply(own["id"], own["to"])
	check(a.timeouts[W] == 0, "a move of your own resets the timeout count")


func _test_clock_powerups() -> void:
	print("Clock powerups")
	var a := standard(45)
	var used := a.use_powerup(W, "time_extension")
	check(used["ok"] and used["event"]["public"] == {"turns": 3, "seconds": 20}, "Time Extension announced with turns and seconds")
	check(a.turn_allotment == 45, "the current turn keeps its clock")
	var allotments: Array = []
	for i in 4:
		move(a, Vector2i(8, 1) if i % 2 == 0 else Vector2i(8, 2), Vector2i(8, 2) if i % 2 == 0 else Vector2i(8, 1))
		var b_from := Vector2i(1, 6) if i % 2 == 0 else Vector2i(2, 6)
		move(a, b_from, Vector2i(2, 6) if i % 2 == 0 else Vector2i(1, 6))
		allotments.append(a.turn_allotment)
	check(allotments == [65, 65, 65, 45], "white's next 3 turns get +20 s, then back to 45 (%s)" % [allotments])

	a = standard(45)
	a.use_powerup(W, "time_squeeze")
	var view := a.rules_view(B)
	check(view["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "time_squeeze"), "black sees the squeeze coming")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	check(a.turn_allotment == 30, "black's turn is 15 s shorter")

	a = standard(45)
	a.use_powerup(W, "quick_step")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	move(a, Vector2i(1, 6), Vector2i(2, 6))
	check(a.turn_paused and a.timer()["deadline"] == null and a.timer()["paused"], "Quick Step: no clock on white's next turn")
	_now += 60.0
	check(a.check_timeout().is_empty(), "a Quick Step turn doesn't time out after 60 s")


# --- Intel ----------------------------------------------------------------------------------------

func _test_intel_powerups() -> void:
	print("Intel powerups")
	var a := standard()
	var spy := a.use_powerup(W, "spy_card")
	var spied: String = spy["result"]["private"]["piece_id"]
	check(spy["ok"] and a.pieces[spied]["side"] == B and spy["result"]["private"]["rank"] == a.pieces[spied]["rank"], "Spy Card reveals a true black rank")
	check(spy["event"]["public"].is_empty(), "Spy Card's announcement carries no secret")
	var shown: Array = a.view_pieces(W).filter(func(p: Dictionary) -> bool: return p["id"] == spied)
	check(shown.size() == 1 and shown[0]["rank"] == a.pieces[spied]["rank"], "the spied rank shows on that piece for white")
	check(a.rules_view(W)["revealed"].size() == 1 and a.rules_view(B)["revealed"].is_empty(), "only white's view lists the reveal")

	var insight := a.use_powerup(W, "insight")
	check(insight["result"]["private"]["officers"] == 3, "Insight counts Colonel, Brigadier General and Captain (3)")
	check(a.rules_view(W)["intel"][0]["type"] == "insight", "Insight is kept in white's intel")

	a = standard()
	check(a.use_powerup(W, "intel_leak")["error"] == "The enemy hasn't moved yet.", "Intel Leak needs an enemy move first")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	move(a, Vector2i(3, 4), Vector2i(4, 4))
	var leak := a.use_powerup(W, "intel_leak")
	check(leak["result"]["private"]["rank"] == "COL" and leak["result"]["private"]["piece_id"] == id_at(a, Vector2i(4, 4)), "Intel Leak names the piece that moved last")
	var recon := a.use_powerup(W, "recon_drone", {"piece_id": id_at(a, Vector2i(8, 7))})
	check(recon["result"]["private"]["is_flag"] == true, "Recon Drone spots the flag")
	move(a, Vector2i(8, 2), Vector2i(8, 1))
	move(a, Vector2i(4, 4), Vector2i(3, 4))
	var miss := a.use_powerup(W, "recon_drone")
	check(not miss["ok"], "Recon Drone is once per match (and needs a target)")

	a = standard()
	var scout := a.use_powerup(W, "scout_report")
	var groups: Array = scout["result"]["private"]["pieces"]
	var right := groups.all(func(g: Dictionary) -> bool: return g["group"] == PowerupLibrary.group_of(a.pieces[g["piece_id"]]["rank"]))
	check(groups.size() == 3 and right, "Scout Report gives the true group of 3 pieces")
	check(scout["event"]["public"] == {"count": 3}, "Scout Report announces only the count")
	var hunter := a.use_powerup(W, "flag_hunter")
	check(hunter["result"]["private"]["x"] == 8, "Flag Hunter reports the flag's column")


func _test_decoy() -> void:
	print("Decoy")
	var a := standard()
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	var decoy := a.use_powerup(B, "decoy", {"piece_id": id_at(a, Vector2i(3, 4))})
	var fake: String = decoy["result"]["private"]["fake_rank"]
	check(decoy["ok"] and fake != "COL", "Decoy picks a believable lie (%s)" % fake)
	move(a, Vector2i(3, 4), Vector2i(4, 4))
	var leak := a.use_powerup(W, "intel_leak")
	check(leak["result"]["private"]["rank"] == fake, "Intel Leak on the decoy reports the lie")
	check(not a.rules_view(W)["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "decoy"), "white never sees the decoy effect")
	var drone := a.use_powerup(W, "recon_drone", {"piece_id": id_at(a, Vector2i(4, 4))})
	check(drone["result"]["private"]["is_flag"] == (fake == "FLG"), "Recon Drone reads the decoy's rank too")


# --- Clash twists ------------------------------------------------------------------------------------

func _test_fortify_second_chance_rally() -> void:
	print("Fortify, Second Chance, Rally Cry")
	var a := board([["FLG", Vector2i(0, 0)], ["PVT", Vector2i(4, 3)], ["SGT", Vector2i(6, 3)]],
		[["FLG", Vector2i(8, 7)], ["G5", Vector2i(4, 4)], ["SGT", Vector2i(6, 4)], ["PVT", Vector2i(1, 6)]])
	var fortify := a.use_powerup(W, "fortify", {"piece_id": id_at(a, Vector2i(4, 3))})
	check(fortify["ok"] and fortify["event"]["public"].is_empty(), "Fortify is secret")
	check(not a.rules_view(B)["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "fortify"), "black can't see the fortify")
	var pvt := id_at(a, Vector2i(4, 3))
	move(a, Vector2i(0, 0), Vector2i(1, 0))
	var bounce := move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(bounce["clash"]["outcome"] == "bounce" and bounce["clash"]["eliminated"].is_empty(), "the attack bounces off the fortified Private")
	check(a.pieces.has(pvt) and id_at(a, Vector2i(4, 4)) != "", "both pieces stay where they were")

	a.use_powerup(W, "second_chance")
	var saved := move(a, Vector2i(4, 3), Vector2i(4, 4))
	check(saved["clash"]["outcome"] == "defender" and saved["clash"]["saved"] == [pvt], "Second Chance saves the losing attacker")
	check(a.pieces.has(pvt) and a.pieces[pvt]["y"] == 3, "the saved piece stays on its square")

	move(a, Vector2i(1, 6), Vector2i(1, 5))
	a.use_powerup(W, "rally_cry")
	var rally := move(a, Vector2i(6, 3), Vector2i(6, 4))
	check(rally["clash"]["outcome"] == "attacker" and rally["clash"]["rally"] == W, "Rally Cry turns the Sergeant tie into a win")
	check(a.piece_at(Vector2i(6, 4)).get("side") == W, "the rallying Sergeant advances")
	check(a.clash_log.back()["outcome"] == "attacker", "the recap records the rallied outcome")


func _test_smoke_screen() -> void:
	print("Smoke Screen")
	var a := standard()
	a.use_powerup(W, "smoke_screen")
	check(a.rules_view(B)["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "smoke_screen" and e.get("armed")), "black sees smoke is armed")
	var mover := id_at(a, Vector2i(3, 2))
	var result := move(a, Vector2i(3, 2), Vector2i(3, 3))
	check(result.get("hidden_from_opponent", false), "the move is marked hidden")
	var seen := LocalArbiter.redact(result, B)
	check(seen.get("hidden") and not seen.has("piece_id") and not seen.has("from") and not seen.has("to"), "black's copy has no piece or squares")
	check(LocalArbiter.redact(result, W) == result, "white sees its own move")
	var black_view: Array = a.view_pieces(B).filter(func(p: Dictionary) -> bool: return p["id"] == mover)
	check(black_view[0]["y"] == 2 and a.rules_view(B)["fog"], "black still sees the General on its old square, under fog")
	check(not a.rules_view(W)["fog"], "white has no fog")
	var obs: Array = a.observation(B)["enemy"].filter(func(p: Dictionary) -> bool: return p["id"] == mover)
	check(obs[0]["y"] == 2, "the AI's observation is fogged the same way")
	var reply := move(a, Vector2i(1, 6), Vector2i(1, 5))
	check(reply.get("fog_lifted", false), "the fog lifts when black's turn ends")
	black_view = a.view_pieces(B).filter(func(p: Dictionary) -> bool: return p["id"] == mover)
	check(black_view[0]["y"] == 3 and not a.rules_view(B)["fog"], "black now sees the real position")


func _test_freeze_sabotage_jammer_chaos() -> void:
	print("Freeze, Sabotage, Jammer, Chaos Order")
	var a := standard()
	var colonel := id_at(a, Vector2i(3, 4))
	var freeze := a.use_powerup(W, "freeze", {"piece_id": colonel})
	check(freeze["event"]["public"] == {"piece_id": colonel, "turns": 2}, "Freeze is public")
	a.use_powerup(W, "sabotage")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	check(a.validate(B, colonel, Vector2i(3, 4), Vector2i(3, 3)) == "That piece is frozen.", "the frozen Colonel can't move")
	check(not a.legal_moves(B).any(func(m: Dictionary) -> bool: return m["id"] == colonel), "frozen pieces have no legal moves")
	check(a.use_powerup(B, "spy_card")["error"] == "Sabotaged! You can't use powerups this turn.", "Sabotage blocks black's powerups")
	check(a.rules_view(B)["powerups"]["blocked"], "black's view says it is blocked")
	move(a, Vector2i(1, 6), Vector2i(2, 6))
	move(a, Vector2i(8, 2), Vector2i(8, 1))
	check(a.is_frozen(B, colonel), "still frozen on black's second turn")
	move(a, Vector2i(2, 6), Vector2i(1, 6))
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	check(not a.is_frozen(B, colonel), "thawed on black's third turn")

	a = standard()
	a.use_powerup(W, "jammer")
	check(a.jammed(B) and a.rules_view(B)["jammed_until"][B] != null, "Jammer silences black for 2 minutes")
	_now += 121.0
	check(not a.jammed(B), "the jam wears off")

	a = standard()
	a.use_powerup(W, "chaos_order")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	check(a.forced_move_pending(), "black's turn starts with a forced move")
	var forced := a.play_forced()
	check(forced.size() == 1 and forced[0].get("chaos", false) and forced[0].get("auto", false), "the forced move is flagged auto/chaos")
	check(a.turn == W and not a.forced_move_pending(), "then it is white's turn again")


func _test_double_march() -> void:
	print("Double March")
	var a := standard()
	a.use_powerup(W, "double_march")
	var first := move(a, Vector2i(8, 1), Vector2i(8, 2))
	check(first["turn"] == W, "after the first step it is still white's turn")
	check(a.validate(W, id_at(a, Vector2i(8, 2)), Vector2i(8, 2), Vector2i(8, 3)) == "Double March: move a different piece.", "the same piece can't march twice")
	check(a.validate(W, id_at(a, Vector2i(7, 3)), Vector2i(7, 3), Vector2i(7, 4)) == "Double March: the second move can't be an attack.", "the second step can't attack")
	var second := move(a, Vector2i(1, 1), Vector2i(1, 2))
	check(second["turn"] == B, "the second step ends the turn")
	check(a.rules_view(B)["effects"]["opponent"].is_empty(), "the march is over")


func _test_board_powerups() -> void:
	print("Swap, Teleport")
	var a := standard()
	var g5 := id_at(a, Vector2i(3, 2))
	var spy := id_at(a, Vector2i(5, 2))
	var swap := a.use_powerup(W, "swap", {"piece_ids": [g5, spy]})
	check(swap["ok"] and swap["ends_turn"] and a.turn == B, "Swap uses the turn")
	check(a.pieces[g5]["x"] == 5 and a.pieces[spy]["x"] == 3, "the two pieces traded squares")
	move(a, Vector2i(1, 6), Vector2i(2, 6))
	var bad := a.use_powerup(W, "teleport", {"piece_id": g5, "x": 4, "y": 5})
	check(bad["error"] == "Pick an empty square in your three home rows.", "Teleport stays in the home rows")
	var tele := a.use_powerup(W, "teleport", {"piece_id": g5, "x": 4, "y": 0})
	check(tele["ok"] and a.pieces[g5]["y"] == 0 and a.turn == B, "Teleport moves the piece and uses the turn")


func _test_mines() -> void:
	print("Mine Field")
	var a := board([["FLG", Vector2i(0, 0)], ["PVT", Vector2i(1, 1)]],
		[["FLG", Vector2i(8, 7)], ["G5", Vector2i(4, 4)], ["PVT", Vector2i(1, 6)]])
	check(not a.use_powerup(W, "mine_field", {"x": 4, "y": 5})["ok"], "mines go on your own half only")
	var mine := a.use_powerup(W, "mine_field", {"x": 4, "y": 3})
	check(mine["ok"] and mine["event"]["public"].is_empty(), "the mine is secret")
	check(a.rules_view(W)["mines"].size() == 1 and a.rules_view(B)["mines"].is_empty(), "only white sees its mine")
	var general := id_at(a, Vector2i(4, 4))
	move(a, Vector2i(1, 1), Vector2i(1, 2))
	var boom := move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(boom["type"] == "clash" and boom["clash"]["outcome"] == "mine" and boom["clash"]["eliminated"] == [general], "stepping on it eliminates the General")
	check(boom["clash"]["mine"] == {"x": 4, "y": 3} and a.rules_view(W)["mines"].is_empty(), "the mine is used up")


func _test_shuffle_and_reinforcement() -> void:
	print("Shuffle, Reinforcement")
	var a := standard()
	check(a.use_powerup(W, "reinforcement", {"x": 4, "y": 0})["error"] == "None of your Privates has been eliminated.", "Reinforcement needs a fallen Private")
	a = standard()
	move(a, Vector2i(2, 1), Vector2i(2, 2))
	move(a, Vector2i(3, 4), Vector2i(2, 4))
	move(a, Vector2i(2, 2), Vector2i(2, 3))
	var kill := move(a, Vector2i(2, 4), Vector2i(2, 3))
	check(kill["clash"]["outcome"] == "attacker", "a white Private falls to the Colonel")
	var recruit := a.use_powerup(W, "reinforcement", {"x": 4, "y": 0})
	var new_id: String = recruit["result"]["private"]["piece"]["id"]
	check(recruit["ok"] and a.pieces[new_id]["rank"] == "PVT" and a.pieces[new_id]["y"] == 0 and a.turn == B, "the Private returns on the back row, using the turn")
	check(a.known_rank(B, new_id) == "PVT", "black knows the newcomer is a Private")

	a = standard()
	var intel := a.use_powerup(W, "spy_card")
	check(intel["ok"], "white spies first")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	var spied_white := a.use_powerup(B, "spy_card")
	var known: String = spied_white["result"]["private"]["piece_id"]
	move(a, Vector2i(1, 6), Vector2i(2, 6))
	var ranks_before := {}
	for p: Dictionary in a.pieces.values():
		ranks_before[p["id"]] = p["rank"]
	var shuffle := a.use_powerup(W, "shuffle")
	var pair: Array = shuffle["result"]["private"]["piece_ids"]
	check(shuffle["ok"] and pair.size() == 2 and not pair.has(known), "Shuffle picks two pieces black hasn't identified")
	check(a.pieces[pair[0]]["rank"] == ranks_before[pair[1]] and a.pieces[pair[1]]["rank"] == ranks_before[pair[0]], "their ranks traded places")
	check(shuffle["forget"] == pair and shuffle["event"]["public"].is_empty(), "the pair stays secret (the AI is told to forget them)")


func _test_limits() -> void:
	print("Limits")
	var a := standard()
	a.loadouts[W] = ["spy_card", "insight", "flag_hunter"]
	check(a.use_powerup(B, "spy_card")["error"] == "Powerups can only be used on your turn.", "only on your turn")
	check(a.use_powerup(W, "freeze")["error"] == "You didn't bring that powerup to this match.", "only what you brought")
	a.use_powerup(W, "spy_card")
	check(a.use_powerup(W, "spy_card")["error"] == "You already used that powerup in this match.", "each one once per match")
	a.use_powerup(W, "insight")
	check(a.use_powerup(W, "flag_hunter")["error"] == "You can't use another powerup this turn.", "two per turn, tops")
	check(a.rules_view(W)["powerups"]["used_this_turn"] == 2, "the view counts uses this turn")
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	move(a, Vector2i(1, 6), Vector2i(2, 6))
	check(a.use_powerup(W, "flag_hunter")["ok"], "the count resets next turn")
	var slots: Array = a.rules_view(W)["powerups"]["mine"]
	check(slots.all(func(s: Dictionary) -> bool: return s["used"]), "all three slots show as used")
	check(a.rules_view(B)["powerups"]["opponent_used"].size() == 3, "black sees which powerups white used")


func _test_secrecy() -> void:
	print("Secrecy")
	var a := standard()
	a.use_powerup(W, "mine_field", {"x": 6, "y": 3})
	a.use_powerup(W, "fortify", {"piece_id": id_at(a, Vector2i(3, 2))})
	move(a, Vector2i(8, 1), Vector2i(8, 2))
	a.use_powerup(B, "spy_card")
	a.use_powerup(B, "decoy", {"piece_id": id_at(a, Vector2i(8, 7))})
	# Which powerups were used is public (opponent_used); where and on what is not.
	var white_view := a.rules_view(W)
	var black_view := a.rules_view(B)
	var black_secrets := JSON.stringify([black_view["effects"], black_view["mines"], black_view["revealed"], black_view["intel"]])
	var white_secrets := JSON.stringify([white_view["effects"], white_view["mines"], white_view["revealed"], white_view["intel"]])
	check(not black_secrets.contains("fortify") and black_view["mines"].is_empty(), "black's view has no white fortify or mine")
	check(not white_secrets.contains("decoy") and not white_secrets.contains("fake_rank"), "white's view has no black decoy")
	check(black_view["powerups"]["opponent_used"] == ["mine_field", "fortify"], "black only learns which powerups white used")
	check(a.view_pieces(W).all(func(p: Dictionary) -> bool: return p["side"] == W or p["rank"] == null), "white sees no black rank")
	var black_known: Array = a.view_pieces(B).filter(func(p: Dictionary) -> bool: return p["side"] == W and p["rank"] != null)
	check(black_known.size() == 1, "black sees exactly the one white rank its Spy Card found")
	check(a.rules_view(B)["revealed"].size() == 1 and a.rules_view(W)["revealed"].is_empty(), "reveals are per side")


func _test_brain_and_ai() -> void:
	print("AI with powerups")
	var loadout := PowerupBrain.pick_loadout()
	check(loadout.size() == 5 and loadout.all(func(id: String) -> bool: return PowerupBrain.POOL.has(id)), "the AI brings 5 powerups from its pool")
	var rookie := PowerupBrain.pick_loadout(true)
	check(rookie.size() == 5 and rookie.all(func(id: String) -> bool: return PowerupBrain.ROOKIE_POOL.has(id)), "Rookie is dealt 5 simple cards")
	var ai := SalpakanAI.new(B, SalpakanAI.Difficulty.MEDIUM)
	var a := standard()
	ai.begin(a.observation(B))
	var enemy_id := id_at(a, Vector2i(3, 2))
	ai.learn(enemy_id, {"rank": "G5"})
	check(ai.possible_ranks(enemy_id).size() == 1 and ai.possible_ranks(enemy_id)[0] == "G5", "learn() pins a rank")
	ai.forget([enemy_id])
	check(ai.possible_ranks(enemy_id).size() == 15, "forget() wipes it")
	ai.learn(enemy_id, {"group": "general"})
	check(ai.possible_ranks(enemy_id).size() == 5, "a group narrows to 5 ranks")
	ai.observe({"piece_id": enemy_id, "bounced": true, "clash": {"defender_id": id_at(a, Vector2i(3, 4)), "outcome": "bounce", "eliminated": []}})
	check(ai.possible_ranks(enemy_id).size() == 5, "a bounce teaches nothing about ranks")
	ai.observe({"hidden": true, "clash": {"defender_id": id_at(a, Vector2i(3, 4)), "eliminated": []}})
	check(true, "a hidden move is digested without a mover")


# --- The second wave (mirrors the server's PowerupDeckTest) ---------------------------------------

func _quiet(seconds := 0) -> LocalArbiter:
	return board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]], seconds)


## White and black shuffle their pieces back and forth; returns each new turn's allotment.
func _rounds(a: LocalArbiter, count: int) -> Array:
	var allotments: Array = []
	for i in count:
		var up := i % 2 == 0
		if a.turn == W:
			move(a, Vector2i(4, 2 if up else 3), Vector2i(4, 3 if up else 2))
		else:
			move(a, Vector2i(4, 6 if up else 5), Vector2i(4, 5 if up else 6))
		allotments.append(a.turn_allotment)
	return allotments


func _test_new_cards() -> void:
	print("Second-wave powerups")
	var a := _quiet(45)
	a.use_powerup(W, "blitz")
	check(a.rules_view(B)["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "blitz"), "Blitz is public")
	var blitz := []
	for i in 5:
		var up := (i / 2) % 2 == 0
		if a.turn == W:
			move(a, Vector2i(4, 2 if up else 3), Vector2i(4, 3 if up else 2))
		else:
			move(a, Vector2i(4, 6 if up else 5), Vector2i(4, 5 if up else 6))
		blitz.append(a.turn_allotment)
	check(blitz == [23, 23, 23, 23, 45], "Blitz halves both players' next 2 turns (%s)" % [blitz])

	a = _quiet(45)
	a.use_powerup(W, "time_steal")
	var steal := []
	for i in 5:
		var up := (i / 2) % 2 == 0
		if a.turn == W:
			move(a, Vector2i(4, 2 if up else 3), Vector2i(4, 3 if up else 2))
		else:
			move(a, Vector2i(4, 6 if up else 5), Vector2i(4, 5 if up else 6))
		steal.append(a.turn_allotment)
	check(steal == [35, 55, 35, 55, 45], "Time Thief moves 10 s a turn from black to white (%s)" % [steal])

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]],
		[["FLG", Vector2i(8, 7)], ["CPT", Vector2i(3, 3)], ["PVT", Vector2i(6, 2)], ["SPY", Vector2i(6, 6)]])
	var sonar := a.use_powerup(W, "sonar_ping")
	check(sonar["result"]["private"] == {"count": 2} and sonar["event"]["public"].is_empty(), "Sonar Ping counts enemies on your half, secretly")
	check(a.rules_view(B)["intel"].is_empty(), "black learns nothing from the ping")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["SPY", Vector2i(4, 3)]])
	check(a.use_powerup(W, "spy_alarm")["result"]["private"] == {"alarm": true}, "Spy Alarm rings for an adjacent Spy")
	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["SPY", Vector2i(4, 5)], ["PVT", Vector2i(4, 3)]])
	check(a.use_powerup(W, "spy_alarm")["result"]["private"] == {"alarm": false}, "Spy Alarm stays quiet otherwise")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["G2", Vector2i(5, 6)]])
	check(a.use_powerup(W, "radar_sweep", {"x": 4, "y": 5})["result"]["private"] == {"x": 4, "y": 5, "found": true}, "Radar Sweep finds a General in the 3x3 area")
	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["G2", Vector2i(8, 4)]])
	check(a.use_powerup(W, "radar_sweep", {"x": 4, "y": 5})["result"]["private"]["found"] == false, "Radar Sweep reports an empty area")
	check(not a.use_powerup(W, "radar_sweep", {"x": 99, "y": 5})["ok"], "Radar Sweep needs a square on the board")

	a = _quiet()
	a.loadouts[B] = ["jammer", "freeze", "insight"]
	a.used[B] = ["insight"]
	check(a.use_powerup(W, "code_breaker")["result"]["private"] == {"cards": ["jammer", "freeze"]}, "Code Breaker reads the unplayed cards")
	check(a.rules_view(B)["intel"].is_empty(), "the codes stay with white")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["COL", Vector2i(4, 3)], ["CPT", Vector2i(6, 6)]])
	check(not a.use_powerup(W, "interrogation", {"piece_id": id_at(a, Vector2i(6, 6))})["ok"], "Interrogation needs an adjacent enemy")
	var told := a.use_powerup(W, "interrogation", {"piece_id": id_at(a, Vector2i(4, 3))})
	check(told["ok"] and told["result"]["private"]["rank"] == "COL", "Interrogation reveals the adjacent enemy's rank")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	var back := a.use_powerup(W, "retreat", {"piece_id": id_at(a, Vector2i(4, 3))})
	check(back["ok"] and back["result"]["private"]["to"] == {"x": 4, "y": 1} and a.turn == B, "Tactical Retreat falls back 2 squares and ends the turn")
	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)], ["PVT", Vector2i(4, 1)]], [["FLG", Vector2i(8, 7)]])
	check(a.use_powerup(W, "retreat", {"piece_id": id_at(a, Vector2i(4, 3))})["result"]["private"]["to"] == {"x": 4, "y": 2}, "Retreat stops at a blocking piece")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(4, 1)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	check(a.validate(W, id_at(a, Vector2i(4, 2)), Vector2i(4, 2), Vector2i(4, 4)) != "", "no dashes without Haste")
	a.use_powerup(W, "haste")
	check(a.validate(W, id_at(a, Vector2i(4, 1)), Vector2i(4, 1), Vector2i(4, 3)) == "Haste can't jump over pieces or roadblocks.", "Haste can't jump over pieces")
	check(a.legal_moves(W).any(func(m: Dictionary) -> bool: return m["to"] == Vector2i(4, 4)), "Haste dashes show up as legal moves")
	check(not move(a, Vector2i(4, 2), Vector2i(4, 4)).is_empty(), "Haste lets a piece dash 2 squares")
	move(a, Vector2i(4, 6), Vector2i(4, 5))
	check(a.validate(W, id_at(a, Vector2i(4, 1)), Vector2i(4, 1), Vector2i(4, 3)) != "", "Haste is spent after one dash")

	a = _quiet()
	check(not a.use_powerup(W, "roadblock", {"x": 4, "y": 6})["ok"], "a Roadblock needs an empty square")
	check(a.use_powerup(W, "roadblock", {"x": 4, "y": 5})["result"]["private"] == {"x": 4, "y": 5, "turns": 3}, "Roadblock placed")
	var seen: Array = a.rules_view(B)["effects"]["opponent"].filter(func(e: Dictionary) -> bool: return e["type"] == "roadblock")
	check(seen.size() == 1 and seen[0]["x"] == 4 and seen[0]["y"] == 5, "black sees the roadblock and where")
	check(a.observation(B)["blocked"] == [Vector2i(4, 5)], "the AI's observation lists the blocked square")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	check(a.validate(B, id_at(a, Vector2i(4, 6)), Vector2i(4, 6), Vector2i(4, 5)) == "A roadblock stands on that square.", "nobody enters a Roadblock")
	move(a, Vector2i(4, 6), Vector2i(3, 6))
	move(a, Vector2i(4, 3), Vector2i(4, 4))
	move(a, Vector2i(3, 6), Vector2i(3, 5))
	check(a.validate(W, id_at(a, Vector2i(4, 4)), Vector2i(4, 4), Vector2i(4, 5)) != "", "it bars white too")
	move(a, Vector2i(4, 4), Vector2i(5, 4))
	move(a, Vector2i(3, 5), Vector2i(3, 4))
	move(a, Vector2i(5, 4), Vector2i(5, 5))
	move(a, Vector2i(3, 4), Vector2i(4, 4))
	check(a.validate(W, id_at(a, Vector2i(5, 5)), Vector2i(5, 5), Vector2i(4, 5)) == "", "it lifts after black's 3rd turn")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(6, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 4)]])
	check(not a.use_powerup(W, "quicksand", {"x": 4, "y": 5})["ok"], "Quicksand goes on your own half")
	a.use_powerup(W, "quicksand", {"x": 4, "y": 3})
	check(a.rules_view(W)["mines"] == [{"x": 4, "y": 3, "kind": "quicksand", "turns_left": 10}] and a.rules_view(B)["mines"].is_empty(), "only white sees the quicksand")
	move(a, Vector2i(6, 2), Vector2i(6, 3))
	var bog := move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(bog.get("quicksand") == {"x": 4, "y": 3, "piece_id": id_at(a, Vector2i(4, 3)), "turns": 2} and bog["clash"] == null, "Quicksand catches the first enemy")
	move(a, Vector2i(6, 3), Vector2i(6, 2))
	check(a.validate(B, id_at(a, Vector2i(4, 3)), Vector2i(4, 3), Vector2i(4, 2)) == "That piece is frozen.", "the caught piece is stuck")

	a = _quiet()
	a.loadouts[B] = ["spy_card", "insight"]
	a.use_powerup(W, "counterspell")
	check(not a.rules_view(B)["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "counterspell"), "black can't see the Counterspell")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	var fizzled := a.use_powerup(B, "spy_card")
	check(fizzled["ok"] and fizzled["result"]["private"] == {"countered": true} and fizzled["event"].get("countered", false), "the next powerup fizzles")
	check(a.used[B].has("spy_card") and a.rules_view(B)["revealed"].is_empty(), "the countered card is spent, with no effect")
	check(a.use_powerup(B, "insight")["result"]["private"]["officers"] == 1, "only one card is countered")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["MAJ", Vector2i(4, 4)]])
	a.use_powerup(W, "trench", {"piece_id": id_at(a, Vector2i(4, 3))})
	check(not a.rules_view(B)["effects"]["opponent"].any(func(e: Dictionary) -> bool: return e["type"] == "trench"), "the Trench is secret")
	move(a, Vector2i(0, 0), Vector2i(0, 1))
	var dug := move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(dug["clash"]["outcome"] == "defender" and dug["clash"].get("trench") == W, "a Trench wins the defender a tie")
	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["MAJ", Vector2i(4, 4)]])
	a.use_powerup(W, "trench", {"piece_id": id_at(a, Vector2i(4, 3))})
	check(move(a, Vector2i(4, 3), Vector2i(4, 4))["clash"]["outcome"] == "both", "a Trench doesn't help an attacker")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["G5", Vector2i(4, 5)]])
	a.use_powerup(W, "ceasefire")
	move(a, Vector2i(4, 3), Vector2i(4, 4))
	check(a.validate(B, id_at(a, Vector2i(4, 5)), Vector2i(4, 5), Vector2i(4, 4)) == "Ceasefire: you can't attack this turn.", "Ceasefire forbids black's attacks")
	check(a.observation(B)["no_attack"] and not a.legal_moves(B).any(func(m: Dictionary) -> bool: return m["to"] == Vector2i(4, 4)), "the AI sees the ceasefire")
	move(a, Vector2i(4, 5), Vector2i(3, 5))
	move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(a.validate(B, id_at(a, Vector2i(3, 5)), Vector2i(3, 5), Vector2i(3, 4)) == "", "and it ends with that turn")

	a = _quiet()
	a.use_powerup(W, "spy_card")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	var burned := a.use_powerup(B, "counter_intel")
	check(burned["result"]["private"] == {"wiped": 1} and burned["forget"].size() == 1 and a.rules_view(W)["revealed"].is_empty(), "Counter-Intel wipes what white learned")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(2, 3)]], [["FLG", Vector2i(8, 7)], ["PVT", Vector2i(2, 4)]])
	check(not a.use_powerup(W, "promotion", {"piece_id": id_at(a, Vector2i(4, 2))})["ok"], "only Privates are promoted")
	var promoted := a.use_powerup(W, "promotion", {"piece_id": id_at(a, Vector2i(2, 3))})
	check(promoted["result"]["private"]["rank"] == "SGT" and promoted["event"]["public"].is_empty(), "Field Promotion makes a secret Sergeant")
	check(move(a, Vector2i(2, 3), Vector2i(2, 4))["clash"]["outcome"] == "attacker", "the new Sergeant beats a Private")

	a = _quiet()
	a.loadouts[W] = ["recall", "insight", "jammer"]
	check(not a.use_powerup(W, "recall")["ok"], "Recall needs a played card")
	a.use_powerup(W, "insight")
	var recalled := a.use_powerup(W, "recall")
	check(recalled["result"]["private"] == {"recalled": "insight"} and not a.used[W].has("insight") and a.used[W].has("recall"), "Recall puts the last card back in your hand")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	move(a, Vector2i(4, 6), Vector2i(4, 5))
	check(a.use_powerup(W, "insight")["ok"], "the recalled card works again")


# --- The third wave (mirrors the server's PowerupArsenalTest) -------------------------------------

## Both sides shuttle their pieces on the quiet board; returns each new turn's allotment.
func _shuttle(a: LocalArbiter, count: int) -> Array:
	var allotments: Array = []
	for i in count:
		var up := (i / 2) % 2 == 0
		if a.turn == W:
			move(a, Vector2i(4, 2 if up else 3), Vector2i(4, 3 if up else 2))
		else:
			move(a, Vector2i(4, 6 if up else 5), Vector2i(4, 5 if up else 6))
		allotments.append(a.turn_allotment)
	return allotments


func _has_effect(a: LocalArbiter, viewer: String, list: String, type: String) -> bool:
	return a.rules_view(viewer)["effects"][list].any(func(e: Dictionary) -> bool: return e["type"] == type)


func _cell_of(a: LocalArbiter, id: String) -> Vector2i:
	return Vector2i(a.pieces[id]["x"], a.pieces[id]["y"]) if a.pieces.has(id) else Vector2i(-1, -1)


func _test_third_wave_clock() -> void:
	print("Third wave: clock")
	check(PowerupLibrary.ids().size() == 81, "the library holds 81 cards")
	var a := _quiet(45)
	check(a.use_powerup(W, "overclock")["result"]["private"] == {"turns": 2}, "Overclock armed")
	check(_has_effect(a, B, "opponent", "overclock"), "Overclock is public")
	var over := _shuttle(a, 6)
	check(over == [45, 90, 45, 90, 45, 45], "Overclock doubles your next 2 turns (%s)" % [over])

	a = _quiet(45)
	a.timeouts[W] = 1
	_now += 30.0
	var fresh := a.use_powerup(W, "fresh_clock")
	check(fresh["result"]["private"] == {"seconds": 45} and fresh["event"]["public"] == {"seconds": 45}, "Fresh Clock tells both sides")
	check(is_equal_approx(a.time_left(), 45.0) and a.timeouts[W] == 0, "Fresh Clock restarts the clock and wipes the strikes")
	a = _quiet(45)
	a.use_powerup(W, "quick_step")
	_shuttle(a, 2)
	check(a.use_powerup(W, "fresh_clock")["error"] == "Your clock isn't running this turn.", "Fresh Clock needs a running clock")

	a = _quiet(45)
	check(a.use_powerup(W, "hurry_up")["result"]["private"] == {"turns": 1, "seconds": 15}, "Hurry Up armed")
	check(_has_effect(a, B, "opponent", "hurry_up"), "Hurry Up is public")
	var hurry := _shuttle(a, 3)
	check(hurry == [15, 45, 45], "Hurry Up caps their next turn at 15 s (%s)" % [hurry])

	a = _quiet(45)
	check(a.use_powerup(W, "time_bank")["result"]["private"] == {"turns": 3, "seconds": 15}, "Time Bank armed")
	var bank := _shuttle(a, 10)
	var mine := [bank[1], bank[3], bank[5], bank[7], bank[9]]
	check(mine == [30, 60, 60, 60, 45], "Time Bank: one short turn, then three long ones (%s)" % [mine])

	a = _quiet(45)
	check(a.use_powerup(W, "last_second")["result"]["private"] == {"turns": 3}, "Last Second armed")
	check(_has_effect(a, B, "opponent", "last_second"), "Last Second is public")
	_now += 50.0
	var passed := a.check_timeout()
	check(passed.size() == 1 and passed[0]["type"] == "pass" and passed[0]["reason"] == "last_second" and passed[0].get("last_second", false),
		"Last Second passes the overdue turn")
	check(a.turn == B and a.timeouts[W] == 0 and id_at(a, Vector2i(4, 2)) != "", "no random move and no strike")


func _test_third_wave_intel() -> void:
	print("Third wave: intel")
	var a := board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["COL", Vector2i(2, 6)]])
	var eagle := a.use_powerup(W, "eagle_eye")
	var eagle_ok: bool = eagle["result"]["private"]["pieces"].size() == 2
	for entry: Dictionary in eagle["result"]["private"]["pieces"]:
		eagle_ok = eagle_ok and a.pieces[entry["piece_id"]]["rank"] == entry["rank"] and a.known_rank(W, entry["piece_id"]) == entry["rank"]
	check(eagle_ok and eagle["event"]["public"].is_empty() and a.rules_view(B)["revealed"].is_empty(), "Eagle Eye reveals 2 ranks to white only")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["LTC", Vector2i(2, 6)]])
	check(a.use_powerup(W, "wiretap")["result"]["private"] == {"turns": 3, "pieces": 2}, "Wiretap armed")
	check(not _has_effect(a, B, "opponent", "wiretap"), "the Wiretap is secret")
	var tap: Array = a.rules_view(W)["effects"]["mine"].filter(func(e: Dictionary) -> bool: return e["type"] == "wiretap")
	check(tap.size() == 1 and tap[0]["left"] == 2, "white sees 2 taps left")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	move(a, Vector2i(4, 6), Vector2i(4, 5))
	check(a.known_rank(W, id_at(a, Vector2i(4, 5))) == "CPT", "the first enemy mover is overheard")
	move(a, Vector2i(4, 3), Vector2i(4, 2))
	move(a, Vector2i(2, 6), Vector2i(2, 5))
	check(a.known_rank(W, id_at(a, Vector2i(2, 5))) == "LTC" and not _has_effect(a, W, "mine", "wiretap"), "so is the second, then the tap is spent")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	move(a, Vector2i(8, 7), Vector2i(8, 6))
	check(a.rules_view(W)["revealed"].size() == 2 and a.rules_view(B)["revealed"].is_empty(), "only two, and only white hears them")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["COL", Vector2i(1, 6)], ["MAJ", Vector2i(4, 5)],
		["CPT", Vector2i(3, 6)], ["SGT", Vector2i(6, 5)], ["PVT", Vector2i(7, 6)], ["SPY", Vector2i(2, 5)]])
	check(a.use_powerup(W, "heat_map")["result"]["private"] == {"counts": [1, 2, 1]}, "Heat Map counts officers per third")
	check(a.rules_view(W)["intel"][0]["type"] == "heat_map" and a.rules_view(B)["intel"].is_empty(), "the map stays with white")

	for game: Array in [[Vector2i(4, 6), "win"], [Vector2i(2, 6), "lose"], [Vector2i(6, 6), "tie"]]:
		a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["COL", Vector2i(2, 6)], ["MAJ", Vector2i(6, 6)]])
		var mine_id := id_at(a, Vector2i(4, 2))
		var foe_id := id_at(a, game[0])
		check(not a.use_powerup(W, "wargame", {"piece_ids": [foe_id, mine_id]})["ok"], "War Game wants your piece first")
		var played := a.use_powerup(W, "wargame", {"piece_ids": [mine_id, foe_id]})
		check(played["result"]["private"] == {"piece_id": foe_id, "mine_id": mine_id, "rank": "MAJ", "outcome": game[1]}, "War Game: %s" % game[1])
		check(played["event"]["public"].is_empty() and a.rules_view(B)["intel"].is_empty(), "the war game stays secret (%s)" % game[1])

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(6, 5)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	check(a.use_powerup(W, "flag_sense")["result"]["private"] == {"steps": 4}, "Flag Sense measures the closest approach")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["PVT", Vector2i(2, 6)], ["PVT", Vector2i(3, 6)]])
	check(a.use_powerup(W, "census")["result"]["private"] == {"privates": 2} and a.rules_view(B)["intel"].is_empty(), "Census counts the enemy Privates")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["G2", Vector2i(4, 6)], ["PVT", Vector2i(5, 5)], ["SPY", Vector2i(0, 6)]])
	var scan := a.use_powerup(W, "satellite_scan", {"x": 4, "y": 5})
	var groups := {}
	for entry: Dictionary in scan["result"]["private"]["pieces"]:
		groups[a.pieces[entry["piece_id"]]["rank"]] = entry["group"]
	check(groups == {"G2": "general", "PVT": "enlisted"}, "Satellite Scan names the groups in the 3x3 area")
	check(a.rules_view(W)["revealed"].size() == 2 and a.rules_view(B)["revealed"].is_empty(), "the scan stays with white")

	a = _quiet()
	var b1 := id_at(a, Vector2i(4, 6))
	a._add_effect("decoy", B, B, {"piece_id": b1, "fake_rank": "G5"})
	a._reveal(W, {"piece_id": b1, "rank": "G5", "source": "spy_card"})
	check(a.use_powerup(W, "lie_detector", {"piece_id": b1})["result"]["private"] == {"piece_id": b1, "decoy": true}, "Lie Detector finds the Decoy")
	check(a.rules_view(W)["revealed"].is_empty() and not _has_effect(a, B, "mine", "decoy"), "the Decoy and its lie are gone")
	a = _quiet()
	check(a.use_powerup(W, "lie_detector", {"piece_id": id_at(a, Vector2i(4, 6))})["result"]["private"]["decoy"] == false, "no Decoy, no lie")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["SPY", Vector2i(2, 6)]])
	var spy := id_at(a, Vector2i(2, 6))
	check(a.use_powerup(W, "spy_catcher")["result"]["private"] == {"found": true, "piece_id": spy, "rank": "SPY"} and a.known_rank(W, spy) == "SPY",
		"Spy Catcher unmasks the Spy")
	a = _quiet()
	check(a.use_powerup(W, "spy_catcher")["result"]["private"] == {"found": false}, "Spy Catcher reports none")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(2, 3)]], [["FLG", Vector2i(8, 7)], ["COL", Vector2i(2, 4)], ["CPT", Vector2i(6, 6)]])
	check(not a.use_powerup(W, "debrief")["ok"], "Debrief needs a lost clash")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	move(a, Vector2i(2, 4), Vector2i(2, 3))
	check(a.use_powerup(W, "debrief")["result"]["private"] == {"piece_id": id_at(a, Vector2i(2, 3)), "rank": "COL"}, "Debrief names the piece that won")


func _test_third_wave_tactics() -> void:
	print("Third wave: tactics")
	var a := board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(5, 3)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	var w1 := id_at(a, Vector2i(4, 2))
	check(not a.use_powerup(W, "flank", {"piece_id": w1, "x": 4, "y": 3})["ok"] and not a.use_powerup(W, "flank", {"piece_id": w1, "x": 5, "y": 3})["ok"],
		"Flank needs an empty diagonal square")
	var flank := a.use_powerup(W, "flank", {"piece_id": w1, "x": 3, "y": 3})
	check(flank["event"]["public"]["to"] == {"x": 3, "y": 3} and _cell_of(a, w1) == Vector2i(3, 3) and a.turn == B, "Flank steps diagonally and ends the turn")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 1)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	check(a.use_powerup(W, "charge", {"piece_id": id_at(a, Vector2i(0, 0))})["error"] == "The Flag can't charge.", "the Flag never charges")
	check(a.use_powerup(W, "charge", {"piece_id": id_at(a, Vector2i(4, 1))})["result"]["private"]["to"] == {"x": 4, "y": 4} and a.turn == B,
		"Charge runs 3 squares forward")
	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 1)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 3)]])
	check(a.use_powerup(W, "charge", {"piece_id": id_at(a, Vector2i(4, 1))})["result"]["private"]["to"] == {"x": 4, "y": 2}, "Charge stops short of a piece")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	check(not a.use_powerup(W, "leapfrog", {"piece_id": id_at(a, Vector2i(4, 3)), "x": 4, "y": 5})["ok"], "Leapfrog needs a piece to jump")
	w1 = id_at(a, Vector2i(4, 2))
	check(a.use_powerup(W, "leapfrog", {"piece_id": w1, "x": 4, "y": 4})["ok"] and _cell_of(a, w1) == Vector2i(4, 4) and a.turn == B, "Leapfrog jumps over a neighbour")

	a = board([["FLG", Vector2i(0, 2)], ["PVT", Vector2i(2, 2)], ["MAJ", Vector2i(4, 2)], ["CPT", Vector2i(6, 2)], ["SGT", Vector2i(4, 1)]],
		[["CPT", Vector2i(6, 3)], ["FLG", Vector2i(8, 7)]])
	var private_id := id_at(a, Vector2i(2, 2))
	var major_id := id_at(a, Vector2i(4, 2))
	var formed := a.use_powerup(W, "formation", {"piece_id": major_id})
	check(formed["result"]["private"]["pieces"] == [
		{"id": private_id, "from": {"x": 2, "y": 2}, "to": {"x": 2, "y": 3}},
		{"id": major_id, "from": {"x": 4, "y": 2}, "to": {"x": 4, "y": 3}}], "Formation advances the row where it can")
	check(id_at(a, Vector2i(0, 2)) != "" and id_at(a, Vector2i(6, 2)) != "" and id_at(a, Vector2i(4, 1)) != "" and a.turn == B, "the Flag, a blocked piece and other rows hold")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(3, 5)], ["COL", Vector2i(4, 5)],
		["PVT", Vector2i(6, 5)], ["PVT", Vector2i(6, 6)], ["SGT", Vector2i(6, 7)]])
	var b1 := id_at(a, Vector2i(3, 5))
	var b2 := id_at(a, Vector2i(4, 5))
	check(not a.use_powerup(W, "tornado", {"piece_ids": [b1, id_at(a, Vector2i(6, 5))]})["ok"], "Tornado wants neighbours")
	check(not a.use_powerup(W, "tornado", {"piece_ids": [id_at(a, Vector2i(6, 6)), id_at(a, Vector2i(6, 7))]})["ok"], "Tornado spares the back rows")
	check(a.use_powerup(W, "tornado", {"piece_ids": [b1, b2]})["ok"] and _cell_of(a, b1) == Vector2i(4, 5) and _cell_of(a, b2) == Vector2i(3, 5) and a.turn == W,
		"Tornado swaps two enemy neighbours")

	a = _quiet()
	var wild := a.use_powerup(W, "wildcard")
	var drawn: String = wild["result"]["private"]["played"]
	check(wild["ok"] and PowerupLibrary.info(drawn)["target"] == "none" and not PowerupLibrary.consumes_turn(drawn) and not drawn in PowerupLibrary.WILDCARD_EXCLUDED
		and wild["event"]["public"]["played"] == drawn and a.turn == W, "Wildcard plays a random untargeted card (%s)" % drawn)

	var landed := {}
	for i in 40:
		a = _quiet()
		var flip := a.use_powerup(W, "coin_flip")
		var told: Dictionary = flip["result"]["private"]
		var learner := W if told["heads"] else B
		landed[told["heads"]] = true
		if a.known_rank(learner, told["piece_id"]) != told["rank"] or not a.rules_view(Ranks.opponent(learner))["revealed"].is_empty() \
				or flip["event"]["public"].keys() != ["heads"]:
			check(false, "Coin Flip tells exactly one side")
		if landed.size() == 2:
			break
	check(landed.size() == 2, "Coin Flip lands both ways")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["MAJ", Vector2i(4, 4)]])
	check(a.use_powerup(W, "morale_boost")["result"]["private"] == {"turns": 2} and _has_effect(a, B, "opponent", "morale_boost"), "Morale Boost is public")
	var boosted := move(a, Vector2i(4, 3), Vector2i(4, 4))
	check(boosted["clash"]["outcome"] == "attacker" and boosted["clash"].get("morale") == W, "Morale Boost wins the tie you start")

	a = _quiet()
	a.use_powerup(W, "mine_field", {"x": 2, "y": 3})
	a._mines[B].append({"x": 3, "y": 5, "from_turn": 1, "until_turn": 10, "kind": "quicksand"})
	a._add_effect("roadblock", W, B, {"x": 6, "y": 3, "from_turn": 1, "to_turn": 5})
	a._add_effect("freeze", W, B, {"piece_id": id_at(a, Vector2i(4, 2)), "from_turn": 1, "to_turn": 5})
	a._add_effect("bunker", W, B, {"piece_id": id_at(a, Vector2i(4, 6)), "from_turn": 1, "to_turn": 5})
	a.use_powerup(W, "earthquake")
	check(a.rules_view(W)["mines"].is_empty() and a.rules_view(B)["mines"].is_empty() and a.rules_view(W)["effects"]["opponent"].is_empty()
		and a.validate(W, id_at(a, Vector2i(4, 2)), Vector2i(4, 2), Vector2i(4, 3)) == "", "Earthquake clears barriers, traps and ice")

	a = _quiet()
	check(not a.use_powerup(W, "rewind")["ok"], "nothing to rewind yet")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	move(a, Vector2i(4, 6), Vector2i(4, 5))
	var mover := id_at(a, Vector2i(4, 5))
	var rewound := a.use_powerup(W, "rewind")
	check(rewound["result"]["private"] == {"piece_id": mover, "from": {"x": 4, "y": 5}, "to": {"x": 4, "y": 6}} and a.turn == B, "Rewind sends the last mover back")
	a = board([["FLG", Vector2i(0, 0)], ["PVT", Vector2i(4, 3)], ["MAJ", Vector2i(2, 2)]], [["FLG", Vector2i(8, 7)], ["COL", Vector2i(4, 4)]])
	move(a, Vector2i(2, 2), Vector2i(2, 1))
	move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(a.use_powerup(W, "rewind")["error"] == "Their last move can't be rewound.", "an attack can't be rewound")


func _test_third_wave_traps() -> void:
	print("Third wave: traps")
	var a := board([["FLG", Vector2i(0, 0)], ["PVT", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["MAJ", Vector2i(4, 4)]])
	var rigged := id_at(a, Vector2i(4, 3))
	var attacker := id_at(a, Vector2i(4, 4))
	check(a.use_powerup(W, "booby_trap", {"piece_id": rigged})["result"]["private"] == {"piece_id": rigged, "turns": 6} and not _has_effect(a, B, "opponent", "booby_trap"),
		"the Booby Trap is secret")
	move(a, Vector2i(0, 0), Vector2i(1, 0))
	var boom := move(a, Vector2i(4, 4), Vector2i(4, 3))
	check(boom["clash"]["outcome"] == "both" and boom["clash"].get("booby_trap") == W and boom["clash"]["eliminated"] == [rigged, attacker], "the winning attacker blows up too")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 4)], ["PVT", Vector2i(7, 6)]])
	a.use_powerup(W, "overwatch", {"piece_id": id_at(a, Vector2i(4, 2))})
	check(not _has_effect(a, B, "opponent", "overwatch"), "the Overwatch is secret")
	move(a, Vector2i(0, 0), Vector2i(1, 0))
	var scout := id_at(a, Vector2i(4, 4))
	check(move(a, Vector2i(4, 4), Vector2i(4, 3)).get("overwatch") == {"x": 4, "y": 3, "piece_id": scout, "turns": 2}, "Overwatch catches the first enemy to come close")
	move(a, Vector2i(1, 0), Vector2i(0, 0))
	check(a.validate(B, scout, Vector2i(4, 3), Vector2i(5, 3)) == "That piece is frozen.", "it is stuck")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["PVT", Vector2i(7, 6)]])
	check(a.use_powerup(W, "barbed_wire", {"x": 4, "y": 5})["result"]["private"] == {"cells": [{"x": 3, "y": 5}, {"x": 4, "y": 5}, {"x": 5, "y": 5}], "turns": 2},
		"Barbed Wire covers three squares")
	check(a.rules_view(B)["effects"]["opponent"].filter(func(e: Dictionary) -> bool: return e["type"] == "barbed_wire").size() == 3, "black sees the wire")
	check(a.observation(B)["blocked"].has(Vector2i(4, 5)), "the AI's observation lists the wire")
	var b1 := id_at(a, Vector2i(4, 6))
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	check(a.validate(B, b1, Vector2i(4, 6), Vector2i(4, 5)) == "Barbed wire bars that square.", "nobody crosses the wire")
	move(a, Vector2i(7, 6), Vector2i(7, 5))
	move(a, Vector2i(4, 3), Vector2i(4, 2))
	check(a.validate(B, b1, Vector2i(4, 6), Vector2i(4, 5)) != "", "for two of their turns")
	move(a, Vector2i(7, 5), Vector2i(7, 6))
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	check(a.validate(B, b1, Vector2i(4, 6), Vector2i(4, 5)) == "", "then it is cut")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)], ["PVT", Vector2i(7, 6)]])
	check(a.use_powerup(W, "flood", {"x": 4, "y": 0})["result"]["private"] == {"x": 4, "turns": 1} and _has_effect(a, B, "opponent", "flood"), "Flood is public")
	check(a.validate(W, id_at(a, Vector2i(4, 2)), Vector2i(4, 2), Vector2i(4, 3)) == "That column is flooded.", "the flood bars white too")
	check(a.observation(B)["blocked"].has(Vector2i(4, 7)), "the AI sees the whole column flooded")
	move(a, Vector2i(4, 2), Vector2i(3, 2))
	b1 = id_at(a, Vector2i(4, 6))
	check(a.validate(B, b1, Vector2i(4, 6), Vector2i(4, 5)) != "", "black can't enter the column")
	move(a, Vector2i(7, 6), Vector2i(7, 5))
	move(a, Vector2i(3, 2), Vector2i(3, 3))
	check(a.validate(B, b1, Vector2i(4, 6), Vector2i(4, 5)) == "", "the water drains after black's turn")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(6, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 4)]])
	var wired := a.use_powerup(W, "tripwire", {"x": 4, "y": 3})
	check(a.rules_view(W)["mines"] == [{"x": 4, "y": 3, "kind": "tripwire", "turns_left": 10}] and a.rules_view(B)["mines"].is_empty() and wired["event"]["public"].is_empty(),
		"only white knows the tripwire")
	move(a, Vector2i(6, 2), Vector2i(6, 3))
	var walker := id_at(a, Vector2i(4, 4))
	check(move(a, Vector2i(4, 4), Vector2i(4, 3)).get("tripwire") == {"x": 4, "y": 3, "piece_id": walker}, "the tripwire goes off")
	check(a.known_rank(W, walker) == "CPT" and a.rules_view(B)["revealed"].is_empty() and a.rules_view(W)["mines"].is_empty(), "white learns its rank")

	a = _quiet()
	var cluster: Array = a.use_powerup(W, "mine_cluster", {"x": 2, "y": 2})["result"]["private"]["mines"]
	check(cluster.size() == 2 and cluster[0] == {"x": 2, "y": 2} and absi(int(cluster[1]["x"]) - 2) + absi(int(cluster[1]["y"]) - 2) == 1, "Mine Cluster buries two mines")
	check(a.rules_view(W)["mines"].size() == 2 and a.rules_view(B)["mines"].is_empty(), "both stay secret")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["PVT", Vector2i(4, 5)], ["CPT", Vector2i(6, 6)]])
	var rebel := id_at(a, Vector2i(4, 5))
	var turned := a.use_powerup(W, "mutiny", {"piece_id": rebel})
	var recruit: Dictionary = turned["result"]["private"].get("piece", {})
	check(turned["result"]["private"]["defected"] and not a.pieces.has(rebel) and a.pieces[recruit["id"]]["side"] == W and a.pieces[recruit["id"]]["rank"] == "PVT"
		and _cell_of(a, recruit["id"]) == Vector2i(4, 5), "Mutiny turns an enemy Private")
	check(a.known_rank(B, recruit["id"]) == "PVT" and not turned["event"]["public"]["piece"].has("rank"), "black knows what it lost")
	var captain := id_at(a, Vector2i(6, 6))
	a.used[W].erase("mutiny")
	check(a.use_powerup(W, "mutiny", {"piece_id": captain})["result"]["private"] == {"piece_id": captain, "defected": false} and a.pieces[captain]["side"] == B,
		"anything but a Private stays loyal")

	a = _quiet()
	a.loadouts[B] = ["spy_card", "jammer"]
	check(a.use_powerup(W, "radio_silence")["result"]["private"] == {"turns": 3} and _has_effect(a, B, "opponent", "radio_silence"), "Radio Silence is public")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	check(a.use_powerup(B, "spy_card")["error"] == "Radio silence! No intel powerups this turn." and not a.can_use_powerup(B, "spy_card"), "intel cards are silenced")
	check(a.use_powerup(B, "jammer")["ok"], "other cards still work")


func _test_third_wave_support() -> void:
	print("Third wave: support")
	var a := _quiet()
	a.loadouts[B] = ["recon_drone"]
	check(not a.use_powerup(W, "decoy_flag", {"piece_id": id_at(a, Vector2i(0, 0))})["ok"], "the Flag can't be a decoy Flag")
	var w1 := id_at(a, Vector2i(4, 2))
	check(a.use_powerup(W, "decoy_flag", {"piece_id": w1})["result"]["private"] == {"piece_id": w1, "fake_rank": "FLG"} and not _has_effect(a, B, "opponent", "decoy"),
		"Decoy Flag dresses up a piece in secret")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	check(a.use_powerup(B, "recon_drone", {"piece_id": w1})["result"]["private"]["is_flag"] == true, "the enemy drone calls it the Flag")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["PVT", Vector2i(5, 2)], ["PVT", Vector2i(5, 1)], ["CPT", Vector2i(2, 2)]],
		[["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	w1 = id_at(a, Vector2i(4, 2))
	var w2 := id_at(a, Vector2i(5, 2))
	a._reveal(B, {"piece_id": w1, "rank": "MAJ", "source": "spy_card"})
	check(not a.use_powerup(W, "shell_game", {"piece_ids": [w1, id_at(a, Vector2i(2, 2))]})["ok"], "Shell Game wants neighbours")
	check(a.use_powerup(W, "shell_game", {"piece_ids": [w2, id_at(a, Vector2i(5, 1))]})["error"] == "Those two pieces have the same rank.", "and different ranks")
	var shell := a.use_powerup(W, "shell_game", {"piece_ids": [w1, w2]})
	check(shell["result"]["private"] == {"piece_ids": [w1, w2]} and a.pieces[w1]["rank"] == "PVT" and a.pieces[w2]["rank"] == "MAJ", "Shell Game trades the ranks")
	check(a.rules_view(B)["revealed"].is_empty() and shell["forget"] == [w1, w2] and shell["event"]["public"].is_empty(), "the enemy forgets both")

	a = _quiet()
	a.loadouts[B] = ["freeze"]
	w1 = id_at(a, Vector2i(4, 2))
	check(a.use_powerup(W, "camouflage", {"piece_id": w1})["result"]["private"] == {"piece_id": w1, "turns": 6} and not _has_effect(a, B, "opponent", "camouflage"),
		"Camouflage is secret")
	move(a, Vector2i(0, 0), Vector2i(1, 0))
	check(a.use_powerup(B, "freeze", {"piece_id": w1})["error"] == "That piece is camouflaged." and not a.used[B].has("freeze"), "enemy cards can't target it")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 3)]], [["FLG", Vector2i(8, 7)], ["G5", Vector2i(4, 4)]])
	w1 = id_at(a, Vector2i(4, 3))
	check(a.use_powerup(W, "bunker", {"piece_id": w1})["result"]["private"] == {"piece_id": w1, "turns": 2}, "Bunker built")
	var seen: Array = a.rules_view(B)["effects"]["opponent"].filter(func(e: Dictionary) -> bool: return e["type"] == "bunker")
	check(seen.size() == 1 and seen[0]["piece_id"] == w1, "black sees the bunker")
	move(a, Vector2i(0, 0), Vector2i(1, 0))
	check(a.validate(B, id_at(a, Vector2i(4, 4)), Vector2i(4, 4), Vector2i(4, 3)) == "That piece is safe in a bunker.", "nobody attacks a bunker")
	check(not a.legal_moves(B).any(func(m: Dictionary) -> bool: return m["to"] == Vector2i(4, 3)) and a.observation(B)["blocked"].has(Vector2i(4, 3)),
		"the AI sees the bunker")

	a = _quiet()
	a._eliminated = [{"id": "old1", "side": W, "rank": "PVT", "x": 1, "y": 3}, {"id": "old2", "side": W, "rank": "COL", "x": 2, "y": 3}]
	check(not a.use_powerup(W, "field_medic", {"x": 3, "y": 1})["ok"], "Field Medic needs your back row")
	var medic := a.use_powerup(W, "field_medic", {"x": 3, "y": 0})
	var patient: Dictionary = medic["result"]["private"]["piece"]
	check(patient["rank"] == "COL" and a.pieces[patient["id"]]["rank"] == "COL" and _cell_of(a, patient["id"]) == Vector2i(3, 0) and a.turn == B,
		"Field Medic revives the latest loss and ends the turn")
	check(a.known_rank(B, patient["id"]) == "COL" and not medic["event"]["public"]["piece"].has("rank") and a.rules_view(W)["eliminated"][W] == 1,
		"black is told its rank")

	a = board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["COL", Vector2i(2, 2)]], [["FLG", Vector2i(8, 7)], ["CPT", Vector2i(4, 6)]])
	w1 = id_at(a, Vector2i(4, 2))
	check(not a.use_powerup(W, "commission", {"piece_id": id_at(a, Vector2i(2, 2))})["ok"], "Colonels are not commissioned")
	var raised := a.use_powerup(W, "commission", {"piece_id": w1})
	check(raised["result"]["private"] == {"piece_id": w1, "rank": "LTC"} and a.pieces[w1]["rank"] == "LTC" and raised["event"]["public"].is_empty(), "Commission promotes one rank, secretly")

	a = _quiet()
	a.loadouts[W] = ["supply_drop", "insight"]
	var drop := a.use_powerup(W, "supply_drop")
	var card: String = drop["result"]["private"]["card"]
	check(PowerupLibrary.has(card) and not card in ["supply_drop", "insight"] and a.loadouts[W] == ["supply_drop", "insight", card], "Supply Drop adds a card")
	check(a.rules_view(W)["powerups"]["mine"].size() == 3 and a.rules_view(B)["powerups"]["opponent_used"] == ["supply_drop"] and drop["event"]["public"].is_empty(),
		"black only sees that a drop came")


func _test_third_wave_secrecy() -> void:
	print("Third wave: secrecy")
	var a := board([["FLG", Vector2i(0, 0)], ["MAJ", Vector2i(4, 2)], ["CPT", Vector2i(2, 2)], ["SGT", Vector2i(3, 2)]],
		[["FLG", Vector2i(8, 7)], ["COL", Vector2i(4, 6)], ["PVT", Vector2i(7, 6)], ["SPY", Vector2i(5, 6)], ["PVT", Vector2i(3, 5)]])
	var w1 := id_at(a, Vector2i(4, 2))
	var w2 := id_at(a, Vector2i(2, 2))
	var w3 := id_at(a, Vector2i(3, 2))
	var b1 := id_at(a, Vector2i(4, 6))
	a.loadouts[W] = ["eagle_eye", "heat_map", "wiretap", "census", "booby_trap", "camouflage", "overwatch", "decoy_flag", "tripwire",
		"mine_cluster", "flag_sense", "spy_catcher", "satellite_scan", "lie_detector", "wargame", "commission", "shell_game", "supply_drop"]
	var turns := [
		[["eagle_eye", {}], ["heat_map", {}]],
		[["wiretap", {}], ["census", {}]],
		[["booby_trap", {"piece_id": w2}], ["camouflage", {"piece_id": w2}]],
		[["overwatch", {"piece_id": w1}], ["decoy_flag", {"piece_id": w2}]],
		[["tripwire", {"x": 6, "y": 3}], ["mine_cluster", {"x": 1, "y": 1}]],
		[["flag_sense", {}], ["spy_catcher", {}]],
		[["satellite_scan", {"x": 4, "y": 5}], ["lie_detector", {"piece_id": b1}]],
		[["wargame", {"piece_ids": [w1, b1]}], ["commission", {"piece_id": w3}]],
		[["shell_game", {"piece_ids": [w2, w3]}], ["supply_drop", {}]],
	]
	var all_ok := true
	var public_empty := true
	for round in turns.size():
		for play: Array in turns[round]:
			var used := a.use_powerup(W, play[0], play[1])
			all_ok = all_ok and used["ok"]
			if not used["ok"]:
				print("    %s: %s" % [play[0], used["error"]])
			public_empty = public_empty and used["event"].get("public", {}).is_empty()
		var up: bool = round % 2 == 0
		move(a, Vector2i(4, 2 if up else 3), Vector2i(4, 3 if up else 2))
		move(a, Vector2i(7, 6 if up else 5), Vector2i(7, 5 if up else 6))
	check(all_ok, "all 18 secret cards play")
	check(public_empty, "none of them tells black anything")
	var mine := a.rules_view(W)
	check(not mine["revealed"].is_empty() and not mine["intel"].is_empty() and mine["mines"].size() == 3, "white learned plenty")
	var theirs := a.rules_view(B)
	check(theirs["revealed"].is_empty() and theirs["intel"].is_empty() and theirs["mines"].is_empty() and theirs["effects"]["opponent"].is_empty(),
		"black's view holds none of it")
	check(theirs["powerups"]["opponent_used"].size() == 18, "black only sees which cards were played")
	check(a.view_pieces(B).all(func(p: Dictionary) -> bool: return p["side"] == B or p["rank"] == null), "white ranks stay hidden")

	a = board([["FLG", Vector2i(0, 0)], ["PVT", Vector2i(4, 2)]], [["FLG", Vector2i(8, 7)], ["MAJ", Vector2i(4, 6)]])
	a.use_powerup(W, "counterspell")
	move(a, Vector2i(4, 2), Vector2i(4, 3))
	var private := id_at(a, Vector2i(4, 3))
	check(a.use_powerup(B, "mutiny", {"piece_id": private})["result"]["private"] == {"countered": true} and a.pieces[private]["side"] == W,
		"Counterspell stops a new card too")


## AI against AI with powerups on: every card in the AI's pool gets dealt, and the brain's plans
## must be legal most of the time. Random moves keep it quick; the brains still track beliefs.
func _test_brain_soak() -> void:
	print("AI powerup soak")
	var played := {}
	var refused := {}
	var plans := 0
	var deck: Array = PowerupBrain.POOL.duplicate()
	deck.shuffle()
	var games := ceili(deck.size() / 10.0)
	for g in games:
		var a := LocalArbiter.new()
		var brains := {}
		for side: String in [W, B]:
			a.deploy(side, Ranks.random_formation(side))
			var first := (g * 10 + (0 if side == W else 5)) % deck.size()
			var hand: Array = []
			for i in 5:
				hand.append(deck[(first + i) % deck.size()])
			a.set_loadout(side, hand)
			brains[side] = SalpakanAI.new(side, SalpakanAI.Difficulty.MEDIUM)
		a.start()
		for side: String in brains:
			brains[side].begin(a.observation(side))
		while not a.is_over() and a.move_number < 300:
			var side := a.turn
			var plan := PowerupBrain.choose(a, side, brains[side])
			if not plan.is_empty():
				plans += 1
				var used := a.use_powerup(side, plan["id"], plan.get("target", {}))
				if used["ok"]:
					played[plan["id"]] = played.get(plan["id"], 0) + 1
					brains[side].sync_own(a.observation(side))
					brains[Ranks.opponent(side)].sync_own(a.observation(Ranks.opponent(side)))
					if not used["forget"].is_empty():
						brains[Ranks.opponent(side)].forget(used["forget"])
					if used["ends_turn"] or a.is_over() or a.turn != side:
						continue
				else:
					refused[plan["id"]] = used["error"]
			if a.forced_move_pending():
				for result in a.play_forced():
					for s2: String in brains:
						brains[s2].observe(LocalArbiter.redact(result, s2))
				continue
			var move := a.random_move(side)
			var result := a.pass_turn(side) if move.is_empty() else a.apply(move["id"], move["to"])
			for s2: String in brains:
				brains[s2].observe(LocalArbiter.redact(result, s2))
	var never: Array = PowerupBrain.POOL.filter(func(id: String) -> bool: return not played.has(id))
	print("    %d plans, %d cards played, refused: %s, never played: %s" % [plans, played.size(), refused, never])
	check(played.size() >= PowerupBrain.POOL.size() * 0.75, "the AI plays most of its pool (%d/%d)" % [played.size(), PowerupBrain.POOL.size()])
	check(refused.size() <= 6, "the AI's plans are legal almost always (%d refused)" % refused.size())
