extends PanelContainer
## Dashboard strip (DashboardRegistry "banner"): the daily login reward. Pops the calendar up the
## first time the dashboard opens each day; afterwards shows the streak and when the next reward
## unlocks.

const EMOJI_FIRE := "1f525"
const EMOJI_GIFT := "1f389"

var _ui: UIRoot
var _row: HBoxContainer
var _icon: TextureRect
var _text: Label
var _button: Button
var _timer: Timer


func _init() -> void:
	visible = false
	var style := ProfileUi.box(Color(AppTheme.PAPER, 0.97), 20, 3)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_row = AppTheme.hbox(10)
	add_child(_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_row.add_child(_icon)
	_text = AppTheme.label("", "", 17)
	_text.add_theme_font_override("font", AppTheme.heading_font())
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Wraps on phones instead of widening the card.
	_text.custom_minimum_size.x = 140
	_row.add_child(_text)
	_button = ProfileUi.colored_button("Claim", AppTheme.PINK, Color.WHITE, _open_popup, 40)
	_button.add_theme_font_size_override("font_size", 17)
	_row.add_child(_button)
	_timer = Timer.new()
	_timer.wait_time = 30.0
	_timer.timeout.connect(_render)
	add_child(_timer)


func setup(dashboard: Screen) -> void:
	_ui = dashboard.ui
	if UiScale.narrow(dashboard):
		size_flags_horizontal = Control.SIZE_FILL  # Phones: full width, the text wraps.
	Economy.daily_changed.connect(_render)


func refresh() -> void:
	await Economy.refresh_daily()
	_render()
	if Economy.should_offer_daily() and _ui and is_visible_in_tree():
		Economy.mark_daily_offered()
		DailyRewardPopup.open(_ui)


func _render() -> void:
	var daily := Economy.daily
	visible = ApiManager.is_logged_in() and not daily.is_empty()
	if not visible:
		_timer.stop()
		return
	var streak := int(daily.get("streak", 0))
	if daily.get("claimed_today", false):
		_icon.texture = EmojiPicker.texture(EMOJI_FIRE)
		var left := EconomyUi.time_left(str(daily.get("next_reset_at", "")))
		_text.text = "%d-day streak  -  next reward in %s" % [maxi(1, streak), left] if left != "" else "%d-day streak!" % maxi(1, streak)
		_button.text = "Calendar"
		_paint(AppTheme.PAPER, AppTheme.INK)
		_timer.start()
	else:
		_icon.texture = EmojiPicker.texture(EMOJI_GIFT)
		var credits := 0
		for day: Dictionary in daily.get("calendar", []):
			if day.get("today", false):
				credits = int(day.get("credits", 0))
		_text.text = "Daily reward ready!  Day %d: %s credits" % [int(daily.get("day", 1)), ProfileUi.grouped(credits)]
		_button.text = "Claim"
		_paint(AppTheme.PINK, Color.WHITE)
		_timer.stop()


func _open_popup() -> void:
	if _ui:
		Economy.mark_daily_offered()
		DailyRewardPopup.open(_ui)



func _paint(bg: Color, fg: Color) -> void:
	_button.add_theme_stylebox_override("normal", ProfileUi.candy(bg, false))
	_button.add_theme_stylebox_override("hover", ProfileUi.candy(bg.lightened(0.12), false))
	_button.add_theme_stylebox_override("pressed", ProfileUi.candy(bg.darkened(0.06), true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_button.add_theme_color_override(state, fg)
	_button.add_theme_constant_override("outline_size", 0 if fg != Color.WHITE else 6)
