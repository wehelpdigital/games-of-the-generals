class_name TutorialRun
extends Node
## One Boot Camp lesson being played (GameSession.tutorial). It walks the lesson's stages and
## steps, checks the player's moves against the step (a drill keeps to its lesson), scripts the
## drill opponent's replies, and tells the coach (ui/hud/TutorialCoach) what to say and which
## squares to light up. The graduation game is played against the real Rookie AI instead.
##
## GameSession builds each stage's board (begin_stage) and reports what happens: on_result for
## every move, on_finished when a stage's game ends, on_ready for a formation, on_powerup for cards.

signal changed  ## The coach's text, marks or progress changed: read state().
signal stage_finished  ## The current stage is done and another follows: GameSession loads it.
signal exit_requested  ## The player resigned or quit the lesson.

const STAGE_PAUSE := 2.2  ## Seconds the coach's reaction stays up before the next stage loads.

var lesson: Dictionary
var scripted := true  ## False for the graduation game: the Rookie AI plays black.
var stage_index := 0
var step_index := 0
var done := false  ## The whole lesson is complete.
var won := false  ## Graduation: whether the player won.
var feedback := ""  ## The coach's reaction to the last thing that happened ("Higher rank wins!").
var feedback_good := true
var waiting := false  ## Between stages: nothing to do until the next one loads.

var _arbiter: LocalArbiter
var _idler := ""  ## The drill opponent's only moving piece.
var _idler_home := Vector2i(-1, -1)
var _piece_ids: Dictionary = {}  ## "x,y" (where the stage put it) -> id, for the steps' cells


func _init(lesson_data: Dictionary, first_stage := 0) -> void:
	lesson = lesson_data
	scripted = not lesson.get("ai", false)
	stage_index = clampi(first_stage, 0, (lesson["stages"] as Array).size() - 1)


func _ready() -> void:
	GameSession.powerup_used.connect(_on_powerup_used)


# --- Queries ------------------------------------------------------------------------------------

func lesson_id() -> String:
	return lesson["id"]


func stage() -> Dictionary:
	return lesson["stages"][stage_index]


func step() -> Dictionary:
	var steps: Array = stage()["steps"]
	return steps[step_index] if step_index < steps.size() else {}


func is_graduation() -> bool:
	return lesson_id() == TutorialLessons.GRADUATION_ID


## Name shown for the drill opponent in the match bar.
func opponent_name() -> String:
	return "Rookie AI" if is_graduation() else "Drill Sergeant"


## Everything the coach needs: lesson, text, progress, buttons and board marks.
func state() -> Dictionary:
	var s := step()
	var number := step_index
	for i in stage_index:
		number += (lesson["stages"][i]["steps"] as Array).size()
	return {
		"id": lesson_id(), "title": lesson["title"], "graduation": is_graduation(),
		"index": TutorialLessons.index_of(lesson_id()), "count": TutorialLessons.LESSONS.size(),
		"text": "" if done or waiting else str(s.get("say", "")),
		"feedback": feedback, "feedback_good": feedback_good,
		"step": mini(number, TutorialLessons.step_count(lesson)), "steps": TutorialLessons.step_count(lesson),
		"next_button": not done and not waiting and s.get("do") == "note",
		"done": done, "won": won, "waiting": waiting,
		"marks": marks(),
	}


## Board marks for the current step: rings on cells and an arrow from the piece to its target.
func marks() -> Dictionary:
	var s := step()
	if done or waiting or not s.get("do") in ["move"]:
		return {"rings": [], "targets": [], "arrow": []}
	var from := _cell(s["piece"])
	var to := _xy(s["to"])
	return {"rings": [from], "targets": [to], "arrow": [from, to]}


# --- From GameSession ---------------------------------------------------------------------------

## A new stage's board is ready: find the pieces its steps talk about and greet the player.
func begin_stage(arbiter: LocalArbiter) -> void:
	_arbiter = arbiter
	step_index = 0
	waiting = false
	_piece_ids.clear()
	_idler = ""
	for p: Dictionary in arbiter.pieces.values():
		_piece_ids["%d,%d" % [p["x"], p["y"]]] = p["id"]
	for entry: Array in stage().get("black", []):
		if entry.size() > 3 and "i" in str(entry[3]):
			_idler = _piece_ids.get("%d,%d" % [entry[1], entry[2]], "")
			_idler_home = Vector2i(entry[1], entry[2])
	if stage_index > 0:
		feedback = ""  # The last stage's reaction was shown while this one loaded.
	changed.emit()


## "" when the player may make this move now, otherwise what the coach says instead.
func check_move(piece_id: String, from: Vector2i, to: Vector2i) -> String:
	if not scripted:
		return ""
	if done:
		return "Drill complete! Tap Next drill to keep going."
	if waiting:
		return "Hold on, the next drill is loading."
	var s := step()
	match str(s.get("do", "")):
		"move":
			if piece_id != _expected_piece() or to != _xy(s["to"]):
				return "Try the glowing move: tap the highlighted piece, then the marked square."
		"any", "clock":
			return ""
		"note":
			return "Read the tip, then press Next."
		"powerup":
			return "Play the %s card first (it's in your hand)." % PowerupLibrary.display_name(str(s["id"]))
		_:
			return "Follow the coach's instructions first."
	return ""


## Every move result of the stage, both sides (full, unredacted).
func on_result(result: Dictionary) -> void:
	if done or waiting or str(result.get("side", "")) != Ranks.WHITE:
		return
	var s := step()
	var kind := str(s.get("do", ""))
	var after: Dictionary = s.get("after", {})
	match kind:
		"move":
			if str(result.get("piece_id", "")) != _expected_piece():
				return
			var clash: Variant = result.get("clash")
			var outcome := str(clash.get("outcome", "")) if clash is Dictionary else "move"
			_react(str(after.get(outcome, after.get("move", ""))), outcome in ["move", "attacker", "both"])
			_advance()
		"any":
			_react(str(after.get("move", "")), true)
			_advance()
		"clock":
			var auto: bool = result.get("auto", false)
			_react(str(after.get("auto" if auto else "move", "")), not auto)
			if _arbiter != null:
				_arbiter.turn_seconds = 0  # Lesson learned: no clock while the player reads on.
			_advance()


## The stage's game ended (flag captured or reached, a forfeit, the graduation result).
func on_finished(info: Dictionary) -> void:
	if done:
		return
	if is_graduation():
		won = bool(info.get("you_won", false))
		if won:
			TutorialProgress.graduate()
			_react("You won! You're officially a Boot Camp graduate.", true)
			_complete()
		else:
			_react("So close! Every General loses a battle. Try the graduation game again.", false)
			done = true
			changed.emit()
		return
	if step().get("do") == "win":
		_advance()


## The player pressed Ready: "" when the formation is fine for this step, else what to fix.
func formation_problem(placements: Array) -> String:
	if not scripted or step().get("do") != "ready":
		return "" if step().get("do") != "swap" else "First try swapping two of your pieces."
	for p: Dictionary in placements:
		if p["rank"] == "FLG" and int(p["y"]) != 0:
			_react("Your Flag is too far forward. Move it to your back row first (the row nearest you).", false)
			changed.emit()
			return "Put your Flag in the back row first."
	return ""


func on_ready() -> void:
	if step().get("do") == "ready":
		_react(str(step().get("after", {}).get("done", "")), true)
		_advance()


## The board reports a swap during the formation step.
func on_swap() -> void:
	if step().get("do") == "swap":
		_react(str(step().get("after", {}).get("done", "")), true)
		_advance()


## The coach's Next button.
func next_pressed() -> void:
	if step().get("do") == "note":
		feedback = ""
		_advance()


## The drill opponent's reply: its idler paces between its square and a free neighbour, keeping
## clear of the player's pieces. Every other enemy piece is part of the lesson and stays put, so
## with nothing to pace it passes ({}).
func black_move(arbiter: LocalArbiter) -> Dictionary:
	if _idler == "" or not arbiter.pieces.has(_idler):
		return {}
	var idler := _idler
	var idle := arbiter.legal_moves(Ranks.BLACK).filter(func(m: Dictionary) -> bool: return m["id"] == idler and arbiter.piece_at(m["to"]).is_empty())
	if idle.is_empty():
		return {}
	var piece: Dictionary = arbiter.pieces[_idler]
	var at := Vector2i(piece["x"], piece["y"])
	for m: Dictionary in idle:
		if at != _idler_home and m["to"] == _idler_home:
			return m  # Back home when away.
	idle.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _crowding(arbiter, a["to"]) < _crowding(arbiter, b["to"]))
	return idle[0]


# --- Internals ------------------------------------------------------------------------------------

func _on_powerup_used(event: Dictionary) -> void:
	if done or waiting or not event.get("mine", false):
		return
	var s := step()
	if s.get("do") == "powerup" and str(event.get("id", "")) == str(s["id"]):
		_react(str(s.get("after", {}).get("done", "")), true)
		_advance()


func _advance() -> void:
	step_index += 1
	if step_index < (stage()["steps"] as Array).size():
		changed.emit()
		return
	if stage_index + 1 < (lesson["stages"] as Array).size():
		waiting = true
		changed.emit()
		await get_tree().create_timer(STAGE_PAUSE).timeout
		if not is_inside_tree():
			return
		stage_index += 1
		stage_finished.emit()
		return
	_complete()


func _complete() -> void:
	done = true
	if not is_graduation():
		TutorialProgress.mark_done(lesson_id())
	changed.emit()


func _react(text: String, good: bool) -> void:
	feedback = text
	feedback_good = good


func _expected_piece() -> String:
	var s := step()
	return _piece_ids.get("%d,%d" % [s["piece"][0], s["piece"][1]], "") if s.has("piece") else ""


## How many player pieces stand next to `cell` (the idler keeps its distance).
func _crowding(arbiter: LocalArbiter, cell: Vector2i) -> int:
	var count := 0
	for n in Ranks.neighbors(cell):
		var p := arbiter.piece_at(n)
		if not p.is_empty() and p["side"] == Ranks.WHITE:
			count += 1
	return count


static func _xy(xy: Array) -> Vector2i:
	return Vector2i(int(xy[0]), int(xy[1]))


## Where a step's piece (named by the square the stage put it on) stands now: it may have moved
## during earlier steps.
func _cell(xy: Array) -> Vector2i:
	var start := Vector2i(int(xy[0]), int(xy[1]))
	var id: String = _piece_ids.get("%d,%d" % [start.x, start.y], "")
	if id != "" and _arbiter != null and _arbiter.pieces.has(id):
		var p: Dictionary = _arbiter.pieces[id]
		return Vector2i(p["x"], p["y"])
	return start
