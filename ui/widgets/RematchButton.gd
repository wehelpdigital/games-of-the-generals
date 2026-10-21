class_name RematchButton
extends VBoxContainer
## "Rematch" on the game-over card of an online match. Offering one waits (with a countdown and
## Cancel) for the opponent, who gets "Opponent wants a rematch!" with Accept; when both agree the
## new game (colours swapped, same powerup rules) loads for both. Shows when the opponent offered
## first, declined, withdrew or didn't answer in time. Polls while waiting in case realtime is down.

const POLL_SECONDS := 3.0
const WAIT_SECONDS := 60.0

var match_id := 0

var _state := "idle"  # idle | waiting | offered | starting | declined | cancelled | expired | blocked | passed
var _deadline := 0.0
var _note: Label
var _main: Button
var _second: Button
var _poll := 0.0
var _busy := false


func _init(for_match: int) -> void:
	match_id = for_match
	add_theme_constant_override("separation", 8)
	_note = ProfileUi.wrap("", 18)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_override("font", AppTheme.heading_font())
	add_child(_note)
	var row := AppTheme.hbox(10)
	_second = AppTheme.button("", "Ghost", _on_second, 54)
	_main = AppTheme.button("Rematch", "Accent", _on_main, 54)
	for b: Button in [_second, _main]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	add_child(row)
	_show()


func _ready() -> void:
	Social.rematch_update.connect(_on_update)
	_check()


func _exit_tree() -> void:
	if Social.rematch_update.is_connected(_on_update):
		Social.rematch_update.disconnect(_on_update)


func state() -> String:
	return _state


## Asks the server where things stand (the opponent may have offered before this card opened).
func _check() -> void:
	var res: Dictionary = await Social.rematch_status(match_id)
	if not res.ok or not is_inside_tree():
		return
	var rematch: Dictionary = res.data.get("rematch") if res.data.get("rematch") is Dictionary else {}
	var status := str(res.data.get("status", "none"))
	match status:
		"waiting":
			_set_state("waiting", rematch)
		"offered":
			_set_state("offered", rematch)
		"started":
			_set_state("starting", rematch)
			Social.open_rematch(rematch)
		"declined", "cancelled":
			if _state in ["waiting", "offered"]:
				_set_state(status, rematch)
		"expired":
			if _state in ["waiting", "offered"]:
				_set_state("expired", rematch)


func _on_update(type: String, rematch: Dictionary) -> void:
	if int(rematch.get("match_id", 0)) != match_id:
		return
	match type:
		"requested":
			_set_state("offered", rematch)
		"declined":
			_set_state("declined", rematch)
		"cancelled":
			_set_state("cancelled", rematch)
		"started":
			_set_state("starting", rematch)


func _set_state(new_state: String, rematch := {}) -> void:
	_state = new_state
	if new_state in ["waiting", "offered"]:
		var until := GameSession.parse_time(rematch.get("expires_at", ""))
		var left := until - Time.get_unix_time_from_system() if until > 0.0 else WAIT_SECONDS
		_deadline = Time.get_ticks_msec() / 1000.0 + clampf(left, 5.0, WAIT_SECONDS * 2.0)
	_show()


func _show() -> void:
	_main.visible = true
	_main.disabled = _busy
	_second.visible = false
	_note.visible = true
	match _state:
		"idle":
			_note.visible = false
			_main.text = "Rematch"
		"waiting":
			_note.text = "Waiting for opponent… %s" % _clock()
			_main.visible = false
			_second.visible = true
			_second.text = "Cancel rematch"
		"offered":
			_note.text = "Opponent wants a rematch!"
			_note.add_theme_color_override("font_color", AppTheme.PINK)
			_main.text = "Accept"
			_second.visible = true
			_second.text = "No thanks"
		"starting":
			_note.text = "Rematch on! Loading…"
			_main.visible = false
		"declined":
			_note.text = "Your opponent said no thanks."
			_main.visible = false
		"cancelled":
			_note.text = "Your opponent changed their mind."
			_main.text = "Ask for a rematch"
		"expired":
			_note.text = "No answer this time."
			_main.text = "Ask again"
		"blocked":
			_note.text = "A rematch isn't possible."
			_main.visible = false
		"passed":
			_note.text = "Maybe next time!"
			_main.visible = false
	if _state != "offered":
		_note.remove_theme_color_override("font_color")


func _clock() -> String:
	var left := maxf(0.0, _deadline - Time.get_ticks_msec() / 1000.0)
	return "%d s" % ceili(left)


func _process(delta: float) -> void:
	if _state not in ["waiting", "offered"]:
		return
	if _deadline - Time.get_ticks_msec() / 1000.0 <= 0.0:
		_set_state("expired")
		return
	if _state == "waiting":
		_note.text = "Waiting for opponent… %s" % _clock()
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		_check()


## Rematch / Accept / Ask again.
func _on_main() -> void:
	if _busy:
		return
	_busy = true
	_main.disabled = true
	var accepting := _state == "offered"
	var res: Dictionary = await Social.request_rematch(match_id)
	_busy = false
	if not is_inside_tree():
		return  # The new match loaded and the card closed.
	if not res.ok:
		_main.disabled = false
		if int(res.status) == 403:
			_set_state("blocked")
		var ui := _ui()
		if ui:
			ui.toast(str(res.error) if str(res.error) != "" else "Couldn't start a rematch.", AppTheme.RED)
		return
	var rematch: Dictionary = res.data.get("rematch") if res.data.get("rematch") is Dictionary else {}
	if str(res.data.get("status", "")) == "started":
		_set_state("starting", rematch)
	else:
		_set_state("waiting", rematch)
		_poll = POLL_SECONDS
		if accepting:
			_check()


## Cancel rematch / No thanks.
func _on_second() -> void:
	_set_state("idle" if _state == "waiting" else "passed")
	await Social.withdraw_rematch(match_id)


func _ui() -> UIRoot:
	return get_tree().root.find_child("UI", true, false) as UIRoot
