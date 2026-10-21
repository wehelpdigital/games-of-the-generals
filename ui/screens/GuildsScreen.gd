extends Screen
## Guilds: your guild (or founding one: Major rank and a Guild Charter), browsing and searching
## all guilds, and the guild rankings.

var _page: Dictionary
var _body: VBoxContainer
var _top: VBoxContainer
var _search: LineEdit
var _tabs: Dictionary
var _list: VBoxContainer
var _more: Button
var _mode := "browse"
var _page_number := 1
var _ticket := 0


func _ready() -> void:
	_page = ProfileUi.page(self, "Guilds", func() -> void: ui.home(), 780)
	_body = _page["body"]
	_top = AppTheme.vbox(12)
	_body.add_child(_top)
	_tabs = ProfileUi.tabs(_body, [["browse", "All guilds"], ["rankings", "Guild rankings"]], _switch)
	var search_row := AppTheme.hbox(8)
	_search = AppTheme.field("Search guilds by name or tag")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(func(_text: String) -> void: _load(1))
	search_row.add_child(_search)
	search_row.add_child(ProfileUi.small_button("Search", "Secondary", func() -> void: _load(1), 52))
	_body.add_child(search_row)
	_list = AppTheme.vbox(8)
	_body.add_child(_list)
	_more = AppTheme.button("Load more", "Ghost", func() -> void: _load(_page_number + 1), 46)
	_body.add_child(_more)
	get_viewport().size_changed.connect(_layout)
	Profile.changed.connect(func() -> void:
		if visible:
			_render_top())


func open(args: Dictionary) -> void:
	_layout()
	_render_top()
	_switch(str(args.get("tab", _mode)))
	AppTheme.pop_in(_page["card"])


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _switch(mode: String) -> void:
	_mode = mode
	ProfileUi.select_tab(_tabs, mode)
	_search.get_parent().visible = mode == "browse"
	_load(1)


func _render_top() -> void:
	ProfileUi.clear(_top)
	var guild := Profile.my_guild()
	if not guild.is_empty():
		var row := _guild_row(guild, -1, "Your guild" + (" - you're the master" if str(guild.get("role", "")) == "master" else ""))
		row.add_theme_stylebox_override("panel", ProfileUi.highlight_style())
		_top.add_child(row)
		return
	var card := AppTheme.card("Row")
	var line := AppTheme.hbox(12)
	card.add_child(line)
	var unlocked := ApiManager.is_logged_in() and Profile.tier() >= PlayerRanks.GUILD_MIN_TIER
	var crown := TileIcon.new("crown" if unlocked else "lock", Vector2(46, 46))
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(crown)
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label("Found your own guild", "", 22)
	title.add_theme_font_override("font", AppTheme.heading_font())
	words.add_child(title)
	var why := "Upload a logo your members fly on their table flags, and climb the guild rankings together."
	if not unlocked:
		why = "Reach %s to found a guild (you're %s). Until then, join one below!" % [
			PlayerRanks.name_of(PlayerRanks.GUILD_MIN_TIER), PlayerRanks.name_of(Profile.tier())]
	words.add_child(ProfileUi.wrap(why, 16, AppTheme.MUTED))
	line.add_child(words)
	var create := ProfileUi.small_button("Create" if unlocked else "Locked", "Primary" if unlocked else "Ghost", _open_create, 46)
	create.disabled = not unlocked
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(create)
	_top.add_child(card)


func _load(page: int) -> void:
	_ticket += 1
	var ticket := _ticket
	if page == 1:
		ProfileUi.clear(_list)
		_list.add_child(ProfileUi.note("Loading guilds..."))
	_more.visible = false
	var res: Dictionary
	if _mode == "rankings":
		res = await Profile.guild_leaderboard(page)
	else:
		res = await Profile.guilds(_search.text.strip_edges(), page)
	if ticket != _ticket or not is_inside_tree():
		return
	if page == 1:
		ProfileUi.clear(_list)
	if not res.ok:
		_list.add_child(ProfileUi.note(res.error if res.error != "" else "Couldn't load guilds."))
		return
	var entries: Array = res.data.get("data", [])
	var meta: Dictionary = res.data.get("meta", {})
	_page_number = int(meta.get("current_page", page))
	_more.visible = _page_number < int(meta.get("last_page", 1))
	if entries.is_empty() and page == 1:
		_list.add_child(ProfileUi.note("No guilds found yet. Be the first to found one!" if _search.text == "" else "No guild matches that search."))
		return
	var position := (page - 1) * maxi(1, int(meta.get("per_page", entries.size()))) + 1
	for entry: Variant in entries:
		if entry is Dictionary:
			_list.add_child(_guild_row(entry, int(entry.get("rank", position)) if _mode == "rankings" else -1, ""))
			position += 1


