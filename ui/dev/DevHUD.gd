class_name DevHUD
extends CanvasLayer
## Phase 1 developer HUD, built in code: login/register, offline practice, online matchmaking,
## setup controls, cosmetic previews and match status. The polished auth modal, leaderboard and
## shop screens replace it in Phase 2; everything here calls the same autoload APIs they will.

signal ready_pressed
signal shuffle_pressed
signal board_theme_selected(slug: String)
signal piece_skin_selected(slug: String)

const PANEL_COLOR := Color(0.055, 0.065, 0.085, 0.88)
const ACCENT := Color("e6c06a")
const TOUCH_HEIGHT := 40.0

var _panel: PanelContainer
var _body: VBoxContainer
var _collapse: Button
var _status: Label
var _hint: Label
var _logged_out: VBoxContainer
var _logged_in: VBoxContainer
var _login_field: LineEdit
var _email_field: LineEdit
var _password_field: LineEdit
var _user_label: Label
var _find_button: Button
var _shuffle_button: Button
var _ready_button: Button
var _resign_button: Button
var _busy_buttons: Array[Button] = []


func _ready() -> void:
	_build()
	ApiManager.auth_changed.connect(func(_logged_in: bool) -> void: _refresh_account())
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: _refresh_account())
	GameSession.status_message.connect(_set_status)
	GameSession.match_loaded.connect(func(_view: Dictionary) -> void: _refresh_match_buttons())
	GameSession.turn_changed.connect(_refresh_match_buttons)
	GameSession.game_over.connect(_on_game_over)
	_refresh_account()
	_refresh_match_buttons()
	_set_status("Practice offline, or log in to find an online match.")


func show_piece_hint(piece: Piece3D) -> void:
	if piece == null:
		_hint.text = ""
	elif piece.rank != "":
		_hint.text = "%s  ·  %s" % [Ranks.display_name(piece.rank), "yours" if piece.side == GameSession.my_side() else "revealed"]
	else:
		_hint.text = "Unknown enemy piece"


# --- Actions ----------------------------------------------------------------------------------

func _on_login() -> void:
	_set_busy(true)
	var res := await ApiManager.login(_login_field.text.strip_edges(), _password_field.text)
	_set_busy(false)
	_set_status("Logged in." if res.ok else res.error)


func _on_register() -> void:
	_set_busy(true)
	var res := await ApiManager.register(_login_field.text.strip_edges(), _email_field.text.strip_edges(),
		_password_field.text, _password_field.text)
	_set_busy(false)
	_set_status("Account created. Welcome, General." if res.ok else res.error)


func _on_logout() -> void:
	GameSession.leave()
	await ApiManager.logout()
	_set_status("Logged out.")


func _on_game_over(info: Dictionary) -> void:
	var reason := str(info.get("end_reason", "")).replace("_", " ")
	_set_status(("VICTORY" if info.get("you_won", false) else "DEFEAT") + "  ·  " + reason)
	_refresh_match_buttons()


# --- State ------------------------------------------------------------------------------------

func _refresh_account() -> void:
	var logged_in := ApiManager.is_logged_in()
	_logged_out.visible = not logged_in
	_logged_in.visible = logged_in
	_find_button.disabled = not logged_in
	if logged_in:
		var user := ApiManager.user
		_user_label.text = "%s  ·  ELO %s  ·  %s credits" % [user.get("username", "?"), user.get("elo", "?"), user.get("credits", "?")]


func _refresh_match_buttons() -> void:
	var status := GameSession.status()
	var arranging := GameSession.has_match() and status in ["waiting", "setup"]
	_shuffle_button.disabled = not arranging
	_ready_button.disabled = not (GameSession.has_match() and status == "setup")
	_resign_button.disabled = not (GameSession.has_match() and status in ["waiting", "setup", "active"])


func _set_status(text: String) -> void:
	_status.text = text


func _set_busy(busy: bool) -> void:
	for button in _busy_buttons:
		button.disabled = busy


# --- Construction -----------------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks reach the 3D board.
	root.theme = _make_theme()
	add_child(root)

	# Status banner, top centre.
	var banner := PanelContainer.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", ACCENT)
	banner.add_child(_status)
	root.add_child(banner)

	# Hovered piece, bottom centre.
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	root.add_child(_hint)

	# Control panel, top left.
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.custom_minimum_size = Vector2(290, 0)
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "GAME OF THE GENERALS"
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_collapse = _button("–", _toggle_collapse)
	_collapse.custom_minimum_size = Vector2(TOUCH_HEIGHT, TOUCH_HEIGHT)
	header.add_child(_collapse)
	column.add_child(header)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	column.add_child(_body)

	# Account
	_logged_out = VBoxContainer.new()
	_login_field = _field("Username (or email to log in)")
	_email_field = _field("Email (register only)")
	_password_field = _field("Password (8+ characters)")
	_password_field.secret = true
	_password_field.text_submitted.connect(func(_t: String) -> void: _on_login())
	for field in [_login_field, _email_field, _password_field]:
		_logged_out.add_child(field)
	var login_row := _row([_button("Log in", _on_login), _button("Register", _on_register)])
	_busy_buttons.append_array([login_row.get_child(0), login_row.get_child(1)])
	_logged_out.add_child(login_row)
	_body.add_child(_logged_out)

	_logged_in = VBoxContainer.new()
	_user_label = Label.new()
	_user_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_logged_in.add_child(_user_label)
	_logged_in.add_child(_button("Log out", _on_logout))
	_body.add_child(_logged_in)

	_body.add_child(HSeparator.new())

	# Play
	_find_button = _button("Find match", GameSession.find_match)
	_body.add_child(_row([_button("Practice offline", GameSession.start_practice), _find_button]))
	_shuffle_button = _button("Shuffle", func() -> void: shuffle_pressed.emit())
	_ready_button = _button("Ready", func() -> void: ready_pressed.emit())
	_resign_button = _button("Resign", GameSession.resign)
	_body.add_child(_row([_shuffle_button, _ready_button, _resign_button]))

	_body.add_child(HSeparator.new())

	# Cosmetic previews (local only; buying/equipping goes through the shop API).
	_body.add_child(_option("Board", CosmeticLibrary.BOARD_THEMES, func(slug: String) -> void: board_theme_selected.emit(slug)))
	_body.add_child(_option("Pieces", CosmeticLibrary.PIECE_SKINS, func(slug: String) -> void: piece_skin_selected.emit(slug)))


func _toggle_collapse() -> void:
	_body.visible = not _body.visible
	_collapse.text = "–" if _body.visible else "+"
	_panel.reset_size()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = TOUCH_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func _field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = TOUCH_HEIGHT
	return field


func _row(controls: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for control: Control in controls:
		row.add_child(control)
	return row


func _option(label_text: String, catalog: Dictionary, on_pick: Callable) -> HBoxContainer:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 60
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = TOUCH_HEIGHT
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slugs: Array = catalog.keys()
	for slug: String in slugs:
		picker.add_item(catalog[slug]["name"])
	picker.item_selected.connect(func(index: int) -> void: on_pick.call(slugs[index]))
	return _row([label, picker])


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_COLOR
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(12)
	panel.border_color = Color(ACCENT, 0.35)
	panel.set_border_width_all(1)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme
