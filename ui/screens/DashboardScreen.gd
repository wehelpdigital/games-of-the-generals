extends Screen
## Home after login, over the orbiting 3D board: who you are (photo, rank, XP, credits, guild,
## the daily-reward gift), the ways to play, icon shortcuts, the season's shop offer, and panels
## from other modules (DashboardRegistry: global chat, missions...). Themed by the admin's
## dashboard_theme setting. Wide screens: play and shortcuts left, global chat in the middle,
## season offer and missions right. Portrait: one scrolling column.

const LOGO_PATH := "res://ui/widgets/GameLogo.gd"
const LEFT_WIDTH := 372.0
const WIDE_MIN := 1100.0  ## Below this width the dashboard is one scrolling column.
const COLUMN_MAX := 680.0
const SIDE_WIDTH := 310.0
## Registry panels the home keeps as icons instead: the daily reward is the gift in the top bar,
## the powerup hand is the My Hand tile.
const HIDDEN_PANELS := ["res://ui/dashboard/DailyRewardBanner.gd", "res://ui/dashboard/PowerupLoadoutCard.gd"]

var _theme: Dictionary = DashboardThemes.get_theme("classic")
var _tint: TextureRect
var _ambient: DashboardAmbient
var _frame: Control
var _portrait := false
var _has_side := false

# Building blocks, moved between the wide and portrait layouts.
var _header: PanelContainer
var _row1: HBoxContainer
var _row2: HBoxContainer
var _avatar_button: Button
var _avatar: AvatarView
var _names: VBoxContainer
var _name_label: Label
var _insignia: RankInsignia
var _rank_label: Label
var _xp_bar: XpBar
var _guild_button: Button
var _credits_button: Button
var _reward_button: Button  # Daily login reward: a gift with a badge when today's is waiting.
var _reward_badge: UnreadBadge
var _logout_button: Button
var _settings_button: Button
var _play_row: BoxContainer  # Quick Match + Rooms.
var _logo_holder: Control
var _logo: Control
var _banners: VBoxContainer
var _season_banner: Control
var _play_card: PanelContainer
var _play_box: VBoxContainer
var _tiles_card: PanelContainer
var _tile_grid: GridContainer
var _season_card: SeasonOfferCard
var _main_box: VBoxContainer
var _side_box: VBoxContainer
var _panels: Array[Control] = []

# Layout containers.
var _wide: MarginContainer
var _wide_top: VBoxContainer
var _left_list: VBoxContainer
var _center_col: VBoxContainer
var _right_scroll: ScrollContainer
var _right_list: VBoxContainer
var _right_col: VBoxContainer
var _tall: MarginContainer
var _tall_top: VBoxContainer
var _tall_list: VBoxContainer


func _ready() -> void:
	_tint = TextureRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.stretch_mode = TextureRect.STRETCH_SCALE
	_tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_ambient = DashboardAmbient.new()
	add_child(_ambient)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_build_header()
	_banners = AppTheme.vbox(8)
	_play_card = AppTheme.card()
	_play_box = AppTheme.vbox(10)
	_play_card.add_child(_play_box)
	_build_tiles()
	_season_card = SeasonOfferCard.new()
	_season_card.setup(ui)
	_main_box = AppTheme.vbox(12)
	_side_box = AppTheme.vbox(12)
	_side_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_layouts()
	_add_registry_panels()

	get_viewport().size_changed.connect(_layout)
	Profile.changed.connect(func() -> void:
		if visible:
			_refresh_profile())
	Profile.promoted.connect(func(tier: int) -> void:
		if visible:
			_celebrate(tier))
	ServerConfig.changed.connect(func() -> void:
		if visible:
			_apply_theme()
			_season_card.refresh())
	Economy.daily_changed.connect(_paint_reward)
	ApiManager.auth_changed.connect(func(logged_in: bool) -> void:
		if visible and not logged_in:
			ui.home())


func open(_args: Dictionary) -> void:
	_layout()  # Decides wide or portrait first: the play buttons are sized for it.
	_apply_theme()
	_layout()
	_refresh_profile()
	for panel in _panels:
		if panel.has_method("refresh"):
			panel.call("refresh")
	var delay := 0.0
	_season_card.refresh()
	for card: Control in [_header, _play_card, _tiles_card, _season_card]:
		AppTheme.pop_in(card, delay)
		delay += 0.05
	_refresh_daily()
	if _logo and _logo.has_method("intro"):
		_logo.call("intro")
	Profile.refresh(4.0)
	if Profile.pending_promotion >= 0:
		_celebrate.call_deferred(Profile.pending_promotion)


