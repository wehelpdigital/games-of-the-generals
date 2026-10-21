extends Screen
## Leaderboards: the global rating board, "Near me" (top 5 in your city, top 30 in your province,
## top 50 in your region, top 100 in your country, with your own position at each level), a full
## board per location level, and the guild rankings. All time or this month.

const PER_PAGE := 15
const NEAR_ME := [["city", 5], ["province", 30], ["region", 50], ["country", 100]]
const PREVIEW_ROWS := 5
const TABS := [["global", "Global"], ["near", "Near me"], ["city", "City"], ["province", "Province"],
	["region", "Region"], ["country", "Country"], ["guilds", "Guilds"]]

var _page: Dictionary
var _tabs: Dictionary
var _periods: Dictionary
var _period_row: HFlowContainer
var _content: VBoxContainer
var _pager: HBoxContainer
var _prev: Button
var _next: Button
var _page_label: Label
var _tab := "global"
var _period := "all"
var _page_number := 1
var _ticket := 0


func _ready() -> void:
	_page = ProfileUi.page(self, "Leaderboards", func() -> void: ui.home(), 800)
	var body: VBoxContainer = _page["body"]
	_tabs = ProfileUi.tabs(body, TABS, _switch)
	_period_row = HFlowContainer.new()
	_period_row.add_theme_constant_override("h_separation", 6)
	body.add_child(_period_row)
	_periods = {}
	for spec: Array in [["all", "All time"], ["monthly", "This month"]]:
		var b := ProfileUi.small_button(spec[1], "Ghost", _set_period.bind(spec[0]), 36)
		b.add_theme_font_size_override("font_size", 15)
		_periods[spec[0]] = b
		_period_row.add_child(b)
	_content = AppTheme.vbox(8)
	body.add_child(_content)
	_pager = AppTheme.hbox(10)
	_prev = AppTheme.button("Prev", "Ghost", func() -> void: _load(_page_number - 1), 44)
	_next = AppTheme.button("Next", "Ghost", func() -> void: _load(_page_number + 1), 44)
	_page_label = AppTheme.label("", "MutedLabel")
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pager.add_child(_prev)
	_pager.add_child(_page_label)
	_pager.add_child(_next)
	body.add_child(_pager)
	get_viewport().size_changed.connect(_layout)


func open(args: Dictionary) -> void:
	_layout()
	AppTheme.pop_in(_page["card"])
	var start := str(args.get("tab", ""))
	if start == "":
		start = "near" if ApiManager.is_logged_in() and Profile.has_location() else _tab
	_switch(start)


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _switch(tab: String) -> void:
	_tab = tab
	ProfileUi.select_tab(_tabs, tab)
	ProfileUi.select_tab(_periods, _period)
	_period_row.visible = tab != "guilds"
	_load(1)


func _set_period(period: String) -> void:
	_period = period
	ProfileUi.select_tab(_periods, period)
	_load(1)


func _load(page: int) -> void:
	_ticket += 1
	var ticket := _ticket
	ProfileUi.clear(_content)
	_pager.visible = false
	_content.add_child(ProfileUi.note("Loading..."))
	match _tab:
		"global":
			await _load_global(page, ticket)
		"near":
			await _load_near(ticket)
		"guilds":
			await _load_guilds(page, ticket)
		_:
			await _load_level(_tab, page, ticket)


# --- Global -------------------------------------------------------------------------------------

func _load_global(page: int, ticket: int) -> void:
	var res := await Profile.global_leaderboard("monthly" if _period == "monthly" else "global", page, PER_PAGE)
	if not _current(ticket, res):
		return
	var entries: Array = res.data.get("data", [])
	if entries.is_empty():
		_content.add_child(ProfileUi.note("No ranked games yet. Win one and claim the top spot!"))
		return
	_content.add_child(_columns([["Rating", 70], ["W", 44], ["L", 44], ["Win %", 60]]))
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var ratio := "%d%%" % roundi(float(entry.get("win_ratio", 0.0)) * 100.0)
		var stats := [[AppTheme.num(entry.get("rating", entry.get("elo", 0))), 70], [AppTheme.num(entry.get("wins", 0)), 44],
			[AppTheme.num(entry.get("losses", 0)), 44], [ratio, 60]]
		var sub := str(entry.get("rank_name", "")) if entry.get("rank_name") != null else ""
		_content.add_child(ProfileUi.player_row(entry, int(entry.get("rank", 0)), sub, stats, _is_me(entry)))
	_show_pager(res.data.get("meta", {}), page)


# --- Near me ------------------------------------------------------------------------------------

