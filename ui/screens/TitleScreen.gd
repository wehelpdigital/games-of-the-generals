extends Screen
## Title: logo, the four ways to play, and the account chip. The 3D board orbits behind it.

const WIDE := 1140.0  # From this width the guest showcase floats bottom-left; below, it joins the column.

var _account: HBoxContainer
var _logo: GameLogo
var _tags: HBoxContainer
var _column: VBoxContainer
var _second: Button  # "Shop" for players, "Sign up free" for guests.
var _showcase: FeatureShowcase
var _frame: Control  # Everything but the backdrop; scaled up on phones (ProfileUi.fit).
var _float_box: VBoxContainer  # Bottom-left home of the guest showcase on wide screens.


func _ready() -> void:
	add_child(AppTheme.backdrop_glow(0.85))
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var column := AppTheme.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column = column

	_logo = GameLogo.new(240.0)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_logo)
	_tags = AppTheme.hbox()
	_tags.alignment = BoxContainer.ALIGNMENT_CENTER
	_tags.add_child(AppTheme.pill("3D STRATEGY", AppTheme.BLUE))
	_tags.add_child(AppTheme.pill("ONLINE + AI", AppTheme.PURPLE))
	column.add_child(_tags)

	column.add_child(_gap(10))
	column.add_child(AppTheme.button("Play vs AI", "Primary", func() -> void: ui.show_screen("ai_setup"), 64))
	column.add_child(AppTheme.button("Play Online", "Secondary", func() -> void: ui.require_login("lobby"), 64))
	var row := AppTheme.hbox(12)
	var ranks := AppTheme.button("Leaderboard", "Accent", func() -> void: ui.show_screen("leaderboard"))
	_second = AppTheme.button("Shop", "Success", _on_second)
	ranks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ranks)
	row.add_child(_second)
	column.add_child(row)
	if not (OS.has_feature("web") or OS.has_feature("mobile")):
		column.add_child(AppTheme.button("Quit", "Ghost", func() -> void: get_tree().quit(), 48))
	_frame.add_child(AppTheme.centered(column, 420))

	# Guests don't get the shop; they see what an account unlocks, on the card and on the board.
	_showcase = FeatureShowcase.new()
	_showcase.sign_up.connect(_sign_up)
	_showcase.dress = func(mine: Dictionary, rival: Dictionary) -> void:
		if ui.game:
			ui.game.set_showcase(mine, rival)
	_float_box = AppTheme.vbox(0)
	_float_box.alignment = BoxContainer.ALIGNMENT_END
	_float_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_box.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_float_box.offset_left = 20.0
	_float_box.offset_right = 340.0
	_float_box.offset_top = 90.0
	_float_box.offset_bottom = -20.0
	_frame.add_child(_float_box)
	_float_box.add_child(_showcase)

	_account = AppTheme.hbox(10)
	_account.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_account.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_frame.add_child(_account)

	ApiManager.auth_changed.connect(func(_logged_in: bool) -> void: _refresh_account())
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: _refresh_account())
	_refresh_account()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_notify_web_loader()


func open(_args: Dictionary) -> void:
	_logo.intro()
	AppTheme.pop_in(_tags, 0.9)
	_refresh_account()


func close() -> void:
	_showcase.stop()
	if ui.game:
		ui.game.set_showcase({})


## Phones get the whole title scaled up (portrait). The logo takes about a third of the height
## and never more than the column width; when the guest showcase joins the column (portrait or
## narrow windows) the logo gets a little smaller to make room.
func _layout() -> void:
	var portrait := ProfileUi.fit(_frame, get_viewport().get_visible_rect().size)
	var view := _frame.size
	var wide := not portrait and view.x >= WIDE
	var home: Control = _float_box if wide else _column
	if _showcase.get_parent() != home:
		_showcase.reparent(home, false)
	var guest_in_column := not wide and _showcase.visible
	var height := clampf(view.y * (0.24 if guest_in_column else 0.38), 120.0, 300.0)
	height = minf(height, minf(view.x - 32.0, 420.0) * GameLogo.VIEW.y / GameLogo.VIEW.x)
	_logo.set_height(height)


## Tells the web loader (web/shell.html) that the game is on screen, so it fades into the canvas.
func _notify_web_loader() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	JavaScriptBridge.eval("window.salpakanBooted && window.salpakanBooted()", true)


func _refresh_account() -> void:
	for child in _account.get_children():
		child.queue_free()
	var guest := not ApiManager.is_logged_in()
	_second.text = "Sign up free" if guest else "Shop"
	_showcase.visible = guest
	if guest and is_visible_in_tree():
		_showcase.start()
	else:
		_showcase.stop()
		if ui and ui.game:
			ui.game.set_showcase({})
	_layout()
	if not guest:
		var user := ApiManager.user
		_account.add_child(AppTheme.pill(str(user.get("username", "General")), AppTheme.PURPLE))
		_account.add_child(AppTheme.pill("ELO %s" % AppTheme.num(user.get("elo", 1200)), AppTheme.BLUE))
		_account.add_child(AppTheme.pill("%s credits" % AppTheme.num(user.get("credits", 0)), AppTheme.GOLD, AppTheme.INK))
		_account.add_child(AppTheme.button("Log out", "Ghost", _logout, 44))
	else:
		_account.add_child(AppTheme.button("Log in", "Ghost", func() -> void: ui.show_screen("auth", {"next": "title"}), 44))


func _on_second() -> void:
	if ApiManager.is_logged_in():
		ui.show_screen("shop")
	else:
		_sign_up()


func _sign_up() -> void:
	ui.show_screen("auth", {"next": "home", "mode": "register"})


func _logout() -> void:
	await ApiManager.logout()
	ui.toast("Logged out. See you soon!")


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
