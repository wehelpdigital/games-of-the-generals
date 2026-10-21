extends Screen
## The powerup binder: every card in the game, all open to everyone, filtered by type and rarity.
## Tap a card to see it big (tap it again to flip it over) and add it to or drop it from your hand
## of 5: the cards you bring to "Select" games (online and against the AI; "Random" games deal 5
## instead, and some games have powerups off).

const GAP := 10.0
const FILTER_KINDS := [["all", "All types"], ["clock", "Clock"], ["intel", "Intel"], ["tactics", "Tactics"], ["trap", "Trap"], ["support", "Support"]]
const FILTER_RARITIES := [["any", "Any rarity"], ["common", "Common"], ["rare", "Rare"], ["epic", "Epic"], ["legendary", "Legendary"]]

var _page: Dictionary
var _body: VBoxContainer
var _tray: HBoxContainer
var _status: Label
var _shown_label: Label
var _grid: GridContainer
var _kind_tabs: Dictionary
var _rarity_tabs: Dictionary
var _cards: Dictionary = {}  # id -> PowerupCard in the binder
var _selected: Array[String] = []
var _kind := "all"
var _rarity := "any"
var _card_width := 0.0
var _width := 0.0  # The body width the cards were last sized for.


func _ready() -> void:
	_page = ProfileUi.page(self, "Powerups", func() -> void: ui.home(), 1000)
	_body = _page["body"]
	get_viewport().size_changed.connect(_layout)
	GameSession.powerups.changed.connect(_on_loadout_changed)
	_build()


func _on_loadout_changed() -> void:
	if visible:
		_selected = GameSession.powerups.active_slots()
		_refresh()


func open(_args: Dictionary) -> void:
	_selected = GameSession.powerups.active_slots()
	_layout()
	_refresh()
	AppTheme.pop_in(_page["card"])
	if ApiManager.is_logged_in():
		await GameSession.powerups.fetch()
		if visible:
			_selected = GameSession.powerups.active_slots()
			_refresh()


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)
	_size_cards.call_deferred()


func _build() -> void:
	_body.add_child(ProfileUi.wrap("Every card is open to everyone: build the hand of 5 you bring to Select games. Random games deal you 5, and some games are played with powerups off. Each card works once per match, on your turn (two per turn, tops).", 16, AppTheme.MUTED))

	var hand := AppTheme.card("Row")
	var box := AppTheme.vbox(10)
	hand.add_child(box)
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Your hand", AppTheme.PURPLE))
	head.add_child(AppTheme.spacer())
	_status = AppTheme.label("", "MutedLabel", 15)
	head.add_child(_status)
	box.add_child(head)
	_tray = AppTheme.hbox(int(GAP) - 2)
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_tray)
	var actions := HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_END
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	actions.add_child(ProfileUi.small_button("Defaults", "Ghost", _defaults, 42))
	actions.add_child(ProfileUi.small_button("Deal 5", "Ghost", _deal, 42))
	actions.add_child(ProfileUi.small_button("Save hand", "Primary", _save, 42))
	box.add_child(actions)
	_body.add_child(hand)

	_kind_tabs = ProfileUi.tabs(_body, FILTER_KINDS, _filter_kind)
	_rarity_tabs = ProfileUi.tabs(_body, FILTER_RARITIES, _filter_rarity)
	_shown_label = AppTheme.label("", "MutedLabel", 15)
	_body.add_child(_shown_label)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP) + 4)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for id in PowerupLibrary.ids():
		var card := PowerupCard.new(id, 160)
		card.pressed.connect(func(c: PowerupCard) -> void: _inspect(c.id))
		_cards[id] = card
		_grid.add_child(card)
	_body.add_child(_grid)
	_body.add_child(ProfileUi.gap(8))


## Card sizes follow the page: two per row on phones, up to six on wide screens.
func _size_cards() -> void:
	var width := _content_width()
	if is_equal_approx(width, _width):
		return
	_width = width
	var columns := clampi(int((width + GAP) / (170.0 + GAP)), 2, 6)
	var card_width := floorf(minf((width - GAP * (columns - 1)) / columns, 210.0))
	_grid.columns = columns
	if not is_equal_approx(card_width, _card_width):
		_card_width = card_width
		for card: PowerupCard in _cards.values():
			card.set_card_width(card_width)
	_fill_tray(width)


