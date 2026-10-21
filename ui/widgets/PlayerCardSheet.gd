class_name PlayerCardSheet
extends PanelContainer
## A player's card over any screen: photo, name, rank and what you can do with them: add friend,
## answer their request, invite to play, remove friend, block or unblock, and report (pick a
## reason, add an optional note). Open it from anywhere a player shows up (chat lines, rows,
## the match HUD):
##
##     PlayerCardSheet.open(ui, user)            # user: a PlayerCard {id, username, rank_tier, avatar_url, title}
##     PlayerCardSheet.open(ui, user, match_id)  # from a match: a report is tied to that game

var ui: UIRoot
var user: Dictionary
var match_id := 0

var _scroll: ScrollContainer
var _box: VBoxContainer
var _relation := ""
var _busy := false
var _reason := ""


static func open(root: UIRoot, player: Dictionary, from_match := 0) -> PlayerCardSheet:
	if root == null or int(player.get("id", 0)) <= 0:
		return null
	var sheet := PlayerCardSheet.new()
	sheet.ui = root
	sheet.user = player
	sheet.match_id = from_match
	ProfileUi.overlay(root, sheet, 440)
	sheet._load()
	return sheet


## Invite a friend to play: straight into the room you're hosting, else pick the powerup rules
## for a new private game first. Also used by the friends screen.
static func invite(root: UIRoot, player: Dictionary) -> void:
	var who := str(player.get("username", "your friend"))
	if GameSession.kind == GameSession.Kind.ONLINE and GameSession.status() == "waiting":
		root.close_dialog()
		_send_invite(root, player, GameSession.powerup_mode())
		return
	GameOptions.ask(root, {
		"title": "Play with %s" % who,
		"subtitle": "Choose the rules. %s gets 2 minutes to say yes." % who,
		"confirm": "Send invite",
	}, func(mode: String) -> void: _send_invite(root, player, mode))


static func _send_invite(root: UIRoot, player: Dictionary, mode: String) -> void:
	var res: Dictionary = await Social.invite_friend(player, mode)
	if res.ok:
		root.toast("Invite sent to %s!" % str(player.get("username", "your friend")), AppTheme.MINT)
		return
	var busy := int(res.data.get("match_id", 0))
	if int(res.status) == 409 and busy > 0 and busy != GameSession.match_id():
		root.confirm("You're already in a match. Jump back into it?", "Resume", func() -> void: GameSession.open_match(busy), false)
		return
	root.toast(Social.field_error(res, "user_id") if int(res.status) == 422 else str(res.error), AppTheme.RED)


func _init() -> void:
	theme_type_variation = "CardPanel"
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = AppTheme.vbox(12)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	_box.minimum_size_changed.connect(func() -> void: _fit_height.call_deferred())


## As tall as its content, up to the screen's height (then it scrolls): landscape phones.
func _fit_height() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var k := maxf(1.0, view.x / ProfileUi.PHONE_WIDTH) if view.y > view.x else 1.0  # ProfileUi.overlay's scale.
	_scroll.custom_minimum_size.y = minf(_box.get_combined_minimum_size().y, view.y / k - 90.0)


func _load() -> void:
	_render_head()
	_box.add_child(ProfileUi.note("Loading…", 16))
	_box.add_child(_close_button())
	if not ApiManager.is_logged_in():
		_relation = "guest"
	elif int(user.get("id", 0)) == int(ApiManager.user.get("id", -1)):
		_relation = "self"
	else:
		var relation: String = await Social.relation_to(int(user.get("id", 0)))
		if relation in ["outgoing", "incoming"] and Social.request_with(int(user.get("id", 0)), relation).is_empty():
			await Social.load_friends()  # The request id lives in the friends overview.
		_relation = relation if relation != "" else "unknown"
	if is_inside_tree():
		_render_main()


