extends PanelContainer
## Dashboard card (DashboardRegistry "main"): today's and this week's missions with progress,
## Claim buttons, one free swap a day and the time left until new missions.

var _ui: UIRoot
var _box: VBoxContainer
var _period := "daily"
var _tabs: Dictionary = {}
var _reset_label: Label
var _list: VBoxContainer
var _timer: Timer
var _busy := false


func _init() -> void:
	theme_type_variation = "CardPanel"
	_box = AppTheme.vbox(10)
	add_child(_box)
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Missions", AppTheme.MINT.darkened(0.25)))
	head.add_child(AppTheme.spacer())
	_reset_label = AppTheme.label("", "MutedLabel", 14)
	head.add_child(_reset_label)
	_box.add_child(head)
	_tabs = ProfileUi.tabs(_box, [["daily", "Daily"], ["weekly", "Weekly"]], _pick)
	_list = AppTheme.vbox(8)
	_box.add_child(_list)
	_timer = Timer.new()
	_timer.wait_time = 30.0
	_timer.timeout.connect(_update_reset)
	add_child(_timer)


func setup(dashboard: Screen) -> void:
	_ui = dashboard.ui
	Economy.missions_changed.connect(_render)
	_render()


func refresh() -> void:
	visible = ApiManager.is_logged_in()
	if visible:
		await Economy.refresh_missions()
	_render()


func _pick(period: String) -> void:
	_period = period
	_render()


func _render() -> void:
	ProfileUi.select_tab(_tabs, _period)
	for period: String in _tabs:
		var count := _claimable(period)
		_tabs[period].text = ("Daily" if period == "daily" else "Weekly") + ("  (%d!)" % count if count > 0 else "")
	ProfileUi.clear(_list)
	var board := Economy.missions
	if board.is_empty():
		_list.add_child(AppTheme.label("Loading missions...", "MutedLabel", 15))
		_reset_label.text = ""
		return
	if not board.get("enabled", true):
		_list.add_child(ProfileUi.wrap("Missions are taking a short break. Check back soon!", 15, AppTheme.MUTED))
		_reset_label.text = ""
		return
	var period: Dictionary = board.get(_period, {})
	var rerolls := int(period.get("rerolls_left", 0))
	for mission: Dictionary in period.get("missions", []):
		_list.add_child(_row(mission, rerolls))
	_update_reset()
	_timer.start()


func _row(mission: Dictionary, rerolls: int) -> PanelContainer:
	var completed: bool = mission.get("completed", false)
	var claimed: bool = mission.get("claimed", false)
	var row := AppTheme.card("Row")
	if completed and not claimed:
		row.add_theme_stylebox_override("panel", ProfileUi.highlight_style())
	var line := AppTheme.hbox(10)
	row.add_child(line)
	var icon := EconomyUi.emoji(str(mission.get("icon", "2b50")), 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if claimed:
		icon.modulate = Color(1, 1, 1, 0.45)
	line.add_child(icon)
	var text := AppTheme.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label(str(mission.get("title", "")), "", 16)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.clip_text = true
	text.add_child(title)
	var desc := AppTheme.label(str(mission.get("desc", "")), "MutedLabel", 13)
	desc.clip_text = true
	row.tooltip_text = str(mission.get("desc", ""))
	text.add_child(desc)
	var target := maxi(1, int(mission.get("target", 1)))
	var progress := mini(target, int(mission.get("progress", 0)))
	var bar := XpBar.new(16, AppTheme.MINT if completed else AppTheme.BLUE)
	bar.set_progress(progress, target, "%d / %d" % [progress, target], false)
	text.add_child(bar)
	line.add_child(text)

	var side := AppTheme.vbox(4)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.custom_minimum_size.x = 96
	var reward := AppTheme.hbox(4)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_child(CoinIcon.new(18))
	var amount := AppTheme.label(ProfileUi.grouped(mission.get("credits", 0)), "", 15)
	amount.add_theme_font_override("font", AppTheme.heading_font())
	reward.add_child(amount)
	if int(mission.get("xp", 0)) > 0:
		reward.add_child(AppTheme.label("+%d XP" % int(mission["xp"]), "MutedLabel", 12))
	side.add_child(reward)
	if claimed:
		var done := AppTheme.label("Claimed", "MutedLabel", 14)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_child(done)
	elif completed:
		var claim := ProfileUi.colored_button("Claim", AppTheme.PINK, Color.WHITE, Callable(), 38)
		claim.add_theme_font_size_override("font_size", 16)
		claim.pressed.connect(_claim.bind(int(mission.get("id", 0)), claim))
		side.add_child(claim)
	elif mission.get("period") == "daily" and rerolls > 0:
		var swap := ProfileUi.small_button("Swap", "Ghost", _reroll.bind(int(mission.get("id", 0))), 32)
		swap.add_theme_font_size_override("font_size", 14)
		swap.tooltip_text = "Swap this mission for another one (once a day)"
		side.add_child(swap)
	line.add_child(side)
	return row


func _claim(id: int, button: Button) -> void:
	if _busy:
		return
	_busy = true
	button.disabled = true
	var from := button.get_global_rect().get_center()
	var res: Dictionary = await Economy.claim_mission(id)
	_busy = false
	if not res.ok:
		if is_instance_valid(button):
			button.disabled = false
		if _ui:
			_ui.toast(res.error, AppTheme.RED)
		return
	var mission: Dictionary = res.data.get("mission", {})
	if _ui:
		DailyRewardPopup.fly_coins(_ui, from, 6)
		Sfx.play(_ui, "coins")
		_ui.toast("+%s credits  -  %s" % [ProfileUi.grouped(mission.get("credits", 0)), str(mission.get("title", ""))], AppTheme.MINT)


func _reroll(id: int) -> void:
	if _busy:
		return
	_busy = true
	var res: Dictionary = await Economy.reroll_mission(id)
	_busy = false
	if not res.ok and _ui:
		_ui.toast(res.error, AppTheme.RED)


func _claimable(period: String) -> int:
	var count := 0
	var board: Variant = Economy.missions.get(period)
	if board is Dictionary:
		for m: Dictionary in board.get("missions", []):
			if m.get("completed", false) and not m.get("claimed", false):
				count += 1
	return count


func _update_reset() -> void:
	var period: Variant = Economy.missions.get(_period)
	if not period is Dictionary:
		_reset_label.text = ""
		return
	var left := EconomyUi.time_left(str(period.get("resets_at", "")))
	_reset_label.text = ("New missions in " + left) if left != "" else ""
