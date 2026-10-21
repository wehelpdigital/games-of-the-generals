extends Screen
## In-match HUD. Kept to the screen edges so it never covers the board: player chips and a turn
## banner on top, setup/resign buttons bottom-right, the hovered piece's rank bottom-centre, and
## the end-of-match card.

var _you: PanelContainer
var _them: PanelContainer
var _turn: PanelContainer
var _status: Label
var _setup_row: VBoxContainer
var _resign: Button
var _hint: PanelContainer
var _pulse: Tween
var _actions: VBoxContainer
var _clips_button: Button
var _taunt_button: Button
var _taunt_menu: VBoxContainer
var _last_info: Dictionary = {}  # The finished match's game-over info (result card and recap).
var _recap_run := 0  # Bumped to cancel a running "Watch all".
var _slots: Dictionary = {}  # HudRegistry slot name -> container


func _ready() -> void:
	var top := AppTheme.hbox(10)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	top.offset_left = 12
	top.offset_right = -12
	add_child(top)
	top.add_child(AppTheme.button("Menu", "Ghost", _ask_leave, 46))
	_clips_button = AppTheme.button("Clips: ON", "Ghost", _toggle_clips, 46)
	top.add_child(_clips_button)
	_you = AppTheme.pill("You", AppTheme.BLUE)
	top.add_child(_you)
	top.add_child(AppTheme.spacer())
	_them = AppTheme.pill("Opponent", AppTheme.PINK)
	top.add_child(_them)

	var center := AppTheme.vbox(4)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(center)
	_turn = AppTheme.pill("SETUP", AppTheme.YELLOW, AppTheme.INK, 26)
	center.add_child(_turn)
	_status = AppTheme.label("", "", 18, Color.WHITE)
	_status.add_theme_color_override("font_outline_color", AppTheme.INK)
	_status.add_theme_constant_override("outline_size", 8)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_status)

	var corner := AppTheme.vbox(10)
	_actions = corner
	add_child(corner)
	_setup_row = AppTheme.vbox(8)
	_setup_row.add_child(AppTheme.button("Shuffle", "Accent", func() -> void: ui.game.shuffle_formation(), 54))
	_setup_row.add_child(AppTheme.button("Ready!", "Primary", _ready_up, 54))
	corner.add_child(_setup_row)
	_resign = AppTheme.button("Resign", "Danger", _ask_resign, 46)
	corner.add_child(_resign)
	_taunt_button = AppTheme.button("Taunt!", "Accent", _toggle_taunt_menu, 50)
	corner.add_child(_taunt_button)
	corner.move_child(_taunt_button, 0)
	_taunt_menu = AppTheme.vbox(6)
	_taunt_menu.visible = false
	corner.add_child(_taunt_menu)
	corner.move_child(_taunt_menu, 1)

	_hint = AppTheme.pill("", AppTheme.INK)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.visible = false
	add_child(_hint)

	_build_slots(top, center, corner)
	get_viewport().size_changed.connect(_layout)
	_layout()

	GameSession.turn_changed.connect(_refresh)
	GameSession.match_loaded.connect(func(_view: Dictionary) -> void: _refresh())
	GameSession.status_message.connect(func(text: String) -> void: _status.text = text)
	GameSession.move_rejected.connect(func(_id: String, message: String) -> void: ui.toast(message, AppTheme.RED))
	GameSession.game_over.connect(_on_game_over)
	GameSession.taunt_received.connect(_on_taunt)


## Containers where feature modules' widgets (HudRegistry) live, then the widgets themselves.
func _build_slots(top: HBoxContainer, center: VBoxContainer, corner: VBoxContainer) -> void:
	var top_left := AppTheme.hbox(10)
	top.add_child(top_left)
	top.move_child(top_left, 2)  # After Menu and Clips.
	var right := AppTheme.vbox(10)
	corner.add_child(right)
	corner.move_child(right, 0)
	var left := AppTheme.vbox(10)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	left.offset_top = 84.0
	add_child(left)
	var bottom_left := AppTheme.vbox(8)
	bottom_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	bottom_left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_left.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom_left)
	var bottom_center := AppTheme.hbox(10)
	bottom_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	bottom_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom_center)
	_slots = {"top_left": top_left, "top_center": center, "left": left, "right": right,
		"bottom_left": bottom_left, "bottom_center": bottom_center}
	for entry: Dictionary in HudRegistry.widgets:
		var widget: Control = entry["script"].new()
		_slots[entry["slot"]].add_child(widget)
		if widget.has_method("setup"):
			widget.call("setup", self)


