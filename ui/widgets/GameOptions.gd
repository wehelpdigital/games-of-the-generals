class_name GameOptions
extends VBoxContainer
## The powerup rules for the next game, chosen before every start (Play vs AI, Quick Match,
## Ranked, hosting or joining a room): powerups On or Off and, when on, Select (your own 5, picked
## right here) or Random (5 dealt from what you've unlocked). The last choice is remembered.
## Joining someone's room shows the host's rules instead (`fixed_mode`).
##
##     GameOptions.ask(ui, {"title": "Quick Match", "confirm": "Find match"}, func(mode: String) -> void:
##         GameSession.find_match(mode))

const SETTING := "powerup_mode"

var ui: UIRoot  ## For toasts; set by ask().

var _mode := PowerupLibrary.MODE_SELECT
var _last_on := PowerupLibrary.MODE_SELECT  # What "On" goes back to.
var _fixed := ""
var _picks: Array[String] = []
var _toggles: Dictionary = {}  # mode button key ("on", "off", "select", "random") -> Button
var _style_row: HBoxContainer
var _detail: VBoxContainer
var _count: Label
var _tiles: Dictionary = {}  # powerup id -> Button


## `mode`: the starting choice; `fixed_mode`: the host's rules when joining a room ("" = choose).
func _init(mode := PowerupLibrary.MODE_SELECT, fixed_mode := "") -> void:
	add_theme_constant_override("separation", 10)
	_fixed = fixed_mode
	_mode = fixed_mode if fixed_mode != "" else (mode if mode in PowerupLibrary.MODES else PowerupLibrary.MODE_SELECT)
	if _mode != PowerupLibrary.MODE_OFF:
		_last_on = _mode
	_picks = GameSession.powerups.active_slots()
	_build()


func mode() -> String:
	return _mode


func picks() -> Array[String]:
	return _picks.duplicate()


## "" when the game can start, otherwise what's missing.
func problem() -> String:
	var need := GameSession.powerups.hand_size()
	if _mode == PowerupLibrary.MODE_SELECT and _picks.size() != need:
		return "Pick %d powerups first (%d picked)." % [need, _picks.size()]
	return ""


## Opens the choice as a dialog. `opts`: title, subtitle?, confirm (button text), fixed_mode?,
## extra? (a Control shown above the rules, e.g. a password field) and check? (a Callable
## returning "" or a problem, run before starting). `on_confirm(mode)` runs once the player's
## Select picks are saved.
static func ask(ui: UIRoot, opts: Dictionary, on_confirm: Callable) -> void:
	var card := AppTheme.card()
	var box := AppTheme.vbox(14)
	card.add_child(box)
	box.add_child(ProfileUi.heading(str(opts.get("title", "New game")), 30))
	if str(opts.get("subtitle", "")) != "":
		box.add_child(ProfileUi.wrap(str(opts["subtitle"]), 17, AppTheme.MUTED))
	if opts.get("extra") is Control:
		box.add_child(opts["extra"])
	var options := GameOptions.new(str(ui.setting(SETTING, PowerupLibrary.MODE_SELECT)), str(opts.get("fixed_mode", "")))
	options.ui = ui
	box.add_child(options)
	var row := AppTheme.hbox(12)
	var cancel := AppTheme.button("Cancel", "Ghost", ui.close_dialog, 54)
	var go := AppTheme.button(str(opts.get("confirm", "Start")), "Primary", Callable(), 54)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(go)
	box.add_child(row)
	var check: Callable = opts.get("check", Callable())
	go.pressed.connect(func() -> void:
		var issue: String = check.call() if check.is_valid() else ""
		if issue == "":
			issue = options.problem()
		if issue != "":
			ui.toast(issue, AppTheme.BLUE)
			return
		go.disabled = true
		if options.mode() == PowerupLibrary.MODE_SELECT:
			var saved: String = await GameSession.powerups.save(options.picks())
			if saved != "":
				go.disabled = false
				ui.toast(saved, AppTheme.RED)
				return
		if str(opts.get("fixed_mode", "")) == "":
			ui.set_setting(SETTING, options.mode())
		ui.close_dialog()
		on_confirm.call(options.mode()))
	ProfileUi.overlay(ui, card, 600)