# --- Building -----------------------------------------------------------------------------------

func _build_header() -> void:
	_header = AppTheme.card("Bar")
	var column := AppTheme.vbox(8)
	_header.add_child(column)
	_row1 = AppTheme.hbox(12)
	_row2 = AppTheme.hbox(10)
	column.add_child(_row1)
	column.add_child(_row2)

	_avatar_button = _bare_button(func() -> void: ui.show_screen("profile"))
	_avatar_button.custom_minimum_size = Vector2(60, 60)
	_avatar_button.tooltip_text = "Your profile"
	_avatar = AvatarView.new(60)
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar_button.add_child(_avatar)

	_names = AppTheme.vbox(0)
	_names.custom_minimum_size.x = 190
	_names.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_label = AppTheme.label("", "", 24)
	_name_label.add_theme_font_override("font", AppTheme.heading_font())
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # Long names end in "..."
	_names.add_child(_name_label)
	var rank_row := AppTheme.hbox(6)
	_insignia = RankInsignia.new(0, 24)
	_insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_row.add_child(_insignia)
	_rank_label = AppTheme.label("", "MutedLabel", 16)
	_rank_label.clip_text = true  # Rank and title can be long; the header must fit a phone.
	_rank_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_child(_rank_label)
	_names.add_child(rank_row)

	_xp_bar = XpBar.new(26)
	_xp_bar.custom_minimum_size.x = 190
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_guild_button = ProfileUi.small_button("Guild", "Success", _open_guild, 44)
	_credits_button = ProfileUi.colored_button("0", AppTheme.GOLD, AppTheme.INK, func() -> void: ui.show_screen("shop"), 44)
	_credits_button.add_theme_font_size_override("font_size", 18)
	_credits_button.tooltip_text = "Credits - visit the shop"
	_settings_button = ui.gear_button("dashboard") if ui else Button.new()
	_reward_button = ProfileUi.colored_button("", AppTheme.PAPER, AppTheme.INK, _open_daily, 44)
	_reward_button.custom_minimum_size.x = 52
	_reward_button.tooltip_text = "Daily reward"
	var gift := TextureRect.new()
	gift.texture = EmojiPicker.texture("1f389")
	gift.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gift.offset_left = 10
	gift.offset_right = -10
	gift.offset_top = 7
	gift.offset_bottom = -11  # Above the button's thicker bottom lip.
	_reward_button.add_child(gift)
	_reward_badge = UnreadBadge.new()
	_reward_button.add_child(_reward_badge)
	_logout_button = ProfileUi.colored_button("", AppTheme.PAPER, AppTheme.INK, _confirm_logout, 44)
	_logout_button.custom_minimum_size.x = 52
	_logout_button.tooltip_text = "Log out"
	var door := TileIcon.new("logout", Vector2(26, 26))
	door.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	door.offset_left = 12
	door.offset_right = -12
	door.offset_top = 9
	door.offset_bottom = -13  # Above the button's thicker bottom lip.
	_logout_button.add_child(door)

	_logo_holder = Control.new()
	_logo_holder.custom_minimum_size = Vector2(110, 64)
	_logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.clip_contents = false
	_logo_holder.resized.connect(_fit_logo)
	_build_logo()


func _build_logo() -> void:
	if ResourceLoader.exists(LOGO_PATH):
		var script: Script = load(LOGO_PATH)
		if script and script.can_instantiate():
			var instance: Object = script.new()
			if instance is Control:
				_logo = instance
				_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_logo_holder.add_child(_logo)
				_fit_logo.call_deferred()
				return
			if instance is Node:
				(instance as Node).queue_free()
	# Fallback wordmark.
	var words := AppTheme.vbox(-10)
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := AppTheme.label("SALPAKAN", "TitleLabel", 34)
	top.add_theme_color_override("font_color", AppTheme.YELLOW)
	top.add_theme_constant_override("outline_size", 9)
	top.add_theme_constant_override("shadow_offset_y", 3)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom := AppTheme.label("TACTICS!", "TitleLabel", 24)
	bottom.add_theme_color_override("font_color", AppTheme.PINK)
	bottom.add_theme_constant_override("outline_size", 8)
	bottom.add_theme_constant_override("shadow_offset_y", 3)
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.rotation = deg_to_rad(-3.0)
	bottom.resized.connect(func() -> void: bottom.pivot_offset = bottom.size * 0.5)
	words.add_child(top)
	words.add_child(bottom)
	_logo_holder.add_child(words)


