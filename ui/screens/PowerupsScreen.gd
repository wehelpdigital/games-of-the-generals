extends Screen
## The powerup library: all 24 powerups with what they do and the rank that unlocks them. The
## player picks exactly 5: their hand in "Select" games (online and against the AI; "Random"
## games deal 5 instead, and some games have powerups off). Logged out, only the rank-0 powerups
## unlock.

const CREDIT := "Powerup glyphs by Lorc, Delapouite and DarkZaitzev, game-icons.net (CC BY 3.0)."

var _page: Dictionary
var _body: VBoxContainer
var _slots_row: GridContainer
var _status: Label
var _grid: GridContainer
var _selected: Array[String] = []
var _portrait := false


func _ready() -> void:
	_page = ProfileUi.page(self, "Powerups", func() -> void: ui.home(), 900)
	_body = _page["body"]
	get_viewport().size_changed.connect(_layout)
	GameSession.powerups.changed.connect(_on_loadout_changed)


func _on_loadout_changed() -> void:
	if visible:
		_render()


func open(_args: Dictionary) -> void:
	_selected = GameSession.powerups.active_slots()
	_layout()
	_render()
	AppTheme.pop_in(_page["card"])
	if ApiManager.is_logged_in():
		await GameSession.powerups.fetch()
		if visible:
			_selected = GameSession.powerups.active_slots()
			_render()


func _layout() -> void:
	_portrait = ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)
	if _grid:
		_grid.columns = 1 if ProfileUi.narrow else (2 if _portrait else 3)
	if _slots_row:
		_slots_row.columns = 2 if _portrait else PowerupLibrary.MAX_SLOTS


func _render() -> void:
	ProfileUi.clear(_body)
	var intro := "Pick your 5 for Select games (Random games deal you 5, and some games are played with powerups off). Each works once per match, on your turn (two per turn, tops)."
	if not ApiManager.is_logged_in():
		intro += " Log in and rank up to unlock more."
	_body.add_child(ProfileUi.wrap(intro, 16, AppTheme.MUTED))

	var loadout := AppTheme.card("Row")
	var box := AppTheme.vbox(8)
	loadout.add_child(box)
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Your loadout", AppTheme.PURPLE))
	head.add_child(AppTheme.spacer())
	_status = AppTheme.label("", "MutedLabel", 15)
	head.add_child(_status)
	box.add_child(head)
	_slots_row = GridContainer.new()
	_slots_row.columns = 2 if _portrait else PowerupLibrary.MAX_SLOTS
	_slots_row.add_theme_constant_override("h_separation", 8)
	_slots_row.add_theme_constant_override("v_separation", 8)
	box.add_child(_slots_row)
	var actions := AppTheme.hbox(8)
	actions.add_child(AppTheme.spacer())
	actions.add_child(ProfileUi.small_button("Defaults", "Ghost", _defaults, 42))
	actions.add_child(ProfileUi.small_button("Save loadout", "Primary", _save, 42))
	box.add_child(actions)
	_body.add_child(loadout)
	_fill_slots()

	_grid = GridContainer.new()
	_grid.columns = 1 if ProfileUi.narrow else (2 if _portrait else 3)
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in PowerupLibrary.ids():
		_grid.add_child(_card(id))
	_body.add_child(_grid)
	_body.add_child(ProfileUi.wrap(CREDIT, 13, AppTheme.MUTED))


func _fill_slots() -> void:
	ProfileUi.clear(_slots_row)
	for i in PowerupLibrary.MAX_SLOTS:
		var slot := AppTheme.card("Row")
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := AppTheme.hbox(8)
		slot.add_child(row)
		if i < _selected.size():
			var id := _selected[i]
			row.add_child(_icon(id, 40))
			var name := AppTheme.label(PowerupLibrary.display_name(id), "", 15)
			name.add_theme_font_override("font", AppTheme.heading_font())
			name.clip_text = true
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
		else:
			var empty := AppTheme.label("Empty slot", "MutedLabel", 15)
			empty.custom_minimum_size.y = 44
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(empty)
		_slots_row.add_child(slot)
	_status.text = "%d / %d picked" % [_selected.size(), PowerupLibrary.MAX_SLOTS]


func _card(id: String) -> Button:
	var info := PowerupLibrary.info(id)
	var unlocked := GameSession.powerups.is_unlocked(id)
	var picked := _selected.has(id)
	var color := PowerupLibrary.color(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 150)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var bg := Color.WHITE.lerp(color, 0.22 if picked else 0.08)
		if state == "hover":
			bg = bg.lightened(0.25)
		if not unlocked:
			bg = Color("ece9f2")
		b.add_theme_stylebox_override(state, ProfileUi.box(bg, 18, 5 if picked else 3, color.darkened(0.25) if picked else AppTheme.INK))
	b.pressed.connect(_toggle.bind(id))
	var box := AppTheme.vbox(6)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	b.add_child(box)
	var top := AppTheme.hbox(8)
	top.add_child(_icon(id, 52))
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label(str(info["name"]), "", 19)
	title.add_theme_font_override("font", AppTheme.heading_font())
	words.add_child(title)
	var tags := AppTheme.hbox(4)
	tags.add_child(AppTheme.pill(PowerupLibrary.KIND_LABELS[info["kind"]], color.darkened(0.15), Color.WHITE, 12))
	if info["consumes_turn"]:
		tags.add_child(AppTheme.pill("Uses turn", AppTheme.MUTED, Color.WHITE, 12))
	if picked:
		tags.add_child(AppTheme.pill("Picked", AppTheme.MINT, Color.WHITE, 12))
	words.add_child(tags)
	top.add_child(words)
	box.add_child(top)
	var desc := AppTheme.label(str(info["desc"]), "", 14, AppTheme.INK if unlocked else AppTheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	if not unlocked:
		var lock := AppTheme.hbox(6)
		lock.add_child(RankInsignia.new(int(info["tier"]), 26))
		lock.add_child(AppTheme.label("Unlocks at %s" % PlayerRanks.name_of(int(info["tier"])), "", 14, AppTheme.MUTED))
		box.add_child(lock)
		b.modulate = Color(1, 1, 1, 0.85)
	return b


func _icon(id: String, size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = PowerupLibrary.icon(id)
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _toggle(id: String) -> void:
	if _selected.has(id):
		_selected.erase(id)
	elif not GameSession.powerups.is_unlocked(id):
		var tier := PowerupLibrary.unlock_tier(id)
		ui.toast("%s unlocks at %s." % [PowerupLibrary.display_name(id), PlayerRanks.name_of(tier)], AppTheme.BLUE)
		return
	elif _selected.size() >= PowerupLibrary.MAX_SLOTS:
		ui.toast("You can bring %d. Tap a picked one to drop it first." % PowerupLibrary.MAX_SLOTS, AppTheme.BLUE)
		return
	else:
		_selected.append(id)
	var scroll: ScrollContainer = _page["scroll"]
	var keep := scroll.scroll_vertical
	_render()
	await get_tree().process_frame
	scroll.scroll_vertical = keep


func _defaults() -> void:
	_selected = PowerupLibrary.DEFAULT_LOADOUT.duplicate()
	_render()


func _save() -> void:
	var problem: String = await GameSession.powerups.save(_selected)
	if problem != "":
		ui.toast(problem, AppTheme.RED)
	else:
		ui.toast("Loadout saved!", AppTheme.MINT)
