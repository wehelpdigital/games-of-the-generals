extends PanelContainer
## Dashboard strip (DashboardRegistry "banner") inviting players who haven't been through Boot
## Camp to try it. Gone once they graduate or tap the x. On phones the button sits under the text
## so the strip fits the narrow column.

var _ui: UIRoot
var _icon: TextureRect
var _words: VBoxContainer
var _text: Label
var _go: Button
var _close: Button


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
	_icon = TextureRect.new()
	_icon.texture = PieceIcons.icon_texture("PVT")
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_words = AppTheme.vbox(6)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_words)
	_text = AppTheme.label("", "", 17)
	_text.add_theme_font_override("font", AppTheme.heading_font())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 140
	_words.add_child(_text)
	_go = ProfileUi.colored_button("Boot Camp", AppTheme.PURPLE, Color.WHITE, _open, 40)
	_go.add_theme_font_size_override("font_size", 17)
	_go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_go)
	_close = ProfileUi.small_button("x", "Ghost", _dismiss, 40)
	_close.tooltip_text = "Hide this"
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_close)


func setup(dashboard: Screen) -> void:
	_ui = dashboard.ui
	if UiScale.narrow(dashboard):
		# Phones: full width, the text wraps and the button goes under it; a slim x.
		size_flags_horizontal = Control.SIZE_FILL
		_icon.custom_minimum_size = Vector2(28, 28)
		_text.custom_minimum_size.x = 90
		_text.add_theme_font_size_override("font_size", 16)
		_go.reparent(_words, false)
		_go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_go.custom_minimum_size.y = 36
		_go.add_theme_font_size_override("font_size", 16)
		_close.custom_minimum_size = Vector2(36, 36)
		_close.add_theme_font_size_override("font_size", 15)
		_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
