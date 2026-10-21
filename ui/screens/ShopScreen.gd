extends Screen
## The cosmetics shop: a full-screen catalogue for browsing and buying. Equipping lives on
## My Board (`my_board`), so the shop stays simple: a category rail (a swipeable tab row on
## phones), a Featured page (the season on sale and today's picks), roomy item cards with a
## picture or clip and a Buy button, and a detail sheet with Preview on board and Try on My Board.
## Prices, ownership and purchases come from the server through Loadout; in test mode everything
## is free. Guests are sent to sign up.
##
## Preview on board: the page steps aside and the board shows the item on your side (not
## equipped) with a camera shot that suits it, under a floating bar to page through the category,
## search every item, buy it, and go back to the same spot in the shop.

const FEATURED := "featured"
const SEASONAL := "seasonal"
const EXTRAS := "extras"
const PAGE_COLOR := Color("f6e8d4")
const WIDE := 900.0  # From this width (UI pixels) the categories sit in a rail on the left.

var _frame: Control  # Everything; scaled up on portrait phones (ProfileUi.fit).
var _page: Control  # The catalogue (hidden while previewing on the board).
var _header: HBoxContainer
var _title: Label
var _wallet: PanelContainer
var _board_wide: Button  # "My Board" with its name; phones get the icon-only one.
var _board_icon: Button
var _shop_search: LineEdit
var _search_slot: Control  # Phones: the search field gets its own row under the header.
var _rail_scroll: ScrollContainer
var _rail: VBoxContainer
var _tab_scroll: ScrollContainer
var _tab_row: HBoxContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _rail_buttons: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _category := FEATURED
var _columns := 4
var _card_width := 200.0
var _wide := true
var _buying := false
var _sheet_key := ""  # "category/slug" of the open detail sheet, refreshed after a purchase.
# Preview mode.
var _preview_bar: PanelContainer
var _preview_slug := ""
var _preview_category := ""
var _bar_head: BoxContainer
var _preview_title: Label
var _preview_badges: HBoxContainer
var _preview_actions: HFlowContainer
var _search: LineEdit
var _results: HFlowContainer


func _ready() -> void:
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(_page)
	var bg := ColorRect.new()
	bg.color = PAGE_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.name = "Margin"
	_page.add_child(margin)
	var column := AppTheme.vbox(12)
	margin.add_child(column)

	_header = AppTheme.hbox(10)
	var back := AppTheme.button("Back", "Ghost", func() -> void: ui.home(), 46)
	back.add_theme_font_size_override("font_size", 18)
	_header.add_child(back)
	_title = AppTheme.label("Shop", "HeadingLabel", 34)
	_header.add_child(_title)
	_header.add_child(AppTheme.spacer())
	_shop_search = AppTheme.field("Search: orb, lava, kraken, snow...")
	_shop_search.custom_minimum_size = Vector2(280, 46)
	_shop_search.clear_button_enabled = true
	_shop_search.text_changed.connect(func(_text: String) -> void: _refresh())
	_header.add_child(_shop_search)
	_wallet = AppTheme.pill("", AppTheme.GOLD, AppTheme.INK, 16)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_wallet)
	_board_wide = ProfileUi.colored_button("My Board", AppTheme.PURPLE, Color.WHITE, func() -> void: ui.show_screen("my_board"), 46)
	_board_wide.add_theme_font_size_override("font_size", 18)
	_header.add_child(_board_wide)
	_board_icon = ProfileUi.colored_button("", AppTheme.PURPLE, Color.WHITE, func() -> void: ui.show_screen("my_board"), 46)
	_board_icon.custom_minimum_size.x = 54
	_board_icon.tooltip_text = "My Board"
	var glyph := TileIcon.new("board", Vector2(26, 26))
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 13
	glyph.offset_right = -13
	glyph.offset_top = 8
	glyph.offset_bottom = -12  # Above the button's thicker bottom lip.
	_board_icon.add_child(glyph)
	_header.add_child(_board_icon)
	column.add_child(_header)

	_search_slot = MarginContainer.new()
	column.add_child(_search_slot)

	_tab_scroll = ScrollContainer.new()
	_tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tab_row = AppTheme.hbox(8)
	_tab_scroll.add_child(_tab_row)
	column.add_child(_tab_scroll)

	var body := AppTheme.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_rail_scroll = ScrollContainer.new()
	_rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rail_scroll.custom_minimum_size.x = 214
	_rail = AppTheme.vbox(6)
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail_scroll.add_child(_rail)
	body.add_child(_rail_scroll)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = AppTheme.vbox(18)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	body.add_child(_scroll)

	for entry: Dictionary in _sections():
		_rail_buttons[entry["key"]] = _rail_button(entry)
		_rail.add_child(_rail_buttons[entry["key"]])
		var tab := AppTheme.button(entry["label"], "Ghost", _switch.bind(entry["key"]), 44)
		tab.add_theme_font_size_override("font_size", 16)
		_tab_buttons[entry["key"]] = tab
		_tab_row.add_child(tab)

	_build_preview_bar()
	get_viewport().size_changed.connect(_on_resized)
	Loadout.changed.connect(func(_category: String, _slug: String) -> void: _refresh_preview_actions())
	Loadout.shop_updated.connect(_on_shop_updated)
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: _update_wallet())


