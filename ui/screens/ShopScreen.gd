extends Screen
## The cosmetics shop / locker. Docked beside the board (below it on portrait phones) so every
## item previews live on the 3D board behind it; equipping is instant. Prices, ownership and
## purchases come from the server through Loadout. While the shop is in test mode
## (Loadout.test_mode()) everything is free and no login is needed.
##
## Toppers get a slot bar (three spots beside your half of the board) and flags open FlagEditor.
## "More" links to things sold elsewhere: shoutouts and guild charters.

const EXTRAS := "extras"

var _panel: PanelContainer
var _category := "arena"
var _tabs: Dictionary = {}
var _tab_grid: GridContainer
var _blurb: Label
var _content: VBoxContainer
var _grid: GridContainer
var _count: PanelContainer
var _wallet: PanelContainer
var _preview_button: Button
var _selected_slot := -1
var _editor: FlagEditor
var _editing_slot := -1
var _buying := false


func _ready() -> void:
	_panel = AppTheme.card()
	add_child(_panel)
	var box := AppTheme.vbox(10)
	_panel.add_child(box)

	var header := AppTheme.hbox(10)
	header.add_child(AppTheme.label("Shop", "HeadingLabel"))
	header.add_child(AppTheme.spacer())
	_wallet = AppTheme.pill("", AppTheme.MINT, Color.WHITE, 16)
	header.add_child(_wallet)
	_count = AppTheme.pill("", AppTheme.PURPLE, Color.WHITE, 16)
	header.add_child(_count)
	box.add_child(header)

	_tab_grid = GridContainer.new()
	_tab_grid.columns = 4
	_tab_grid.add_theme_constant_override("h_separation", 6)
	_tab_grid.add_theme_constant_override("v_separation", 6)
	var entries: Array = CosmeticCatalog.CATEGORIES.duplicate()
	entries.append({"key": EXTRAS, "label": "More"})
	for entry: Dictionary in entries:
		var key: String = entry["key"]
		var tab := AppTheme.button(entry["label"], "Ghost", _switch.bind(key), 36)
		tab.add_theme_font_size_override("font_size", 14)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[key] = tab
		_tab_grid.add_child(tab)
	box.add_child(_tab_grid)

	_blurb = AppTheme.label("", "MutedLabel", 16)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_blurb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = AppTheme.vbox(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	box.add_child(scroll)

	var footer := AppTheme.hbox(8)
	_preview_button = AppTheme.button("Play effect", "Accent", _play_preview, 48)
	footer.add_child(_preview_button)
	footer.add_child(AppTheme.button("Randomize", "Secondary", _randomize, 48))
	footer.add_child(AppTheme.button("Reset", "Ghost", _reset, 48))
	footer.add_child(AppTheme.spacer())
	footer.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.home(), 48))
	box.add_child(footer)

	get_viewport().size_changed.connect(_layout)
	Loadout.changed.connect(func(_category: String, _slug: String) -> void: _refresh())
	Loadout.shop_updated.connect(_on_shop_updated)
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: _update_header())


