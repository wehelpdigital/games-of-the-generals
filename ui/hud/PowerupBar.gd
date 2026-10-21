extends VBoxContainer
## In-match powerups (HUD "left" slot): your 5 cards (hidden when the game has powerups off), the board-picking prompt for targeted ones,
## banners for what you learned and what the opponent used, and chips for intel and active effects.
## On portrait screens the cards shrink to an icon row so the board stays clear.

const RESULT_SECONDS := 5.0
const MAX_BANNERS := 2
const COLUMN_LETTERS := "ABCDEFGHI"

var _hud: Screen
var _fx: RulesFX
var _title: PanelContainer
var _cards: GridContainer
var _buttons: Dictionary = {}  # id -> Button
var _prompt: PanelContainer
var _prompt_label: Label
var _chips: HFlowContainer
var _banners: VBoxContainer
var _pending_id := ""
var _compact := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = 176
	_title = AppTheme.pill("POWERUPS", AppTheme.PURPLE, Color.WHITE, 15)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_title)
	_cards = GridContainer.new()
	_cards.add_theme_constant_override("h_separation", 6)
	_cards.add_theme_constant_override("v_separation", 6)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

	_prompt = AppTheme.card("Row")
	var prompt_box := AppTheme.vbox(6)
	_prompt.add_child(prompt_box)
	_prompt_label = AppTheme.label("", "", 16)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_box.add_child(_prompt_label)
	var cancel := AppTheme.button("Cancel", "Ghost", _cancel_targeting, 38)
	cancel.add_theme_font_size_override("font_size", 16)
	prompt_box.add_child(cancel)
	_prompt.visible = false
	add_child(_prompt)

	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 4)
	_chips.add_theme_constant_override("v_separation", 4)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chips)
	_banners = AppTheme.vbox(6)
	add_child(_banners)

	visible = false
	GameSession.rules_changed.connect(_refresh)
	GameSession.turn_changed.connect(_refresh)
	GameSession.match_loaded.connect(func(_view: Dictionary) -> void: _refresh())
	GameSession.powerup_result.connect(_on_result)
	GameSession.powerup_used.connect(_on_used)
	get_viewport().size_changed.connect(_layout)
	_layout()


func setup(hud: Screen) -> void:
	_hud = hud
	_attach_fx.call_deferred()  # The 3D game is handed to the UI after the HUD is built.


func _attach_fx() -> void:
	if _fx != null or _hud == null or _hud.ui == null or _hud.ui.game == null:
		return
	_fx = _hud.ui.game.rules_fx()
	_fx.target_picked.connect(_on_target_picked)
	_fx.targeting_changed.connect(_on_targeting_changed)


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var portrait := screen.x < screen.y
	_compact = portrait or screen.y < 560.0  # Phones: icon cards (a row in portrait, a column in landscape).
	_cards.columns = PowerupLibrary.MAX_SLOTS if portrait else 1
	custom_minimum_size.x = 0.0 if _compact else 176.0
	_title.visible = not _compact
	_refresh()


func _refresh() -> void:
	_attach_fx()
	var slots := GameSession.powerup_slots()
	visible = GameSession.has_match() and GameSession.status() == "active" and not slots.is_empty()
	if not visible:
		if _fx and _fx.is_targeting():
			_fx.cancel_targeting()
		return
	var ids: Array = slots.map(func(s: Dictionary) -> String: return str(s.get("id", "")))
	if ids != _buttons.keys():
		for child in _cards.get_children():
			child.queue_free()
		_buttons.clear()
		for id: String in ids:
			_buttons[id] = _card(id)
			_cards.add_child(_buttons[id])
	for slot: Dictionary in slots:
		var id := str(slot.get("id", ""))
		var b: Button = _buttons[id]
		var problem := GameSession.powerup_problem(id)
		var used: bool = slot.get("used", false)
		b.text = "" if _compact else (PowerupLibrary.display_name(id) + ("\nUSED" if used else ""))
		b.disabled = problem != ""
		b.modulate = Color(1, 1, 1, 0.45) if used else Color.WHITE
		b.tooltip_text = "%s\n%s%s" % [PowerupLibrary.display_name(id), PowerupLibrary.info(id).get("desc", ""),
			("\n\n" + problem) if problem != "" and not used else ""]
		b.custom_minimum_size = Vector2(56, 56) if _compact else Vector2(176, 50)
	_refresh_chips()


