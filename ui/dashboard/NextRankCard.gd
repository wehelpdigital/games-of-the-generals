class_name NextRankCard
extends PanelContainer
## Dashboard card: the next rank's insignia, XP toward it, its tasks with progress, and a Share
## button (sharing the game is one of the tasks).

var ui: UIRoot
var _box: VBoxContainer
var _accent := AppTheme.PINK
var _accent2 := AppTheme.BLUE


func _init() -> void:
	theme_type_variation = "CardPanel"
	_box = AppTheme.vbox(10)
	add_child(_box)


func set_colors(accent: Color, accent2: Color) -> void:
	_accent = accent
	_accent2 = accent2


func refresh() -> void:
	ProfileUi.clear(_box)
	var progress := Profile.xp_progress()
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Next rank" if not progress["maxed"] else "Top rank", _accent.darkened(0.15)))
	head.add_child(AppTheme.spacer())
	head.add_child(ProfileUi.small_button("All ranks", "Ghost", func() -> void: ui.show_screen("ranks"), 36))
	_box.add_child(head)

	if progress["maxed"]:
		var top := AppTheme.hbox(12)
		top.add_child(RankInsignia.new(PlayerRanks.MAX_TIER, 56))
		var words := AppTheme.vbox(0)
		words.add_child(ProfileUi.heading(PlayerRanks.name_of(PlayerRanks.MAX_TIER), 24))
		words.add_child(AppTheme.label("You reached the top. Stay active to keep it!", "MutedLabel", 15))
		top.add_child(words)
		_box.add_child(top)
		_add_share()
		return

	var next := Profile.next_rank()
	var next_tier := int(next.get("tier", Profile.tier() + 1))
	var row := AppTheme.hbox(12)
	var insignia := RankInsignia.new(next_tier, 56)
	insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(insignia)
	var words := AppTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(ProfileUi.heading(str(next.get("name", PlayerRanks.name_of(next_tier))), 24))
	var to_go := maxi(0, int(progress["to"]) - int(progress["xp"]))
	words.add_child(AppTheme.label("%s XP to go" % ProfileUi.grouped(to_go) if to_go > 0 else "XP ready - finish the tasks!", "MutedLabel", 15))
	row.add_child(words)
	_box.add_child(row)
	var bar := XpBar.new(24, _accent)
	_box.add_child(bar)
	bar.set_progress(float(progress["xp"]) - float(progress["from"]), float(progress["to"]) - float(progress["from"]),
		"%s / %s XP" % [ProfileUi.grouped(progress["xp"]), ProfileUi.grouped(progress["to"])])

	var tasks: Array = (next.get("tasks", []) as Array).duplicate()
	if tasks.is_empty():
		for task: Variant in Profile.tier_tasks(next_tier):
			if task is Dictionary:
				tasks.append({"label": task.get("label", ""), "progress": 0, "target": task.get("target", 1), "done": false})
	if tasks.is_empty():
		_box.add_child(AppTheme.label("Win online matches to earn XP.", "MutedLabel", 15))
	for task: Variant in tasks:
		if task is Dictionary:
			_box.add_child(_task_row(task))
	_add_share()


func _task_row(task: Dictionary) -> Control:
	var done := bool(task.get("done", false))
	var target := maxi(1, int(task.get("target", 1)))
	var have := mini(int(task.get("progress", 0)), target)
	var row := AppTheme.hbox(10)
	if done:
		var tick := TileIcon.new("check", Vector2(26, 26))
		tick.fill = AppTheme.MINT
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tick)
	else:
		var chip := AppTheme.pill("%d/%d" % [have, target], Color(AppTheme.INK, 0.08), AppTheme.INK, 14)
		chip.custom_minimum_size.x = 58
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
	var words := AppTheme.vbox(3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := ProfileUi.wrap(str(task.get("label", "")), 16, AppTheme.MUTED if done else AppTheme.INK)
	words.add_child(text)
	if not done and target > 1:
		var bar := XpBar.new(9, _accent2)
		words.add_child(bar)
		bar.set_progress(have, target, "", false)
	row.add_child(words)
	return row


func _add_share() -> void:
	var share := ProfileUi.colored_button("Share & earn XP", _accent2, Color.WHITE, func() -> void: ShareSheet.open(ui), 50)
	_box.add_child(share)