## A small pill naming a game's powerup rules (room and lobby lists).
static func mode_pill(mode: String, size := 13, short := false) -> PanelContainer:
	match mode:
		PowerupLibrary.MODE_OFF:
			return AppTheme.pill("NO POWERUPS", AppTheme.MUTED, Color.WHITE, size)
		PowerupLibrary.MODE_RANDOM:
			return AppTheme.pill("RANDOM 5" if short else "RANDOM POWERUPS", AppTheme.PINK, Color.WHITE, size)
	return AppTheme.pill("PICK 5" if short else "PICK 5 POWERUPS", AppTheme.PURPLE, Color.WHITE, size)


func _build() -> void:
	ProfileUi.clear(self)
	_toggles.clear()
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Powerups", AppTheme.PURPLE))
	head.add_child(AppTheme.spacer())
	if _fixed != "":
		head.add_child(mode_pill(_fixed))
	add_child(head)
	if _fixed == "":
		var on_off := AppTheme.hbox(8)
		on_off.add_child(_toggle("on", "On", "Tricks and twists", _set_on.bind(true)))
		on_off.add_child(_toggle("off", "Off", "Classic Salpakan", _set_on.bind(false)))
		add_child(on_off)
		_style_row = AppTheme.hbox(8)
		_style_row.add_child(_toggle("select", "Select", "Pick your 5", _set_mode.bind(PowerupLibrary.MODE_SELECT)))
		_style_row.add_child(_toggle("random", "Random", "Get 5 at random", _set_mode.bind(PowerupLibrary.MODE_RANDOM)))
		add_child(_style_row)
	_detail = AppTheme.vbox(8)
	add_child(_detail)
	_refresh()