## Fits the brand logo into its slot in the header, whatever its natural size.
func _fit_logo() -> void:
	if _logo == null or not is_instance_valid(_logo):
		return
	var room := _logo_holder.size
	if _logo.has_method("set_height"):
		# GameLogo keeps its own aspect inside whatever rect it gets.
		_logo.call("set_height", minf(room.y, room.x * 0.72))
		_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var natural := _logo.get_combined_minimum_size()
	if natural.x < 1.0 or natural.y < 1.0:
		_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var k := minf(room.x / natural.x, room.y / natural.y)
	_logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_logo.size = natural
	_logo.scale = Vector2(k, k)
	_logo.position = (room - natural * k) / 2.0


func _build_tiles() -> void:
	_tiles_card = AppTheme.card()
	_tile_grid = GridContainer.new()
	_tile_grid.columns = 3
	_tile_grid.add_theme_constant_override("h_separation", 10)
	_tile_grid.add_theme_constant_override("v_separation", 10)
	_tiles_card.add_child(_tile_grid)


## Tiles depend on which screens exist (other modules register theirs), so they are rebuilt on open.
func _fill_tiles() -> void:
	ProfileUi.clear(_tile_grid)
	var specs := [
		["My Board", "board", AppTheme.PINK, "my_board"],
		["Shop", "cart", AppTheme.GOLD, "shop"],
		["My Hand", "bolt", AppTheme.PURPLE, "powerups"],
		["Next Rank", "ranks", AppTheme.BRONZE, "ranks"],
		["Leaderboards", "trophy", AppTheme.BLUE, "leaderboard"],
		["Guild", "shield", AppTheme.MINT, "guilds"],
		["Profile", "person", AppTheme.PINK, "profile"],
		["Awards", "crown", AppTheme.PURPLE, "achievements"],
	]
	for spec: Array in specs:
		var target: String = spec[3]
		if not ui.has_screen(target):
			continue
		var action := _open_guild if target == "guilds" else func() -> void: ui.show_screen(target)
		var t := ProfileUi.tile(spec[0], spec[1], spec[2], action)
		t.custom_minimum_size.y = 80
		_tile_grid.add_child(t)
	_fit_tiles()


## Seven or more tiles go four wide on wide screens so the column stays short.
func _fit_tiles() -> void:
	_tile_grid.columns = 4 if _tile_grid.get_child_count() > 6 and not _portrait else 3
	for t: Control in _tile_grid.get_children():
		t.custom_minimum_size.x = 76 if _tile_grid.columns == 4 else 96
		for label: Node in t.find_children("*", "Label", true, false):
			(label as Label).add_theme_font_size_override("font_size", 13 if _tile_grid.columns == 4 else 15)


func _fill_play() -> void:
	ProfileUi.fit(_frame, get_viewport().get_visible_rect().size)  # Sets ProfileUi.narrow for flex().
	ProfileUi.clear(_play_box)
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Play", Color(_theme["accent"]).darkened(0.15)))
	var greeting := AppTheme.label(_greeting(), "MutedLabel", 15)
	greeting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	greeting.clip_text = true  # Long names mustn't widen the card past a phone screen.
	greeting.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(greeting)
	_play_box.add_child(head)
	if ui.has_screen("ranked"):
		_play_box.add_child(ProfileUi.play_button("Ranked Match", "Your rank only - win +60 XP",
			_theme["accent"], func() -> void: ui.show_screen("ranked"), 74 if _portrait else 62, "swords"))
	var row := ProfileUi.flex(10)  # Side by side, or stacked (phones, and the narrow left column).
	_play_row = row
	row.vertical = ProfileUi.narrow or not _portrait
	var quick := ProfileUi.play_button("Quick Match", "Anyone online", _theme["accent2"],
		func() -> void: ui.require_login("lobby"), 64 if _portrait else 54, "globe")
	quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(quick)
	if ui.has_screen("rooms"):
		var rooms := ProfileUi.play_button("Rooms", "Host or join", AppTheme.PURPLE, func() -> void: ui.show_screen("rooms"), 64 if _portrait else 54, "users")
		rooms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rooms)
	_play_box.add_child(row)
	_play_box.add_child(ProfileUi.play_button("Play vs AI", "Practice offline", AppTheme.MINT,
		func() -> void: ui.show_screen("ai_setup"), 58 if _portrait else 50, "robot"))


