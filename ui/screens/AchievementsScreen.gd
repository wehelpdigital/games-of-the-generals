extends Screen
## Achievements: every badge with its progress and reward, unlocked ones first, plus the title
## picker (titles come from unlocked achievements and show next to the player's name).

var _page: Dictionary
var _body: VBoxContainer
var _portrait := false


func _ready() -> void:
	_page = ProfileUi.page(self, "Achievements", _back, 900)
	_body = _page["body"]
	get_viewport().size_changed.connect(_on_resize)
	Economy.achievements_changed.connect(func() -> void:
		if visible:
			_render())


func open(_args: Dictionary) -> void:
	_layout()
	_render()
	AppTheme.pop_in(_page["card"])
	await Economy.refresh_achievements()
	if visible:
		_render()


func _on_resize() -> void:
	var was := _portrait
	_layout()
	if visible and was != _portrait:
		_render()


func _layout() -> void:
	_portrait = ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _back() -> void:
	ui.home()


func _render() -> void:
	ProfileUi.clear(_body)
	var board := Economy.achievements
	if not ApiManager.is_logged_in():
		_body.add_child(ProfileUi.wrap("Log in to earn achievements, credits and titles.", 18, AppTheme.MUTED))
		return
	if board.is_empty():
		_body.add_child(AppTheme.label("Loading achievements...", "MutedLabel", 17))
		return
	var unlocked := int(board.get("unlocked", 0))
	var total := maxi(1, int(board.get("total", 1)))
	var summary := AppTheme.hbox(12)
	var count := AppTheme.label("%d / %d unlocked" % [unlocked, total], "", 22)
	count.add_theme_font_override("font", AppTheme.heading_font())
	summary.add_child(count)
	var bar := XpBar.new(22, AppTheme.PURPLE)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_progress(unlocked, total, "%d%%" % roundi(100.0 * unlocked / total), false)
	summary.add_child(bar)
	_body.add_child(summary)
	_body.add_child(_title_card(board))

	var grid := GridContainer.new()
	grid.columns = 2 if _portrait else 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var items: Array = board.get("data", []).duplicate()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.get("unlocked", false) != b.get("unlocked", false):
			return a.get("unlocked", false)
		return _ratio(a) > _ratio(b))
	for item: Dictionary in items:
		grid.add_child(_badge(item))
	_body.add_child(grid)


func _title_card(board: Dictionary) -> PanelContainer:
	var card := AppTheme.card("Row")
	var row := AppTheme.hbox(12)
	card.add_child(row)
	row.add_child(EconomyUi.emoji("1f396", 40))
	var text := AppTheme.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := AppTheme.label("Your title", "", 18)
	head.add_theme_font_override("font", AppTheme.heading_font())
	text.add_child(head)
	var titles: Array = board.get("titles", [])
	var note := "Shown next to your name in chat, leaderboards and matches." if not titles.is_empty() \
		else "Unlock achievements marked with a title to wear one."
	text.add_child(ProfileUi.wrap(note, 14, AppTheme.MUTED))
	row.add_child(text)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(200, 44)
	picker.add_item("No title")
	var current := str(board.get("title", "")) if board.get("title") != null else ""
	for i in titles.size():
		picker.add_item(str(titles[i]))
		if str(titles[i]) == current:
			picker.select(i + 1)
	picker.disabled = titles.is_empty()
	picker.item_selected.connect(func(index: int) -> void: _wear("" if index == 0 else picker.get_item_text(index)))
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picker)
	return card


func _badge(item: Dictionary) -> PanelContainer:
	var unlocked: bool = item.get("unlocked", false)
	var card := AppTheme.card("Row")
	if unlocked:
		var style := ProfileUi.box(Color("fff4d6"), 18, 3)
		style.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", style)
	var column := AppTheme.vbox(6)
	card.add_child(column)
	var top := AppTheme.hbox(10)
	var medal := _medal(str(item.get("icon", "1f3c6")), unlocked)
	top.add_child(medal)
	var names := AppTheme.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := AppTheme.label(str(item.get("name", "")), "", 17)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(name_label)
	var desc := ProfileUi.wrap(str(item.get("desc", "")), 13, AppTheme.MUTED)
	names.add_child(desc)
	top.add_child(names)
	column.add_child(top)
	var target := maxi(1, int(item.get("target", 1)))
	if not unlocked and target > 1:
		var progress := mini(target, int(item.get("progress", 0)))
		var bar := XpBar.new(14, AppTheme.BLUE)
		bar.set_progress(progress, target, "%s / %s" % [ProfileUi.grouped(progress), ProfileUi.grouped(target)], false)
		column.add_child(bar)
	var reward := AppTheme.hbox(6)
	if int(item.get("credits", 0)) > 0:
		reward.add_child(CoinIcon.new(18))
		reward.add_child(AppTheme.label(ProfileUi.grouped(item["credits"]), "", 14))
	if int(item.get("xp", 0)) > 0:
		reward.add_child(AppTheme.label("+%d XP" % int(item["xp"]), "MutedLabel", 13))
	reward.add_child(AppTheme.spacer())
	if item.get("title") != null:
		reward.add_child(EconomyUi.chip("Title: " + str(item["title"]), AppTheme.PURPLE if unlocked else AppTheme.MUTED, Color.WHITE, 12))
	column.add_child(reward)
	return card


func _medal(code: String, unlocked: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 52)
	var disc := Panel.new()
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	disc.add_theme_stylebox_override("panel", ProfileUi.box(AppTheme.GOLD if unlocked else Color("d8d4e6"), 26, 3))
	holder.add_child(disc)
	var icon := EconomyUi.emoji(code, 32)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.position = Vector2(10, 10)
	if not unlocked:
		icon.modulate = Color(0.35, 0.35, 0.45, 0.55)
	holder.add_child(icon)
	if not unlocked:
		var lock := TileIcon.new("lock", Vector2(18, 18))
		lock.position = Vector2(34, 34)
		holder.add_child(lock)
	return holder


func _wear(title: String) -> void:
	var res: Dictionary = await Economy.set_title(title)
	if res.ok:
		ui.toast("Title removed" if title == "" else "You are now \"%s\"" % title, AppTheme.PURPLE)
	else:
		ui.toast(res.error, AppTheme.RED)
		_render()


static func _ratio(item: Dictionary) -> float:
	return float(item.get("progress", 0)) / maxf(1.0, float(item.get("target", 1)))
