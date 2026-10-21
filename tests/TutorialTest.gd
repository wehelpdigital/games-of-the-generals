extends SmokeTestBase
## Boot Camp end to end, headless: the Boot Camp and How to Play screens, every drill played
## through the real board (taps), notes, the formation drill (a wrong Ready first), both powerup
## cards, the clock running out, the drill opponent pacing, progress saved, the graduation game
## counting a win without the normal game-over card, and the in-match Rules card.
##   godot --headless --path . res://tests/TutorialTest.tscn

const W := Ranks.WHITE

var ui: UIRoot
var _game_overs := 0


func _ready() -> void:
	TutorialProgress.reset()
	await boot()
	ui = main.get_node("UI")
	GameSession.game_over.connect(func(_info: Dictionary) -> void: _game_overs += 1)

	ui.show_screen("boot_camp")
	await frames(3)
	check(ui.current_name == "boot_camp" and ui.screen("boot_camp").visible, "the Boot Camp screen opens")
	ui.show_screen("how_to_play")
	await frames(3)
	check(ui.screen("how_to_play").visible, "the How to Play screen opens")
	check(TutorialProgress.should_nudge(), "a new player is nudged toward Boot Camp")

	for lesson: Dictionary in TutorialLessons.LESSONS:
		await _play(lesson)
	check(TutorialProgress.done_count() == TutorialLessons.LESSONS.size(), "every drill is marked done")
	await _graduation()
	check(_game_overs == 0, "Boot Camp shows its own endings (no normal game-over card)")

	GameSession.leave()
	await frames(3)
	check(GameSession.tutorial == null and not _coach().visible, "leaving ends the lesson and hides the coach")
	TutorialProgress.reset()
	finish()


## Plays one drill the way a player would.
func _play(lesson: Dictionary) -> void:
	var id: String = lesson["id"]
	GameSession.start_lesson(id)
	await _settle()
	var run := GameSession.tutorial
	check(run != null and run.lesson_id() == id and ui.current_name == "hud", "[%s] the drill starts in the match HUD" % id)
	check(_coach().visible and (_coach().get("_text") as Label).text == str(run.step().get("say", "")), "[%s] the coach says what to do" % id)
	var guard := 0
	while run and not run.done and guard < 30:
		guard += 1
		var s := run.step()
		match str(s.get("do", "")):
			"note":
				run.next_pressed()
			"move":
				var from := run._cell(s["piece"])
				var to := TutorialRun._xy(s["to"])
				if id == "moving" and run.step_index == 0:
					await _wrong_move_is_refused(run)
				var marks: Dictionary = run.marks()
				check(marks["rings"] == [from] and marks["targets"] == [to], "[%s] the board marks the piece and its square" % id)
				await tap_move(from, to)
			"any":
				var move: Dictionary = GameSession._arbiter.legal_moves(W)[0]
				await tap_move(move["from"], move["to"])
			"clock":
				check(GameSession.deadline > 0.0, "[%s] the clock runs" % id)
				GameSession._arbiter.turn_deadline = GameSession._arbiter.now() - 5.0  # Let it run out.
				await wait_until(func() -> bool: return run.step_index > 0, 5.0)
				check(run.feedback.begins_with("Too slow"), "[%s] a timeout plays a move and the coach says so" % id)
			"swap":
				var own := _own_cells()
				await tap_move(own[0], own[1])
			"ready":
				await _formation(run)
			"powerup":
				var card := str(s["id"])
				var target := {}
				if str(PowerupLibrary.info(card).get("target", PowerupLibrary.TARGET_NONE)) != PowerupLibrary.TARGET_NONE:
					target = {"piece_id": _enemy_id()}
				var used := await GameSession.use_powerup(card, target)
				check(used["ok"], "[%s] %s is played" % [id, card])
		await _settle()
	check(run != null and run.done and TutorialProgress.is_done(id), "[%s] the drill completes and is saved" % id)
	check(_coach().visible and str((_coach().get("_title") as Label).text) == "Drill complete!", "[%s] the coach shows the drill as complete" % id)


