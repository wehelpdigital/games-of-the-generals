class_name GlobalChatPanel
extends PanelContainer
## Dashboard panel: the everyone-online chat room. Live through the public `global` channel
## (Social), history from GET /api/chat/global. Logged-out players can read along and get a
## "Log in to chat" button instead of the input row.

var ui: UIRoot

var _live: PanelContainer
var _chat: ChatView
var _input_row: HBoxContainer
var _login_row: Control
var _field: LineEdit
var _send: Button
var _picker: EmojiPicker
var _loading := false


func _init() -> void:
	theme_type_variation = "CardPanel"
	custom_minimum_size = Vector2(300, 440)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = AppTheme.PAPER
	style.set_corner_radius_all(24)
	style.set_border_width_all(4)
	style.border_color = AppTheme.INK
	style.set_content_margin_all(16)
	style.shadow_color = Color(AppTheme.INK, 0.3)
	style.shadow_offset = Vector2(0, 6)
	style.shadow_size = 2
	add_theme_stylebox_override("panel", style)

	var box := AppTheme.vbox(10)
	add_child(box)
	var header := AppTheme.hbox(8)
	var icon := TextureRect.new()
	icon.texture = EmojiPicker.icon("chat")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	header.add_child(icon)
	header.add_child(AppTheme.label("Global Chat", "HeadingLabel", 26))
	header.add_child(AppTheme.spacer())
	_live = AppTheme.pill("OFFLINE", AppTheme.MUTED, Color.WHITE, 13)
	_live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_live)
	box.add_child(header)

	var well := PanelContainer.new()
	var well_style := StyleBoxFlat.new()
	well_style.bg_color = Color("f3ead9")
	well_style.set_corner_radius_all(16)
	well_style.set_content_margin_all(8)
	well.add_theme_stylebox_override("panel", well_style)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat = ChatView.new()
	well.add_child(_chat)
	box.add_child(well)

	_picker = EmojiPicker.new()
	_picker.visible = false
	_picker.picked.connect(_on_emoji)
	box.add_child(_picker)

	_input_row = AppTheme.hbox(6)
	var emoji := AppTheme.button("", "Ghost", func() -> void: _picker.visible = not _picker.visible, 46)
	emoji.icon = EmojiPicker.icon("smile")
	emoji.add_theme_constant_override("icon_max_width", 24)
	emoji.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	emoji.tooltip_text = "Emoji"
	ChatView.compact_button(emoji)
	_input_row.add_child(emoji)
	_field = AppTheme.field("Say hi to everyone...")
	_field.max_length = Social.MAX_CHAT_LENGTH
	_field.custom_minimum_size.y = 46
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text_submitted.connect(func(_text: String) -> void: _submit())
	_input_row.add_child(_field)
	_send = AppTheme.button("Send", "Primary", _submit, 46)
	_send.add_theme_font_size_override("font_size", 20)
	ChatView.compact_button(_send)
	_input_row.add_child(_send)
	box.add_child(_input_row)

	_login_row = AppTheme.button("Log in to chat", "Secondary", _login, 48)
	box.add_child(_login_row)

	Social.global_message.connect(_on_message)
	Social.live_changed.connect(func(_live_now: bool) -> void: _refresh_live())
	ApiManager.auth_changed.connect(func(_logged_in: bool) -> void: _refresh_input())
	_refresh_input()


## DashboardRegistry hook.
func setup(dashboard: Screen) -> void:
	ui = dashboard.ui


## DashboardRegistry hook: called whenever the dashboard opens.
func refresh() -> void:
	_refresh_input()
	_refresh_live()
	if not Social.is_live():
		Social.connect_realtime()
	if _loading:
		return
	_loading = true
	var res: Dictionary = await Social.load_global()
	_loading = false
	if res.ok or _chat.message_count() == 0:
		_chat.set_messages(Social.global_messages)
	if _chat.message_count() == 0:
		_chat.add_system("No messages yet. Start the conversation!" if res.ok else "Chat is offline right now.")


func _ready() -> void:
	if _chat.message_count() == 0 and not Social.global_messages.is_empty():
		_chat.set_messages(Social.global_messages)


func _login() -> void:
	if ui:
		ui.show_screen("auth", {"next": "home"})


func _on_message(message: Dictionary) -> void:
	_chat.add_message(message)


func _on_emoji(emoji: String) -> void:
	_field.insert_text_at_caret(emoji)
	_field.grab_focus()


func _submit() -> void:
	var text := _field.text
	if Social.clean(text, Social.MAX_CHAT_LENGTH) == "":
		return
	_send.disabled = true
	var res: Dictionary = await Social.send_global(text)
	_send.disabled = false
	if res.ok:
		_field.text = ""
		_picker.visible = false
	elif res.error != "" and ui:
		ui.toast(res.error, AppTheme.RED)


func _refresh_input() -> void:
	var logged_in := ApiManager.is_logged_in()
	_input_row.visible = logged_in
	_login_row.visible = not logged_in
	if not logged_in:
		_picker.visible = false


func _refresh_live() -> void:
	var live := Social.is_live()
	AppTheme.set_pill(_live, "LIVE" if live else "OFFLINE", AppTheme.MINT if live else AppTheme.MUTED)
