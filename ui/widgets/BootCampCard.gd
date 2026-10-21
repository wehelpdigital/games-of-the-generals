extends PanelContainer
## Dashboard strip (DashboardRegistry "banner") inviting players who haven't been through Boot
## Camp to try it. Gone once they graduate or tap the x.

var _ui: UIRoot
var _text: Label


func _init() -> void:
	visible = false
	var style := ProfileUi.box(Color(AppTheme.PAPER, 0.97), 20, 3)
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := AppTheme.hbox(10)
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = PieceIcons.icon_texture("PVT")
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	_text = AppTheme.label("", "", 17)
	_text.add_theme_font_override("font", AppTheme.heading_font())
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 140
	row.add_child(_text)
	var go := ProfileUi.colored_button("Boot Camp", AppTheme.PURPLE, Color.WHITE, _open, 40)
	go.add_theme_font_size_override("font_size", 17)
	row.add_child(go)
	var close := ProfileUi.small_button("x", "Ghost", _dismiss, 40)
	close.tooltip_text = "Hide this"
	row.add_child(close)


func setup(dashboard: Screen) -> void:
	_ui = dashboard.ui
	if UiScale.narrow(dashboard):
		size_flags_horizontal = Control.SIZE_FILL  # Phones: full width, the text wraps.
	refresh()


func refresh() -> void:
	visible = TutorialProgress.should_nudge()
	var done := TutorialProgress.done_count()
	_text.text = "New to Salpakan? Learn it in 5 minutes." if done == 0 else "Boot Camp: %d of %d drills done. Keep going!" % [done, TutorialLessons.LESSONS.size()]


func _open() -> void:
	if _ui:
		_ui.show_screen("boot_camp", {"back": "dashboard"})


func _dismiss() -> void:
	TutorialProgress.dismiss_nudge()
	visible = false