func _toggle(key: String, title: String, sub: String, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 64
	b.pressed.connect(action)
	var words := AppTheme.vbox(0)
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := AppTheme.label(title, "", 21)
	big.add_theme_font_override("font", AppTheme.heading_font())
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(big)
	var small := AppTheme.label(sub, "", 13)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(small)
	b.add_child(words)
	_toggles[key] = b
	return b


func _style_toggle(key: String, selected: bool, color: Color) -> void:
	var b: Button = _toggles.get(key)
	if b == null:
		return
	var bg := color if selected else Color.WHITE
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var tint := bg.lightened(0.12) if state == "hover" and not selected else bg
		b.add_theme_stylebox_override(state, ProfileUi.candy(tint, selected and state == "pressed"))
	var words: VBoxContainer = b.get_child(0)
	for l: Label in words.get_children():
		l.add_theme_color_override("font_color", Color.WHITE if selected else AppTheme.INK)


func _set_on(on: bool) -> void:
	_mode = _last_on if on else PowerupLibrary.MODE_OFF
	_refresh()


func _set_mode(mode: String) -> void:
	_mode = mode
	_last_on = mode
	_refresh()


func _refresh() -> void:
	var on := _mode != PowerupLibrary.MODE_OFF
	_style_toggle("on", on, AppTheme.MINT)
	_style_toggle("off", not on, AppTheme.INK)
	_style_toggle("select", _mode == PowerupLibrary.MODE_SELECT, AppTheme.PURPLE)
	_style_toggle("random", _mode == PowerupLibrary.MODE_RANDOM, AppTheme.PINK)
	if _style_row:
		_style_row.visible = on
	ProfileUi.clear(_detail)
	_tiles.clear()
	_count = null
	match _mode:
		PowerupLibrary.MODE_OFF:
			_detail.add_child(ProfileUi.wrap("Classic Salpakan: no powerups for either side. Pure ranks and nerve.", 16, AppTheme.MUTED))
		PowerupLibrary.MODE_RANDOM:
			_detail.add_child(_random_row())
			var unlocked := GameSession.powerups.unlocked_ids().size()
			_detail.add_child(ProfileUi.wrap("You'll be dealt %d at random from the %d powerups you've unlocked. Your opponent gets their own." % [PowerupLibrary.MAX_SLOTS, unlocked], 16, AppTheme.MUTED))
		_:
			_detail.add_child(_picker())


func _random_row() -> HBoxContainer:
	var row := AppTheme.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in PowerupLibrary.MAX_SLOTS:
		var mystery := PanelContainer.new()
		mystery.custom_minimum_size = Vector2(54, 54)
		mystery.add_theme_stylebox_override("panel", ProfileUi.box(AppTheme.PINK.lightened(0.15 * (i % 2)), 16, 3))
		var q := AppTheme.label("?", "", 28, Color.WHITE)
		q.add_theme_font_override("font", AppTheme.heading_font())
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mystery.add_child(q)
		row.add_child(mystery)
	return row


## Select: every unlocked powerup as a tap-to-toggle tile; exactly 5 must be lit.
func _picker() -> VBoxContainer:
	var box := AppTheme.vbox(8)
	var top := AppTheme.hbox(8)
	top.add_child(ProfileUi.wrap("Tap to choose your %d." % PowerupLibrary.MAX_SLOTS, 16, AppTheme.MUTED))
	top.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = AppTheme.label("", "", 16)
	_count.add_theme_font_override("font", AppTheme.heading_font())
	top.add_child(_count)
	box.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in GameSession.powerups.unlocked_ids():
		var tile := _tile(id)
		_tiles[id] = tile
		grid.add_child(tile)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(64.0 * ceilf(_tiles.size() / 2.0) + 8.0 * (ceilf(_tiles.size() / 2.0) - 1.0), 280.0)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(grid)
	box.add_child(scroll)
	_paint_tiles()
	return box


func _tile(id: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 64)
	b.icon = PowerupLibrary.icon(id)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	b.add_theme_constant_override("h_separation", 8)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = PowerupLibrary.display_name(id)
	b.clip_text = true
	b.add_theme_font_override("font", AppTheme.heading_font())
	b.add_theme_font_size_override("font_size", 16)
	b.tooltip_text = str(PowerupLibrary.info(id).get("desc", ""))
	b.pressed.connect(_toggle_pick.bind(id))
	return b


func _toggle_pick(id: String) -> void:
	if _picks.has(id):
		_picks.erase(id)
	elif _picks.size() >= GameSession.powerups.hand_size():
		if ui:
			ui.toast("You bring %d. Tap a lit one to drop it first." % GameSession.powerups.hand_size(), AppTheme.BLUE)
		return
	else:
		_picks.append(id)
	_paint_tiles()


func _paint_tiles() -> void:
	for id: String in _tiles:
		var b: Button = _tiles[id]
		var picked := _picks.has(id)
		var color := PowerupLibrary.color(id)
		var bg := Color.WHITE.lerp(color, 0.32) if picked else Color.WHITE
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var tint := bg.lightened(0.15) if state == "hover" else bg
			b.add_theme_stylebox_override(state, ProfileUi.box(tint, 16, 4 if picked else 2, color.darkened(0.3) if picked else Color(AppTheme.INK, 0.35)))
		b.add_theme_color_override("font_color", AppTheme.INK)
		b.add_theme_color_override("font_hover_color", AppTheme.INK)
		b.add_theme_color_override("font_pressed_color", AppTheme.INK)
		b.modulate = Color.WHITE if picked or _picks.size() < GameSession.powerups.hand_size() else Color(1, 1, 1, 0.6)
	if _count:
		var need := GameSession.powerups.hand_size()
		var full := _picks.size() == need
		_count.text = "%d / %d" % [_picks.size(), need]
		_count.add_theme_color_override("font_color", AppTheme.MINT if full else AppTheme.PINK)