func open(_args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen.call_deferred("auth", {"next": "shop", "mode": "register"})  # The shop is for players.
		return
	_layout()
	_close_editor()
	_switch(_category)
	_update_header()
	AppTheme.pop_in(_panel)
	Loadout.refresh_shop()  # Prices and ownership; the cards refresh when it answers.


func close() -> void:
	_close_editor()
	ui.game.show_attract()


## Landscape: a column on the left, board visible on the right. Portrait: the lower half.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x >= view.y:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 14)
		_panel.offset_right = _panel.offset_left + minf(560.0, view.x * 0.46)
		_tab_grid.columns = 5 if _panel.offset_right - _panel.offset_left >= 480.0 else 4
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
		_panel.offset_top = -view.y * 0.58
		_tab_grid.columns = 3 if view.x < 520.0 else 4


func _update_header() -> void:
	if Loadout.test_mode():
		AppTheme.set_pill(_wallet, "TEST MODE · ALL FREE", AppTheme.MINT)
	elif ApiManager.is_logged_in():
		AppTheme.set_pill(_wallet, "%s CREDITS" % AppTheme.num(ApiManager.user.get("credits", 0)), AppTheme.GOLD, AppTheme.INK)
	else:
		AppTheme.set_pill(_wallet, "LOG IN TO BUY", AppTheme.BLUE)
	var total := 0
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		total += CosmeticCatalog.items(entry["key"]).size()
	_count.get_child(0).text = "%d ITEMS" % total


func _on_shop_updated() -> void:
	_update_header()
	_refresh()


func _switch(category: String) -> void:
	_close_editor()
	_category = category
	_selected_slot = -1
	for key: String in _tabs:
		_tabs[key].theme_type_variation = "AccentButton" if key == category else "GhostButton"
	_blurb.text = "Shoutouts, guild charters and other extras." if category == EXTRAS else ""
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		if entry["key"] == category:
			_blurb.text = entry["blurb"]
	if category == "icons":
		# CC BY 3.0 attribution for the third-party glyphs (see assets/icons/CREDITS.md).
		_blurb.text += "\nSome icon art by Lorc and Delapouite, game-icons.net, CC BY 3.0."
	_preview_button.visible = category in ["trail", "kill"]
	_refresh()


func _refresh() -> void:
	if _editor != null:
		return  # The flag editor owns the panel until Done.
	for child in _content.get_children():
		child.queue_free()
	if _category == EXTRAS:
		_build_extras()
		return
	if _category == "topper":
		_content.add_child(_topper_slots())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_grid)
	var items := CosmeticCatalog.items(_category)
	if items.is_empty():
		_grid.add_child(AppTheme.label("Coming soon.", "MutedLabel"))
		return
	for slug: String in CosmeticCatalog.slugs(_category):
		_grid.add_child(_card(slug, items[slug]))


# --- Item cards ----------------------------------------------------------------------------------

func _card(slug: String, item: Dictionary) -> PanelContainer:
	var owned := Loadout.owns(_category, slug)
	var equipped := _category not in ["taunt", "topper"] and Loadout.get_item(_category) == slug
	var card := AppTheme.card("Row")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if equipped:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(AppTheme.YELLOW, 0.35)
		style.set_corner_radius_all(18)
		style.set_border_width_all(4)
		style.border_color = AppTheme.INK
		style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", style)
	var box := AppTheme.vbox(6)
	card.add_child(box)
	box.add_child(_swatch(item.get("swatch", [])))
	var name_label := AppTheme.label(str(item.get("name", slug.capitalize())), "", 18)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 4)
	badges.add_theme_constant_override("v_separation", 4)
	var rarity := str(item.get("rarity", "common"))
	badges.add_child(AppTheme.pill(rarity.to_upper(), _rarity_color(rarity), Color.WHITE, 13))
	var info := Loadout.shop_info(_category, slug)
	if info.get("featured", false):
		badges.add_child(AppTheme.pill("FEATURED", AppTheme.PINK, Color.WHITE, 13))
	var season := _season_badge(info)
	if season != "":
		badges.add_child(AppTheme.pill(season, AppTheme.PURPLE, Color.WHITE, 13))
	box.add_child(badges)
	if item.has("desc"):
		var desc := AppTheme.label(str(item["desc"]), "MutedLabel", 13)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
	var action := _action(slug, item, owned, equipped)
	action.add_theme_font_size_override("font_size", 17)
	box.add_child(action)
	return card


func _action(slug: String, item: Dictionary, owned: bool, equipped: bool) -> Button:
	if not owned:
		if not ApiManager.is_logged_in():
			return AppTheme.button("Log in to buy", "Secondary", func() -> void: ui.require_login("shop"), 42)
		var buy := AppTheme.button("Buy · %s" % AppTheme.num(Loadout.price(_category, slug)), "Primary", _buy.bind(slug, item), 42)
		buy.disabled = _buying
		return buy
	match _category:
		"taunt":
			# Taunts aren't equipped: every owned taunt is in the in-match Taunt menu. Preview instead.
			return AppTheme.button("Throw!", "Accent", func() -> void: ui.game.throw_taunt(Ranks.BLACK, slug), 42)
		"topper":
			var placed := _topper_index(slug) >= 0
			if placed and ToppersLibrary.kind_of(slug) == "object":
				return AppTheme.button("Remove", "Ghost", _remove_topper.bind(_topper_index(slug)), 42)
			return AppTheme.button("Add flag" if ToppersLibrary.kind_of(slug) == "flag" else "Place", "Primary", _place_topper.bind(slug), 42)
	var equip := AppTheme.button("Equipped" if equipped else "Equip", "Success" if equipped else "Primary", Loadout.equip.bind(_category, slug), 42)
	equip.disabled = equipped
	return equip


