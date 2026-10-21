extends PanelContainer
## Dashboard card (DashboardRegistry "main"): the player's hand of 5 for Select games (Random
## games deal 5 instead), fanned out as cards, with a way to the powerup binder.

var _ui: UIRoot
var _box: VBoxContainer
var _fan: Control


func _init() -> void:
	theme_type_variation = "CardPanel"
	_box = AppTheme.vbox(10)
	add_child(_box)


func setup(dashboard: Screen) -> void:
	_ui = dashboard.ui
	GameSession.powerups.changed.connect(refresh)
	refresh()


func refresh() -> void:
	ProfileUi.clear(_box)
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Your hand", AppTheme.PURPLE))
	head.add_child(AppTheme.spacer())
	head.add_child(ProfileUi.small_button("Change", "Ghost", _open_library, 36))
	_box.add_child(head)
	_fan = Control.new()
	_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fan.resized.connect(_spread)
	for id in GameSession.powerups.active_slots():
		var card := PowerupCard.new(id, 70)
		card.tooltip_text = "%s\n%s" % [PowerupLibrary.display_name(id), PowerupLibrary.info(id).get("desc", "")]
		card.pressed.connect(func(_c: PowerupCard) -> void: _open_library())
		_fan.add_child(card)
	_box.add_child(_fan)
	_spread()
	var note := AppTheme.label("Your 5 for Select games. All %d cards are open to everyone." % PowerupLibrary.ids().size(), "MutedLabel", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Wraps instead of widening the dashboard's middle column.
	_box.add_child(note)


## Fans the cards out like a hand held up: overlapping, turned outwards, the outer ones lower.
func _spread() -> void:
	var cards := _fan.get_children()
	if cards.is_empty():
		return
	var room := _fan.size.x if _fan.size.x > 0.0 else 320.0
	var w := floorf(clampf(room / 3.9, 54.0, 92.0))
	var h := roundf(w * PowerupCard.ASPECT)
	var step := w * 0.64
	var mid := (cards.size() - 1) / 2.0
	_fan.custom_minimum_size.y = h + w * 0.32
	for i in cards.size():
		var card: PowerupCard = cards[i]
		var off := i - mid
		card.set_card_width(w)
		card.pivot_offset = Vector2(w / 2.0, h)
		card.position = Vector2(roundf(room / 2.0 - w / 2.0 + off * step), roundf(absf(off) * absf(off) * w * 0.05 + 4.0))
		card.rotation = deg_to_rad(off * 6.0)


func _open_library() -> void:
	if _ui:
		_ui.show_screen("powerups")