func _card(id: String) -> Button:
	var b := AppTheme.button(PowerupLibrary.display_name(id), "Ghost", _activate.bind(id), 50)
	b.icon = PowerupLibrary.icon(id)
	b.expand_icon = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 38)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _card_style(PowerupLibrary.color(id), false))
	b.add_theme_stylebox_override("hover", _card_style(PowerupLibrary.color(id).lightened(0.15), false))
	b.add_theme_stylebox_override("pressed", _card_style(PowerupLibrary.color(id), true))
	b.add_theme_stylebox_override("disabled", _card_style(Color("d9d4e6"), false))
	b.clip_text = true
	return b


func _card_style(color: Color, pressed: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.WHITE.lerp(color, 0.28)
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	s.border_width_bottom = 3 if pressed else 6
	s.border_color = AppTheme.INK
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6.0 + (3.0 if pressed else 0.0)
	s.content_margin_bottom = 6
	return s


func _activate(id: String) -> void:
	var problem := GameSession.powerup_problem(id)
	if problem != "":
		_toast(problem, AppTheme.BLUE)
		return
	if _fx and _fx.is_targeting():
		_fx.cancel_targeting()
	if PowerupLibrary.picks(id).is_empty():
		_use(id, {})
		return
	_pending_id = id
	_attach_fx()
	if _fx:
		_fx.begin_targeting(id)


func _use(id: String, target: Dictionary) -> void:
	var res: Dictionary = await GameSession.use_powerup(id, target)
	if not res.get("ok", false):
		_toast(str(res.get("error", "That didn't work.")), AppTheme.RED)


func _on_target_picked(target: Dictionary) -> void:
	var id := _pending_id
	_pending_id = ""
	if id != "":
		_use(id, target)


func _on_targeting_changed(prompt: String) -> void:
	_prompt.visible = prompt != ""
	_prompt_label.text = prompt
	if prompt == "":
		_pending_id = ""


func _cancel_targeting() -> void:
	if _fx:
		_fx.cancel_targeting()


# --- What you learned, what they did ------------------------------------------------------------

func _on_result(result: Dictionary) -> void:
	var id := str(result.get("id", ""))
	var p: Dictionary = result.get("private", {}) if result.get("private") is Dictionary else {}
	var text := ""
	match id:
		"spy_card", "intel_leak":
			text = "That piece is a %s!" % Ranks.display_name(str(p.get("rank", "")))
		"insight":
			text = "%d enemy officers still standing." % int(p.get("officers", 0))
		"recon_drone":
			text = "It IS their Flag!" if p.get("is_flag", false) else "Not the Flag."
		"scout_report":
			var names: Array = []
			for entry: Variant in p.get("pieces", []):
				if entry is Dictionary:
					names.append(PowerupLibrary.GROUP_NAMES.get(str(entry.get("group")), "?"))
			text = "Scouted: %s." % ", ".join(names)
		"flag_hunter":
			text = "Their Flag stands in column %s." % _column(int(p.get("x", 0)))
		"fortify":
			text = "Shield up for %d turns. They can't see it." % int(p.get("turns", PowerupLibrary.FORTIFY_TURNS))
		"decoy":
			text = "Their intel will say it's a %s." % Ranks.display_name(str(p.get("fake_rank", "")))
		"mine_field":
			text = "Mine buried for %d turns." % int(p.get("turns", PowerupLibrary.MINE_TURNS))
		"swap":
			text = "Swapped!"
		"teleport":
			text = "Teleported!"
		"reinforcement":
			text = "A Private rejoins the fight."
		"shuffle":
			text = "Two pieces traded ranks in secret."
		"time_extension":
			text = "+%d s on your next %d turns." % [int(p.get("seconds", 20)), int(p.get("turns", 3))]
		"time_squeeze":
			text = "Their next %d turns: %d s shorter." % [int(p.get("turns", 3)), absi(int(p.get("seconds", -15)))]
		"quick_step":
			text = "No clock on your next turn."
		"sabotage":
			text = "They can't use powerups for %d turns." % int(p.get("turns", 3))
		"freeze":
			text = "Frozen for %d of their turns." % int(p.get("turns", 2))
		"jammer":
			text = "Their chat and taunts are jammed."
		"smoke_screen":
			text = "Your next move will be hidden."
		"chaos_order":
			text = "Their next move will be random!"
		"double_march":
			text = "Move two different pieces this turn."
		"second_chance", "rally_cry":
			text = "Armed and ready."
	_banner(id, PowerupLibrary.display_name(id), text, true)


func _on_used(event: Dictionary) -> void:
	if event.get("mine", false):
		return
	var id := str(event.get("id", ""))
	var p: Dictionary = event.get("public", {}) if event.get("public") is Dictionary else {}
	var detail := ""
	match id:
		"time_extension":
			detail = "+%d s for their next %d turns." % [int(p.get("seconds", 20)), int(p.get("turns", 3))]
		"time_squeeze":
			detail = "Your next %d turns are shorter!" % int(p.get("turns", 3))
		"sabotage":
			detail = "No powerups for you for %d turns." % int(p.get("turns", 3))
		"freeze":
			detail = "One of your pieces is frozen."
		"jammer":
			detail = "Your chat and taunts are jammed."
		"smoke_screen":
			detail = "Their next move will be hidden."
		"chaos_order":
			detail = "Your next move will be random!"
		"scout_report":
			detail = "They scouted %d of your pieces." % int(p.get("count", 3))
		_:
			detail = str(PowerupLibrary.info(id).get("desc", ""))
	_banner(id, "Opponent: %s!" % PowerupLibrary.display_name(id), detail, false)


func _banner(id: String, heading: String, text: String, mine: bool) -> void:
	var card := AppTheme.card("Row")
	var row := AppTheme.hbox(8)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = PowerupLibrary.icon(id)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(icon)
	var words := AppTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label(heading, "", 15, AppTheme.INK if mine else AppTheme.RED)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 112
	words.add_child(title)
	if text != "":
		var body := AppTheme.label(text, "", 13)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 112
		words.add_child(body)
	row.add_child(words)
	card.custom_minimum_size.x = 176 if not _compact else 220
	_banners.add_child(card)
	_banners.move_child(card, 0)
	for old in _banners.get_children().slice(MAX_BANNERS):
		_banners.remove_child(old)
		old.queue_free()
	AppTheme.pop_in(card)
	var t := card.create_tween()
	t.tween_interval(RESULT_SECONDS)
	t.tween_property(card, "modulate:a", 0.0, 0.4)
	t.tween_callback(card.queue_free)


## Standing intel (Insight, Flag Hunter) and effects in play, as small chips.
func _refresh_chips() -> void:
	for chip in _chips.get_children():
		chip.queue_free()
	var officers: Variant = null
	var column: Variant = null
	for entry: Variant in GameSession.intel():
		if entry is Dictionary:
			if entry.get("type") == "insight":
				officers = entry.get("officers")
			elif entry.get("type") == "flag_hunter":
				column = entry.get("x")
	if officers != null:
		_chip("Officers: %d" % int(officers), AppTheme.BLUE)
	if column != null:
		_chip("Flag: col %s" % _column(int(column)), AppTheme.PINK)
	var fx := GameSession.effects()
	for e: Variant in fx.get("mine", []):
		if not e is Dictionary:
			continue
		match str(e.get("type")):
			"fortify":
				_chip("Shield %s" % _turns(e), AppTheme.GOLD)
			"decoy":
				_chip("Decoy", AppTheme.PURPLE)
			"second_chance":
				_chip("2nd chance", AppTheme.MINT)
			"rally_cry":
				_chip("Rally ready", AppTheme.GOLD)
			"smoke_screen":
				_chip("Smoke on" if e.get("active") else "Smoke armed", AppTheme.PURPLE)
			"chaos_order":
				_chip("Chaos armed", AppTheme.PURPLE)
			"double_march":
				_chip("March: 2nd move" if e.get("first_piece_id") != null else "March: 2 moves", AppTheme.PINK)
	var mines := GameSession.my_mines().size()
	if mines > 0:
		_chip("Mines: %d" % mines, AppTheme.RED)
	for e: Variant in fx.get("opponent", []):
		if not e is Dictionary:
			continue
		match str(e.get("type")):
			"freeze":
				_chip("Frozen %s" % _turns(e), Color("5fc8ff"))
			"time_squeeze":
				_chip("Squeezed %s" % _turns(e), AppTheme.RED)
			"sabotage":
				_chip("Sabotaged %s" % _turns(e), AppTheme.RED)
			"jammer":
				_chip("Jammed", AppTheme.RED)
			"chaos_order":
				_chip("Chaos incoming!", AppTheme.RED)
			"smoke_screen":
				_chip("Smoke!", AppTheme.MUTED)
	_chips.visible = _chips.get_child_count() > 0


func _chip(text: String, color: Color) -> void:
	_chips.add_child(AppTheme.pill(text, color, Color.WHITE, 13))


func _turns(effect: Dictionary) -> String:
	return "(%d)" % int(effect["turns_left"]) if effect.get("turns_left") != null else ""


func _column(x: int) -> String:
	return COLUMN_LETTERS[clampi(x, 0, COLUMN_LETTERS.length() - 1)]


func _toast(text: String, color: Color) -> void:
	if _hud and _hud.ui:
		_hud.ui.toast(text, color)