func _add_registry_panels() -> void:
	for slot: String in ["banner", "main", "side"]:
		for entry: Dictionary in DashboardRegistry.in_slot(slot):
			if (entry["script"] as Script).resource_path in HIDDEN_PANELS:
				continue
			var panel: Control = (entry["script"] as Script).new()
			var parent: Control = {"banner": _banners, "main": _main_box, "side": _side_box}[slot]
			parent.add_child(panel)
			_panels.append(panel)
			if slot == "side":
				_has_side = true
				panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if panel.has_method("setup"):
				panel.call("setup", self)


func _build_layouts() -> void:
	# Wide: header, banners, then [play + tiles | global chat | season offer + module cards].
	_wide = _margin(10)
	_frame.add_child(_wide)
	_wide_top = AppTheme.vbox(12)
	_wide.add_child(_wide_top)
	var body := AppTheme.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wide_top.add_child(body)
	var left := _scroll()
	left.custom_minimum_size.x = LEFT_WIDTH
	_left_list = AppTheme.vbox(12)
	_left_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_left_list)
	body.add_child(left)
	_center_col = AppTheme.vbox(12)
	_center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_center_col)
	_right_col = AppTheme.vbox(12)
	_right_col.custom_minimum_size.x = SIDE_WIDTH
	_right_scroll = _scroll()
	_right_list = AppTheme.vbox(12)
	_right_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.add_child(_right_list)
	_right_col.add_child(_right_scroll)
	body.add_child(_right_col)

	# Portrait: logo, header, then one scrolling column.
	_tall = _margin(8)
	_frame.add_child(_tall)
	_tall_top = AppTheme.vbox(10)
	_tall.add_child(_tall_top)
	var tall_scroll := _scroll()
	tall_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tall_list = AppTheme.vbox(14)
	_tall_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tall_scroll.add_child(_tall_list)
	_tall_top.add_child(tall_scroll)


# --- Layout -------------------------------------------------------------------------------------

func _layout() -> void:
	if not is_inside_tree():
		return
	var phone_portrait := ProfileUi.fit(_frame, get_viewport().get_visible_rect().size)
	var view := _frame.size
	# The three-column layout needs about 1100 px; narrower screens (landscape phones, tablets)
	# get the single scrolling column too, centred and at most COLUMN_MAX wide.
	var was_portrait := _portrait
	_portrait = phone_portrait or view.x < WIDE_MIN
	if was_portrait != _portrait and _play_box.get_child_count() > 0:
		_fill_play()
	var short := view.y < 560.0  # Landscape phones: the logo is dropped and the header scrolls too.
	_wide.visible = not _portrait
	_tall.visible = _portrait
	var side_margin := maxf(8.0, (view.x - COLUMN_MAX) / 2.0)
	_tall.add_theme_constant_override("margin_left", int(side_margin))
	_tall.add_theme_constant_override("margin_right", int(side_margin))
	_fit_tiles()
	_arrange_header()
	if _play_row:
		_play_row.vertical = ProfileUi.narrow or not _portrait
	if _portrait:
		_logo_holder.visible = not short
		_put(_logo_holder, _tall_top, 0)
		if short:
			_put(_header, _tall_list, 0)
		else:
			_put(_header, _tall_top, 1)
		for part: Control in [_banners, _play_card, _tiles_card, _season_card, _main_box, _side_box]:
			_put(part, _tall_list)
		_side_box.custom_minimum_size.y = 460.0 if _has_side else 0.0
	else:
		_logo_holder.visible = true
		_put(_header, _wide_top, 0)
		_put(_banners, _center_col, 0)  # Above the chat, so the play column keeps its height.
		_put(_play_card, _left_list)
		_put(_tiles_card, _left_list)
		_side_box.custom_minimum_size.y = 0.0
		# Global chat takes the middle; the season offer and module cards (missions) the right.
		_put(_side_box, _center_col)
		_put(_season_card, _right_list)
		_put(_main_box, _right_list)
		_right_scroll.visible = true
		_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fit_logo.call_deferred()


