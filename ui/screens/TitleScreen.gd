extends Screen
## Title: logo, the four ways to play, and the account chip. The 3D board orbits behind it.

var _account: HBoxContainer
var _logo: GameLogo
var _tags: HBoxContainer


func _ready() -> void:
	add_child(AppTheme.backdrop_glow(0.85))
	var column := AppTheme.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

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
	var shop := AppTheme.button("Shop", "Success", func() -> void: ui.show_screen("shop"))
	ranks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ranks)
	row.add_child(shop)
	column.add_child(row)
	if not (OS.has_feature("web") or OS.has_feature("mobile")):
		column.add_child(AppTheme.button("Quit", "Ghost", func() -> void: get_tree().quit(), 48))
	add_child(AppTheme.centered(column, 420))

	_account = AppTheme.hbox(10)
	_account.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_account.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_account)

	ApiManager.auth_changed.connect(func(_logged_in: bool) -> void: _refresh_account())
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: _refresh_account())
	_refresh_account()
	get_viewport().size_changed.connect(_fit_logo)
	_fit_logo()
	_notify_web_loader()


func open(_args: Dictionary) -> void:
	_logo.intro()
	AppTheme.pop_in(_tags, 0.9)


## The logo takes over a third of the screen height, and never more than the column width.
func _fit_logo() -> void:
	var view := get_viewport().get_visible_rect().size
	var height := clampf(view.y * 0.38, 130.0, 300.0)
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
	if ApiManager.is_logged_in():
		var user := ApiManager.user
		_account.add_child(AppTheme.pill(str(user.get("username", "General")), AppTheme.PURPLE))
		_account.add_child(AppTheme.pill("ELO %s" % AppTheme.num(user.get("elo", 1200)), AppTheme.BLUE))
		_account.add_child(AppTheme.pill("%s credits" % AppTheme.num(user.get("credits", 0)), AppTheme.GOLD, AppTheme.INK))
		_account.add_child(AppTheme.button("Log out", "Ghost", _logout, 44))
	else:
		_account.add_child(AppTheme.button("Log in", "Ghost", func() -> void: ui.show_screen("auth", {"next": "title"}), 44))


func _logout() -> void:
	await ApiManager.logout()
	ui.toast("Logged out. See you soon!")


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