func _load_near(ticket: int) -> void:
	if not _needs_location(ticket):
		return
	var positions := await Profile.my_positions()
	if ticket != _ticket:
		return
	ProfileUi.clear(_content)
	_content.add_child(ProfileUi.wrap("Your hometown: %s. Climb from the top of your town to the top of the country!"
		% Profile.location_text(true), 16, AppTheme.MUTED))
	var cards := []
	for spec: Array in NEAR_ME:
		var place := Profile.place(spec[0])
		if place.is_empty() or str(place.get("code", "")) == "":
			continue
		var card := _near_card(spec[0], place, int(spec[1]), positions.get(spec[0], {}))
		_content.add_child(card)
		cards.append([card, spec, place])
	if cards.is_empty():
		_content.add_child(ProfileUi.note("We couldn't find local boards for your hometown yet."))
	for item: Array in cards:
		var spec: Array = item[1]
		var res := await Profile.location_leaderboard(spec[0], str(item[2]["code"]), _period, 1, int(spec[1]))
		if ticket != _ticket:
			return
		_fill_near_card(item[0], res, int(spec[1]))


func _near_card(level: String, place: Dictionary, top: int, mine: Variant) -> PanelContainer:
	var card := AppTheme.card("Row")
	var box := AppTheme.vbox(8)
	card.add_child(box)
	var head := AppTheme.hbox(10)
	var title := AppTheme.label("Top %d in %s" % [top, str(place.get("name", "?"))], "", 22)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if mine is Dictionary and mine.get("rank") != null:
		var me_text := "You: #%s of %s" % [AppTheme.num(mine["rank"]), AppTheme.num(mine.get("total", "?"))]
		head.add_child(AppTheme.pill(me_text, AppTheme.PINK, Color.WHITE, 15))
	else:
		head.add_child(AppTheme.pill("Unranked", Color(AppTheme.INK, 0.1), AppTheme.MUTED, 15))
	box.add_child(head)
	var captions := AppTheme.hbox(10)
	var level_label := AppTheme.label(level.capitalize(), "MutedLabel", 14)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	captions.add_child(level_label)
	for spec: Array in [["XP", 80], ["Wins", 56]]:
		var caption := AppTheme.label(spec[0], "MutedLabel", 14)
		caption.custom_minimum_size.x = spec[1]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		captions.add_child(caption)
	captions.add_child(ProfileUi.gap(16))
	box.add_child(captions)
	var rows := AppTheme.vbox(6)
	rows.name = "Rows"
	rows.add_child(ProfileUi.note("Loading...", 15))
	box.add_child(rows)
	return card


func _fill_near_card(card: PanelContainer, res: Dictionary, top: int) -> void:
	if not is_instance_valid(card):
		return
	var rows: VBoxContainer = card.find_child("Rows", true, false)
	ProfileUi.clear(rows)
	if not res.ok:
		rows.add_child(ProfileUi.note(res.error if res.error != "" else "Couldn't load this board.", 15))
		return
	var entries: Array = res.data.get("data", [])
	if entries.is_empty():
		rows.add_child(ProfileUi.note("Nobody here yet - win a match and be #1!", 15))
		return
	var hidden: Array[Control] = []
	for i in mini(entries.size(), top):
		var entry: Variant = entries[i]
		if not entry is Dictionary:
			continue
		var row := _xp_row(entry)
		rows.add_child(row)
		if i >= PREVIEW_ROWS:
			row.visible = false
			hidden.append(row)
	if not hidden.is_empty():
		var more := ProfileUi.small_button("Show all %d" % (PREVIEW_ROWS + hidden.size()), "Ghost", Callable(), 38)
		more.pressed.connect(func() -> void:
			for row in hidden:
				row.visible = true
			more.queue_free())
		rows.add_child(more)


# --- One location level ---------------------------------------------------------------------

func _load_level(level: String, page: int, ticket: int) -> void:
	if not _needs_location(ticket):
		return
	var place := Profile.place(level)
	if place.is_empty() or str(place.get("code", "")) == "":
		ProfileUi.clear(_content)
		_content.add_child(ProfileUi.note("Your hometown has no %s board. Try another tab." % level))
		return
	var res := await Profile.location_leaderboard(level, str(place["code"]), _period, page, PER_PAGE)
	if not _current(ticket, res):
		return
	var title := AppTheme.label("Top players in %s" % str(res.data.get("name", place.get("name", "?"))), "", 22)
	title.add_theme_font_override("font", AppTheme.heading_font())
	_content.add_child(title)
	var entries: Array = res.data.get("data", [])
	if entries.is_empty():
		_content.add_child(ProfileUi.note("Nobody here yet - win a match and be #1!"))
		return
	_content.add_child(_columns([["XP", 80], ["Wins", 56]]))
	for entry: Variant in entries:
		if entry is Dictionary:
			_content.add_child(_xp_row(entry))
	_show_pager(res.data.get("meta", {}), page)


func _xp_row(entry: Dictionary) -> PanelContainer:
	var stats := [[ProfileUi.grouped(entry.get("xp", 0)), 80], [AppTheme.num(entry.get("wins", 0)), 56]]
	var sub := str(entry.get("rank_name", PlayerRanks.name_of(entry.get("rank_tier", 0))))
	return ProfileUi.player_row(entry, int(entry.get("rank", 0)), sub, stats, _is_me(entry))


