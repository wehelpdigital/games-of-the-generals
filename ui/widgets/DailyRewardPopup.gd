class_name DailyRewardPopup
extends RefCounted
## The daily login reward dialog: a 7-day calendar (today's card bounces), a Claim button, then
## the reward with coins flying up to the credits counter.
##
##     DailyRewardPopup.open(ui)

const EMOJI_GIFT := "1f389"


static func open(ui: UIRoot) -> void:
	var card := AppTheme.card()
	var box := AppTheme.vbox(14)
	card.add_child(box)
	var head := AppTheme.hbox(10)
	var title := ProfileUi.heading("Daily Reward", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(ProfileUi.small_button("Close", "Ghost", ui.close_dialog, 40))
	box.add_child(head)
	var daily := Economy.daily
	var streak := int(daily.get("streak", 0))
	var subtitle := "Log in every day to keep your streak going!"
	if streak > 0:
		subtitle = "%d-day streak! Don't break it." % streak
	var streak_label := ProfileUi.wrap(subtitle, 17, AppTheme.MUTED)
	box.add_child(streak_label)

	var portrait := ui.get_viewport().get_visible_rect().size.y > ui.get_viewport().get_visible_rect().size.x
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = (3 if UiScale.narrow(ui) else 4) if portrait else 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var today_card: Control = null
	for day: Dictionary in daily.get("calendar", []):
		var day_card := _day_card(day)
		grid.add_child(day_card)
		if day.get("today", false):
			today_card = day_card
	box.add_child(grid)

	var result := AppTheme.vbox(6)
	box.add_child(result)
	var claim := ProfileUi.colored_button("Claim reward", AppTheme.PINK, Color.WHITE, Callable(), 60)
	claim.add_theme_font_size_override("font_size", 24)
	box.add_child(claim)
	if daily.get("claimed_today", false):
		claim.disabled = true
		claim.text = "Come back tomorrow!"
	claim.pressed.connect(func() -> void: _claim(ui, claim, result, today_card, grid, streak_label))

	ProfileUi.overlay(ui, card, 720 if not portrait else 520)
	if today_card and not daily.get("claimed_today", false):
		_bounce(today_card)


static func _day_card(day: Dictionary) -> PanelContainer:
	var today: bool = day.get("today", false)
	var claimed: bool = day.get("claimed", false)
	var panel := PanelContainer.new()
	var bg := AppTheme.YELLOW if today else (Color("d9f5e8") if claimed else Color.WHITE)
	var style := ProfileUi.box(bg, 16, 3)
	style.set_content_margin_all(8)
	if today:
		style.border_width_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(70, 104)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := AppTheme.vbox(4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var label := AppTheme.label("Day %d" % int(day.get("day", 0)), "", 15)
	label.add_theme_font_override("font", AppTheme.heading_font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var icon_holder := CenterContainer.new()
	if day.get("item") is Dictionary:
		var gift := TextureRect.new()
		gift.texture = EmojiPicker.texture(EMOJI_GIFT)
		gift.custom_minimum_size = Vector2(38, 38)
		gift.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gift.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(gift)
	else:
		icon_holder.add_child(CoinIcon.new(36))
	column.add_child(icon_holder)
	var amount := AppTheme.label(ProfileUi.grouped(day.get("credits", 0)), "", 18)
	amount.add_theme_font_override("font", AppTheme.heading_font())
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(amount)
	if day.get("item") is Dictionary:
		var bonus := AppTheme.label("+ mystery item", "MutedLabel", 11)
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(bonus)
	if claimed:
		var check := TileIcon.new("check", Vector2(22, 22))
		check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(check)
	return panel


static func _claim(ui: UIRoot, button: Button, result: VBoxContainer, today_card: Control, grid: GridContainer, streak_label: Label) -> void:
	button.disabled = true
	button.text = "Claiming..."
	var res: Dictionary = await Economy.claim_daily()
	if not is_instance_valid(button):
		return
	if not res.ok:
		button.text = "Come back tomorrow!"
		ui.toast(res.error, AppTheme.RED)
		return
	var reward: Dictionary = res.data.get("reward", {})
	button.text = "Awesome!"
	button.disabled = false
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])
	button.pressed.connect(ui.close_dialog)
	var line := AppTheme.label("+%s credits!" % ProfileUi.grouped(reward.get("credits", 0)), "TitleLabel", 34)
	line.add_theme_color_override("font_color", AppTheme.GOLD)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_child(line)
	AppTheme.pop_in(line)
	if reward.get("item") is Dictionary:
		var item: Dictionary = reward["item"]
		var got := ProfileUi.wrap("Bonus: %s (%s) is in your locker!" % [str(item.get("name", "?")), str(item.get("rarity", ""))], 18, AppTheme.PURPLE)
		got.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.add_child(got)
	if today_card and is_instance_valid(today_card):
		fly_coins(ui, today_card.get_global_rect().get_center(), 8)
	Sfx.play(ui, "coins")
	# Show today as collected.
	if is_instance_valid(grid):
		for child in grid.get_children():
			child.queue_free()
		for day: Dictionary in Economy.daily.get("calendar", []):
			grid.add_child(_day_card(day))
	if is_instance_valid(streak_label):
		streak_label.text = "%d-day streak! See you tomorrow." % maxi(1, int(Economy.daily.get("streak", 1)))


## Coins burst from `from` (global position) and fly to the top-right corner (the credits counter).
static func fly_coins(ui: UIRoot, from: Vector2, count := 8) -> void:
	var view := ui.get_viewport().get_visible_rect().size
	var target := Vector2(view.x - 170.0, 44.0)
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)
	for i in count:
		var coin := CoinIcon.new(30)
		coin.position = from - Vector2(15, 15)
		layer.add_child(coin)
		var burst := from + Vector2.from_angle(TAU * i / count) * randf_range(40.0, 80.0) - Vector2(15, 15)
		var t := coin.create_tween()
		t.tween_property(coin, "position", burst, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.05 * i)
		t.tween_property(coin, "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(coin, "scale", Vector2(0.5, 0.5), 0.5)
		t.tween_callback(coin.queue_free)
	var cleanup := layer.create_tween()
	cleanup.tween_interval(0.3 + 0.05 * count + 0.6)
	cleanup.tween_callback(layer.queue_free)


static func _bounce(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.resized.connect(func() -> void: node.pivot_offset = node.size / 2.0)
	var t := node.create_tween().set_loops()
	t.tween_property(node, "scale", Vector2(1.07, 1.07), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
