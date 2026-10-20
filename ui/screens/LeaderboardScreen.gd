extends Screen
## Global and monthly rankings with paging. The signed-in player's row is highlighted.

const PER_PAGE := 10

var _card: PanelContainer
var _period := "global"
var _page := 1
var _last_page := 1
var _tabs: Dictionary = {}
var _rows: VBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(12)
	_card.add_child(box)
	var heading := AppTheme.label("Leaderboard", "HeadingLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var tabs := AppTheme.hbox(8)
	for period: String in ["global", "monthly"]:
		var tab := AppTheme.button("All time" if period == "global" else "This month", "Ghost", func() -> void: _switch(period), 46)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[period] = tab
		tabs.add_child(tab)
	box.add_child(tabs)

	box.add_child(_row_line(["#", "Player", "Rating", "W", "L", "Win %"], true))
	_rows = AppTheme.vbox(6)
	box.add_child(_rows)

	var pager := AppTheme.hbox(10)
	_prev = AppTheme.button("Prev", "Ghost", func() -> void: _load(_page - 1), 44)
	_next = AppTheme.button("Next", "Ghost", func() -> void: _load(_page + 1), 44)
	_page_label = AppTheme.label("", "MutedLabel")
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pager.add_child(_prev)
	pager.add_child(_page_label)
	pager.add_child(_next)
	box.add_child(pager)
	box.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.show_screen("title"), 48))
	add_child(AppTheme.centered(_card, 620))


func open(_args: Dictionary) -> void:
	AppTheme.pop_in(_card)
	_switch(_period)


func _switch(period: String) -> void:
	_period = period
	for key: String in _tabs:
		_tabs[key].theme_type_variation = "AccentButton" if key == period else "GhostButton"
	_load(1)


func _load(page: int) -> void:
	_prev.disabled = true
	_next.disabled = true
	var res := await ApiManager.leaderboard(_period, page, PER_PAGE)
	for child in _rows.get_children():
		child.queue_free()
	if not res.ok:
		_rows.add_child(AppTheme.label(res.error, "MutedLabel"))
		return
	var meta: Dictionary = res.data.get("meta", {})
	_page = int(meta.get("current_page", page))
	_last_page = maxi(1, int(meta.get("last_page", 1)))
	_page_label.text = "Page %d of %d" % [_page, _last_page]
	_prev.disabled = _page <= 1
	_next.disabled = _page >= _last_page
	var entries: Array = res.data.get("data", [])
	if entries.is_empty():
		var empty := AppTheme.label("No ranked games yet. Win one and claim the top spot!", "MutedLabel")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(empty)
		return
	var me := str(ApiManager.user.get("username", ""))
	for entry: Dictionary in entries:
		var ratio := "%d%%" % roundi(float(entry.get("win_ratio", 0.0)) * 100.0)
		var line := _row_line([AppTheme.num(entry.get("rank")), str(entry.get("username")), AppTheme.num(entry.get("rating")),
			AppTheme.num(entry.get("wins")), AppTheme.num(entry.get("losses")), ratio], false, int(entry.get("rank", 99)))
		var row := AppTheme.card("Row")
		if entry.get("username") == me:
			row.add_theme_stylebox_override("panel", _highlight_style())
		row.add_child(line)
		_rows.add_child(row)


func _row_line(cells: Array, header: bool, rank := 99) -> HBoxContainer:
	var line := AppTheme.hbox(8)
	var widths := [56, 0, 80, 44, 44, 70]
	for i in cells.size():
		var cell: Control
		if i == 0 and not header and rank <= 3:
			cell = AppTheme.pill(cells[i], [AppTheme.GOLD, AppTheme.SILVER, AppTheme.BRONZE][rank - 1], AppTheme.INK)
		else:
			var l := AppTheme.label(cells[i], "MutedLabel" if header else "", 18 if header else 20)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 1 else HORIZONTAL_ALIGNMENT_CENTER
			l.clip_text = true
			cell = l
		if widths[i] > 0:
			cell.custom_minimum_size.x = widths[i]
		else:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(cell)
	return line


func _highlight_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(AppTheme.YELLOW, 0.35)
	s.set_corner_radius_all(18)
	s.set_border_width_all(3)
	s.border_color = AppTheme.INK
	s.set_content_margin_all(10)
	return s