func open(args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen.call_deferred("auth", {"next": "shop", "mode": "register"})  # The shop is for players.
		return
	_hide_preview()
	ui.game.visible = false  # The catalogue covers the screen; the 3D world rests underneath.
	if args.has("category"):
		_category = str(args["category"])
	_layout()
	_switch(_category)
	_update_wallet()
	AppTheme.pop_in(_content)
	Loadout.refresh_shop()  # Prices and ownership; the cards refresh when it answers.


func close() -> void:
	ui.close_dialog()
	_hide_preview()
	ShopThumbs.clear()
	ui.game.visible = true
	ui.game.show_attract()


# --- Layout --------------------------------------------------------------------------------------

func _on_resized() -> void:
	if visible:
		_layout()
		_refresh()


## Wide screens: the categories in a rail on the left and the search in the header. Phones and
## narrow windows: a swipeable tab row and the search on its own line.
func _layout() -> void:
	ProfileUi.fit(_frame, get_viewport().get_visible_rect().size)
	var view := _frame.size
	_wide = view.x >= WIDE
	var narrow := view.x < ProfileUi.NARROW
	var pad := 12 if narrow else 24
	var margin: MarginContainer = _page.get_node("Margin")
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, pad)
	margin.add_theme_constant_override("margin_top", 12 if narrow else 18)
	margin.add_theme_constant_override("margin_bottom", 8)
	_title.add_theme_font_size_override("font_size", 28 if narrow else 34)
	_board_wide.visible = not narrow
	_board_icon.visible = narrow
	_rail_scroll.visible = _wide
	_tab_scroll.visible = not _wide
	if _wide and _shop_search.get_parent() != _header:
		_shop_search.reparent(_header, false)
		_header.move_child(_shop_search, 3)
	elif not _wide and _shop_search.get_parent() != _search_slot:
		_shop_search.reparent(_search_slot, false)
	_search_slot.visible = not _wide
	_shop_search.custom_minimum_size.x = 260.0 if _wide else 0.0
	_update_wallet()
	# Cards: as many ~210 px columns as fit (2 on phones, up to 5).
	var content_width := view.x - pad * 2 - (214.0 + 18.0 if _wide else 0.0) - 16.0
	_columns = clampi(int(content_width / 210.0), 2, 5)
	_card_width = (content_width - (_columns - 1) * 14.0) / _columns
	_layout_preview()


func _sections() -> Array:
	var entries: Array = [{"key": FEATURED, "label": "Featured"}, {"key": SEASONAL, "label": "Seasonal"}]
	entries.append_array(CosmeticCatalog.CATEGORIES)
	entries.append({"key": EXTRAS, "label": "More"})
	return entries