func _buy(slug: String, item: Dictionary) -> void:
	if _buying:
		return
	_buying = true
	_refresh()
	var category := _category
	var res: Dictionary = await Loadout.buy(category, slug)
	_buying = false
	if res.ok:
		ui.toast("Unlocked %s!" % str(item.get("name", slug)), AppTheme.MINT)
		if category not in ["taunt", "topper"]:
			Loadout.equip(category, slug)
	elif res.status == 401:
		ui.require_login("shop")
	else:
		ui.toast(str(res.get("error", "")) if str(res.get("error", "")) != "" else "Not enough credits.", AppTheme.RED)
	_refresh()


## "HALLOWEEN · 3D LEFT" for seasonal items with an end date.
func _season_badge(info: Dictionary) -> String:
	var season := str(info.get("season", "")) if info.get("season") != null else ""
	var until := str(info.get("available_until", "")) if info.get("available_until") != null else ""
	if until == "":
		return season.to_upper()
	var end := Time.get_unix_time_from_datetime_string(until.left(19))
	var left := end - Time.get_unix_time_from_system()
	if left <= 0:
		return season.to_upper()
	var when := "%dD LEFT" % ceili(left / 86400.0) if left >= 86400 else "%dH LEFT" % ceili(left / 3600.0)
	return ("%s · %s" % [season.to_upper(), when]) if season != "" else when


func _swatch(colors: Array) -> HBoxContainer:
	var strip := AppTheme.hbox(0)
	if colors.is_empty():
		colors = [AppTheme.MUTED]
	for color: Variant in colors:
		var chip := ColorRect.new()
		chip.color = Color(color) if (color is Color or color is String) else AppTheme.MUTED
		chip.color.a = 1.0
		chip.custom_minimum_size = Vector2(0, 30)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(chip)
	return strip


func _rarity_color(rarity: String) -> Color:
	return {"common": AppTheme.MUTED, "rare": AppTheme.BLUE, "epic": AppTheme.PURPLE, "legendary": AppTheme.PINK}.get(rarity, AppTheme.MUTED)


# --- Toppers -------------------------------------------------------------------------------------

## The three spots beside your half of the board. Tap one to choose which spot Place replaces.
func _topper_slots() -> Control:
	var box := AppTheme.vbox(6)
	box.add_child(AppTheme.label("Your spots (tap one to replace it)", "", 16, AppTheme.MUTED))
	var row := AppTheme.hbox(8)
	var slots: Array = Loadout.get_toppers()["slots"]
	for i in ToppersLibrary.MAX_SLOTS:
		var card := AppTheme.card("Row")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == _selected_slot:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(AppTheme.BLUE, 0.25)
			style.set_corner_radius_all(16)
			style.set_border_width_all(4)
			style.border_color = AppTheme.INK
			style.set_content_margin_all(8)
			card.add_theme_stylebox_override("panel", style)
		var inner := AppTheme.vbox(4)
		card.add_child(inner)
		var title := AppTheme.label("%d. %s" % [i + 1, ToppersLibrary.STYLES[slots[i]["slug"]]["name"] if i < slots.size() else "Empty"],
			"", 15, AppTheme.INK if i < slots.size() else AppTheme.MUTED)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(title)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_slot(i))
		if i < slots.size():
			var buttons := AppTheme.hbox(4)
			if slots[i]["kind"] == "flag":
				var design := AppTheme.button("Design", "Accent", _edit_flag.bind(i), 34)
				design.add_theme_font_size_override("font_size", 14)
				design.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				buttons.add_child(design)
			var remove := AppTheme.button("Remove", "Ghost", _remove_topper.bind(i), 34)
			remove.add_theme_font_size_override("font_size", 14)
			remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons.add_child(remove)
			inner.add_child(buttons)
		row.add_child(card)
	box.add_child(row)
	return box


func _select_slot(index: int) -> void:
	_selected_slot = -1 if _selected_slot == index else index
	_refresh()


