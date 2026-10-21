extends SmokeTestBase
## Screenshots of the powerup hand (raised card, targeting, the effects tray, banners, the
## opponent's card flipping up), intel markers, shields, mines and Smoke Screen fog, and the powerup
## library, for visual review. Also checks that tapping a card raises it and that picking a target
## on the board really plays a targeted card. Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/PowerupShots.tscn -- --out=<dir>
## Add --device=phone_portrait (with --resolution 390x844) and so on for the other layouts.

const W := Ranks.WHITE
const B := Ranks.BLACK

var _out := "user://powerup_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await boot()
	var ui: UIRoot = main.get_node("UI")
	ui.show_screen("powerups")
	await _shot("01_library", 1.2)
	ui.screen("powerups")._inspect("counterspell")
	await _shot("01b_library_inspect", 0.8)
	ui.close_dialog()

	GameSession.start_practice(SalpakanAI.Difficulty.EASY)
	await frames(5)
	GameSession.submit_setup(board.get_setup_placements())
	await wait_until(func() -> bool: return GameSession.status() == "active" and not board.is_animating())
	var arbiter: LocalArbiter = GameSession._arbiter
	arbiter.loadouts[W] = ["spy_card", "freeze", "fortify", "smoke_screen", "counterspell"]
	_reload()
	await _shot("02_hand", 1.8)  # After the opening deal turns every card up.

	var bar := _bar(ui)
	var card: PowerupCard = bar._cards["fortify"]
	var tap := card.get_global_rect().position + Vector2(card.size.x * 0.5, 16.0)  # Its uncovered top edge.
	await pointer(tap, true)
	await pointer(tap, false)
	check(bar._raised == card, "tapping a card raises it")
	await _shot("03_inspect", 0.6)

	bar._lower()
	bar._activate("freeze")
	await _shot("04_targeting_freeze", 0.6)
	var fx := ui.game.rules_fx()
	check(fx.is_targeting() and not fx._valid.is_empty(), "Freeze asks for a target")
	if not fx._valid.is_empty():
		fx._pick(fx._valid[0])
	await wait_until(func() -> bool: return arbiter.used[W].has("freeze"), 3.0)
	check(arbiter.used[W].has("freeze"), "picking a target on the board plays the card")
	await get_tree().create_timer(1.2).timeout
	check(bar._cards["freeze"].face_down, "a played card lies face down")

	arbiter._usage = {"side": "", "turn": 0, "count": 0}  # Room for two more this turn.
	await GameSession.use_powerup("spy_card")
	var my_piece := _own_piece(arbiter)
	await GameSession.use_powerup("fortify", {"piece_id": my_piece})
	await _shot("05_intel_and_shield", 1.2)

	# Black's side: a frozen piece of ours, a squeeze on our clock, smoke over their army.
	arbiter._add_effect("freeze", W, B, {"piece_id": _own_piece(arbiter, 1), "from_turn": 0, "to_turn": 99})
	arbiter._add_effect("time_squeeze", W, B, {"from_turn": 0, "to_turn": 99, "seconds": -15})
	arbiter._mines[W].append({"x": 4, "y": 3, "until_turn": 99})
	arbiter._revealed[W].append({"piece_id": _enemy_piece(arbiter, 2), "group": "officer", "source": "scout_report", "move_number": 0})
	arbiter._revealed[W].append({"piece_id": _enemy_piece(arbiter, 3), "is_flag": false, "source": "recon_drone", "move_number": 0})
	arbiter._start_fog(B)
	arbiter.turn_deadline = arbiter.now() + 7.5
	arbiter.turn_allotment = 30
	_reload()
	await frames(5)
	bar._toggle_tray()
	await _shot("06_fog_mines_effects", 1.6)
	bar._toggle_tray()

	GameSession.powerup_used.emit({"side": B, "id": "chaos_order", "name": "Chaos Order", "public": {}, "mine": false})
	await _shot("07_opponent_card", 1.0)
	await get_tree().create_timer(2.2).timeout
	GameSession.powerup_used.emit({"side": B, "id": "blitz", "name": "Blitz", "public": {"countered": true}, "countered": true, "mine": false})
	await _shot("08_opponent_countered", 1.1)
	await get_tree().create_timer(2.2).timeout
	if not Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--device=")):
		# Portrait phone layout (last: resizing the window back can stall some drivers).
		get_window().size = Vector2i(720, 1280)
		await _shot("09_portrait", 1.2)
		bar._raise(bar._cards["counterspell"])
		await _shot("10_portrait_inspect", 0.8)
	finish()


func _reload() -> void:
	GameSession._practice_load("active", GameSession.version)


func _bar(ui: UIRoot) -> Node:
	for node in ui.screen("hud").find_children("*", "VBoxContainer", true, false):
		if node.has_method("_activate"):
			return node
	return null


func _own_piece(arbiter: LocalArbiter, skip := 0) -> String:
	var mine: Array = arbiter.pieces.values().filter(func(p: Dictionary) -> bool: return p["side"] == W and p["y"] == 2)
	return mine[skip]["id"]


func _enemy_piece(arbiter: LocalArbiter, skip := 0) -> String:
	var theirs: Array = arbiter.pieces.values().filter(func(p: Dictionary) -> bool: return p["side"] == B and p["y"] == 5)
	return theirs[skip]["id"]


func _shot(file: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
