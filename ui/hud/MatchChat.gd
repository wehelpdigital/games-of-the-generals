extends VBoxContainer
## In-match chat: a collapsible panel with the match's messages, quick emoji and taunts, and
## "mute opponent", which hides their chat and their taunts. Online it uses GET/POST
## /api/games/{id}/chat and the ChatMessage event on private-game.{id}; against the AI the chat
## stays on this device and the AI sometimes answers. While the opponent's Jammer powerup is
## active (GameSession.jammed_left()) the input is locked.
##
## Registered in the HUD's "bottom_left" slot, but it places itself in the bottom-right corner:
## the powerup column owns the left edge, and the panel opens upwards, kept clear of the action
## buttons (beside them in portrait, below them in landscape).

const QUICK_TAUNTS := 3
const MARGIN := 16.0
const PANEL_WIDTH := 320.0
const CHAT_HEIGHT := Vector2(90.0, 200.0)  # Min / max height of the message list.
const AI_TIERS := [0, 4, 11]  # Rank colours for the Rookie / Officer / General AI.
const AI_LINES := [
	"Is that your best move? 😏", "Hmm... interesting. 🤔", "My spy sees everything 👀",
	"You'll regret that 😈", "Ha! 😂", "Calculating... 🤖", "Nice try, General!", "Bold. Very bold. 😎",
	"I've seen scarier armies 🐔", "Steady... steady... 🎯",
]
const AI_WIN_LINES := ["Gotcha! 😈", "Boom! 💥", "Too easy 😎", "That one's mine 🏆"]
const AI_LOSE_LINES := ["Ouch! 😱", "Lucky shot... 😡", "I meant to do that 🙄", "Okay, okay 😅"]

var hud: Screen

var _panel: PanelContainer
var _chat: ChatView
var _field: LineEdit
var _send: Button
var _toggle: Button
var _badge: UnreadBadge  # Unread messages from the opponent while the chat is closed.
var _mute: Button
var _jam_pill: PanelContainer
var _quick: Array[Control] = []
var _match_key := ""
var _unread := 0
var _jammed := false


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true  # Positioned by _place(), not by the slot.
	visible = false

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(AppTheme.PAPER, 0.96)
	style.set_corner_radius_all(20)
	style.set_border_width_all(3)
	style.border_color = AppTheme.INK
	style.set_content_margin_all(10)
	style.shadow_color = Color(AppTheme.INK, 0.3)
	style.shadow_offset = Vector2(0, 5)
	style.shadow_size = 2
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel.visible = false
	add_child(_panel)

	var box := AppTheme.vbox(6)
	_panel.add_child(box)
	var header := AppTheme.hbox(6)
	header.add_child(AppTheme.label("Match Chat", "", 18, AppTheme.INK))
	(header.get_child(0) as Label).add_theme_font_override("font", AppTheme.heading_font())
	header.add_child(AppTheme.spacer())
	_jam_pill = AppTheme.pill("JAMMED", AppTheme.RED, Color.WHITE, 13)
	_jam_pill.visible = false
	header.add_child(_jam_pill)
	box.add_child(header)

	_chat = ChatView.new(true)
	_chat.custom_minimum_size.y = CHAT_HEIGHT.y
	box.add_child(_chat)

	var quick := AppTheme.hbox(4)
	for hex: String in EmojiPicker.QUICK:
		var b := TextureButton.new()
		b.texture_normal = EmojiPicker.texture(hex)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(32, 32)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_say.bind(EmojiPicker.char_of(hex)))
		quick.add_child(b)
		_quick.append(b)
	quick.add_child(AppTheme.spacer())
	box.add_child(quick)

	var taunts := AppTheme.hbox(4)
	var slugs: Array = CosmeticCatalog.slugs("taunt")
	for slug: String in slugs.slice(0, QUICK_TAUNTS):
		var b := AppTheme.button(str(CosmeticCatalog.info("taunt", slug).get("name", slug)).left(14), "Accent", _taunt.bind(slug), 34)
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ChatView.compact_button(b)
		taunts.add_child(b)
		_quick.append(b)
	box.add_child(taunts)

	var input := AppTheme.hbox(6)
	_field = AppTheme.field("Message...")
	_field.max_length = Social.MAX_CHAT_LENGTH
	_field.custom_minimum_size.y = 40
	_field.add_theme_font_size_override("font_size", 16)
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text_submitted.connect(func(_text: String) -> void: _submit())
	input.add_child(_field)
	_send = AppTheme.button("Send", "Primary", _submit, 40)
	_send.add_theme_font_size_override("font_size", 17)
	ChatView.compact_button(_send)
	input.add_child(_send)
	box.add_child(input)

	var bar := AppTheme.hbox(8)
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toggle = AppTheme.button("", "Ghost", _toggle_panel, 46)
	_toggle.icon = EmojiPicker.icon("chat")
	_toggle.add_theme_constant_override("icon_max_width", 26)
	_toggle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_toggle.custom_minimum_size.x = 58
	_toggle.tooltip_text = "Match chat"
	bar.add_child(_toggle)
	_badge = UnreadBadge.new()
	_toggle.add_child(_badge)
	_mute = AppTheme.button("", "Ghost", _toggle_mute, 46)
	_mute.custom_minimum_size.x = 58
	_mute.add_theme_constant_override("icon_max_width", 24)
	_mute.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bar.add_child(_mute)
	add_child(bar)

	var tick := Timer.new()
	tick.wait_time = 0.5
	tick.autostart = true
	tick.timeout.connect(_tick)
	add_child(tick)
	resized.connect(_place)


