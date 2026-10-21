extends PanelContainer
## Under the turn banner while you host a room nobody has joined yet: "Copy invite link" (a
## one-time link that seats a friend without the room's password) and "Invite a friend" (pick from
## your friends list). While an invite is out it shows who you're waiting for, with a countdown
## and Cancel.

var hud: Screen

var _status: Label
var _cancel: Button
var _copy: Button
var _invite: Button
var _deadline := 0.0
var _busy := false


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := ProfileUi.box(Color(AppTheme.PAPER, 0.96), 18, 3)
	style.set_content_margin_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	add_theme_stylebox_override("panel", style)
	var box := AppTheme.vbox(6)
	add_child(box)
	var line := AppTheme.hbox(8)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	_status = AppTheme.label("", "", 16)
	_status.add_theme_font_override("font", AppTheme.heading_font())
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_status)
	_cancel = ProfileUi.small_button("Cancel", "Ghost", _cancel_invite, 36)
	line.add_child(_cancel)
	box.add_child(line)
	var row := AppTheme.hbox(8)
	_copy = ProfileUi.small_button("Copy invite link", "Secondary", _copy_link, 42)
	_invite = ProfileUi.small_button("Invite a friend", "Success", _pick_friend, 42)
	for b: Button in [_copy, _invite]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	box.add_child(row)


## HudRegistry hook.
func setup(owner_hud: Screen) -> void:
	hud = owner_hud
	GameSession.match_loaded.connect(func(_view: Dictionary) -> void: _refresh())
	GameSession.turn_changed.connect(_refresh)
	Social.invite_update.connect(func(_type: String, _invite_data: Dictionary) -> void: _refresh())
	_refresh()


## Hosting a room that's still waiting for its second player.
static func wanted() -> bool:
	var view := GameSession.match_view
	return GameSession.kind == GameSession.Kind.ONLINE and GameSession.status() == "waiting" \
		and view.get("room_name") != null and GameSession.my_side() == "white"


func _refresh() -> void:
	var wanted_now := wanted()
	if wanted_now != visible:
		visible = wanted_now
		if wanted_now:
			AppTheme.pop_in(self)
	if not wanted_now:
		return
	var sent := Social.sent_invite
	var pending := not sent.is_empty() and int(sent.get("room_id", 0)) == GameSession.match_id()
	_cancel.visible = pending
	if pending:
		var until := GameSession.parse_time(sent.get("expires_at", ""))
		_deadline = Time.get_ticks_msec() / 1000.0 + clampf(until - Time.get_unix_time_from_system(), 5.0, 180.0) if until > 0.0 else 0.0
	else:
		_deadline = 0.0
		_status.text = "Bring a friend!"
	_tick()
	var narrow := get_viewport().get_visible_rect().size.x < 520.0
	custom_minimum_size.x = 300.0 if narrow else 360.0


func _process(_delta: float) -> void:
	if visible and _deadline > 0.0:
		_tick()


func _tick() -> void:
	if _deadline <= 0.0:
		return
	var left := _deadline - Time.get_ticks_msec() / 1000.0
	var to: Variant = Social.sent_invite.get("to")
	var who := str((to as Dictionary).get("username", "your friend")) if to is Dictionary else "your friend"
	if left <= 0.0:
		_deadline = 0.0
		Social.sent_invite = {}
		_cancel.visible = false
		_status.text = "%s didn't answer. Try again?" % who
		return
	_status.text = "Waiting for %s… %d:%02d" % [who, int(left) / 60, int(left) % 60]


func _copy_link() -> void:
	if _busy:
		return
	_busy = true
	var res: Dictionary = await Social.room_link(GameSession.match_id())
	_busy = false
	var ui := hud.ui if hud else null
	if not res.ok:
		if ui:
			ui.toast(str(res.error), AppTheme.RED)
		return
	DisplayServer.clipboard_set(str(res["url"]))
	if ui:
		ui.toast("Invite link copied! It works once, for 30 minutes.", AppTheme.MINT)


func _cancel_invite() -> void:
	await Social.cancel_sent_invite()
	_refresh()


## A friends list to invite from (online friends first).
func _pick_friend() -> void:
	var ui := hud.ui if hud else null
	if ui == null:
		return
	var card := AppTheme.card()
	var box := AppTheme.vbox(12)
	card.add_child(box)
	box.add_child(ProfileUi.heading("Invite a friend", 28))
	var list := AppTheme.vbox(8)
	list.add_child(ProfileUi.note("Loading your friends…", 16))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 300
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	box.add_child(PlayerCardSheet._wide("Close", "Ghost", ui.close_dialog, 48))
	ProfileUi.overlay(ui, card, 480)
	await Social.load_friends()
	if not list.is_inside_tree():
		return
	ProfileUi.clear(list)
	var friends: Array = Social.friends.get("friends", [])
	if friends.is_empty():
		list.add_child(ProfileUi.note("No friends yet. Copy the invite link instead, or add players from the Friends screen.", 16))
		return
	for entry: Variant in friends:
		if entry is Dictionary:
			var friend: Dictionary = entry
			var send := FriendRow.action("Invite", "Success", func() -> void:
				ui.close_dialog()
				PlayerCardSheet.invite(ui, friend))
			send.disabled = str(friend.get("status", "")) == "in_match"
			list.add_child(FriendRow.new(friend, "", [send]))
