extends Screen
## The rank ladder: all thirteen ranks from Private to General of the Army with their insignia,
## the XP each needs and the tasks that unlock it. The player's own rank is highlighted.

var _page: Dictionary
var _body: VBoxContainer


func _ready() -> void:
	_page = ProfileUi.page(self, "Rank Ladder", _back, 760)
	_body = _page["body"]
	get_viewport().size_changed.connect(_layout)


func open(_args: Dictionary) -> void:
	_layout()
	_render()
	AppTheme.pop_in(_page["card"])
	if Profile.tiers.is_empty():
		await Profile.load_tiers()
		if visible:
			_render()


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _back() -> void:
	if ApiManager.is_logged_in():
		ui.show_screen("profile")
	else:
		ui.home()


func _render() -> void:
	ProfileUi.clear(_body)
	_body.add_child(ProfileUi.wrap("Win online matches for XP (+40, ranked +60). Losses cost XP (-15, ranked -25). "
		+ "A promotion needs the XP and every task. After two weeks without a match your XP slowly fades, "
		+ "so keep battling!", 16, AppTheme.MUTED))
	var mine := Profile.tier() if ApiManager.is_logged_in() else -1
	var xp := int(Profile.data.get("xp", 0))
	var my_row: Control = null
	for t in range(PlayerRanks.MAX_TIER + 1):
		var row := _tier_row(t, mine, xp)
		_body.add_child(row)
		if t == mine:
			my_row = row
	if my_row:
		_scroll_to.call_deferred(my_row)


func _tier_row(t: int, mine: int, xp: int) -> PanelContainer:
	var row := AppTheme.card("Row")
	if t == mine:
		row.add_theme_stylebox_override("panel", ProfileUi.highlight_style())
	var line := AppTheme.hbox(14)
	row.add_child(line)
	var insignia := RankInsignia.new(t, 44 if ProfileUi.narrow else 56)
	insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if mine >= 0 and t > mine:
		insignia.modulate = Color(1, 1, 1, 0.55)
	line.add_child(insignia)
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := AppTheme.label(PlayerRanks.name_of(t), "", 22)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	words.add_child(name_label)
	var needed := Profile.tier_xp(t)
	words.add_child(AppTheme.label("Starting rank" if t == 0 else "%s XP" % ProfileUi.grouped(needed), "", 16, PlayerRanks.color_of(t).darkened(0.35)))
	var tasks := Profile.tier_tasks(t)
	if not tasks.is_empty():
		var lines: Array[String] = []
		for task: Variant in tasks:
			if task is Dictionary:
				lines.append("- " + str(task.get("label", "")))
		words.add_child(ProfileUi.wrap("\n".join(lines), 15, AppTheme.MUTED))
	line.add_child(words)
	var chip: PanelContainer
	if t == mine:
		chip = AppTheme.pill("YOU", AppTheme.PINK, Color.WHITE, 16)
	elif mine >= 0 and t < mine:
		chip = AppTheme.pill("DONE", AppTheme.MINT, Color.WHITE, 16)
	elif mine >= 0 and t == mine + 1 and xp >= needed:
		chip = AppTheme.pill("TASKS LEFT", AppTheme.YELLOW, AppTheme.INK, 14)
	else:
		chip = AppTheme.pill("LOCKED" if mine >= 0 else "", Color(AppTheme.INK, 0.12), AppTheme.MUTED, 14)
		chip.visible = mine >= 0
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ProfileUi.narrow:
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		words.add_child(chip)  # Phones: the status chip goes under the rank's details.
	else:
		line.add_child(chip)
	return row


func _scroll_to(row: Control) -> void:
	var scroll: ScrollContainer = _page["scroll"]
	await get_tree().process_frame
	if is_instance_valid(row):
		scroll.scroll_vertical = maxi(0, int(row.position.y - 80))