func _arrange_header() -> void:
	for row: HBoxContainer in [_row1, _row2]:
		for child in row.get_children():
			row.remove_child(child)
			if child.has_meta("spacer"):
				child.queue_free()
	_put(_avatar_button, _row1)
	_put(_names, _row1)
	_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _portrait else Control.SIZE_FILL
	_names.custom_minimum_size.x = 96.0 if _portrait else 190.0
	_xp_bar.custom_minimum_size.x = 72.0 if _portrait else 190.0
	if _portrait:
		# Phones: name, settings and log-out on the first row; XP, credits and guild on the second.
		_put(_settings_button, _row1)
		_put(_logout_button, _row1)
		_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_put(_xp_bar, _row2)
		_put(_credits_button, _row2)
		_put(_reward_button, _row2)
		_put(_guild_button, _row2)
		_row2.visible = true
		_logo_holder.custom_minimum_size = Vector2(240, 150)
		_logo_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_xp_bar.size_flags_horizontal = Control.SIZE_FILL
		_put(_xp_bar, _row1)
		_row1.add_child(_header_spacer())
		_put(_logo_holder, _row1)
		_row1.add_child(_header_spacer())
		_put(_guild_button, _row1)
		_put(_credits_button, _row1)
		_put(_reward_button, _row1)
		_put(_settings_button, _row1)
		_put(_logout_button, _row1)
		_row2.visible = false
		_logo_holder.custom_minimum_size = Vector2(110, 64)


func _header_spacer() -> Control:
	var spacer := AppTheme.spacer()
	spacer.set_meta("spacer", true)
	return spacer


func _put(node: Control, parent: Control, index := -1) -> void:
	if node.get_parent() != parent:
		if node.get_parent():
			node.get_parent().remove_child(node)
		parent.add_child(node)
	if index >= 0:
		parent.move_child(node, index)
	else:
		parent.move_child(node, parent.get_child_count() - 1)


# --- Data and theme ------------------------------------------------------------------------------

func _apply_theme() -> void:
	_theme = DashboardThemes.resolve(ServerConfig.get_value("dashboard_theme", "classic"), ServerConfig.get_value("dashboard_palette"))
	_tint.texture = DashboardThemes.tint_texture(_theme)
	_ambient.set_style(_theme["deco"], _theme["accent"], _theme["accent2"])
	for card: PanelContainer in [_play_card, _tiles_card]:
		card.add_theme_stylebox_override("panel", DashboardThemes.card_style(_theme))
	_season_card.set_colors(_theme)
	var bar := ProfileUi.box(Color(_theme["card"], 0.96), 24, 3)
	bar.set_content_margin_all(10)
	bar.content_margin_left = 12
	bar.content_margin_right = 12
	_header.add_theme_stylebox_override("panel", bar)
	_xp_bar.set_color(_theme["accent"])
	_fill_play()
	_fill_tiles()
	_fill_banners()


func _fill_banners() -> void:
	if _season_banner:
		_season_banner.queue_free()
		_season_banner = null
	var holder := AppTheme.vbox(6)
	var notice := str(ServerConfig.get_value("maintenance_message", ""))
	if notice != "":
		var note := PanelContainer.new()
		var style := ProfileUi.box(AppTheme.RED, 18, 3)
		style.set_content_margin_all(10)
		note.add_theme_stylebox_override("panel", style)
		var text := ProfileUi.wrap(notice, 17, Color.WHITE)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_child(text)
		holder.add_child(note)
	if holder.get_child_count() == 0:
		holder.free()
		return
	_season_banner = holder
	_banners.add_child(holder)
	_banners.move_child(holder, 0)


func _refresh_profile() -> void:
	var data := Profile.data
	_avatar.set_user(data)
	_name_label.text = str(data.get("username", ApiManager.user.get("username", "Player")))
	_insignia.set_tier(Profile.tier())
	_rank_label.text = str(data.get("rank_name", PlayerRanks.name_of(Profile.tier())))
	var title := Economy.title_of(data)
	if title != "":
		_rank_label.text += "  -  " + title
	var progress := Profile.xp_progress()
	if progress["maxed"]:
		_xp_bar.set_progress(1, 1, "%s XP - MAX RANK" % ProfileUi.grouped(progress["xp"]))
	else:
		_xp_bar.set_progress(float(progress["xp"]) - float(progress["from"]), float(progress["to"]) - float(progress["from"]),
			"%s / %s XP" % [ProfileUi.grouped(progress["xp"]), ProfileUi.grouped(progress["to"])])
	# Phones drop the "cr": the gold button already says credits, and the row must fit.
	_credits_button.text = ProfileUi.grouped(Profile.credits()) + ("" if _portrait else " cr")
	var guild := Profile.my_guild()
	if guild.is_empty():
		_guild_button.text = "Guilds"
		_guild_button.theme_type_variation = "GhostButton"
	else:
		_guild_button.text = "[%s]" % str(guild.get("tag", "?"))
		_guild_button.theme_type_variation = "SuccessButton"
	_guild_button.visible = ui.has_screen("guilds")


