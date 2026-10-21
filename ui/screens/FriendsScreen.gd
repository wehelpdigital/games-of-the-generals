extends Screen
## Friends: your friends (online first, then in a match, then by last seen) with Invite to play;
## friend requests you got and sent; finding players by username; and the last opponents you
## played, to add them. Tapping a player opens their card (block, report, remove). Requests,
## answers and invites arrive in realtime as toasts (see Social); the lists refresh by themselves.
##
##     ui.show_screen("friends")                 # or {"tab": "requests" | "add" | "recent", "back": "lobby"}

const TABS := [["friends", "Friends"], ["requests", "Requests"], ["add", "Add friend"], ["recent", "Played with"]]
const REFRESH_SECONDS := 30.0

var _page: Dictionary
var _tabs: Dictionary
var _search_row: HBoxContainer
var _search: LineEdit
var _list: VBoxContainer
var _tab := "friends"
var _back := ""
var _results: Array = []
var _searched := ""
var _ticket := 0
var _refresh: Timer


func _ready() -> void:
	_page = ProfileUi.page(self, "Friends", _go_back, 720)
	var body: VBoxContainer = _page["body"]
	_tabs = ProfileUi.tabs(body, TABS, _switch)
	_search_row = AppTheme.hbox(8)
	_search = AppTheme.field("Search by username")
	_search.max_length = 40
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(func(_text: String) -> void: _find())
	_search_row.add_child(_search)
	_search_row.add_child(ProfileUi.small_button("Search", "Secondary", _find, 52))
	body.add_child(_search_row)
	_list = AppTheme.vbox(8)
	body.add_child(_list)
	_refresh = Timer.new()
	_refresh.wait_time = REFRESH_SECONDS
	_refresh.timeout.connect(func() -> void: Social.load_friends())
	add_child(_refresh)
	get_viewport().size_changed.connect(_layout)
	Social.friends_changed.connect(func() -> void:
		if visible:
			_update_badge()
			if _tab != "add":
				_render())


func open(args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen("auth", {"next": "friends"})
		return
	_back = str(args.get("back", ""))
	_layout()
	AppTheme.pop_in(_page["card"])
	_switch(str(args.get("tab", "friends")))
	_refresh.start()
	Social.load_friends()


func close() -> void:
	_refresh.stop()


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)
	if visible:
		_render()


func _switch(tab: String) -> void:
	_tab = tab if TABS.any(func(t: Array) -> bool: return t[0] == tab) else "friends"
	ProfileUi.select_tab(_tabs, _tab)
	_search_row.visible = _tab == "add"
	_render()
	if _tab == "add":
		_search.grab_focus.call_deferred()


func _update_badge() -> void:
	var waiting := (Social.friends.get("incoming", []) as Array).size()
	_tabs["requests"].text = "Requests (%d)" % waiting if waiting > 0 else "Requests"


func _render() -> void:
	ProfileUi.clear(_list)
	_update_badge()
	if Social.friends.is_empty() and _tab != "add":
		_list.add_child(ProfileUi.note("Loading…"))
		return
	match _tab:
		"friends":
			_render_friends()
		"requests":
			_render_requests()
		"add":
			_render_results()
		"recent":
			_render_recent()


func _render_friends() -> void:
	var friends: Array = Social.friends.get("friends", [])
	if friends.is_empty():
		_list.add_child(ProfileUi.note("No friends yet. Add players you meet in games, or search by username!"))
		var find := AppTheme.button("Find players", "Primary", _switch.bind("add"), 52)
		find.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(find)
		return
	var online := friends.filter(func(f: Variant) -> bool: return f is Dictionary and str(f.get("status", "")) != "offline").size()
	_list.add_child(ProfileUi.eyebrow("%d friend%s · %d online" % [friends.size(), "" if friends.size() == 1 else "s", online]))
	for entry: Variant in friends:
		if entry is Dictionary:
			var friend: Dictionary = entry
			var play := FriendRow.action("Invite", "Success", func() -> void: PlayerCardSheet.invite(ui, friend))
			play.tooltip_text = "Invite to play"
			if str(friend.get("status", "")) == "in_match":
				play.disabled = true
				play.tooltip_text = "In a match right now"
			_list.add_child(FriendRow.new(friend, "", [play], _card.bind(friend)))