func _topper_index(slug: String) -> int:
	var slots: Array = Loadout.get_toppers()["slots"]
	for i in slots.size():
		if slots[i]["slug"] == slug:
			return i
	return -1


func _place_topper(slug: String) -> void:
	var config: Dictionary = Loadout.get_toppers().duplicate(true)
	var slots: Array = config["slots"]
	var slot := {"kind": ToppersLibrary.kind_of(slug), "slug": slug}
	if slot["kind"] == "flag":
		slot["flag"] = FlagFactory.DEFAULT_DESIGN.duplicate()
	var index := _selected_slot
	if index < 0 or index >= slots.size():
		if slots.size() < ToppersLibrary.MAX_SLOTS:
			index = slots.size()
			slots.append(slot)
		else:
			index = slots.size() - 1
			slots[index] = slot
			ui.toast("All three spots were full, so the last one was replaced. Tap a spot to pick which.", AppTheme.PURPLE)
	else:
		slots[index] = slot
	_selected_slot = -1
	Loadout.set_toppers(config)
	if slot["kind"] == "flag":
		_edit_flag(index)


func _remove_topper(index: int) -> void:
	var config: Dictionary = Loadout.get_toppers().duplicate(true)
	var slots: Array = config["slots"]
	if index >= 0 and index < slots.size():
		slots.remove_at(index)
	_selected_slot = -1
	Loadout.set_toppers(config)


func _edit_flag(index: int) -> void:
	var slots: Array = Loadout.get_toppers()["slots"]
	if index >= slots.size() or slots[index]["kind"] != "flag":
		return
	_close_editor()
	for child in _content.get_children():
		child.queue_free()
	_editing_slot = index
	_editor = FlagEditor.new(slots[index].get("flag", {}))
	_editor.ui = ui
	_editor.changed.connect(_on_flag_changed)
	_editor.done.connect(func() -> void:
		_close_editor()
		_refresh())
	_content.add_child(_editor)


func _on_flag_changed(design: Dictionary) -> void:
	var config: Dictionary = Loadout.get_toppers().duplicate(true)
	var slots: Array = config["slots"]
	if _editing_slot >= 0 and _editing_slot < slots.size():
		slots[_editing_slot]["flag"] = design
		Loadout.set_toppers(config)


func _close_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null
	_editing_slot = -1


# --- Extras --------------------------------------------------------------------------------------

func _build_extras() -> void:
	var charter: Array = Loadout.server_items_of("guild_charter")
	var charter_price := " · %s credits" % AppTheme.num(charter[0].get("price", 0)) if not charter.is_empty() and not Loadout.test_mode() else ""
	_content.add_child(_extra_card("Shoutouts", "Put your message on everyone's screen as an animated marquee, in a theme of your choice.",
		[Color("ff4f8b"), Color("ffcf3f"), Color("3d8bff")], "Send a shoutout", "shoutout"))
	_content.add_child(_extra_card("Guild Charter", "Found your own guild (Major rank and up): upload a logo, recruit members, climb the guild rankings%s." % charter_price,
		[Color("8b5cf6"), Color("ffd54a"), Color("1d1736")], "Guilds", "guilds"))


func _extra_card(title: String, desc: String, colors: Array, action: String, screen_name: String) -> PanelContainer:
	var card := AppTheme.card("Row")
	var box := AppTheme.vbox(6)
	card.add_child(box)
	box.add_child(_swatch(colors))
	box.add_child(AppTheme.label(title, "", 20))
	var text := AppTheme.label(desc, "MutedLabel", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	box.add_child(AppTheme.button(action, "Primary", _open_extra.bind(screen_name), 44))
	return card


func _open_extra(screen_name: String) -> void:
	if ui.has_screen(screen_name):
		ui.require_login(screen_name)
	else:
		ui.toast("Coming soon!", AppTheme.PURPLE)


# --- Footer --------------------------------------------------------------------------------------

func _randomize() -> void:
	_close_editor()
	Loadout.randomize_all()
	ui.toast("Random loadout!", AppTheme.PURPLE)


func _reset() -> void:
	_close_editor()
	Loadout.reset()


func _play_preview() -> void:
	ui.game.preview_effect(_category)