## HudRegistry hook.
func setup(owner_hud: Screen) -> void:
	hud = owner_hud
	GameSession.match_loaded.connect(_on_match_loaded)
	GameSession.taunt_received.connect(_on_taunt)
	GameSession.move_result.connect(_on_move_result)
	GameSession.game_over.connect(func(_info: Dictionary) -> void: _chat.add_system("Match over. Say GG! 🫡"))
	Social.match_message.connect(_on_match_message)
	get_viewport().size_changed.connect(_place)
	_refresh_mute()


# --- Match lifecycle --------------------------------------------------------------------------

func _on_match_loaded(_view: Dictionary) -> void:
	var key := "%d:%d" % [GameSession.kind, GameSession.match_id()]
	visible = true
	_place()
	if key == _match_key:
		return
	_match_key = key
	_chat.clear()
	_set_unread(0)
	if GameSession.kind == GameSession.Kind.PRACTICE:
		_chat.add_system("Chat with %s. Be nice... or don't. 😎" % _ai_user()["username"])
		return
	_chat.add_system("Chat with your opponent. Keep it friendly! 🫡")
	var id := GameSession.match_id()
	var history: Array = await Social.load_match_chat(id)
	if GameSession.match_id() != id:
		return
	for message: Variant in history:
		if message is Dictionary and _show_from(message):
			_chat.add_message(message, false)
	_chat.scroll_to_end()


func _tick() -> void:
	var in_match := GameSession.has_match()
	if visible != in_match:
		visible = in_match
		if not in_match:
			_match_key = ""
			_panel.visible = false
	if in_match:
		_update_jam()
		_place()  # The action buttons above change between setup and play.


## Bottom-right corner. The panel's width and the message list's height shrink so the panel never
## covers the HUD's action buttons: beside them when they sit at the bottom (portrait), below them
## when they form the top-right column (landscape).
func _place() -> void:
	if not is_inside_tree() or not visible:
		return
	var screen := get_viewport().get_visible_rect().size
	var width := minf(PANEL_WIDTH, screen.x - 2.0 * MARGIN)
	var top_limit := 84.0  # Below the HUD's top bar.
	var panel_bottom := screen.y - MARGIN - _toggle.get_combined_minimum_size().y - 8.0
	var actions: Variant = hud.get("_actions") if hud else null
	if actions is Control and (actions as Control).is_visible_in_tree():
		var rect := (actions as Control).get_global_rect()
		if rect.end.x > screen.x - MARGIN - width and rect.position.y < panel_bottom:
			if rect.position.y > screen.y * 0.5:
				width = maxf(220.0, screen.x - MARGIN - rect.end.x - 12.0)  # Beside the buttons.
			else:
				top_limit = maxf(top_limit, rect.end.y + 12.0)  # Below the column.
	_panel.custom_minimum_size.x = width
	var fixed := _panel.get_combined_minimum_size().y - _chat.custom_minimum_size.y
	_chat.custom_minimum_size.y = clampf(panel_bottom - top_limit - fixed, CHAT_HEIGHT.x, CHAT_HEIGHT.y)
	reset_size()
	position = Vector2(screen.x - MARGIN - size.x, screen.y - MARGIN - size.y)


# --- Messages ---------------------------------------------------------------------------------

func _on_match_message(id: int, message: Dictionary) -> void:
	if GameSession.kind != GameSession.Kind.ONLINE or id != GameSession.match_id():
		return
	if not _show_from(message):
		return
	if _chat.add_message(message) and not _panel.visible and not ChatView.is_mine(message):
		_set_unread(_unread + 1)


## False for the opponent's messages while they're muted.
func _show_from(message: Dictionary) -> bool:
	return ChatView.is_mine(message) or not _muted()


func _on_taunt(side: String, slug: String) -> void:
	var mine := side == GameSession.my_side()
	if not mine and _muted():
		return
	_chat.add_message({"kind": "taunt", "body": slug, "user": _me() if mine else _opponent_user(side), "mine": mine})
	if not mine and not _panel.visible:
		_set_unread(_unread + 1)


func _on_move_result(result: Dictionary) -> void:
	if GameSession.kind != GameSession.Kind.PRACTICE or not (result.get("clash") is Dictionary) or randf() > 0.25:
		return
	var ai_side := Ranks.opponent(GameSession.my_side())
	var outcome := str(result["clash"].get("outcome", ""))
	var attacker_is_ai := str(result.get("side", "")) == ai_side
	var ai_won := (outcome == "attacker" and attacker_is_ai) or (outcome == "defender" and not attacker_is_ai)
	var ai_lost := (outcome == "attacker" and not attacker_is_ai) or (outcome == "defender" and attacker_is_ai)
	if ai_won:
		_ai_say(AI_WIN_LINES.pick_random(), randf_range(0.8, 1.6))
	elif ai_lost:
		_ai_say(AI_LOSE_LINES.pick_random(), randf_range(0.8, 1.6))