func _guild_row(guild: Dictionary, position: int, note: String) -> PanelContainer:
	var row := AppTheme.card("Row")
	var line := AppTheme.hbox(10)
	row.add_child(line)
	if position > 0:
		line.add_child(ProfileUi.position_chip(position))
	var logo := ProfileUi.guild_logo(guild, 50)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(logo)
	var words := AppTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label("%s  [%s]" % [guild.get("name", "?"), guild.get("tag", "?")], "", 20)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.clip_text = true
	words.add_child(title)
	var master: Variant = guild.get("master")
	var sub := note if note != "" else "%s members" % AppTheme.num(guild.get("members_count", 0))
	if note == "" and master is Dictionary:
		sub += " - led by " + str(master.get("username", "?"))
	var sub_label := AppTheme.label(sub, "MutedLabel", 15)
	sub_label.clip_text = true
	words.add_child(sub_label)
	line.add_child(words)
	for stat: Array in [[ProfileUi.grouped(guild.get("xp_total", 0)), "XP"], [ProfileUi.grouped(guild.get("wins_total", 0)), "Wins"]]:
		var cell := AppTheme.vbox(0)
		cell.custom_minimum_size.x = 64
		var value := AppTheme.label(stat[0], "", 18)
		value.add_theme_font_override("font", AppTheme.heading_font())
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(value)
		var caption := AppTheme.label(stat[1], "MutedLabel", 13)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(caption)
		line.add_child(cell)
	var view := ProfileUi.small_button("View", "Secondary", func() -> void: ui.show_screen("guild", {"id": int(guild.get("id", 0))}), 40)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(view)
	return row


# --- Create -------------------------------------------------------------------------------------

func _open_create() -> void:
	var card := AppTheme.card()
	var box := AppTheme.vbox(12)
	card.add_child(box)
	var head := AppTheme.hbox(10)
	head.add_child(TileIcon.new("crown", Vector2(40, 40)))
	head.add_child(ProfileUi.heading("Found a guild", 30))
	box.add_child(head)
	var name_field := AppTheme.field("Guild name (3-24 characters)")
	name_field.max_length = 24
	box.add_child(name_field)
	var tag_field := AppTheme.field("Tag, 2-5 letters (e.g. ALC)")
	tag_field.max_length = 5
	tag_field.text_changed.connect(func(text: String) -> void:
		var upper := text.to_upper()
		if upper != text:
			var caret := tag_field.caret_column
			tag_field.text = upper
			tag_field.caret_column = caret)
	box.add_child(tag_field)
	var price := AppTheme.label("Guild Charter: checking price...", "", 18)
	box.add_child(price)
	var error := AppTheme.label("", "", 16, AppTheme.RED)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.visible = false
	box.add_child(error)
	var row := AppTheme.hbox(10)
	var cancel := AppTheme.button("Cancel", "Ghost", func() -> void: ui.close_dialog(), 52)
	var create := AppTheme.button("Create", "Primary", Callable(), 52)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(create)
	box.add_child(row)
	create.pressed.connect(_create.bind(name_field, tag_field, error, create))
	ProfileUi.overlay(ui, card, 460)
	var cost := await Profile.charter_price()
	if is_instance_valid(price):
		if cost <= 0:
			price.text = "Guild Charter: FREE (test mode)"
		else:
			price.text = "Guild Charter: %s credits (you have %s)" % [ProfileUi.grouped(cost), ProfileUi.grouped(Profile.credits())]
			if Profile.credits() < cost:
				price.add_theme_color_override("font_color", AppTheme.RED)


func _create(name_field: LineEdit, tag_field: LineEdit, error: Label, button: Button) -> void:
	var guild_name := name_field.text.strip_edges()
	var tag := tag_field.text.strip_edges().to_upper()
	if guild_name.length() < 3 or tag.length() < 2:
		error.text = "Give your guild a name (3+ letters) and a tag (2-5 letters)."
		error.visible = true
		return
	button.disabled = true
	var res := await Profile.create_guild(guild_name, tag)
	if not is_instance_valid(button):
		return
	if not res.ok:
		error.text = res.error
		error.visible = true
		button.disabled = false
		return
	ui.close_dialog()
	ui.toast("Guild founded! Upload a logo for your banner.", AppTheme.MINT)
	var guild: Variant = res.data.get("guild", res.data.get("data", {}))
	var id := int(guild.get("id", 0)) if guild is Dictionary else int(Profile.my_guild().get("id", 0))
	ui.show_screen("guild", {"id": id})