## Location boards need a login and a hometown; shows the way there if missing.
func _needs_location(ticket: int) -> bool:
	if ticket != _ticket:
		return false
	if not ApiManager.is_logged_in():
		ProfileUi.clear(_content)
		_content.add_child(ProfileUi.note("Log in to see who rules your town."))
		_content.add_child(AppTheme.button("Log in", "Primary", func() -> void: ui.show_screen("auth", {"next": "leaderboard"}), 52))
		return false
	if not Profile.has_location():
		ProfileUi.clear(_content)
		var pin := TileIcon.new("pin", Vector2(64, 64))
		pin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content.add_child(pin)
		_content.add_child(ProfileUi.note("Set your hometown to compete for the top 5 in your town, top 30 in your province, and more!"))
		_content.add_child(AppTheme.button("Set hometown", "Success", func() -> void: LocationPicker.open(ui, func() -> void: _load(1)), 52))
		return false
	return true


# --- Guilds -------------------------------------------------------------------------------------

func _load_guilds(page: int, ticket: int) -> void:
	var res := await Profile.guild_leaderboard(page)
	if not _current(ticket, res):
		return
	var entries: Array = res.data.get("data", [])
	if entries.is_empty():
		_content.add_child(ProfileUi.note("No guilds yet. Reach Major and found the first one!"))
		return
	var mine := int(Profile.my_guild().get("id", -1))
	var position := (page - 1) * PER_PAGE + 1
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var row := AppTheme.card("Row")
		if int(entry.get("id", -2)) == mine:
			row.add_theme_stylebox_override("panel", ProfileUi.highlight_style())
		var line := AppTheme.hbox(10)
		row.add_child(line)
		line.add_child(ProfileUi.position_chip(int(entry.get("rank", position))))
		var logo := ProfileUi.guild_logo(entry, 44)
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(logo)
		var title := AppTheme.label("%s  [%s]" % [entry.get("name", "?"), entry.get("tag", "?")], "", 20)
		title.add_theme_font_override("font", AppTheme.heading_font())
		title.clip_text = true
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(title)
		var guild_stats := [[ProfileUi.grouped(entry.get("xp_total", 0)), "XP"], [ProfileUi.grouped(entry.get("wins_total", 0)), "Wins"],
				[AppTheme.num(entry.get("members_count", 0)), "Members"]]
		for stat: Array in guild_stats.slice(0, 1 if ProfileUi.narrow else 3):
			var cell := AppTheme.vbox(0)
			cell.custom_minimum_size.x = 56 if ProfileUi.narrow else 62
			var value := AppTheme.label(stat[0], "", 18)
			value.add_theme_font_override("font", AppTheme.heading_font())
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(value)
			var caption := AppTheme.label(stat[1], "MutedLabel", 13)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(caption)
			line.add_child(cell)
		var id := int(entry.get("id", 0))
		var view := ProfileUi.small_button(">" if ProfileUi.narrow else "View", "Secondary", func() -> void: ui.show_screen("guild", {"id": id}), 38)
		view.tooltip_text = "View guild"
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(view)
		_content.add_child(row)
		position += 1
	_show_pager(res.data.get("meta", {}), page)


# --- Helpers ------------------------------------------------------------------------------------

## True if this response is still wanted; clears the loading note and shows errors.
func _current(ticket: int, res: Dictionary) -> bool:
	if ticket != _ticket or not is_inside_tree():
		return false
	ProfileUi.clear(_content)
	if not res.ok:
		_content.add_child(ProfileUi.note(res.error if res.error != "" else "Couldn't load the leaderboard."))
		return false
	return true


func _show_pager(meta: Variant, page: int) -> void:
	if not meta is Dictionary:
		return
	_page_number = int(meta.get("current_page", page))
	var last := maxi(1, int(meta.get("last_page", 1)))
	_page_label.text = "Page %d of %d" % [_page_number, last]
	_prev.disabled = _page_number <= 1
	_next.disabled = _page_number >= last
	_pager.visible = last > 1


## Column captions lined up with player_row's stat cells.
func _columns(stats: Array) -> HBoxContainer:
	var line := AppTheme.hbox(10)
	var lead := AppTheme.label("Player", "MutedLabel", 15)
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.custom_minimum_size.x = (40 + 36 if ProfileUi.narrow else 50 + 44) + 10
	line.add_child(ProfileUi.gap(14))
	line.add_child(lead)
	for stat: Array in stats.slice(0, ProfileUi.max_stats()):
		var l := AppTheme.label(stat[0], "MutedLabel", 15)
		l.custom_minimum_size.x = stat[1] * (0.8 if ProfileUi.narrow else 1.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(l)
	line.add_child(ProfileUi.gap(12))
	return line


func _is_me(entry: Dictionary) -> bool:
	if not ApiManager.is_logged_in():
		return false
	var my_id: Variant = Profile.data.get("id", ApiManager.user.get("id"))
	if entry.get("user_id") != null and my_id != null:
		return int(entry["user_id"]) == int(my_id)
	return str(entry.get("username", "")) == str(Profile.data.get("username", ApiManager.user.get("username", "")))
