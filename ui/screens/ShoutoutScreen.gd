extends Screen
## Compose a shoutout: up to 120 characters in a themed marquee across every player's screen for
## 12 seconds. Pick a theme with a live preview; prices come from the shop (free in test mode).

const PLACEHOLDER := "Your message across every screen!"

var _card: PanelContainer
var _preview: ShoutoutMarquee
var _field: LineEdit
var _count: Label
var _grid: GridContainer
var _picker: EmojiPicker
var _send: Button
var _credits: Label
var _themes: Array = []
var _theme := "classic"
var _group := ButtonGroup.new()
var _back := ""
var _sending := false


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(14)
	_card.add_child(box)

	var header := AppTheme.hbox(10)
	var icon := TextureRect.new()
	icon.texture = EmojiPicker.icon("megaphone")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	header.add_child(icon)
	header.add_child(AppTheme.label("Shoutout", "HeadingLabel"))
	header.add_child(AppTheme.spacer())
	_credits = AppTheme.label("", "MutedLabel", 16)
	_credits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_credits)
	box.add_child(header)
	var blurb := AppTheme.label("Your message scrolls across the top of every player's screen for 12 seconds.", "MutedLabel")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)

	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = AppTheme.INK
	frame_style.set_corner_radius_all(14)
	frame_style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", frame_style)
	_preview = ShoutoutMarquee.new(true)
	frame.add_child(_preview)
	box.add_child(frame)

	var input := AppTheme.hbox(8)
	var emoji := AppTheme.button("", "Ghost", func() -> void: _picker.visible = not _picker.visible, 52)
	emoji.icon = EmojiPicker.icon("smile")
	emoji.add_theme_constant_override("icon_max_width", 26)
	emoji.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	emoji.tooltip_text = "Emoji"
	input.add_child(emoji)
	_field = AppTheme.field(PLACEHOLDER)
	_field.max_length = Social.MAX_SHOUTOUT_LENGTH
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text_changed.connect(func(_text: String) -> void: _update_preview())
	input.add_child(_field)
	_count = AppTheme.label("0/%d" % Social.MAX_SHOUTOUT_LENGTH, "MutedLabel", 15)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	input.add_child(_count)
	box.add_child(input)
	_picker = EmojiPicker.new()
	_picker.visible = false
	_picker.picked.connect(_on_emoji)
	box.add_child(_picker)

	box.add_child(AppTheme.label("Theme", "", 20))
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)

	var actions := AppTheme.hbox(12)
	var back := AppTheme.button("Back", "Ghost", _go_back, 56)
	_send = AppTheme.button("Send Shoutout", "Primary", _confirm_send, 56)
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	actions.add_child(_send)
	box.add_child(actions)

	add_child(_page(_card, 760))
	resized.connect(_layout)
	_build_grid(_fallback_themes())


