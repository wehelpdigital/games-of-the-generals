extends Screen
## Global lobby: quick match, ranked, custom rooms, open matches from other players (join one),
## host your own, or resume the match you're already in. Updates live from the public `lobby`
## channel, with a slow poll as a fallback.

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

	var specs := [
		[["Quick Match", "Primary", _quick_match], ["Ranked", "Accent", func() -> void: ui.show_screen("ranked", {"back": "lobby"})]],
		[["Custom Rooms", "Secondary", func() -> void: ui.show_screen("rooms", {"back": "lobby"})], ["Host Match", "Ghost", _create_match]],
	]
	for row_specs: Array in specs:
		var actions := AppTheme.hbox(10)
		for spec: Array in row_specs:
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

	box.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.home(), 48))
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
	var avatar := AvatarView.new(44.0)
	avatar.set_user(host)
	line.add_child(avatar)
	var info := AppTheme.vbox(0)
	var is_room: bool = entry.get("is_room", false) or entry.get("name") != null or entry.get("room_name") != null
	var title := str(entry.get("name", entry.get("room_name", ""))) if is_room else username
	info.add_child(AppTheme.label(title if title != "" else username, "", 22))
	var sub := "ELO %s" % AppTheme.num(host.get("elo", "?"))
	if is_room:
		sub = "by " + username
	elif host.get("rank_tier") != null:
		sub = PlayerRanks.name_of(host["rank_tier"])
	info.add_child(AppTheme.label("%s  ·  %s" % [sub, _ago(str(entry.get("created_at", "")))], "MutedLabel", 16))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	if entry.get("has_password", false):
		var lock := TextureRect.new()
		lock.texture = EmojiPicker.icon("lock")
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.custom_minimum_size = Vector2(26, 26)
		lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(lock)
	var id := int(entry.get("id", 0))
	line.add_child(GameOptions.mode_pill(str(entry.get("powerup_mode", PowerupLibrary.MODE_SELECT))))
	var join := AppTheme.button("Join", "Success", _join_entry.bind(entry) if is_room else _join.bind(id, str(entry.get("powerup_mode", PowerupLibrary.MODE_SELECT))), 46)
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
	GameOptions.ask(ui, {
		"title": "Quick Match",
		"subtitle": "You'll face someone who picked the same powerup rules.",
		"confirm": "Find match",
	}, func(mode: String) -> void: _run(GameSession.find_match.bind(mode)))


func _create_match() -> void:
	GameOptions.ask(ui, {"title": "Host Match", "subtitle": "Your rules: whoever joins plays by them.", "confirm": "Host"},
		func(mode: String) -> void: _run(GameSession.create_match.bind(mode)))


func _join(id: int, mode := PowerupLibrary.MODE_SELECT) -> void:
	GameOptions.ask(ui, {"title": "Join Match", "subtitle": "The host chose these rules.", "confirm": "Join", "fixed_mode": mode},
		func(_mode: String) -> void: _run(GameSession.join_match.bind(id)))


## Rooms join through the rooms screen, which asks for the password when there is one.
func _join_entry(entry: Dictionary) -> void:
	var room := entry.duplicate()
	if not room.has("name"):
		room["name"] = entry.get("room_name", "Room")
	ui.screen("rooms").call("join_room", room)


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


func _ago(iso: String) -> String:
	var created := Time.get_unix_time_from_datetime_string(iso.left(19))
	if iso == "" or created <= 0:
		return "just now"
	var minutes := int((Time.get_unix_time_from_system() - created) / 60.0)
	if minutes < 1:
		return "just now"
	return "%d min ago" % minutes
