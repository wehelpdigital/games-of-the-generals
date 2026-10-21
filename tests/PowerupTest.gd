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
	check(a.pieces[results[0]["piece_id"]]["rank"] != "FLG", "the random move avoids the flag")
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
	move(a, Vector2i(1, 1), Vector2i(1, 2))
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
	check(loadout.size() == 3 and loadout.all(func(id: String) -> bool: return PowerupBrain.POOL.has(id)), "the AI brings 3 powerups from its pool")
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
