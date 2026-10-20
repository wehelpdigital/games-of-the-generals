extends Screen
## Title: logo, the four ways to play, and the account chip. The 3D board orbits behind it.

var _account: HBoxContainer
var _logo: Control
var _wiggle_tween: Tween


func _ready() -> void:
	add_child(AppTheme.backdrop_glow(0.85))
	var column := AppTheme.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	_logo = AppTheme.vbox(0)
	var small := AppTheme.label("GAME OF THE", "TitleLabel", 36)
	small.add_theme_constant_override("outline_size", 10)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var big := AppTheme.label("GENERALS", "TitleLabel", 84)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_color", AppTheme.YELLOW)
	_logo.add_child(small)
	_logo.add_child(big)
	var tag_row := AppTheme.hbox()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_child(AppTheme.pill("SALPAKAN", AppTheme.PINK))
	tag_row.add_child(AppTheme.pill("3D", AppTheme.BLUE))
	_logo.add_child(tag_row)
	column.add_child(_logo)

	column.add_child(_gap(18))
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


func open(_args: Dictionary) -> void:
	AppTheme.pop_in(_logo)
	_wiggle()


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


## The logo bobs gently while the title is on screen.
func _wiggle() -> void:
	if _wiggle_tween:
		_wiggle_tween.kill()
	_logo.pivot_offset = _logo.size * 0.5
	var t := _logo.create_tween().set_loops()
	_wiggle_tween = t
	t.tween_property(_logo, "rotation", deg_to_rad(-1.5), 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(_logo, "rotation", deg_to_rad(1.5), 1.6).set_trans(Tween.TRANS_SINE)


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
