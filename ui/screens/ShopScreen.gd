extends Screen
## Cosmetic shop. Tapping an item previews it live on the 3D board behind the panel; buying spends
## credits and equips it. Purely cosmetic: nothing here changes how pieces fight.

var _card: PanelContainer
var _category := "board_theme"
var _tabs: Dictionary = {}
var _credits: PanelContainer
var _grid: GridContainer
var _items: Array = []
var _owned: Dictionary = {}     # slug -> true
var _equipped: Dictionary = {}  # {board_theme, piece_skin}


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(12)
	_card.add_child(box)

	var header := AppTheme.hbox(10)
	header.add_child(AppTheme.label("Shop", "HeadingLabel"))
	header.add_child(AppTheme.spacer())
	_credits = AppTheme.pill("—", AppTheme.GOLD, AppTheme.INK)
	header.add_child(_credits)
	box.add_child(header)

	var tabs := AppTheme.hbox(8)
	for category: String in ["board_theme", "piece_skin"]:
		var tab := AppTheme.button("Boards" if category == "board_theme" else "Pieces", "Ghost", func() -> void: _switch(category), 46)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[category] = tab
		tabs.add_child(tab)
	box.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 330
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	box.add_child(scroll)

	var note := AppTheme.label("Win matches to earn credits. Cosmetics never change the rules.", "MutedLabel", 16)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	box.add_child(AppTheme.button("Back", "Ghost", _leave, 48))
	add_child(AppTheme.centered(_card, 640))


func open(_args: Dictionary) -> void:
	AppTheme.pop_in(_card)
	await _load()
	_switch(_category)


func close() -> void:
	ui.game.show_attract()  # Drop any preview and show the equipped looks again.


func _leave() -> void:
	ui.show_screen("title")


func _load() -> void:
	var res := await ApiManager.shop_items()
	_items = res.data.get("data", []) if res.ok else []
	_owned.clear()
	_equipped = {"board_theme": CosmeticLibrary.DEFAULT_BOARD, "piece_skin": CosmeticLibrary.DEFAULT_PIECES}
	if ApiManager.is_logged_in():
		var inventory := await ApiManager.inventory()
		if inventory.ok:
			for item: Dictionary in inventory.data.get("items", []):
				_owned[item.get("slug")] = true
			var equipped: Variant = inventory.data.get("equipped")
			if equipped is Dictionary:
				for key: String in equipped:
					if equipped[key] is String:
						_equipped[key] = equipped[key]
			_update_credits(inventory.data.get("credits", 0))
	else:
		_credits.get_child(0).text = "Log in to buy"


func _switch(category: String) -> void:
	_category = category
	for key: String in _tabs:
		_tabs[key].theme_type_variation = "AccentButton" if key == category else "GhostButton"
	for child in _grid.get_children():
		child.queue_free()
	for item: Dictionary in _items:
		if item.get("type") == category:
			_grid.add_child(_item_card(item))


func _item_card(item: Dictionary) -> PanelContainer:
	var slug := str(item.get("slug"))
	var card := AppTheme.card("Row")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := AppTheme.vbox(8)
	card.add_child(box)
	box.add_child(_swatch(slug))
	var name_label := AppTheme.label(str(item.get("name")), "", 20)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var row := AppTheme.hbox(8)
	row.add_child(AppTheme.pill(str(item.get("rarity", "common")).to_upper(), _rarity_color(str(item.get("rarity"))), Color.WHITE, 14))
	row.add_child(AppTheme.spacer())
	var price := int(item.get("price_credits", 0))
	row.add_child(AppTheme.label("Free" if price == 0 else "%d cr" % price, "", 18, AppTheme.MUTED))
	box.add_child(row)

	var actions := AppTheme.hbox(8)
	var preview := AppTheme.button("Try", "Ghost", func() -> void: _preview(slug), 44)
	actions.add_child(preview)
	var action: Button
	if _equipped.get(item.get("type")) == slug:
		action = AppTheme.button("Equipped", "Success", Callable(), 44)
		action.disabled = true
	elif _owned.has(slug):
		action = AppTheme.button("Equip", "Secondary", func() -> void: _equip(slug), 44)
	else:
		action = AppTheme.button("Buy", "Primary", func() -> void: _buy(slug, price), 44)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action)
	box.add_child(actions)
	return card


func _preview(slug: String) -> void:
	if _category == "board_theme":
		ui.game.board.set_board_theme(slug)
	else:
		ui.game.board.set_piece_skin(Ranks.WHITE, slug)
		ui.game.board.set_piece_skin(Ranks.BLACK, slug)


func _buy(slug: String, price: int) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen("auth", {"next": "shop"})
		return
	ui.confirm("Buy this for %d credits?" % price, "Buy", func() -> void: _purchase(slug), false)


func _purchase(slug: String) -> void:
	var res := await ApiManager.purchase(slug)
	if not res.ok:
		ui.toast(res.error, AppTheme.RED)
		return
	ui.toast("Unlocked and equipped!", AppTheme.MINT)
	await _load()
	_switch(_category)
	_preview(slug)


func _equip(slug: String) -> void:
	var res := await ApiManager.equip(slug)
	if not res.ok:
		ui.toast(res.error, AppTheme.RED)
		return
	await _load()
	_switch(_category)
	_preview(slug)


func _update_credits(amount: Variant) -> void:
	_credits.get_child(0).text = "%s credits" % AppTheme.num(amount)


func _rarity_color(rarity: String) -> Color:
	return {"common": AppTheme.MUTED, "rare": AppTheme.BLUE, "epic": AppTheme.PURPLE, "legendary": AppTheme.PINK}.get(rarity, AppTheme.MUTED)


## A strip of the item's key colours.
func _swatch(slug: String) -> HBoxContainer:
	var colors: Array = []
	if CosmeticLibrary.BOARD_THEMES.has(slug):
		var theme: Dictionary = CosmeticLibrary.BOARD_THEMES[slug]
		colors = [theme["frame"], theme["tile_a"], theme["tile_b"], theme["divider"]]
	elif CosmeticLibrary.PIECE_SKINS.has(slug):
		var skin: Dictionary = CosmeticLibrary.PIECE_SKINS[slug]
		colors = [skin["white"]["body"], skin["white"]["base"], skin["black"]["body"], skin["black"]["base"]]
	var strip := AppTheme.hbox(0)
	for color: Color in colors:
		var chip := ColorRect.new()
		chip.color = Color(color, 1.0)
		chip.custom_minimum_size = Vector2(0, 34)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(chip)
	return strip