func open(args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen("auth", {"next": "shoutout"})
		return
	_back = str(args.get("back", ""))
	_layout()
	AppTheme.pop_in(_card)
	_preview.set_running(true)
	_update_preview()
	_update_credits()
	var themes: Array = await Social.shoutout_themes()
	if visible:
		_build_grid(themes)


func close() -> void:
	_preview.set_running(false)
	_picker.visible = false


func _layout() -> void:
	_grid.columns = 4 if get_viewport_rect().size.x >= 760.0 else 2


func _fallback_themes() -> Array:
	var list: Array = []
	for slug: String in ShoutoutMarquee.THEMES:
		list.append({"slug": slug, "name": ShoutoutMarquee.THEMES[slug]["name"], "price": 0})
	return list


func _build_grid(themes: Array) -> void:
	_themes = themes
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var slugs: Array = []
	for entry: Variant in themes:
		if entry is Dictionary:
			slugs.append(str(entry.get("slug", "")))
			_grid.add_child(_swatch(entry))
	if not (_theme in slugs) and not slugs.is_empty():
		_theme = slugs[0]
	for b in _grid.get_children():
		if b is Button and b.get_meta("slug", "") == _theme:
			(b as Button).button_pressed = true
	_update_preview()


func _swatch(entry: Dictionary) -> Button:
	var slug := str(entry.get("slug", "classic"))
	var look := ShoutoutMarquee.theme_of(slug)
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 70)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("slug", slug)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = look["bottom"] if state.begins_with("hover") else look["top"]
		style.set_corner_radius_all(16)
		var selected := state.ends_with("pressed")
		style.set_border_width_all(5 if selected else 3)
		style.border_color = AppTheme.YELLOW if selected else AppTheme.INK
		if selected:
			style.shadow_color = Color(AppTheme.YELLOW, 0.6)
			style.shadow_size = 6
		b.add_theme_stylebox_override(state, style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var column := AppTheme.vbox(4)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := AppTheme.label(str(entry.get("name", slug.capitalize())), "", 17, look["text"])
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.add_theme_color_override("font_outline_color", look["outline"])
	title.add_theme_constant_override("outline_size", 0 if look["outline"] == look["top"] else 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var price_row := AppTheme.hbox()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var paid := _price(entry) > 0
	price_row.add_child(AppTheme.pill(_price_text(entry), AppTheme.GOLD if paid else AppTheme.MINT, AppTheme.INK if paid else Color.WHITE, 13))
	column.add_child(price_row)
	b.add_child(column)
	b.toggled.connect(_on_swatch_toggled.bind(slug))
	return b


func _on_swatch_toggled(on: bool, slug: String) -> void:
	if on:
		_theme = slug
		_update_preview()


func _on_emoji(emoji: String) -> void:
	_field.insert_text_at_caret(emoji)
	_update_preview()


func _test_mode() -> bool:
	return bool(ServerConfig.get_value("shop_test_mode", true))


func _price(entry: Dictionary) -> int:
	return 0 if _test_mode() else int(entry.get("price", 0))


func _price_text(entry: Dictionary) -> String:
	var price := _price(entry)
	return "FREE" if price <= 0 else "%s credits" % AppTheme.num(price)


func _current_entry() -> Dictionary:
	for entry: Variant in _themes:
		if entry is Dictionary and str(entry.get("slug", "")) == _theme:
			return entry
	return {"slug": _theme, "price": 0}


func _update_preview() -> void:
	var text := _field.text.strip_edges()
	_count.text = "%d/%d" % [_field.text.length(), Social.MAX_SHOUTOUT_LENGTH]
	var me: Dictionary = ApiManager.user if ApiManager.is_logged_in() else {"username": "You"}
	_preview.preview({"user": me, "message": text if text != "" else PLACEHOLDER, "theme": _theme})
	_send.text = "Send Shoutout  ·  %s" % _price_text(_current_entry())


func _update_credits() -> void:
	_credits.text = ("%s credits" % AppTheme.num(ApiManager.user.get("credits", 0))) if ApiManager.is_logged_in() else ""


func _confirm_send() -> void:
	var text := Social.clean(_field.text, Social.MAX_SHOUTOUT_LENGTH)
	if text.length() < 2:
		ui.toast("Write your shoutout first!", AppTheme.MUTED)
		return
	var price := _price(_current_entry())
	if price > 0:
		ui.confirm("Send this shoutout for %s credits?" % AppTheme.num(price), "Send it!", _send_now, false)
	else:
		_send_now()


func _send_now() -> void:
	if _sending:
		return
	_sending = true
	_send.disabled = true
	var res: Dictionary = await Social.send_shoutout(_field.text, _theme)
	_sending = false
	_send.disabled = false
	if res.ok:
		_field.text = ""
		_update_preview()
		_update_credits()
		ui.toast("Shoutout sent! Look up!", AppTheme.MINT)
	elif res.status == 401:
		ui.show_screen("auth", {"next": "shoutout"})
	else:
		ui.toast(res.error, AppTheme.RED)


## The card centred on screen; it scrolls when taller than the screen (phones, short windows).
func _page(card: Control, max_width: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_child(card)
	center.add_child(margin)
	scroll.add_child(center)
	var fit := func() -> void: card.custom_minimum_size.x = minf(max_width, get_viewport_rect().size.x - 32.0)
	resized.connect(fit)
	fit.call_deferred()
	return scroll


func _go_back() -> void:
	if _back != "" and ui.has_screen(_back):
		ui.show_screen(_back)
	else:
		ui.home()