func _render_requests() -> void:
	var incoming: Array = Social.friends.get("incoming", [])
	var outgoing: Array = Social.friends.get("outgoing", [])
	if incoming.is_empty() and outgoing.is_empty():
		_list.add_child(ProfileUi.note("No friend requests right now."))
		return
	if not incoming.is_empty():
		_list.add_child(ProfileUi.eyebrow("Want to be your friend", AppTheme.PINK))
		for entry: Variant in incoming:
			if entry is Dictionary:
				var request: Dictionary = entry
				var request_id := int(request.get("request_id", 0))
				var user: Dictionary = request.get("user", {})
				var no := FriendRow.action("Decline", "Ghost", _run.bind(Social.answer_request.bind(request_id, false), ""))
				var yes := FriendRow.action("Accept", "Success", _run.bind(Social.answer_request.bind(request_id, true),
					"You're now friends with %s!" % str(user.get("username", ""))))
				_list.add_child(FriendRow.new(user, "Sent %s" % FriendRow.ago(str(request.get("sent_at", ""))), [no, yes], _card.bind(user)))
	if not outgoing.is_empty():
		_list.add_child(ProfileUi.eyebrow("Sent"))
		for entry: Variant in outgoing:
			if entry is Dictionary:
				var request: Dictionary = entry
				var user: Dictionary = request.get("user", {})
				var cancel := FriendRow.action("Cancel", "Ghost", _run.bind(Social.cancel_request.bind(int(request.get("request_id", 0))), "Request cancelled."))
				_list.add_child(FriendRow.new(user, "Waiting for an answer", [cancel], _card.bind(user)))


func _render_recent() -> void:
	var recent: Array = Social.friends.get("recent", [])
	if recent.is_empty():
		_list.add_child(ProfileUi.note("Players you face online show up here, so you can add them after a good game."))
		return
	_list.add_child(ProfileUi.eyebrow("Your last opponents"))
	for entry: Variant in recent:
		if entry is Dictionary:
			_list.add_child(_player_row(entry))


func _render_results() -> void:
	if _searched == "":
		_list.add_child(ProfileUi.note("Type at least 2 letters of a username."))
		return
	if _results.is_empty():
		_list.add_child(ProfileUi.note("No players named like \"%s\"." % _searched))
		return
	for entry: Variant in _results:
		if entry is Dictionary:
			_list.add_child(_player_row(entry))


## A search result or recent opponent, with the button their relation allows.
func _player_row(player: Dictionary) -> FriendRow:
	var id := int(player.get("id", 0))
	var who := str(player.get("username", ""))
	var actions: Array = []
	match str(player.get("relation", "none")):
		"none":
			actions.append(FriendRow.action("Add", "Primary", _run.bind(Social.add_friend.bind(id), "Friend request sent to %s!" % who)))
		"incoming":
			actions.append(FriendRow.action("Accept", "Success", _run.bind(Social.add_friend.bind(id), "You're now friends with %s!" % who)))
		"outgoing":
			var sent := FriendRow.action("Sent", "Ghost", Callable())
			sent.disabled = true
			actions.append(sent)
		"friend":
			actions.append(FriendRow.action("Invite", "Success", func() -> void: PlayerCardSheet.invite(ui, player)))
		"blocked":
			actions.append(AppTheme.pill("BLOCKED", AppTheme.RED, Color.WHITE, 14))
	var sub := PlayerRanks.name_of(player["rank_tier"]) if player.get("rank_tier") != null else ""
	return FriendRow.new(player, sub, actions, _card.bind(player))


func _find() -> void:
	var query := _search.text.strip_edges()
	if query.length() < 2:
		ui.toast("Type at least 2 letters.", AppTheme.BLUE)
		return
	_ticket += 1
	var ticket := _ticket
	var res: Dictionary = await Social.search_players(query)
	if ticket != _ticket:
		return
	if not res.ok:
		ui.toast(str(res.error), AppTheme.RED)
		return
	_searched = query
	_results = res.data.get("data", []) if res.data.get("data") is Array else []
	if _tab == "add":
		_render()


## Runs a friend call; on success toasts `done` and re-runs the search so its buttons update.
func _run(request_fn: Callable, done: String) -> void:
	var res: Dictionary = await request_fn.call()
	if not res.ok:
		ui.toast(str(res.error) if str(res.error) != "" else "That didn't work. Try again.", AppTheme.RED)
		return
	if done != "":
		ui.toast(done, AppTheme.MINT)
	if _tab == "add" and _searched != "":
		_search.text = _searched
		_find()


func _card(player: Dictionary) -> void:
	PlayerCardSheet.open(ui, player)


func _go_back() -> void:
	if _back != "" and ui.has_screen(_back):
		ui.show_screen(_back)
	else:
		ui.home()
