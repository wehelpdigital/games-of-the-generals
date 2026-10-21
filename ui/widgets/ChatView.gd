class_name ChatView
extends ScrollContainer
## Scrolling chat: a bubble per message with the sender's photo, name in their rank colour and
## the time; emoji drawn inline. Emoji-only messages show big without a bubble, taunts as a
## yellow "threw a ..." chip, and "system" lines as centred notes. Messages with an id are shown
## once, so the copy from the POST response and the realtime echo don't double up.
##
## Message: {id, user: {id, username, rank_tier, avatar_url}, kind: text|emoji|taunt|system,
##           body, created_at, mine?}

const MAX_MESSAGES := 120

var compact := false  # In-match panel: smaller avatars and text.

var _list: VBoxContainer
var _ids: Dictionary = {}
var _bubbles: Array[RichTextLabel] = []


func _init(is_compact := false) -> void:
	compact = is_compact
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list = AppTheme.vbox(6 if compact else 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	resized.connect(_fit_bubbles)


func clear() -> void:
	_ids.clear()
	_bubbles.clear()
	for child in _list.get_children():
		child.queue_free()


func message_count() -> int:
	return _list.get_child_count()


func has_message(id: Variant) -> bool:
	return id != null and _ids.has(str(id))


func set_messages(messages: Array) -> void:
	clear()
	for message: Variant in messages:
		if message is Dictionary:
			add_message(message, false)
	scroll_to_end()


## Adds a message; false when it was already shown.
func add_message(message: Dictionary, scroll := true) -> bool:
	var id: Variant = message.get("id")
	if id != null:
		if _ids.has(str(id)):
			return false
		_ids[str(id)] = true
	var near_end := get_v_scroll_bar().value >= get_v_scroll_bar().max_value - size.y - 80.0
	_list.add_child(_row(message))
	while _list.get_child_count() > MAX_MESSAGES:
		var old := _list.get_child(0)
		_list.remove_child(old)
		old.queue_free()
	if scroll and (near_end or is_mine(message)):
		scroll_to_end()
	return true


func add_system(text: String) -> void:
	add_message({"kind": "system", "body": text})


func scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		scroll_vertical = int(get_v_scroll_bar().max_value)


static func is_mine(message: Dictionary) -> bool:
	if message.get("mine", false):
		return true
	var user: Variant = message.get("user")
	return user is Dictionary and ApiManager.is_logged_in() \
		and int(user.get("id", -1)) == int(ApiManager.user.get("id", -2))


# --- Rows -------------------------------------------------------------------------------------

func _row(message: Dictionary) -> Control:
	var kind := str(message.get("kind", "text"))
	var body := str(message.get("body", ""))
	if kind == "system":
		var note := AppTheme.label(body, "MutedLabel", 13 if compact else 15)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return note

	var mine := is_mine(message)
	var user: Dictionary = message.get("user") if message.get("user") is Dictionary else {}
	var row := AppTheme.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var avatar := AvatarView.new(28.0 if compact else 36.0)
	avatar.set_user(user)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var column := AppTheme.vbox(2)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_child(_header(user, str(message.get("created_at", "")), mine))
	if kind == "taunt":
		column.add_child(_taunt_chip(body))
	elif kind == "emoji" or EmojiPicker.is_only_emoji(body):
		column.add_child(_rich(body, 40 if compact else 48, 0, mine, false))
	else:
		column.add_child(_bubble(body, mine))

	if mine:
		row.add_child(column)
		row.add_child(avatar)
	else:
		row.add_child(avatar)
		row.add_child(column)
	return row


func _header(user: Dictionary, created_at: String, mine: bool) -> HBoxContainer:
	var header := AppTheme.hbox(6)
	header.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var tier: Variant = user.get("rank_tier")
	var name_label := AppTheme.label("You" if mine else str(user.get("username", "Player")), "", 13 if compact else 15)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.add_theme_color_override("font_color", PlayerRanks.color_of(tier).darkened(0.25) if tier != null else AppTheme.INK)
	if tier != null and not compact:
		var short := AppTheme.label(PlayerRanks.short_of(tier), "MutedLabel", 12)
		header.add_child(short)
	header.add_child(name_label)
	if user.get("title") != null and str(user["title"]) != "" and not compact:
		var title := AppTheme.label(str(user["title"]), "MutedLabel", 12)
		title.add_theme_color_override("font_color", AppTheme.PURPLE)
		header.add_child(title)
	var time := AppTheme.label(_clock(created_at), "MutedLabel", 11 if compact else 12)
	header.add_child(time)
	if mine:
		header.move_child(name_label, 0)
	return header


func _bubble(body: String, mine: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffe1ec") if mine else Color.WHITE
	style.set_corner_radius_all(14)
	if mine:
		style.corner_radius_top_right = 4
	else:
		style.corner_radius_top_left = 4
	style.set_border_width_all(2)
	style.border_color = AppTheme.INK
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	panel.add_child(_rich(body, 18 if compact else 22, 15 if compact else 18, mine, true))
	return panel


## A RichTextLabel sized to its text (wrapping past the bubble's maximum width).
func _rich(body: String, emoji_size: int, font_size: int, mine: bool, wrap: bool) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if font_size > 0:
		rich.add_theme_font_size_override("normal_font_size", font_size)
	rich.add_theme_color_override("default_color", AppTheme.INK)
	rich.text = EmojiPicker.bbcode(body, emoji_size)
	var natural := EmojiPicker.measure(body, CosmeticLibrary.display_font(), font_size if font_size > 0 else 20, emoji_size) + 6.0
	rich.set_meta("natural_width", natural)
	rich.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	_bubbles.append(rich)
	_fit(rich)
	return rich


func _taunt_chip(slug: String) -> PanelContainer:
	var info := CosmeticCatalog.info("taunt", slug)
	var text := "threw %s!" % str(info.get("name", slug.capitalize()))
	var chip := AppTheme.pill(text, AppTheme.YELLOW, AppTheme.INK, 14 if compact else 16)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return chip


func _max_bubble_width() -> float:
	var width := size.x if size.x > 0.0 else 320.0
	return maxf(120.0, width * 0.78 - (36.0 if compact else 48.0))


func _fit(rich: RichTextLabel) -> void:
	rich.custom_minimum_size.x = minf(float(rich.get_meta("natural_width", 100.0)), _max_bubble_width())


func _fit_bubbles() -> void:
	var alive: Array[RichTextLabel] = []
	for rich in _bubbles:
		if is_instance_valid(rich):
			_fit(rich)
			alive.append(rich)
	_bubbles = alive


## Chat-sized candy button: slimmer padding than the menu buttons. Styles come from the app
## theme, so this works before the button is in the tree.
static func compact_button(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := AppTheme.get_theme().get_stylebox(state, b.theme_type_variation).duplicate() as StyleBoxFlat
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, box)


## "14:05" in local time from the server's ISO-8601 UTC timestamp ("" when missing).
static func _clock(iso: String) -> String:
	if iso == "":
		var now := Time.get_time_dict_from_system()
		return "%02d:%02d" % [now.hour, now.minute]
	var unix := Time.get_unix_time_from_datetime_string(iso.left(19))
	if unix <= 0:
		return ""
	unix += Time.get_time_zone_from_system().get("bias", 0) * 60
	var t := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d:%02d" % [t.hour, t.minute]