func open(_args: Dictionary) -> void:
	if not ui.game.board.hover_changed.is_connected(_on_hover):
		ui.game.board.hover_changed.connect(_on_hover)
	ui.game.board.clash_presenter = _present_clash
	_clips_button.text = "Clips: ON" if ui.setting("clash_clips", true) else "Clips: OFF"
	_last_info = {}
	_refresh()


func close() -> void:
	if _pulse:
		_pulse.kill()
	ui.game.board.clash_presenter = Callable()


func _refresh() -> void:
	if not GameSession.has_match():
		return
	var view := GameSession.match_view
	var my_side := GameSession.my_side()
	var players: Dictionary = view.get("players", {}) if view.get("players") is Dictionary else {}
	_set_pill(_you, _player_label(players.get(my_side), "You"), AppTheme.BLUE)
	_set_pill(_them, _player_label(players.get(Ranks.opponent(my_side)), "Waiting..."), AppTheme.PINK)

	var status := GameSession.status()
	_setup_row.visible = status in ["waiting", "setup"]
	_resign.visible = status in ["waiting", "setup", "active"]
	_taunt_button.visible = status in ["setup", "active"]
	if not _taunt_button.visible:
		_taunt_menu.visible = false
	_resign.text = "Leave" if status in ["waiting", "setup"] else "Resign"
	match status:
		"waiting":
			_set_turn("WAITING FOR OPPONENT", AppTheme.YELLOW, AppTheme.INK, false)
		"setup":
			var ready: bool = view.get("setup_ready", {}).get(my_side, false)
			_set_turn("READY! WAITING..." if ready else "ARRANGE YOUR ARMY", AppTheme.YELLOW, AppTheme.INK, false)
		"active":
			if GameSession.is_my_turn():
				_set_turn("YOUR TURN", AppTheme.PINK, Color.WHITE, true)
			else:
				_set_turn("OPPONENT'S TURN", AppTheme.BLUE, Color.WHITE, false)
		"finished":
			_set_turn("GAME OVER", AppTheme.PURPLE, Color.WHITE, false)
		"cancelled":
			_set_turn("CANCELLED", AppTheme.MUTED, Color.WHITE, false)


## Action buttons sit beside the board on landscape screens and below it on portrait phones, so
## they never cover a tile.
func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var portrait := screen.x < screen.y
	_actions.custom_minimum_size.x = 0.0 if portrait else 150.0
	if portrait:
		_actions.alignment = BoxContainer.ALIGNMENT_END
		_actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
		_actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		# A narrow column in the top-right corner, beside the board's far (narrower) rows.
		_actions.alignment = BoxContainer.ALIGNMENT_BEGIN
		_actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
		_actions.offset_top = 84.0
		_actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_actions.grow_vertical = Control.GROW_DIRECTION_END


func _player_label(player: Variant, fallback: String) -> String:
	if not player is Dictionary:
		return fallback
	var text := str(player.get("username", fallback))
	if player.has("elo"):
		text += "  %s" % AppTheme.num(player["elo"])
	return text


func _set_pill(pill: PanelContainer, text: String, color: Color) -> void:
	(pill.get_child(0) as Label).text = text
	var style := pill.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = color
	pill.add_theme_stylebox_override("panel", style)


func _set_turn(text: String, bg: Color, fg: Color, pulse: bool) -> void:
	_set_pill(_turn, text, bg)
	(_turn.get_child(0) as Label).add_theme_color_override("font_color", fg)
	if _pulse:
		_pulse.kill()
	_turn.pivot_offset = _turn.size * 0.5
	_turn.scale = Vector2.ONE
	if pulse:
		_pulse = _turn.create_tween().set_loops()
		_pulse.tween_property(_turn, "scale", Vector2.ONE * 1.08, 0.45).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_turn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func _on_hover(piece: Piece3D) -> void:
	if piece == null or not visible:
		_hint.visible = false
		return
	var text := "Unknown enemy piece"
	if piece.rank != "":
		text = Ranks.display_name(piece.rank)
	(_hint.get_child(0) as Label).text = text
	_hint.visible = true


func _ready_up() -> void:
	if GameSession.status() == "waiting":
		ui.toast("Waiting for someone to join first.", AppTheme.BLUE)
		return
	GameSession.submit_setup(ui.game.board.get_setup_placements())