func _submit() -> void:
	var text := _field.text
	if Social.clean(text, Social.MAX_CHAT_LENGTH) == "":
		return
	if await _say(text):
		_field.text = ""


## Sends a chat line; true when it went out.
func _say(text: String) -> bool:
	if not GameSession.has_match():
		return false
	if _jam_seconds_left() > 0:
		hud.ui.toast(_jam_text(), AppTheme.RED)
		return false
	var body := Social.clean(text, Social.MAX_CHAT_LENGTH)
	if GameSession.kind == GameSession.Kind.PRACTICE:
		_chat.add_message({"kind": Social.kind_of(body), "body": body, "user": _me(), "mine": true})
		_ai_reply(body)
		return true
	_send.disabled = true
	var res: Dictionary = await Social.send_match(GameSession.match_id(), body)
	_send.disabled = false
	if not res.ok and res.error != "":
		hud.ui.toast(_jam_text() if _jam_seconds_left() > 0 else res.error, AppTheme.RED)
	return res.ok


func _taunt(slug: String) -> void:
	if _jam_seconds_left() > 0:
		hud.ui.toast(_jam_text(), AppTheme.RED)
		return
	var problem: String = await GameSession.send_taunt(slug)
	if problem != "":
		hud.ui.toast(problem, AppTheme.MUTED)


func _ai_reply(body: String) -> void:
	if randf() > 0.5:
		return
	var lower := body.to_lower()
	var line: String = AI_LINES.pick_random()
	if lower.contains("gg") or lower.contains("good game"):
		line = "GG 🫡"
	elif lower.contains("hi") or lower.contains("hello") or lower.contains("hey"):
		line = "Greetings, General. Prepare yourself 😎"
	elif EmojiPicker.is_only_emoji(body):
		line = EmojiPicker.char_of(EmojiPicker.PICKER.pick_random())
	_ai_say(line, randf_range(1.0, 2.6))


func _ai_say(line: String, delay: float) -> void:
	var key := _match_key
	await get_tree().create_timer(delay).timeout
	if key != _match_key or GameSession.kind != GameSession.Kind.PRACTICE or _muted():
		return
	_chat.add_message({"kind": Social.kind_of(line), "body": line, "user": _ai_user()})
	if not _panel.visible:
		_set_unread(_unread + 1)


# --- People -----------------------------------------------------------------------------------

func _me() -> Dictionary:
	var me: Dictionary = ApiManager.user.duplicate() if ApiManager.is_logged_in() else {"username": "You"}
	return me


func _opponent_user(side: String) -> Dictionary:
	if GameSession.kind == GameSession.Kind.PRACTICE:
		return _ai_user()
	var players: Variant = GameSession.match_view.get("players")
	if players is Dictionary and players.get(side) is Dictionary:
		return players[side]
	return {"username": "Opponent"}


func _ai_user() -> Dictionary:
	var level := int(GameSession.practice_level)
	return {"username": "%s AI" % SalpakanAI.LABELS.get(level, "Officer"), "rank_tier": AI_TIERS[clampi(level, 0, 2)]}


# --- Controls ---------------------------------------------------------------------------------

func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	_place()
	if _panel.visible:
		_set_unread(0)
		_chat.scroll_to_end()
		AppTheme.pop_in(_panel)


func _set_unread(count: int) -> void:
	_unread = count
	_badge.set_count(count)


func _muted() -> bool:
	return hud != null and bool(hud.ui.setting("mute_chat", false))


func _toggle_mute() -> void:
	var muted := not _muted()
	hud.ui.set_setting("mute_chat", muted)
	hud.ui.set_setting("mute_taunts", muted)
	_refresh_mute()
	_chat.add_system("Opponent muted: their chat and taunts are hidden." if muted else "Opponent unmuted.")


func _refresh_mute() -> void:
	var muted := _muted()
	_mute.icon = EmojiPicker.icon("muted" if muted else "speaker")
	_mute.tooltip_text = "Unmute opponent" if muted else "Mute opponent (chat + taunts)"


func _update_jam() -> void:
	var left := _jam_seconds_left()
	var jammed := left > 0
	if jammed != _jammed or jammed:
		_jammed = jammed
		_jam_pill.visible = jammed
		_field.editable = not jammed
		_send.disabled = jammed
		for c in _quick:
			if c is BaseButton:
				(c as BaseButton).disabled = jammed
		_field.placeholder_text = _jam_text() if jammed else "Message..."
		if jammed:
			AppTheme.set_pill(_jam_pill, "JAMMED %d:%02d" % [floori(left / 60.0), left % 60], AppTheme.RED)


## Whole seconds left on the opponent's Jammer against me (0 when free).
func _jam_seconds_left() -> int:
	return ceili(GameSession.jammed_left())


func _jam_text() -> String:
	var left := _jam_seconds_left()
	return "Jammed! %d:%02d" % [floori(left / 60.0), left % 60]