func _greeting() -> String:
	var hour: int = Time.get_datetime_dict_from_system()["hour"]
	var name_text := str(Profile.data.get("username", "General"))
	if hour < 12:
		return "Good morning, %s!" % name_text
	if hour < 18:
		return "Ready for battle, %s?" % name_text
	return "Evening ops, %s!" % name_text


func _time_left(iso: String) -> String:
	if iso.length() < 19:
		return ""
	var end := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	var left := int(end - Time.get_unix_time_from_system())
	if left <= 0:
		return "ending now"
	var days := left / 86400
	var hours := (left % 86400) / 3600
	if days > 0:
		return "%dd %dh left" % [days, hours]
	return "%dh %dm left" % [hours, (left % 3600) / 60]


# --- Actions ------------------------------------------------------------------------------------

## Fetches today's reward; the first visit of the day opens the calendar by itself.
func _refresh_daily() -> void:
	await Economy.refresh_daily()
	_paint_reward()
	if Economy.should_offer_daily() and is_visible_in_tree():
		Economy.mark_daily_offered()
		DailyRewardPopup.open(ui)


func _paint_reward() -> void:
	var daily := Economy.daily
	_reward_button.visible = ApiManager.is_logged_in() and not daily.is_empty()
	var waiting: bool = not daily.is_empty() and not daily.get("claimed_today", true)
	_reward_badge.set_count(1 if waiting else 0)
	var left := EconomyUi.time_left(str(daily.get("next_reset_at", "")))
	_reward_button.tooltip_text = "Daily reward - ready to claim!" if waiting else (
		"Daily reward - next one in %s" % left if left != "" else "Daily reward")


func _open_daily() -> void:
	Economy.mark_daily_offered()
	DailyRewardPopup.open(ui)


func _open_guild() -> void:
	var guild := Profile.my_guild()
	if guild.is_empty():
		ui.show_screen("guilds")
	else:
		ui.show_screen("guild", {"id": int(guild.get("id", 0))})


func _confirm_logout() -> void:
	ui.confirm("Log out of %s?" % str(Profile.data.get("username", "your account")), "Log out", func() -> void:
		await ApiManager.logout()
		ui.home()
		ui.toast("Logged out. See you soon!"))


## Full-screen "PROMOTED!" moment with confetti and a share prompt.
func _celebrate(tier: int) -> void:
	Profile.pending_promotion = -1
	var card := AppTheme.card()
	var box := AppTheme.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var title := AppTheme.label("PROMOTED!", "TitleLabel", 42 if ProfileUi.narrow else 58)
	title.add_theme_color_override("font_color", AppTheme.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var insignia := RankInsignia.new(tier, 150)
	insignia.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(insignia)
	var line := AppTheme.label("You're now a %s!" % PlayerRanks.name_of(tier), "HeadingLabel", 30)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	box.add_child(ProfileUi.note("Brag about it - sharing also counts toward your next rank."))
	var row := AppTheme.hbox(10)
	var share := AppTheme.button("Share it!", "Secondary", func() -> void: ShareSheet.open(ui), 54)
	var ok := AppTheme.button("Awesome!", "Primary", func() -> void: ui.close_dialog(), 54)
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(share)
	row.add_child(ok)
	box.add_child(row)
	var confetti := DashboardAmbient.new()
	confetti.set_style("confetti", AppTheme.PINK, AppTheme.BLUE)
	ProfileUi.overlay(ui, card, 460, confetti)
	insignia.resized.connect(func() -> void: insignia.pivot_offset = insignia.size * 0.5)
	insignia.scale = Vector2.ONE * 0.2
	insignia.rotation = -0.6
	var t := insignia.create_tween().set_parallel(true)
	t.tween_property(insignia, "scale", Vector2.ONE, 0.7).set_delay(0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(insignia, "rotation", 0.0, 0.5).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Helpers ------------------------------------------------------------------------------------

func _margin(amount: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, amount)
	return m


func _scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s


## A button with no visuals of its own (wraps the avatar).
func _bare_button(action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(action)
	return b