func _ask_resign() -> void:
	if GameSession.status() in ["waiting", "setup"]:
		ui.confirm("Leave this match?", "Leave", _leave_match)
	else:
		ui.confirm("Resign and give the win to your opponent?", "Resign", func() -> void: GameSession.resign())


func _ask_leave() -> void:
	if GameSession.status() == "active" and GameSession.kind == GameSession.Kind.ONLINE:
		ui.confirm("Leaving resigns the match. Leave anyway?", "Leave", _leave_match)
	elif GameSession.status() == "active":
		ui.confirm("Quit this practice game?", "Quit", _leave_match)
	else:
		_leave_match()


func _leave_match() -> void:
	if GameSession.kind == GameSession.Kind.ONLINE and GameSession.status() in ["waiting", "setup", "active"]:
		await GameSession.resign()
	ui.back_to_menu()


func _on_game_over(info: Dictionary) -> void:
	_refresh()
	_last_info = info
	# Let the final clash, its battle clip and the rank reveal play out first.
	await get_tree().create_timer(0.5).timeout
	if ui.game.board.is_animating():
		await ui.game.board.animations_idle
	await get_tree().create_timer(0.7).timeout
	if visible and _last_info == info:
		_show_result_card()


func _show_result_card() -> void:
	_recap_run += 1
	var info := _last_info
	var won: bool = info.get("you_won", false)
	var card := AppTheme.card()
	var box := AppTheme.vbox(14)
	card.add_child(box)
	var title := AppTheme.label("VICTORY!" if won else "DEFEAT", "TitleLabel", 64)
	title.add_theme_color_override("font_color", AppTheme.YELLOW if won else AppTheme.BLUE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var reason := AppTheme.label(_reason_text(str(info.get("end_reason", "")), won), "", 22)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reason)
	var rating: Variant = info.get("rating")
	if rating is Dictionary and rating.get(GameSession.my_side()) is Dictionary:
		var mine: Dictionary = rating[GameSession.my_side()]
		var delta := int(mine.get("after", 0)) - int(mine.get("before", 0))
		box.add_child(AppTheme.pill("ELO %s  (%+d)" % [AppTheme.num(mine.get("after")), delta], AppTheme.MINT if delta >= 0 else AppTheme.RED))
	var practice := GameSession.kind == GameSession.Kind.PRACTICE
	box.add_child(AppTheme.button("Play again" if practice else "Back to lobby", "Primary", _play_again.bind(practice), 60))
	var clashes: Array = info.get("clashes", [])
	if not clashes.is_empty():
		box.add_child(AppTheme.button("Battle recap (%d)" % clashes.size(), "Accent", _show_recap, 54))
	box.add_child(AppTheme.button("Main menu", "Ghost", func() -> void: ui.back_to_menu(), 50))
	ui.show_overlay(AppTheme.centered(card, 420))
	AppTheme.pop_in(card)


