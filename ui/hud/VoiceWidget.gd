extends HBoxContainer
## Voice chat in the in-match top bar (online matches only). One compact mic button whose colour
## shows the call state (cream: off, yellow: connecting, green: live, red: my mic muted) and
## glows while someone talks; tapping it opens a small panel to join, mute myself, mute the
## opponent or leave. Native builds explain that voice is a browser feature.

const SPEAKING := 0.035
const GLOW := Color(0.8, 1.35, 0.9)

var hud: Screen

var _main: Button
var _panel: PanelContainer
var _status: Label
var _join: Button
var _controls: VBoxContainer
var _mic: Button
var _them: Button
var _voice: VoiceChat
var _pulse: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_main = _icon_button("mic", "", _toggle_panel, 46)
	_main.tooltip_text = "Voice chat"
	add_child(_main)

	_panel = PanelContainer.new()
	_panel.top_level = true
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = AppTheme.PAPER
	style.set_corner_radius_all(18)
	style.set_border_width_all(3)
	style.border_color = AppTheme.INK
	style.set_content_margin_all(12)
	style.shadow_color = Color(AppTheme.INK, 0.3)
	style.shadow_offset = Vector2(0, 5)
	style.shadow_size = 2
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size.x = 250
	add_child(_panel)

	var box := AppTheme.vbox(8)
	_panel.add_child(box)
	var title := AppTheme.label("Voice chat", "", 20)
	title.add_theme_font_override("font", AppTheme.heading_font())
	box.add_child(title)
	_status = AppTheme.label("", "MutedLabel", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_join = _icon_button("mic", "Join voice", _on_join, 46, "Success")
	box.add_child(_join)
	_controls = AppTheme.vbox(8)
	var row := AppTheme.hbox(8)
	_mic = _icon_button("mic", "Me", _toggle_mic, 44)
	_mic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_mic)
	_them = _icon_button("speaker", "Them", _toggle_them, 44)
	_them.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_them)
	_controls.add_child(row)
	_controls.add_child(_icon_button("muted", "Leave voice", _on_leave, 44, "Danger"))
	box.add_child(_controls)

	var tick := Timer.new()
	tick.wait_time = 0.5
	tick.autostart = true
	tick.timeout.connect(_refresh)
	add_child(tick)


## HudRegistry hook.
func setup(owner_hud: Screen) -> void:
	hud = owner_hud
	_voice = Social.voice
	_voice.state_changed.connect(_on_state)
	_voice.levels_changed.connect(_on_levels)
	_voice.peer_changed.connect(func(_joined: bool, _muted: bool) -> void: _refresh())
	_refresh()


func _icon_button(icon_name: String, text: String, action: Callable, height: float, kind := "Ghost") -> Button:
	var b := AppTheme.button(text, kind, action, height)
	b.icon = EmojiPicker.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 24)
	b.add_theme_font_size_override("font_size", 18)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if text == "":
		b.custom_minimum_size.x = 58
	return b


func _refresh() -> void:
	var online := GameSession.kind == GameSession.Kind.ONLINE and GameSession.status() in ["waiting", "setup", "active", "finished"]
	visible = online
	if not online or _voice == null:
		_panel.visible = false
		return
	var joined := _voice.state in ["starting", "waiting", "connecting", "live"]
	_join.visible = not joined
	_controls.visible = joined
	var kind := "Ghost"
	match _voice.state:
		"starting", "waiting", "connecting":
			kind = "Accent"
		"live":
			kind = "Danger" if _voice.mic_muted else "Success"
		_:
			kind = "Accent" if _voice.peer_joined else "Ghost"
	_main.theme_type_variation = kind + "Button"
	_main.icon = EmojiPicker.icon("muted" if joined and _voice.mic_muted else "mic")
	_set_pulse(not joined and _voice.peer_joined)
	_mic.text = "Me: off" if _voice.mic_muted else "Me: on"
	_mic.icon = EmojiPicker.icon("muted" if _voice.mic_muted else "mic")
	_mic.theme_type_variation = "DangerButton" if _voice.mic_muted else "SuccessButton"
	_them.text = "Them: off" if _voice.remote_muted else "Them: on"
	_them.icon = EmojiPicker.icon("muted" if _voice.remote_muted else "speaker")
	_them.theme_type_variation = "DangerButton" if _voice.remote_muted else "GhostButton"
	_status.text = _status_text()
	if _panel.visible:
		_place_panel()


func _status_text() -> String:
	match _voice.state:
		"starting":
			return "Allow the microphone in your browser..."
		"waiting":
			return "You're in! Waiting for your opponent to join."
		"connecting":
			return "Connecting..."
		"live":
			return "Live! Talk away." + ("  (Their mic is muted.)" if _voice.peer_muted else "")
	if not VoiceChat.supported():
		return "Voice chat is available in the browser version."
	if _voice.peer_joined:
		return "Your opponent is in voice chat. Join them!"
	return "Talk with your opponent. Your mic only turns on after you join."


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()
		_place_panel()
		AppTheme.pop_in(_panel)


func _place_panel() -> void:
	var screen := get_viewport().get_visible_rect().size
	var pos := _main.global_position + Vector2(0, _main.size.y + 8)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, screen.x - _panel.size.x - 8.0))
	_panel.global_position = pos


func _set_pulse(on: bool) -> void:
	if on and _pulse == null:
		_main.pivot_offset = _main.size / 2.0
		_pulse = _main.create_tween().set_loops()
		_pulse.tween_property(_main, "scale", Vector2.ONE * 1.12, 0.45).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_main, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	elif not on and _pulse != null:
		_pulse.kill()
		_pulse = null
		_main.scale = Vector2.ONE


func _on_join() -> void:
	if not VoiceChat.supported():
		hud.ui.toast("Voice chat is available in the browser version.", AppTheme.MUTED)
		return
	_voice.join()
	_refresh()


func _on_leave() -> void:
	_voice.leave()
	_panel.visible = false
	_refresh()


func _toggle_mic() -> void:
	_voice.set_mic_muted(not _voice.mic_muted)
	_refresh()


func _toggle_them() -> void:
	_voice.set_remote_muted(not _voice.remote_muted)
	_refresh()


func _on_state(state: String) -> void:
	if state == "error" and _voice.error_text != "" and hud:
		hud.ui.toast(_voice.error_text, AppTheme.RED)
	elif state == "live" and hud:
		hud.ui.toast("Voice chat connected", AppTheme.MINT)
	_refresh()


func _on_levels(mine: float, theirs: float) -> void:
	var me_talking := mine > SPEAKING and not _voice.mic_muted
	var they_talk := theirs > SPEAKING and not _voice.remote_muted
	_mic.modulate = GLOW if me_talking else Color.WHITE
	_them.modulate = GLOW if they_talk else Color.WHITE
	_main.modulate = GLOW if me_talking or they_talk else Color.WHITE