## A rail entry: an icon (a real item's picture for item categories) and the name.
func _rail_button(entry: Dictionary) -> Button:
	var key: String = entry["key"]
	var b := AppTheme.button("", "Ghost", _switch.bind(key), 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := AppTheme.hbox(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -8
	row.offset_bottom = -4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph: Control
	match key:
		FEATURED:
			glyph = TileIcon.new("star", Vector2(30, 30))
		SEASONAL:
			glyph = TileIcon.new("crown", Vector2(30, 30))
		EXTRAS:
			glyph = TileIcon.new("bolt", Vector2(30, 30))
		_:
			var picture := TextureRect.new()
			picture.texture = ShopThumbs.icon(key, _sample_slug(key), 44)
			picture.custom_minimum_size = Vector2(46, 32)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph = picture
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var name_label := AppTheme.label(entry["label"], "", 17)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	b.add_child(row)
	return b


## A recognisable item of the category for its rail icon (not the plain default).
func _sample_slug(category: String) -> String:
	var all := CosmeticCatalog.slugs(category)
	for slug: String in all:
		if slug != Loadout.DEFAULTS.get(category, "") and str(CosmeticCatalog.info(category, slug).get("season", "")) == "":
			return slug
	return all[0] if not all.is_empty() else ""


func _update_wallet() -> void:
	var short := _frame != null and _frame.size.x < 700.0  # Phones: keep the header on one line.
	if Loadout.test_mode():
		AppTheme.set_pill(_wallet, "ALL FREE" if short else "TEST MODE · ALL FREE", AppTheme.MINT)
	else:
		var credits := AppTheme.num(ApiManager.user.get("credits", 0))
		AppTheme.set_pill(_wallet, ("%s cr" if short else "%s credits") % credits, AppTheme.GOLD, AppTheme.INK)


func _on_shop_updated() -> void:
	_update_wallet()
	if visible:
		_refresh()
		_refresh_sheet()
	_refresh_preview_actions()


# --- Pages ---------------------------------------------------------------------------------------

func _switch(key: String) -> void:
	if _shop_search.text != "":
		_shop_search.text = ""  # Picking a category ends the search.
	ShopThumbs.clear()  # Only the page on screen keeps its pictures decoded.
	_category = key
	for k: String in _rail_buttons:
		var on := k == key
		(_rail_buttons[k] as Button).theme_type_variation = "AccentButton" if on else "GhostButton"
		(_tab_buttons[k] as Button).theme_type_variation = "AccentButton" if on else "GhostButton"
	if _tab_buttons.has(key):
		_tab_scroll.ensure_control_visible.call_deferred(_tab_buttons[key])
	_refresh()
	_scroll.scroll_vertical = 0


func _refresh() -> void:
	if _content == null:
		return
	ProfileUi.clear(_content)
	if _search_query() != "":
		_build_search_results()
		return
	match _category:
		FEATURED:
			_build_featured()
		SEASONAL:
			_build_seasonal()
		EXTRAS:
			_build_extras()
		_:
			_build_category(_category)


func _search_query() -> String:
	return _shop_search.text.strip_edges().to_lower()


func _section_title(text: String, note := "") -> Control:
	var box := AppTheme.vbox(2)
	var title := AppTheme.label(text, "HeadingLabel", 26)
	box.add_child(title)
	if note != "":
		var line := AppTheme.label(note, "MutedLabel", 16)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
	return box


func _grid_of(pairs: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = _columns
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair: Array in pairs:
		grid.add_child(_card(pair[0], pair[1]))
	return grid


## The landing page: the occasion on sale now, then today's picks.
func _build_featured() -> void:
	var today := Time.get_date_dict_from_system()
	for occasion: String in Seasons.ORDER:
		if Seasons.is_live(occasion, today):
			_content.add_child(_season_banner(occasion, true))
	_content.add_child(_section_title("Featured today", "Hand-picked looks, new every day."))
	_content.add_child(_grid_of(_featured_items()))
	_content.add_child(_section_title("Browse", "Every kind of look, one tap away."))
	var shortcuts := HFlowContainer.new()
	shortcuts.add_theme_constant_override("h_separation", 8)
	shortcuts.add_theme_constant_override("v_separation", 8)
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var b := AppTheme.button(entry["label"], "Ghost", _switch.bind(entry["key"]), 44)
		b.add_theme_font_size_override("font_size", 16)
		shortcuts.add_child(b)
	_content.add_child(shortcuts)


## Items the admin featured, topped up with a daily pick of epic and legendary looks on sale.
func _featured_items() -> Array:
	var picked: Array = []
	for key: String in Loadout.shop_items:
		var info: Dictionary = Loadout.shop_items[key]
		var parts := key.split("/")
		if parts.size() == 2 and info.get("featured", false) and not CosmeticCatalog.info(parts[0], parts[1]).is_empty():
			picked.append([parts[0], parts[1]])
	var pool: Array = []
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		for slug: String in CosmeticCatalog.slugs(category):
			var item := CosmeticCatalog.info(category, slug)
			if str(item.get("rarity", "")) in ["epic", "legendary"] and Loadout.available(category, slug):
				pool.append([category, slug])
	var rng := RandomNumberGenerator.new()
	var date := Time.get_date_dict_from_system()
	rng.seed = date["year"] * 1000 + date["month"] * 40 + date["day"]
	for i in range(pool.size() - 1, 0, -1):  # Shuffle with today's seed: the same picks all day.
		var j := rng.randi_range(0, i)
		var swap: Array = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for pair: Array in pool:
		if picked.size() >= _columns * 2:
			break
		if not picked.any(func(p: Array) -> bool: return p[0] == pair[0] and p[1] == pair[1]):
			picked.append(pair)
	return picked


func _build_category(category: String) -> void:
	var blurb := ""
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		if entry["key"] == category:
			blurb = entry["blurb"]
	if category == "icons":
		# CC BY 3.0 attribution for the third-party glyphs (see assets/icons/CREDITS.md).
		blurb += "\nSome icon art by Lorc and Delapouite, game-icons.net, CC BY 3.0."
	_content.add_child(_section_title(CosmeticCatalog.label(category), blurb))
	var pairs: Array = []
	for slug: String in CosmeticCatalog.slugs(category):
		pairs.append([category, slug])
	if pairs.is_empty():
		_content.add_child(AppTheme.label("Coming soon.", "MutedLabel"))
		return
	_content.add_child(_grid_of(pairs))


## Every item, in any category, whose name, category or description matches the search.
func _build_search_results() -> void:
	var query := _search_query()
	var pairs: Array = []
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		var label := str(entry["label"]).to_lower()
		for slug: String in CosmeticCatalog.slugs(category):
			var item := CosmeticCatalog.info(category, slug)
			if str(item.get("name", slug)).to_lower().contains(query) or label.contains(query) or str(item.get("desc", "")).to_lower().contains(query):
				pairs.append([category, slug])
			if pairs.size() >= 40:
				break
		if pairs.size() >= 40:
			break
	_content.add_child(_section_title("%d item%s match \"%s\"" % [pairs.size(), "" if pairs.size() == 1 else "s", _shop_search.text.strip_edges()]))
	if not pairs.is_empty():
		_content.add_child(_grid_of(pairs))


## Every holiday collection, on-sale ones first, then by how soon each comes back.
func _build_seasonal() -> void:
	var today := Time.get_date_dict_from_system()
	var order: Array = Seasons.ORDER.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var la := Seasons.is_live(a, today)
		var lb := Seasons.is_live(b, today)
		if la != lb:
			return la
		return _days_until(a, today) < _days_until(b, today))
	for occasion: String in order:
		var found := _season_items(occasion)
		if found.is_empty():
			continue
		_content.add_child(_season_banner(occasion, false))
		_content.add_child(_grid_of(found))


func _season_items(occasion: String) -> Array:
	var found: Array = []
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		for slug: String in CosmeticCatalog.slugs(category):
			if str(CosmeticCatalog.info(category, slug).get("season", "")) == occasion:
				found.append([category, slug])
	return found


## A big coloured banner for an occasion; on the Featured page it links to the collection.
func _season_banner(occasion: String, linked: bool) -> PanelContainer:
	var live := Seasons.is_live(occasion)
	var card := PanelContainer.new()
	var style := ProfileUi.box(Seasons.color_of(occasion), 22, 4)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	var row := ProfileUi.flex(14)
	card.add_child(row)
	var words := AppTheme.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label(Seasons.name_of(occasion), "", 30, Color.WHITE)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.add_theme_color_override("font_outline_color", AppTheme.INK)
	title.add_theme_constant_override("outline_size", 8)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var line := "%s  ·  %d items  ·  %s" % [Seasons.window_text(occasion), _season_items(occasion).size(),
		"On sale now" if live else "Returns %s" % Seasons.returns_text(occasion)]
	var sub := AppTheme.label(line, "", 16, Color.WHITE)
	sub.add_theme_color_override("font_outline_color", AppTheme.INK)
	sub.add_theme_constant_override("outline_size", 5)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(sub)
	row.add_child(words)
	if linked:
		var go := ProfileUi.colored_button("Shop the collection", AppTheme.PAPER, AppTheme.INK, _switch.bind(SEASONAL), 50)
		go.add_theme_font_size_override("font_size", 18)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(go)
	return card


func _days_until(occasion: String, today: Dictionary) -> int:
	var start := str(Seasons.OCCASIONS.get(occasion, {}).get("start", "01-01")).split("-")
	var now := int(today["month"]) * 31 + int(today["day"])
	var then := int(start[0]) * 31 + int(start[1])
	return posmod(then - now, 12 * 31)


func _build_extras() -> void:
	_content.add_child(_section_title("More", "Things you buy for the moment, not for your board."))
	var charter: Array = Loadout.server_items_of("guild_charter")
	var charter_price := " · %s credits" % AppTheme.num(charter[0].get("price", 0)) if not charter.is_empty() and not Loadout.test_mode() else ""
	var grid := GridContainer.new()
	grid.columns = mini(_columns, 2)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.add_child(_extra_card("Shoutouts", "Put your message on everyone's screen as an animated marquee, in a theme of your choice.",
		AppTheme.PINK, "Send a shoutout", "shoutout"))
	grid.add_child(_extra_card("Guild Charter", "Found your own guild (Major rank and up): upload a logo, recruit members, climb the guild rankings%s." % charter_price,
		AppTheme.PURPLE, "Guilds", "guilds"))
	_content.add_child(grid)


func _extra_card(title: String, desc: String, color: Color, action: String, screen_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := ProfileUi.box(AppTheme.PAPER, 20, 3)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := AppTheme.vbox(10)
	card.add_child(box)
	var stripe := ColorRect.new()
	stripe.color = color
	stripe.custom_minimum_size.y = 10
	box.add_child(stripe)
	box.add_child(AppTheme.label(title, "HeadingLabel", 24))
	var text := AppTheme.label(desc, "MutedLabel", 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	box.add_child(AppTheme.button(action, "Primary", _open_extra.bind(screen_name), 48))
	return card


func _open_extra(screen_name: String) -> void:
	if ui.has_screen(screen_name):
		ui.require_login(screen_name)
	else:
		ui.toast("Coming soon!", AppTheme.PURPLE)


# --- Item cards ----------------------------------------------------------------------------------

## A roomy card: picture (or clip), name, rarity, price or Owned, and one main button. Tapping the
## card anywhere else opens its detail sheet.
func _card(category: String, slug: String) -> PanelContainer:
	var item := CosmeticCatalog.info(category, slug)
	var card := PanelContainer.new()
	var style := ProfileUi.box(AppTheme.PAPER, 20, 3)
	style.set_content_margin_all(10)
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_on_tap(card, _open_sheet.bind(category, slug))
	var box := AppTheme.vbox(8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(ThumbView.new(category, slug, roundf(clampf(_card_width * 0.6, 96.0, 170.0)), item.get("swatch", [])))
	var name_label := AppTheme.label(str(item.get("name", slug.capitalize())), "", 18)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	box.add_child(name_label)
	var line := AppTheme.hbox(6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rarity := str(item.get("rarity", "common"))
	line.add_child(_dot(_rarity_color(rarity)))
	var rarity_label := AppTheme.label(rarity.capitalize(), "", 14, _rarity_color(rarity).darkened(0.15))
	line.add_child(rarity_label)
	line.add_child(AppTheme.spacer())
	line.add_child(_price_label(category, slug))
	box.add_child(line)
	var action := _action(category, slug, 44)
	box.add_child(action)
	return card


func _dot(color: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", ProfileUi.box(color, 6, 2))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


## "900", "Owned", "Free" or "Oct 15" (back on sale), to the right of the rarity.
func _price_label(category: String, slug: String) -> Label:
	var text := ""
	var color := AppTheme.INK
	if Loadout.owns(category, slug):
		text = "Owned"
		color = AppTheme.MINT.darkened(0.25)
	elif not Loadout.available(category, slug):
		text = "Back %s" % Loadout.returns_text(category, slug)
		color = AppTheme.MUTED
	else:
		text = "%s cr" % AppTheme.num(Loadout.price(category, slug))
	var label := AppTheme.label(text, "", 15, color)
	label.add_theme_font_override("font", AppTheme.heading_font())
	return label


## The main button: Buy, Owned (opens My Board), Returns on a date, or Log in to buy.
func _action(category: String, slug: String, height: float) -> Button:
	var b: Button
	if Loadout.owns(category, slug):
		# Owned: a quiet button, so a page of things you have doesn't shout.
		b = AppTheme.button("Wear it" if category != "taunt" else "Owned", "Ghost", _use_on_board.bind(category, slug), height)
		b.disabled = category == "taunt"
	elif not ApiManager.is_logged_in():
		b = AppTheme.button("Log in to buy", "Secondary", func() -> void: ui.require_login("shop"), height)
	elif not Loadout.available(category, slug):
		b = AppTheme.button("Returns %s" % Loadout.returns_text(category, slug), "Ghost", Callable(), height)
		b.disabled = true
	else:
		b = AppTheme.button("Buy · %s" % AppTheme.num(Loadout.price(category, slug)), "Primary", _buy.bind(category, slug), height)
		b.disabled = _buying
	b.add_theme_font_size_override("font_size", 17)
	return b


## Calls `action` on a tap (press and release without dragging), so swiping through a scrolling
## page never opens anything.
func _on_tap(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				control.set_meta("press_at", event.global_position)
			elif control.has_meta("press_at") and (control.get_meta("press_at") as Vector2).distance_to(event.global_position) < 12.0:
				control.remove_meta("press_at")
				action.call())


func _buy(category: String, slug: String) -> void:
	if _buying:
		return
	_buying = true
	_refresh()
	var res: Dictionary = await Loadout.buy(category, slug)
	_buying = false
	var item := CosmeticCatalog.info(category, slug)
	if res.ok:
		ui.toast("Unlocked %s! Wear it on My Board." % str(item.get("name", slug)), AppTheme.MINT)
	elif res.status == 401:
		ui.require_login("shop")
	else:
		ui.toast(str(res.get("error", "")) if str(res.get("error", "")) != "" else "Not enough credits.", AppTheme.RED)
	_refresh()
	_refresh_sheet()


## Owned: equip it and see it on My Board (taunts aren't equipped: all of them are in the match's
## Taunt menu).
func _use_on_board(category: String, slug: String) -> void:
	ui.close_dialog()
	if category != "topper":
		Loadout.equip(category, slug)
	ui.show_screen("my_board", {"category": category, "place": slug if category == "topper" else ""})


func _rarity_color(rarity: String) -> Color:
	return {"common": AppTheme.MUTED, "rare": AppTheme.BLUE, "epic": AppTheme.PURPLE, "legendary": AppTheme.PINK}.get(rarity, AppTheme.MUTED)


# --- Detail sheet --------------------------------------------------------------------------------

func _open_sheet(category: String, slug: String) -> void:
	_sheet_key = "%s/%s" % [category, slug]
	var item := CosmeticCatalog.info(category, slug)
	var card := AppTheme.card()
	var box := AppTheme.vbox(12)
	card.add_child(box)
	var top := AppTheme.hbox(8)
	var name_label := AppTheme.label(str(item.get("name", slug.capitalize())), "HeadingLabel", 30)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var close := AppTheme.button("Close", "Ghost", _close_sheet, 44)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(close)
	box.add_child(top)
	box.add_child(ThumbView.new(category, slug, 230.0, item.get("swatch", [])))
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 6)
	badges.add_theme_constant_override("v_separation", 6)
	var rarity := str(item.get("rarity", "common"))
	badges.add_child(AppTheme.pill(CosmeticCatalog.label(category).to_upper(), AppTheme.INK, Color.WHITE, 14))
	badges.add_child(AppTheme.pill(rarity.to_upper(), _rarity_color(rarity), Color.WHITE, 14))
	var occasion := Loadout.season_of(category, slug)
	if occasion != "":
		badges.add_child(AppTheme.pill(Seasons.name_of(occasion).to_upper(), Seasons.color_of(occasion), Color.WHITE, 14))
	if Loadout.shop_info(category, slug).get("featured", false):
		badges.add_child(AppTheme.pill("FEATURED", AppTheme.PINK, Color.WHITE, 14))
	box.add_child(badges)
	if item.has("desc"):
		box.add_child(ProfileUi.wrap(str(item["desc"]), 18))
	for blurb: Dictionary in CosmeticCatalog.CATEGORIES:
		if blurb["key"] == category:
			box.add_child(ProfileUi.note(blurb["blurb"], 15))
	var main := _action(category, slug, 56)
	main.add_theme_font_size_override("font_size", 21)
	box.add_child(main)
	var row := ProfileUi.flex(10)  # Side by side; stacked on phones.
	var preview := AppTheme.button("Preview on board", "Secondary", _open_preview.bind(category, slug), 50)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_theme_font_size_override("font_size", 17)
	row.add_child(preview)
	if category != "taunt":
		var try := AppTheme.button("Try on My Board", "Accent", _try_on_board.bind(category, slug), 50)
		try.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		try.add_theme_font_size_override("font_size", 17)
		row.add_child(try)
	box.add_child(row)
	var shade := ColorRect.new()  # Catches taps beside the sheet (the overlay already dims).
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_on_tap(shade, _close_sheet)
	ProfileUi.overlay(ui, card, 560.0, shade)


func _close_sheet() -> void:
	_sheet_key = ""
	ui.close_dialog()


## After a purchase the open sheet shows the new state.
func _refresh_sheet() -> void:
	if _sheet_key == "" or not visible:
		return
	var parts := _sheet_key.split("/")
	_open_sheet(parts[0], parts[1])


func _try_on_board(category: String, slug: String) -> void:
	_close_sheet()
	ui.show_screen("my_board", {"try_category": category, "try_slug": slug})


# --- Preview mode --------------------------------------------------------------------------------

func _build_preview_bar() -> void:
	_preview_bar = AppTheme.card()
	_preview_bar.visible = false
	_frame.add_child(_preview_bar)
	var box := AppTheme.vbox(8)
	_preview_bar.add_child(box)

	_bar_head = BoxContainer.new()
	_bar_head.add_theme_constant_override("separation", 8)
	box.add_child(_bar_head)
	var nav := AppTheme.hbox(8)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(AppTheme.button("<", "Ghost", _step_preview.bind(-1), 44))
	var info := AppTheme.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_title = AppTheme.label("", "", 22)
	_preview_title.add_theme_font_override("font", AppTheme.heading_font())
	_preview_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_preview_title)
	_preview_badges = AppTheme.hbox(4)
	info.add_child(_preview_badges)
	nav.add_child(info)
	nav.add_child(AppTheme.button(">", "Ghost", _step_preview.bind(1), 44))
	_bar_head.add_child(nav)
	_preview_actions = HFlowContainer.new()  # Wraps on phones (Buy / Replay / Back to shop).
	_preview_actions.add_theme_constant_override("h_separation", 6)
	_preview_actions.add_theme_constant_override("v_separation", 6)
	_bar_head.add_child(_preview_actions)

	_search = AppTheme.field("Search every item: orbs, lava, dragon, snow...")
	_search.custom_minimum_size.y = 42
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _fill_results())
	box.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.name = "Results"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_results = HFlowContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("h_separation", 6)
	_results.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_results)
	box.add_child(scroll)


## Landscape: a bar across the top, the board fills the rest. Portrait: the lower part.
func _layout_preview() -> void:
	if _preview_bar == null:
		return
	var view := _frame.size
	var portrait := view.y > view.x
	_bar_head.vertical = portrait or view.x < 900.0
	AppTheme.set_card_padding(_preview_bar, view.x < ProfileUi.NARROW)
	if portrait:
		_preview_bar.custom_minimum_size.x = 0.0
		_preview_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
		_preview_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		_preview_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
		_preview_bar.custom_minimum_size.x = minf(view.x - 24.0, 1040.0)
		_preview_bar.offset_left = -_preview_bar.custom_minimum_size.x / 2.0
		_preview_bar.offset_right = _preview_bar.custom_minimum_size.x / 2.0
		_preview_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _open_preview(category: String, slug: String) -> void:
	ui.close_dialog()
	_sheet_key = ""
	_preview_category = category
	_preview_slug = slug
	_page.visible = false
	ui.game.visible = true
	_preview_bar.visible = true
	_layout_preview()
	_show_preview_item()
	_fill_results()
	AppTheme.pop_in(_preview_bar)


func _close_preview() -> void:
	if not _preview_bar.visible:
		return
	_hide_preview()
	ui.game.visible = false
	_page.visible = true
	# Back where the shop was, scroll position and all.


func _hide_preview() -> void:
	if _preview_bar == null or not _preview_bar.visible:
		return
	_preview_bar.visible = false
	_page.visible = true
	ui.game.end_preview()
	_preview_slug = ""


func _show_preview_item() -> void:
	var item := CosmeticCatalog.info(_preview_category, _preview_slug)
	_preview_title.text = str(item.get("name", _preview_slug.capitalize()))
	for child in _preview_badges.get_children():
		child.queue_free()
	var rarity := str(item.get("rarity", "common"))
	_preview_badges.add_child(AppTheme.pill(CosmeticCatalog.label(_preview_category).to_upper(), AppTheme.INK, Color.WHITE, 13))
	_preview_badges.add_child(AppTheme.pill(rarity.to_upper(), _rarity_color(rarity), Color.WHITE, 13))
	if item.has("desc"):
		_preview_title.tooltip_text = str(item["desc"])
	_refresh_preview_actions()
	ui.game.preview_item(_preview_category, _preview_slug)
	_play_preview_effect()
	_mark_results()


func _refresh_preview_actions() -> void:
	if _preview_bar == null or not _preview_bar.visible or _preview_slug == "":
		return
	for child in _preview_actions.get_children():
		child.queue_free()
	_preview_actions.add_child(_action(_preview_category, _preview_slug, 42))
	if _preview_category in ["trail", "kill", "taunt"]:
		_preview_actions.add_child(AppTheme.button("Replay", "Accent", _play_preview_effect, 42))
	_preview_actions.add_child(AppTheme.button("Back to shop", "Ghost", _close_preview, 42))


## Effects that only show during play get a demo: a move (trail), a knockout (kill), a throw (taunt).
func _play_preview_effect() -> void:
	var slug := _preview_slug
	match _preview_category:
		"trail", "kill":
			await get_tree().create_timer(0.35).timeout
			if _preview_bar.visible and _preview_slug == slug:
				ui.game.preview_effect(_preview_category)
		"taunt":
			ui.game.throw_taunt(Ranks.BLACK, slug)


func _step_preview(direction: int) -> void:
	var all := CosmeticCatalog.slugs(_preview_category)
	if all.is_empty():
		return
	var index := all.find(_preview_slug)
	_preview_slug = all[posmod(index + direction, all.size())]
	_show_preview_item()


## Search results: every item whose name or category matches; with no search, this category.
func _fill_results() -> void:
	for child in _results.get_children():
		child.queue_free()
	var query := _search.text.strip_edges().to_lower()
	# One row of this category's items while browsing; more room once you search.
	(_results.get_parent() as Control).custom_minimum_size.y = 80.0 if query != "" else 40.0
	var found := 0
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		if query == "" and category != _preview_category:
			continue
		var label := str(entry["label"])
		for slug: String in CosmeticCatalog.slugs(category):
			var name_text := str(CosmeticCatalog.info(category, slug).get("name", slug))
			if query != "" and not (name_text.to_lower().contains(query) or label.to_lower().contains(query)):
				continue
			var text := name_text if query == "" else "%s · %s" % [name_text, label]
			var b := AppTheme.button(text, "Ghost", _open_preview.bind(category, slug), 34)
			b.add_theme_font_size_override("font_size", 14)
			b.icon = ShopThumbs.icon(category, slug, 44)
			b.set_meta("item", "%s/%s" % [category, slug])
			_results.add_child(b)
			found += 1
			if found >= 60:
				return
	if found == 0:
		_results.add_child(AppTheme.label("Nothing matches \"%s\"." % _search.text.strip_edges(), "MutedLabel", 15))
	_mark_results()


func _mark_results() -> void:
	var current := "%s/%s" % [_preview_category, _preview_slug]
	for child in _results.get_children():
		if child is Button:
			(child as Button).theme_type_variation = "AccentButton" if child.get_meta("item", "") == current else "GhostButton"


func _unhandled_input(event: InputEvent) -> void:
	if _preview_bar != null and _preview_bar.visible and event.is_action_pressed("ui_cancel"):
		_close_preview()
		get_viewport().set_input_as_handled()