## The body's width, from the page's own size (not from the body, which the cards would hold wide).
func _content_width() -> float:
	var card: PanelContainer = _page["card"]
	var style := card.get_theme_stylebox("panel")
	var width := card.custom_minimum_size.x if card.custom_minimum_size.x > 0.0 else float(_page["max_width"])
	return floorf(width - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT) - 20.0)  # 20: the scroll bar.


func _refresh() -> void:
	for id: String in _cards:
		var card: PowerupCard = _cards[id]
		card.selected = _selected.has(id)
		card.visible = (_kind == "all" or PowerupLibrary.kind(id) == _kind) and (_rarity == "any" or PowerupLibrary.rarity(id) == _rarity)
	var shown := _cards.values().filter(func(c: PowerupCard) -> bool: return c.visible).size()
	_shown_label.text = "Showing %d of %d cards" % [shown, _cards.size()]
	ProfileUi.select_tab(_kind_tabs, _kind)
	ProfileUi.select_tab(_rarity_tabs, _rarity)
	_fill_tray(_content_width())


func _fill_tray(width: float) -> void:
	ProfileUi.clear(_tray)
	var slot_width := floorf(clampf((width - 30.0 - (GAP - 2.0) * 4.0) / 5.0, 44.0, 124.0))  # 30: the tray panel padding.
	for i in PowerupLibrary.MAX_SLOTS:
		if i < _selected.size():
			var card := PowerupCard.new(_selected[i], slot_width)
			card.pressed.connect(func(c: PowerupCard) -> void: _inspect(c.id))
			_tray.add_child(card)
		else:
			_tray.add_child(_empty_slot(slot_width))
	_status.text = "%d / %d picked" % [_selected.size(), PowerupLibrary.MAX_SLOTS]


func _empty_slot(width: float) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(width, roundf(width * PowerupCard.ASPECT))
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := ProfileUi.box(Color(AppTheme.PURPLE, 0.08), int(width * 0.075), 2, Color(AppTheme.PURPLE, 0.45))
	slot.add_theme_stylebox_override("panel", style)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plus := AppTheme.label("+", "", int(width * 0.4), Color(AppTheme.PURPLE, 0.55))
	plus.add_theme_font_override("font", AppTheme.heading_font())
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(plus)
	return slot


func _filter_kind(kind: String) -> void:
	_kind = kind
	_refresh()


func _filter_rarity(rarity: String) -> void:
	_rarity = rarity
	_refresh()


## The card big: tap it to flip it over; add it to the hand or drop it.
func _inspect(id: String) -> void:
	var view := get_viewport().get_visible_rect().size
	var box := AppTheme.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var card := PowerupCard.new(id, floorf(clampf(minf(minf(view.x, 520.0) * 0.72, (view.y - 210.0) / PowerupCard.ASPECT), 190.0, 340.0)))
	card.hover_lift = false
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pressed.connect(func(c: PowerupCard) -> void: c.flip(not c.face_down))
	box.add_child(card)
	var hint := AppTheme.pill("Tap the card to flip it over", AppTheme.INK, Color.WHITE, 15)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hint)
	var row := AppTheme.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var picked := _selected.has(id)
	row.add_child(ProfileUi.small_button("Drop from hand" if picked else "Add to hand", "Ghost" if picked else "Primary", _pick_from_viewer.bind(id), 48))
	row.add_child(ProfileUi.small_button("Close", "Ghost", ui.close_dialog, 48))
	box.add_child(row)
	var backdrop := Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	ProfileUi.overlay(ui, box, 520, backdrop)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		ui.close_dialog()


func _pick_from_viewer(id: String) -> void:
	ui.close_dialog()
	_toggle(id)


func _toggle(id: String) -> void:
	if _selected.has(id):
		_selected.erase(id)
	elif _selected.size() >= PowerupLibrary.MAX_SLOTS:
		ui.toast("Your hand holds %d. Drop one first." % PowerupLibrary.MAX_SLOTS, AppTheme.BLUE)
		return
	else:
		_selected.append(id)
		AppTheme.pop_in(_tray)
	_refresh()


func _defaults() -> void:
	_selected = PowerupLibrary.DEFAULT_LOADOUT.duplicate()
	_refresh()


func _deal() -> void:
	_selected = PowerupLibrary.deal()
	_refresh()


func _save() -> void:
	var problem: String = await GameSession.powerups.save(_selected)
	if problem != "":
		ui.toast(problem, AppTheme.RED)
	else:
		ui.toast("Hand saved!", AppTheme.MINT)
