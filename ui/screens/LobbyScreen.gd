extends Screen
## Global lobby: open matches from other players (join one), host your own, quick match, or
## resume the match you're already in. Updates live from the public `lobby` channel, with a slow
## poll as a fallback.

const LOBBY_CHANNEL := "lobby"
const POLL_SECONDS := 6.0

var _card: PanelContainer
var _live: PanelContainer
var _resume_box: VBoxContainer
var _list: VBoxContainer
var _empty: Label
var _buttons: Array[Button] = []
var _poll: Timer
var _loading := false


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(14)
	_card.add_child(box)

	var header := AppTheme.hbox(10)
	header.add_child(AppTheme.label("Global Lobby", "HeadingLabel"))
	header.add_child(AppTheme.spacer())
	_live = AppTheme.pill("CONNECTING", AppTheme.MUTED)
	header.add_child(_live)
	box.add_child(header)

	var actions := AppTheme.hbox(10)
	for spec: Array in [["Quick Match", "Primary", _quick_match], ["Create Match", "Secondary", _create_match]]:
		var b := AppTheme.button(spec[0], spec[1], spec[2], 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_buttons.append(b)
		actions.add_child(b)
	box.add_child(actions)

	_resume_box = AppTheme.vbox(8)
	box.add_child(_resume_box)

	var list_header := AppTheme.hbox()
	list_header.add_child(AppTheme.label("Open matches", "", 22))
	list_header.add_child(AppTheme.spacer())
	list_header.add_child(AppTheme.button("Refresh", "Ghost", refresh, 40))
	box.add_child(list_header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = AppTheme.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	_empty = AppTheme.label("No open matches right now.\nCreate one and get a friend to join!", "MutedLabel")
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	box.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.show_screen("title"), 48))
	add_child(AppTheme.centered(_card, 640))

	_poll = Timer.new()
	_poll.wait_time = POLL_SECONDS
	_poll.timeout.connect(refresh)
	add_child(_poll)
	ReverbManager.event_received.connect(_on_realtime_event)
	ReverbManager.subscribed.connect(_on_subscribed)
	ReverbManager.disconnected.connect(func() -> void: _set_live(false))


func open(_args: Dictionary) -> void:
	AppTheme.pop_in(_card)
	_set_live(ReverbManager.is_subscribed(LOBBY_CHANNEL))
	_poll.start()
	refresh()
	if await GameSession.ensure_realtime():
		ReverbManager.subscribe(LOBBY_CHANNEL)
	else:
		_set_live(false)


func close() -> void:
	_poll.stop()
	ReverbManager.unsubscribe(LOBBY_CHANNEL)


func refresh() -> void:
	if _loading or not visible:
		return
	_loading = true
	var res := await ApiManager.lobby()
	_loading = false
	if not res.ok:
		if res.status == 401:
			ui.show_screen("auth", {"next": "lobby"})
		else:
			ui.toast(res.error, AppTheme.RED)
		return
	_show_resume(res.data.get("your_match"))
	_show_matches(res.data.get("data", []))


func _show_matches(matches: Array) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		if child != _empty:
			child.queue_free()
	if matches.is_empty():
		_list.add_child(_empty)
		return
	for entry: Dictionary in matches:
		_list.add_child(_match_row(entry))


func _match_row(entry: Dictionary) -> PanelContainer:
	var row := AppTheme.card("Row")
	var line := AppTheme.hbox(12)
	row.add_child(line)
	var host: Dictionary = entry.get("host", {})
	var username := str(host.get("username", "?"))
	line.add_child(AppTheme.pill(username.left(1).to_upper(), _avatar_color(username), Color.WHITE, 22))
	var info := AppTheme.vbox(0)
	info.add_child(AppTheme.label(username, "", 22))
	info.add_child(AppTheme.label("ELO %s  ·  %s" % [AppTheme.num(host.get("elo", "?")), _ago(str(entry.get("created_at", "")))], "MutedLabel", 16))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var id := int(entry.get("id", 0))
	var join := AppTheme.button("Join", "Success", func() -> void: _join(id), 46)
	_buttons.append(join)
	line.add_child(join)
	return row


func _show_resume(view: Variant) -> void:
	for child in _resume_box.get_children():
		child.queue_free()
	if not view is Dictionary:
		return
	var row := AppTheme.card("Row")
	var line := AppTheme.hbox(10)
	row.add_child(line)
	var status := str(view.get("status", ""))
	var text := "Your match is waiting for an opponent." if status == "waiting" else "You have a match in progress."
	var l := AppTheme.label(text, "", 19)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(l)
	var id := int(view.get("id", 0))
	line.add_child(AppTheme.button("Resume", "Accent", func() -> void: _run(GameSession.open_match.bind(id)), 46))
	_resume_box.add_child(row)


func _quick_match() -> void:
	await _run(GameSession.find_match)


func _create_match() -> void:
	await _run(GameSession.create_match)


func _join(id: int) -> void:
	await _run(GameSession.join_match.bind(id))


## Runs a GameSession online request with the buttons locked. Success switches to the HUD by
## itself (GameSession emits match_loaded); failures explain themselves.
func _run(request_fn: Callable) -> void:
	_set_buttons_disabled(true)
	var res: Dictionary = await request_fn.call()
	_set_buttons_disabled(false)
	if res.ok:
		return
	if res.status == 401:
		ui.show_screen("auth", {"next": "lobby"})
		return
	ui.toast(res.error, AppTheme.RED)
	refresh()


func _set_buttons_disabled(disabled: bool) -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.disabled = disabled


func _set_live(live: bool) -> void:
	AppTheme.set_pill(_live, "LIVE" if live else "AUTO-REFRESH", AppTheme.MINT if live else AppTheme.MUTED)


func _on_subscribed(channel: String) -> void:
	if channel == LOBBY_CHANNEL and visible:
		_set_live(true)


func _on_realtime_event(channel: String, event: String, _data: Dictionary) -> void:
	if channel == LOBBY_CHANNEL and event == "LobbyUpdated":
		refresh()


func _avatar_color(username: String) -> Color:
	var palette := [AppTheme.PINK, AppTheme.BLUE, AppTheme.PURPLE, AppTheme.MINT, AppTheme.BRONZE]
	return palette[absi(username.hash()) % palette.size()]


func _ago(iso: String) -> String:
	var created := Time.get_unix_time_from_datetime_string(iso.left(19))
	if iso == "" or created <= 0:
		return "just now"
	var minutes := int((Time.get_unix_time_from_system() - created) / 60.0)
	if minutes < 1:
		return "just now"
	return "%d min ago" % minutes
