extends Screen
## Custom rooms: host a named room (optionally password-locked) or join one from the list. The
## list refreshes live from the `lobby` channel (LobbyUpdated), with a slow poll as a fallback.
## Joining a locked room asks for its password; your own room offers "Open" instead of "Join", and
## "Copy link": a one-time invite link that seats a friend without the password. Tap a host's
## photo for their player card.

const LOBBY_CHANNEL := "lobby"
const POLL_SECONDS := 6.0

var _card: PanelContainer
var _live: PanelContainer
var _name: LineEdit
var _password: LineEdit
var _create: Button
var _list: VBoxContainer
var _empty: Label
var _poll: Timer
var _loading := false
var _busy := false
var _back := ""


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(14)
	_card.add_child(box)

	var header := HFlowContainer.new()  # Title and live pill; the pill wraps under on phones.
	header.add_theme_constant_override("h_separation", 10)
	header.add_theme_constant_override("v_separation", 6)
	var heading := AppTheme.label("Custom Rooms", "HeadingLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_live = AppTheme.pill("CONNECTING", AppTheme.MUTED)
	_live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_live)
	box.add_child(header)

	var host := AppTheme.card("Row")
	var host_box := AppTheme.vbox(10)
	host.add_child(host_box)
	_name = AppTheme.field("Room name (e.g. Friday Night Generals)")
	_name.max_length = 40
	host_box.add_child(_name)
	var host_row := BoxContainer.new()
	host_row.vertical = UiScale.narrow(self)  # Phones: the Host button goes under the password.
	host_row.add_theme_constant_override("separation", 10)
	_password = AppTheme.field("Password (optional)", true)
	_password.max_length = 40
	_password.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_password.text_submitted.connect(func(_text: String) -> void: _create_room())
	host_row.add_child(_password)
	_create = AppTheme.button("Host Room", "Primary", _create_room, 52)
	host_row.add_child(_create)
	host_box.add_child(host_row)
	box.add_child(host)

	var list_header := AppTheme.hbox()
	list_header.add_child(AppTheme.label("Open rooms", "", 22))
	list_header.add_child(AppTheme.spacer())
	list_header.add_child(AppTheme.button("Refresh", "Ghost", refresh, 40))
	box.add_child(list_header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 216
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = AppTheme.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	_empty = AppTheme.label("No rooms open right now.\nHost one and share the name with your friends!", "MutedLabel")
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	box.add_child(AppTheme.button("Back", "Ghost", _go_back, 48))
	add_child(_page(_card, 680))

	_poll = Timer.new()
	_poll.wait_time = POLL_SECONDS
	_poll.timeout.connect(refresh)
	add_child(_poll)
	ReverbManager.event_received.connect(_on_realtime_event)
	ReverbManager.subscribed.connect(_on_subscribed)
	ReverbManager.disconnected.connect(func() -> void: _set_live(false))


func open(args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen("auth", {"next": "rooms"})
		return
	_back = str(args.get("back", ""))
	AppTheme.pop_in(_card)
	_set_live(ReverbManager.is_subscribed(LOBBY_CHANNEL))
	if _name.text == "":
		_name.text = "%s's room" % str(ApiManager.user.get("username", "General"))
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
	var res: Dictionary = await Social.list_rooms()
	_loading = false
	if not res.ok:
		if res.status == 401:
			ui.show_screen("auth", {"next": "rooms"})
		elif res.error != "":
			ui.toast(res.error, AppTheme.RED)
		return
	show_rooms(res.data.get("data", []))


func show_rooms(rooms: Array) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		if child != _empty:
			child.queue_free()
	if rooms.is_empty():
		_list.add_child(_empty)
		return
	for room: Variant in rooms:
		if room is Dictionary:
			_list.add_child(_room_row(room))


func _room_row(room: Dictionary) -> PanelContainer:
	var row := AppTheme.card("Row")
	var line := AppTheme.hbox(12)
	row.add_child(line)
	var host: Dictionary = room.get("host") if room.get("host") is Dictionary else {}
	var avatar := AvatarView.new(36.0 if UiScale.narrow(self) else 46.0)
	avatar.set_user(host)
	if not room.get("is_yours", false):
		avatar.mouse_filter = Control.MOUSE_FILTER_STOP
		avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		avatar.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				PlayerCardSheet.open(ui, host))
	line.add_child(avatar)
	var info := AppTheme.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label(str(room.get("name", "Room")), "", 22)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	info.add_child(title)
	var tier: Variant = host.get("rank_tier")
	var by := "by %s" % str(host.get("username", "?"))
	if tier != null:
		by += "  ·  %s" % PlayerRanks.name_of(tier)
	by += "  ·  %s" % _ago(str(room.get("created_at", "")))
	var sub := AppTheme.label(by, "MutedLabel", 15)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.clip_text = true
	info.add_child(sub)
	line.add_child(info)
	var rules := GameOptions.mode_pill(str(room.get("powerup_mode", PowerupLibrary.MODE_SELECT)), 13, UiScale.narrow(self))
	if UiScale.narrow(self):
		rules.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		info.add_child(rules)  # Phones: the rules sit under the room's name.
	else:
		line.add_child(rules)
	if room.get("has_password", false):
		var lock := _icon("lock", 28.0)
		lock.tooltip_text = "Password required"
		lock.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(lock)
	var action := AppTheme.button("Open", "Accent", _open_own.bind(int(room.get("id", 0))), 46) if room.get("is_yours", false) 		else AppTheme.button("Join", "Success", join_room.bind(room), 46)
	if UiScale.narrow(self):
		action.add_theme_font_size_override("font_size", 19)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if room.get("is_yours", false):
		var link := AppTheme.button("Copy link", "Ghost", _copy_link.bind(int(room.get("id", 0))), 40 if UiScale.narrow(self) else 46)
		link.add_theme_font_size_override("font_size", 16 if UiScale.narrow(self) else 18)
		link.tooltip_text = "A one-time link that lets a friend straight in (no password needed)"
		link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if UiScale.narrow(self):
			link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			info.add_child(link)  # Phones: under the room's name.
		else:
			line.add_child(link)
	line.add_child(action)
	return row


static func _icon(icon_name: String, size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = EmojiPicker.icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


## Joins a room: shows the host's powerup rules (and asks a locked room's password) first. Also
## used by the lobby list.
func join_room(room: Dictionary) -> void:
	var id := int(room.get("id", 0))
	var field: LineEdit = null
	var extra: Control = null
	if room.get("has_password", false):
		var box := AppTheme.vbox(8)
		var head := AppTheme.hbox(8)
		head.add_child(_icon("lock", 28.0))
		var note := ProfileUi.wrap("This room is locked. Enter its password to join.", 16, AppTheme.MUTED)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(note)
		box.add_child(head)
		field = AppTheme.field("Password", true)
		field.max_length = 40
		box.add_child(field)
		extra = box
	var opts := {
		"title": str(room.get("name", "Room")),
		"subtitle": "The host chose these rules.",
		"confirm": "Join",
		"fixed_mode": str(room.get("powerup_mode", PowerupLibrary.MODE_SELECT)),
		"extra": extra,
	}
	if field:
		opts["check"] = func() -> String: return "Type the password first." if field.text == "" else ""
	GameOptions.ask(ui, opts, func(_mode: String) -> void: _run(Social.join_room.bind(id, field.text if field else "")))
	if field:
		field.grab_focus.call_deferred()


## Copies a one-time invite link to your room (never its password).
func _copy_link(id: int) -> void:
	var res: Dictionary = await Social.room_link(id)
	if not res.ok:
		ui.toast(str(res.error), AppTheme.RED)
		return
	DisplayServer.clipboard_set(str(res["url"]))
	ui.toast("Invite link copied! It works once, for 30 minutes.", AppTheme.MINT)


## Your own room is a waiting match: open it to wait at the table.
func _open_own(id: int) -> void:
	await _run(GameSession.open_match.bind(id))


func _create_room() -> void:
	var room_name := _name.text.strip_edges()
	if room_name.length() < 3:
		ui.toast("Give your room a name (3+ letters).", AppTheme.MUTED)
		return
	var password := _password.text
	GameOptions.ask(ui, {
		"title": "Host \"%s\"" % room_name,
		"subtitle": "Everyone who joins plays by your rules.",
		"confirm": "Host Room",
	}, func(mode: String) -> void: _run(Social.create_room.bind(room_name, password, mode)))


## Runs a room request with the buttons locked. Success switches to the HUD by itself.
func _run(request_fn: Callable) -> void:
	if _busy:
		return
	_busy = true
	_create.disabled = true
	var res: Dictionary = await request_fn.call()
	_busy = false
	_create.disabled = false
	if res.ok:
		_password.text = ""
		return
	match int(res.status):
		401:
			ui.show_screen("auth", {"next": "rooms"})
			return
		422:
			var problem := Social.field_error(res, "password")
			ui.toast(problem if problem != "" else "Wrong room password.", AppTheme.RED)
		429:
			ui.toast("Too many wrong passwords. Try again in a minute.", AppTheme.RED)
		409:
			var busy_id := int(res.data.get("match_id", 0))
			if busy_id > 0:
				ui.confirm("You're already in a match. Jump back into it?", "Resume", _resume.bind(busy_id), false)
				return
			ui.toast(res.error if res.error != "" else "That room is full.", AppTheme.RED)
		_:
			ui.toast(res.error, AppTheme.RED)
	refresh()


func _resume(id: int) -> void:
	await _run(GameSession.open_match.bind(id))


## The card centred on screen; it scrolls when taller than the screen (phones, short windows).
func _page(card: Control, max_width: float) -> ScrollContainer:
	return AppTheme.page_scroll(self, card, max_width)


func _go_back() -> void:
	if _back != "" and ui.has_screen(_back):
		ui.show_screen(_back)
	else:
		ui.home()


func _set_live(live: bool) -> void:
	AppTheme.set_pill(_live, "LIVE" if live else "AUTO-REFRESH", AppTheme.MINT if live else AppTheme.MUTED)


func _on_subscribed(channel: String) -> void:
	if channel == LOBBY_CHANNEL and visible:
		_set_live(true)


func _on_realtime_event(channel: String, event: String, _data: Dictionary) -> void:
	if channel == LOBBY_CHANNEL and Social.event_name(event) == "LobbyUpdated" and visible:
		refresh()


static func _ago(iso: String) -> String:
	var created := Time.get_unix_time_from_datetime_string(iso.left(19))
	if iso == "" or created <= 0:
		return "just now"
	var minutes := int((Time.get_unix_time_from_system() - created) / 60.0)
	if minutes < 1:
		return "just now"
	if minutes < 60:
		return "%d min ago" % minutes
	return "%d h ago" % floori(minutes / 60.0)
