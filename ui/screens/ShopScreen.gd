extends Screen
## The cosmetics shop / locker. Docked beside the board (below it on portrait phones) so every
## item previews live on the 3D board behind it. Eight categories; equipping is instant.
## TEST MODE (Loadout.test_mode()): everything is free and no login is needed.

var _panel: PanelContainer
var _category := "arena"
var _tabs: Dictionary = {}
var _blurb: Label
var _grid: GridContainer
var _count: PanelContainer
var _preview_button: Button


func _ready() -> void:
	_panel = AppTheme.card()
	add_child(_panel)
	var box := AppTheme.vbox(10)
	_panel.add_child(box)

	var header := AppTheme.hbox(10)
	header.add_child(AppTheme.label("Shop", "HeadingLabel"))
	header.add_child(AppTheme.spacer())
	if Loadout.test_mode():
		header.add_child(AppTheme.pill("TEST MODE · ALL FREE", AppTheme.MINT, Color.WHITE, 16))
	_count = AppTheme.pill("", AppTheme.PURPLE, Color.WHITE, 16)
	header.add_child(_count)
	box.add_child(header)

	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var key: String = entry["key"]
		var tab := AppTheme.button(entry["label"], "Ghost", _switch.bind(key), 42)
		tab.add_theme_font_size_override("font_size", 17)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[key] = tab
		tabs.add_child(tab)
	box.add_child(tabs)

	_blurb = AppTheme.label("", "MutedLabel", 16)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_blurb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	box.add_child(scroll)

	var footer := AppTheme.hbox(8)
	_preview_button = AppTheme.button("Play effect", "Accent", _play_preview, 48)
	footer.add_child(_preview_button)
	footer.add_child(AppTheme.button("Randomize", "Secondary", _randomize, 48))
	footer.add_child(AppTheme.button("Reset", "Ghost", _reset, 48))
	footer.add_child(AppTheme.spacer())
	footer.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.show_screen("title"), 48))
	box.add_child(footer)

	get_viewport().size_changed.connect(_layout)
	Loadout.changed.connect(func(_category: String, _slug: String) -> void: _refresh_cards())


func open(_args: Dictionary) -> void:
	_layout()
	_count.get_child(0).text = "%d ITEMS" % CosmeticCatalog.count()
	_switch(_category)
	AppTheme.pop_in(_panel)


func close() -> void:
	ui.game.show_attract()


## Landscape: a column on the left, board visible on the right. Portrait: the lower half.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x >= view.y:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 14)
		_panel.offset_right = _panel.offset_left + minf(520.0, view.x * 0.46)
		_grid.columns = 2
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
		_panel.offset_top = -view.y * 0.56
		_grid.columns = 2


func _switch(category: String) -> void:
	_category = category
	for key: String in _tabs:
		_tabs[key].theme_type_variation = "AccentButton" if key == category else "GhostButton"
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		if entry["key"] == category:
			_blurb.text = entry["blurb"]
	if category == "icons":
		# CC BY 3.0 attribution for the third-party glyphs (see assets/icons/CREDITS.md).
		_blurb.text += "\nSome icon art by Lorc and Delapouite, game-icons.net, CC BY 3.0."
	_preview_button.visible = category in ["trail", "kill"]
	_refresh_cards()


func _refresh_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var items := CosmeticCatalog.items(_category)
	if items.is_empty():
		var soon := AppTheme.label("Coming soon.", "MutedLabel")
		_grid.add_child(soon)
		return
	for slug: String in CosmeticCatalog.slugs(_category):
		_grid.add_child(_card(slug, items[slug]))


func _card(slug: String, item: Dictionary) -> PanelContainer:
	var equipped := _category != "taunt" and Loadout.get_item(_category) == slug
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
	var rarity := str(item.get("rarity", "common"))
	box.add_child(AppTheme.pill(rarity.to_upper(), _rarity_color(rarity), Color.WHITE, 13))
	var action: Button
	if _category == "taunt":
		# Taunts aren't equipped: every owned taunt is in the in-match Taunt menu. Preview instead.
		action = AppTheme.button("Throw!", "Accent", func() -> void: ui.game.throw_taunt(Ranks.BLACK, slug), 42)
	else:
		action = AppTheme.button("Equipped" if equipped else "Equip", "Success" if equipped else "Primary",
			Loadout.equip.bind(_category, slug), 42)
		action.disabled = equipped
	action.add_theme_font_size_override("font_size", 18)
	box.add_child(action)
	return card


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


func _randomize() -> void:
	Loadout.randomize_all()
	ui.toast("Random loadout!", AppTheme.PURPLE)


func _reset() -> void:
	Loadout.reset()


func _play_preview() -> void:
	ui.game.preview_effect(_category)
