extends PanelContainer
## Dashboard card (DashboardRegistry "main"): the 3 powerups the player brings into matches, with
## a button to the powerup library.

var _ui: UIRoot
var _box: VBoxContainer


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
	head.add_child(ProfileUi.eyebrow("Powerups", AppTheme.PURPLE))
	head.add_child(AppTheme.spacer())
	head.add_child(ProfileUi.small_button("Change", "Ghost", _open_library, 36))
	_box.add_child(head)
	var row := AppTheme.hbox(10)
	for id in GameSession.powerups.active_slots():
		var slot := AppTheme.vbox(4)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.texture = PowerupLibrary.icon(id)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.tooltip_text = str(PowerupLibrary.info(id).get("desc", ""))
		slot.add_child(icon)
		var name := AppTheme.label(PowerupLibrary.display_name(id), "", 14)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(name)
		row.add_child(slot)
	_box.add_child(row)
	var unlocked := 0
	for id in PowerupLibrary.ids():
		if GameSession.powerups.is_unlocked(id):
			unlocked += 1
	_box.add_child(AppTheme.label("%d of %d unlocked. Rank up for more." % [unlocked, PowerupLibrary.ids().size()], "MutedLabel", 14))


func _open_library() -> void:
	if _ui:
		_ui.show_screen("powerups")