func _wrong_move_is_refused(run: TutorialRun) -> void:
	var sergeant := GameSession._arbiter.piece_at(Vector2i(2, 1))
	var refused := [false]
	var on_reject := func(_id: String, _message: String) -> void: refused[0] = true
	GameSession.move_rejected.connect(on_reject)
	await tap_move(Vector2i(2, 1), Vector2i(2, 2))
	await frames(5)
	GameSession.move_rejected.disconnect(on_reject)
	check(refused[0] and GameSession._arbiter.piece_at(Vector2i(2, 1)).get("id") == sergeant.get("id") and run.step_index == 0,
		"a move other than the drill's is refused")
	await _settle()


## The formation drill: Ready with the Flag up front is refused, then fixed.
func _formation(run: TutorialRun) -> void:
	var placements: Array = board.get_setup_placements()
	var flag: Dictionary = placements.filter(func(p: Dictionary) -> bool: return p["rank"] == "FLG")[0]
	check(int(flag["y"]) != 0, "the drill deals the Flag away from the back row")
	GameSession.submit_setup(placements)
	await frames(3)
	check(GameSession.status() == "setup" and run.step().get("do") == "ready", "Ready with the Flag up front is refused")
	var back: Dictionary = placements.filter(func(p: Dictionary) -> bool: return int(p["y"]) == 0)[0]
	var spot := Vector2i(int(flag["x"]), int(flag["y"]))
	flag["x"] = back["x"]
	flag["y"] = 0
	back["x"] = spot.x
	back["y"] = spot.y
	GameSession.submit_setup(placements)
	await frames(3)
	check(GameSession.status() == "active", "Ready with the Flag at the back starts the battle")


func _graduation() -> void:
	GameSession.start_lesson(TutorialLessons.GRADUATION_ID)
	await _settle()
	var run := GameSession.tutorial
	check(run != null and not run.scripted and GameSession.status() == "active", "the graduation game starts against the AI")
	var players: Dictionary = GameSession.match_view.get("players", {})
	check(str(players.get("black", {}).get("username", "")) == "Rookie AI", "the opponent is the Rookie AI")
	var before := int(GameSession.match_view.get("move_number", 0))
	var move := {}
	for m: Dictionary in GameSession._arbiter.legal_moves(W):
		if GameSession._arbiter.piece_at(m["to"]).is_empty():
			move = m
			break
	await tap_move(move["from"], move["to"])
	await wait_until(func() -> bool: return GameSession.is_my_turn() and int(GameSession.match_view.get("move_number", 0)) >= before + 2, 12.0)
	check(int(GameSession.match_view.get("move_number", 0)) >= before + 2, "the Rookie AI replies")
	var arbiter: LocalArbiter = GameSession._arbiter
	arbiter._finish(W, "flag_captured")
	GameSession._practice_load("finished", GameSession.version + 1)
	await frames(5)
	check(run.done and run.won and TutorialProgress.is_graduate(), "winning the graduation game graduates the player")
	check(not TutorialProgress.should_nudge(), "graduates aren't nudged any more")

	# The in-match Rules card.
	var rules: Node = _hud_widget("res://ui/hud/RulesHelp.gd")
	ui.close_dialog()
	await frames(2)
	rules.call("_open")
	await frames(3)
	check(ui._overlay.get_child_count() > 0, "the Rules button opens the rank ladder card")
	ui.close_dialog()


## Wait until the drill is ready for the player: their turn (or setup), nothing animating.
func _settle() -> void:
	await frames(2)
	await wait_until(_ready_for_player, 12.0)
	await frames(2)


func _ready_for_player() -> bool:
	var run := GameSession.tutorial
	if run == null:
		return true
	if run.done:
		return not board.is_animating()
	var ready_turn := GameSession.status() == "setup" or GameSession.is_my_turn()
	return not run.waiting and ready_turn and not board.is_animating()


func _own_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for p: Dictionary in board.get_setup_placements():
		cells.append(Vector2i(int(p["x"]), int(p["y"])))
	return cells


func _enemy_id() -> String:
	for p: Dictionary in GameSession._arbiter.pieces.values():
		if p["side"] != W:
			return p["id"]
	return ""


func _coach() -> Control:
	return _hud_widget("res://ui/hud/TutorialCoach.gd")


## A HUD widget by script: in its slot, or moved out of it (the coach on phones).
func _hud_widget(path: String) -> Control:
	for node in ui.screen("hud").find_children("*", "Control", true, false):
		if node.get_script() and (node.get_script() as Script).resource_path == path:
			return node
	return null