## The photo, name and rank: big on the main card, one compact line on the report and block forms.
func _render_head(compact := false) -> void:
	ProfileUi.clear(_box)
	if compact:
		var line := AppTheme.hbox(10)
		var small := AvatarView.new(48)
		small.set_user(user)
		line.add_child(small)
		var words := AppTheme.vbox(0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		var title := AppTheme.label(str(user.get("username", "?")), "", 22)
		title.add_theme_font_override("font", AppTheme.heading_font())
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(title)
		if user.get("rank_tier") != null:
			words.add_child(AppTheme.label(PlayerRanks.name_of(user["rank_tier"]), "MutedLabel", 15))
		line.add_child(words)
		_box.add_child(line)
		return
	var head := AppTheme.vbox(6)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var avatar := AvatarView.new(88)
	avatar.set_user(user)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(avatar)
	var name_label := ProfileUi.heading(str(user.get("username", "?")), 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	if user.get("rank_tier") != null:
		var rank := AppTheme.hbox(6)
		rank.alignment = BoxContainer.ALIGNMENT_CENTER
		var insignia := RankInsignia.new(user["rank_tier"], 24)
		insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rank.add_child(insignia)
		rank.add_child(AppTheme.label(PlayerRanks.name_of(user["rank_tier"]), "MutedLabel", 17))
		head.add_child(rank)
	if user.get("title") != null and str(user["title"]) != "":
		var worn := AppTheme.label("\"%s\"" % str(user["title"]), "", 16, AppTheme.PURPLE)
		worn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(worn)
	_box.add_child(head)


func _render_main() -> void:
	_render_head()
	var id := int(user.get("id", 0))
	var who := str(user.get("username", "this player"))
	match _relation:
		"guest":
			_box.add_child(ProfileUi.note("Log in to add friends and play together.", 16))
		"self":
			_box.add_child(ProfileUi.note("That's you!", 17))
		"friend":
			_box.add_child(_status_pill("FRIENDS", AppTheme.MINT))
			_box.add_child(_wide("Invite to play", "Success", func() -> void: PlayerCardSheet.invite(ui, user), 54))
		"outgoing":
			_box.add_child(_status_pill("FRIEND REQUEST SENT", AppTheme.BLUE))
			var request := Social.request_with(id, "outgoing")
			if not request.is_empty():
				_box.add_child(_wide("Cancel request", "Ghost", _call.bind(Social.cancel_request.bind(int(request.get("request_id", 0))), "Request cancelled."), 48))
		"incoming":
			_box.add_child(_status_pill("WANTS TO BE YOUR FRIEND", AppTheme.PINK))
			var request := Social.request_with(id, "incoming")
			var row := AppTheme.hbox(10)
			var request_id := int(request.get("request_id", 0))
			var no := _wide("Decline", "Ghost", _call.bind(Social.answer_request.bind(request_id, false), "Request declined."), 50)
			var yes := _wide("Accept", "Success", _call.bind(Social.answer_request.bind(request_id, true), "You're now friends with %s!" % who), 50)
			if request_id <= 0:  # Couldn't find it; adding them accepts it too.
				yes = _wide("Accept", "Success", _call.bind(Social.add_friend.bind(id), "You're now friends with %s!" % who), 50)
				no.disabled = true
			row.add_child(no)
			row.add_child(yes)
			_box.add_child(row)
		"blocked":
			_box.add_child(_status_pill("BLOCKED", AppTheme.RED))
			_box.add_child(ProfileUi.note("You won't see their chat, and they can't send you requests or invites.", 15))
		"blocked_you":
			_box.add_child(ProfileUi.note("You can't add this player.", 16))
		"none":
			_box.add_child(_wide("Add friend", "Primary", _call.bind(Social.add_friend.bind(id), "Friend request sent to %s!" % who), 54))
		_:
			_box.add_child(ProfileUi.note("Couldn't load this player. Check your connection.", 16))

	if _relation not in ["guest", "self", "unknown"]:
		var safety := AppTheme.hbox(10)
		if _relation == "friend":
			safety.add_child(_wide("Unfriend", "Ghost", _confirm_remove, 44, 16))
		if _relation == "blocked":
			safety.add_child(_wide("Unblock", "Ghost", _call.bind(Social.unblock_player.bind(id), "%s is unblocked." % who), 44, 16))
		else:
			safety.add_child(_wide("Block", "Ghost", _render_block, 44, 16))
		safety.add_child(_wide("Report", "Ghost", _render_report, 44, 16))
		_box.add_child(safety)
	_box.add_child(_close_button())


func _confirm_remove() -> void:
	_render_head()
	var who := str(user.get("username", "this player"))
	_box.add_child(ProfileUi.note("Remove %s from your friends?" % who, 18))
	var row := AppTheme.hbox(10)
	row.add_child(_wide("Keep", "Ghost", _render_main, 50))
	row.add_child(_wide("Remove", "Danger", _call.bind(Social.remove_friend.bind(int(user.get("id", 0))), "%s was removed from your friends." % who), 50))
	_box.add_child(row)


func _render_block() -> void:
	_render_head(true)
	var who := str(user.get("username", "this player"))
	_box.add_child(ProfileUi.heading("Block them?", 24))
	_box.add_child(ProfileUi.wrap("They can't send you friend requests, game invites or rematches, and you won't see their chat messages. They are also removed from your friends. You can unblock them any time.", 16, AppTheme.MUTED))
	var row := AppTheme.hbox(10)
	row.add_child(_wide("Cancel", "Ghost", _render_main, 50))
	row.add_child(_wide("Block", "Danger", _call.bind(Social.block_player.bind(user), "%s is blocked." % who), 50))
	_box.add_child(row)


func _render_report() -> void:
	_render_head(true)
	_reason = ""
	var who := str(user.get("username", "this player"))
	_box.add_child(ProfileUi.heading("Report this player", 24))
	_box.add_child(ProfileUi.wrap("What happened? Our moderators will take a look. %s won't know who reported them." % who, 16, AppTheme.MUTED))
	var reasons := GridContainer.new()
	reasons.columns = 1 if ProfileUi.narrow else 2
	reasons.add_theme_constant_override("h_separation", 6)
	reasons.add_theme_constant_override("v_separation", 6)
	var buttons := {}
	for entry: Array in Social.REPORT_REASONS:
		var b := ProfileUi.small_button(entry[1], "Ghost", Callable(), 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_reason = entry[0]
			ProfileUi.select_tab(buttons, entry[0]))
		buttons[entry[0]] = b
		reasons.add_child(b)
	_box.add_child(reasons)
	var note := AppTheme.field("Anything else? (optional)")
	note.max_length = 500
	_box.add_child(note)
	var row := AppTheme.hbox(10)
	row.add_child(_wide("Back", "Ghost", _render_main, 50))
	row.add_child(_wide("Send report", "Danger", func() -> void: _send_report(note.text), 50))
	_box.add_child(row)


func _send_report(note: String) -> void:
	if _reason == "":
		ui.toast("Pick a reason first.", AppTheme.BLUE)
		return
	if _busy:
		return
	_busy = true
	var res: Dictionary = await Social.report_player(int(user.get("id", 0)), _reason, note, match_id)
	_busy = false
	if not res.ok:
		ui.toast(str(res.error), AppTheme.RED)
		return
	_render_head(true)
	_box.add_child(ProfileUi.heading("Thanks for telling us", 24))
	_box.add_child(ProfileUi.wrap("Our team will review your report. If they're bothering you, you can block them too.", 16, AppTheme.MUTED))
	if _relation != "blocked":
		_box.add_child(_wide("Block %s" % str(user.get("username", "them")), "Danger", _render_block, 50))
	_box.add_child(_close_button())


## Runs a Social call, toasts `done` on success and re-reads the relation.
func _call(request_fn: Callable, done: String) -> void:
	if _busy:
		return
	_busy = true
	var res: Dictionary = await request_fn.call()
	_busy = false
	if not res.ok:
		ui.toast(str(res.error) if str(res.error) != "" else "That didn't work. Try again.", AppTheme.RED)
		return
	ui.toast(done, AppTheme.MINT)
	if is_inside_tree():
		_relation = await Social.relation_to(int(user.get("id", 0)))
		if is_inside_tree():
			_render_main()


func _status_pill(text: String, color: Color) -> Control:
	var pill := AppTheme.pill(text, color, Color.WHITE, 15)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return pill


func _close_button() -> Button:
	return _wide("Close", "Ghost", func() -> void: ui.close_dialog(), 48)


static func _wide(text: String, kind: String, action: Callable, height := 50.0, font := 19) -> Button:
	var b := AppTheme.button(text, kind, action, height)
	b.add_theme_font_size_override("font_size", font)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