## Every clash of the match with both ranks revealed; each row replays its battle clip.
func _show_recap() -> void:
	var clashes: Array = _last_info.get("clashes", [])
	var viewer := GameSession.my_side()
	var card := AppTheme.card()
	var box := AppTheme.vbox(12)
	card.add_child(box)
	var heading := AppTheme.label("Battle Recap", "HeadingLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var sub := AppTheme.label("Every clash, ranks revealed. Tap Watch to replay one.", "MutedLabel", 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 340
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := AppTheme.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	for clash: Dictionary in clashes:
		list.add_child(_recap_row(clash, viewer))
	var actions := AppTheme.hbox(10)
	var back := AppTheme.button("Back", "Ghost", _show_result_card, 52)
	var all := AppTheme.button("Watch all", "Primary", _watch_all, 52)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	actions.add_child(all)
	box.add_child(actions)
	ui.show_overlay(AppTheme.centered(card, 600))
	AppTheme.pop_in(card)


func _recap_row(clash: Dictionary, viewer: String) -> PanelContainer:
	var row := AppTheme.card("Row")
	var line := AppTheme.hbox(10)
	row.add_child(line)
	line.add_child(_mini_badge(str(clash["attacker"].get("rank", ""))))
	var text := AppTheme.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caption := AppTheme.label(ClashCutIn.caption_text(clash["attacker"], clash["defender"], str(clash.get("outcome")), viewer, true), "", 18)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(caption)
	text.add_child(AppTheme.label("Move %s" % AppTheme.num(clash.get("move_number", 0)), "MutedLabel", 15))
	line.add_child(text)
	line.add_child(_mini_badge(str(clash["defender"].get("rank", ""))))
	line.add_child(AppTheme.button("Watch", "Secondary", _watch.bind(clash), 44))
	return row


func _mini_badge(rank: String) -> TextureRect:
	var badge := TextureRect.new()
	badge.texture = PieceIcons.badge_or_mystery(rank)
	badge.custom_minimum_size = Vector2(52, 52)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge


func _watch(clash: Dictionary) -> void:
	await ui.play_clash(_recap_clip(clash))


func _watch_all() -> void:
	_recap_run += 1
	var run := _recap_run
	for clash: Dictionary in _last_info.get("clashes", []):
		if not visible or run != _recap_run:
			return  # Left the recap; stop the playlist.
		await ui.play_clash(_recap_clip(clash))


func _recap_clip(clash: Dictionary) -> Dictionary:
	return {"attacker": clash["attacker"], "defender": clash["defender"], "outcome": str(clash.get("outcome")),
		"viewer": GameSession.my_side(), "reveal": true}


## Live battle clip for a clash on the board. Only what this player knows is shown.
func _present_clash(data: Dictionary) -> void:
	if not visible or not ui.setting("clash_clips", true):
		return
	data["viewer"] = GameSession.my_side()
	data["reveal"] = false
	await ui.play_clash(data)


func _toggle_clips() -> void:
	var on: bool = not ui.setting("clash_clips", true)
	ui.set_setting("clash_clips", on)
	_clips_button.text = "Clips: ON" if on else "Clips: OFF"
	ui.toast("Battle clips %s" % ("on" if on else "off"))


func _play_again(practice: bool) -> void:
	ui.close_dialog()
	if practice:
		GameSession.start_practice(GameSession.practice_level)
	else:
		GameSession.leave()
		ui.game.show_attract()
		ui.show_screen("lobby")


func _reason_text(reason: String, won: bool) -> String:
	match reason:
		"flag_captured":
			return "You captured the enemy flag!" if won else "Your flag was captured."
		"flag_reached":
			return "Your flag made it across!" if won else "Their flag slipped through your lines."
		"resignation":
			return "Your opponent resigned." if won else "You resigned."
		"no_moves":
			return "Your opponent ran out of moves." if won else "You ran out of moves."
		"timeout":
			return "Your opponent ran out of time three turns in a row." if won else "You ran out of time three turns in a row."
	return ""


# --- Taunts ---------------------------------------------------------------------------------------

func _on_taunt(side: String, slug: String) -> void:
	if not visible:
		return
	if side != GameSession.my_side() and ui.setting("mute_taunts", false):
		return
	ui.game.throw_taunt(side, slug)


func _toggle_taunt_menu() -> void:
	_taunt_menu.visible = not _taunt_menu.visible
	if _taunt_menu.visible:
		_build_taunt_menu()


func _build_taunt_menu() -> void:
	for child in _taunt_menu.get_children():
		child.queue_free()
	var panel := AppTheme.card("Row")
	var box := AppTheme.vbox(6)
	panel.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var taunts := CosmeticCatalog.items("taunt")
	for slug: String in CosmeticCatalog.slugs("taunt"):
		if not Loadout.owns("taunt", slug):
			continue  # Only the taunts in the player's locker.
		var b := AppTheme.button(str(taunts[slug].get("name", slug)), "Ghost", _throw.bind(slug), 40)
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	box.add_child(grid)
	if grid.get_child_count() < CosmeticCatalog.slugs("taunt").size():
		var more := AppTheme.label("More taunts in the Shop!", "", 14, AppTheme.MUTED)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(more)
	var muted: bool = ui.setting("mute_taunts", false)
	var mute := AppTheme.button("Unmute their taunts" if muted else "Mute their taunts", "Ghost", _toggle_mute, 38)
	mute.add_theme_font_size_override("font_size", 15)
	box.add_child(mute)
	_taunt_menu.add_child(panel)


func _throw(slug: String) -> void:
	var problem: String = await GameSession.send_taunt(slug)
	if problem != "":
		ui.toast(problem, AppTheme.BLUE)
	else:
		_taunt_menu.visible = false


func _toggle_mute() -> void:
	var muted: bool = not ui.setting("mute_taunts", false)
	ui.set_setting("mute_taunts", muted)
	ui.toast("Opponent taunts muted" if muted else "Opponent taunts on")
	_build_taunt_menu()
