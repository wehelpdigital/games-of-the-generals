extends VBoxContainer
## In-match powerups (HUD "left" slot) as a hand of trading cards (hidden when the game has powerups
## off). Tap a card to raise it and see it big, then tap it again (or Play) to use it, or to pick
## its target on the board. Played cards slam, then grey out face down; the opponent's cards flip
## up big for a moment.
##
## Landscape: a cascade of cards down the left column (a two-column grid of small cards on short
## screens). Portrait: a row of small cards under the board, above the action buttons. What you
## learned and what they did shows away from the board (under the turn banner in portrait, bottom
## right in landscape), and the effects in play fold into an "Effects" tray.

enum Mode { COLUMN, GRID, ROW }

const RESULT_SECONDS := 5.0
const OPPONENT_CARD_SECONDS := 1.3
const COLUMN_LETTERS := "ABCDEFGHI"
const COLUMN_CARD_WIDTH := 150.0
const BANNER_WIDTH := 236.0

var _hud: Screen
var _fx: RulesFX
var _mode := Mode.COLUMN
var _header: HBoxContainer
var _title: PanelContainer
var _effects_button: Button
var _hand: Control
var _cards: Dictionary = {}  # id -> PowerupCard, in slot order
var _raised: PowerupCard
var _shown: PowerupCard  # The card the big view shows (raised, or hovered on desktop).
var _playing := ""  # The card whose slam is still running (its flip waits).
var _prompt: PanelContainer
var _prompt_card: PowerupCard
var _prompt_label: Label
var _pending_id := ""
var _chip_count := 0
var _hand_top := -1.0  # Where the hand started when it was last laid out.
# The overlay over the whole HUD, outside this column: banners, the inspected card (with a dimmer
# that closes it), the effects tray and the opponent's played card.
var _layer: Control
var _dimmer: ColorRect
var _inspect: VBoxContainer
var _inspect_card: PowerupCard
var _inspect_note: PanelContainer
var _inspect_buttons: HBoxContainer
var _play: Button
var _banners: VBoxContainer
var _tray: PanelContainer
var _chips: VBoxContainer
var _stage: Control


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header = AppTheme.hbox(8)
	add_child(_header)
	_title = AppTheme.pill("POWERUPS", AppTheme.PURPLE, Color.WHITE, 14)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_title)
	_header.add_child(AppTheme.spacer())
	_effects_button = AppTheme.button("Effects", "Ghost", _toggle_tray, 36)
	_effects_button.add_theme_font_size_override("font_size", 15)
	_header.add_child(_effects_button)
	_hand = Control.new()
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.item_rect_changed.connect(_on_hand_moved)
	add_child(_hand)

	_prompt = AppTheme.card("Row")
	var prompt_row := AppTheme.hbox(10)
	_prompt.add_child(prompt_row)
	_prompt_card = _still_card("", 54)
	_prompt_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_card)
	var prompt_box := AppTheme.vbox(6)
	prompt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_row.add_child(prompt_box)
	_prompt_label = AppTheme.label("", "", 16)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.custom_minimum_size.x = 110
	prompt_box.add_child(_prompt_label)
	var cancel := AppTheme.button("Cancel", "Ghost", _cancel_targeting, 38)
	cancel.add_theme_font_size_override("font_size", 16)
	prompt_box.add_child(cancel)
	_prompt.visible = false
	add_child(_prompt)

	_build_overlay()
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
	hud.add_child.call_deferred(_layer)  # Last, so it draws over the other HUD widgets.
	_attach_fx.call_deferred()  # The 3D game is handed to the UI after the HUD is built.
	_layout.call_deferred()


func _attach_fx() -> void:
	if _fx != null or _hud == null or _hud.ui == null or _hud.ui.game == null:
		return
	_fx = _hud.ui.game.rules_fx()
	_fx.target_picked.connect(_on_target_picked)
	_fx.targeting_changed.connect(_on_targeting_changed)


func _build_overlay() -> void:
	_layer = Control.new()
	_layer.name = "PowerupOverlay"
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.visible = false
	_dimmer = ColorRect.new()
	_dimmer.color = Color(AppTheme.INK, 0.3)
	_dimmer.visible = false
	_dimmer.gui_input.connect(_on_dimmer_input)
	_layer.add_child(_dimmer)
	_banners = AppTheme.vbox(6)
	_layer.add_child(_banners)

	_tray = AppTheme.card("Row")
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips = AppTheme.vbox(5)
	_tray.add_child(_chips)
	_tray.visible = false
	_layer.add_child(_tray)

	_inspect = AppTheme.vbox(8)
	_inspect.visible = false
	_inspect_card = _still_card("", 220)
	_inspect_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inspect.add_child(_inspect_card)
	_inspect_note = AppTheme.pill("", AppTheme.INK, Color.WHITE, 15)
	_inspect_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inspect.add_child(_inspect_note)
	_inspect_buttons = AppTheme.hbox(8)
	_play = AppTheme.button("Play it!", "Primary", _play_raised, 50)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.add_theme_font_size_override("font_size", 20)
	_inspect_buttons.add_child(_play)
	var close := AppTheme.button("Close", "Ghost", _lower, 50)
	close.add_theme_font_size_override("font_size", 18)
	_inspect_buttons.add_child(close)
	_inspect.add_child(_inspect_buttons)
	_layer.add_child(_inspect)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_stage)


## A card that only shows (no hover, no taps).
func _still_card(id: String, width: float) -> PowerupCard:
	var card := PowerupCard.new(id, width)
	card.interactive = false
	card.hover_lift = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


# --- Layout --------------------------------------------------------------------------------------

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	if screen.x < screen.y:
		_mode = Mode.ROW
	elif screen.y < 560.0 or screen.x / screen.y < 1.5:
		_mode = Mode.GRID  # Short, or squarish (the board then reaches further left): small cards.
	else:
		_mode = Mode.COLUMN
	_title.visible = _mode != Mode.ROW
	_place_cards()
	_refresh()
	_place_overlay.call_deferred()


## Lays the hand out for the mode: a cascade (each card shows its name and the top of its art, the
## last one whole), a grid, or a row.
func _place_cards() -> void:
	var cards: Array = _cards.values()
	var n := maxi(cards.size(), 1)
	var screen := get_viewport().get_visible_rect().size
	# Where the hand starts (the column sits under the top bar, with the header above the cards).
	var top := _hand.get_global_rect().position.y if _hand.is_inside_tree() and _hand.get_global_rect().position.y > 0.0 else 130.0
	_hand_top = top
	match _mode:
		Mode.ROW:
			var gap := 8.0
			var w := floorf(clampf((minf(screen.x, 600.0) - 24.0 - gap * (n - 1)) / n, 52.0, 104.0))
			for i in cards.size():
				_put(cards[i], w, Vector2(i * (w + gap), 0), Vector2.UP)
			_hand.custom_minimum_size = Vector2(n * w + (n - 1) * gap, roundf(w * PowerupCard.ASPECT))
			_prompt.custom_minimum_size.x = _hand.custom_minimum_size.x
		Mode.GRID:
			# Two columns, as tall as the screen allows.
			var gap := 6.0
			var rows := ceili(n / 2.0)
			var w := floorf(clampf((screen.y - top - 10.0 - gap * (rows - 1)) / rows / PowerupCard.ASPECT, 44.0, 80.0))
			var h := roundf(w * PowerupCard.ASPECT)
			for i in cards.size():
				_put(cards[i], w, Vector2((i % 2) * (w + gap), (i / 2) * (h + gap)), Vector2.UP)
			_hand.custom_minimum_size = Vector2(w * 2.0 + gap, rows * h + (rows - 1) * gap)
			_prompt.custom_minimum_size.x = 200.0
		Mode.COLUMN:
			var w := floorf(clampf(screen.x * 0.118, 112.0, COLUMN_CARD_WIDTH))  # Narrower where the board fills the width (tablets).
			var h := roundf(w * PowerupCard.ASPECT)
			# Room down to the Reset view button in the bottom-left corner.
			var room := screen.y - top - 70.0
			var step := clampf((room - h) / maxf(n - 1, 1), 44.0, h + 8.0)
			for i in cards.size():
				_put(cards[i], w, Vector2(0, i * step), Vector2.RIGHT)
			_hand.custom_minimum_size = Vector2(w + 20.0, h + step * (n - 1))
			_prompt.custom_minimum_size.x = 200.0


## The HUD moved the column (rotation, header shown or hidden): the room for the cards changed.
func _on_hand_moved() -> void:
	if _hand.is_inside_tree() and absf(_hand.get_global_rect().position.y - _hand_top) > 0.5 and _mode != Mode.ROW:
		_place_cards.call_deferred()


func _put(card: PowerupCard, width: float, at: Vector2, lift: Vector2) -> void:
	card.lift_direction = lift
	card.set_card_width(width)
	card.position = at


func _place_overlay() -> void:
	if not _layer.is_inside_tree():
		return
	var screen := _layer.size
	if _mode == Mode.ROW:
		_banners.custom_minimum_size.x = minf(screen.x - 24.0, 400.0)
		_banners.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, _top_reserved() + 8.0)
		_banners.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_banners.grow_vertical = Control.GROW_DIRECTION_END
	else:
		# Bottom right, above the chat buttons and under the action column; older banners give way
		# when they don't fit.
		_banners.custom_minimum_size.x = BANNER_WIDTH if _mode == Mode.COLUMN else 210.0
		var room := screen.y - 84.0 - (_right_reserved() + 10.0)
		while _banners.get_child_count() > 1 and _banners.get_combined_minimum_size().y > room:
			var oldest := _banners.get_child(_banners.get_child_count() - 1)
			_banners.remove_child(oldest)
			oldest.queue_free()
		_banners.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
		_banners.offset_bottom = -84.0
		_banners.offset_top = _banners.offset_bottom - _banners.get_combined_minimum_size().y
		_banners.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_banners.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if _inspect.visible:
		_place_inspect()
	if _tray.visible:
		_place_tray()


func _top_reserved() -> float:
	return _hud.top_reserved() if _hud and _hud.has_method("top_reserved") else 120.0


func _right_reserved() -> float:
	return _hud.right_reserved() if _hud and _hud.has_method("right_reserved") else 240.0


## The inspected card: above the hand in portrait (as big as the room allows), beside the column
## in landscape, next to the card it shows.
func _place_inspect() -> void:
	var screen := _layer.size
	var hand := _hand.get_global_rect()
	var extras := (58.0 if _inspect_buttons.visible else 0.0) + (40.0 if _inspect_note.visible else 0.0)
	if _mode == Mode.ROW:
		var room := hand.position.y - 14.0 - (_top_reserved() + 6.0) - extras
		_inspect_card.set_card_width(floorf(clampf(minf(screen.x * 0.64, room / PowerupCard.ASPECT), 140.0, 290.0)))
	else:
		var room := screen.y - 90.0 - extras
		_inspect_card.set_card_width(floorf(clampf(room / PowerupCard.ASPECT, 150.0, 250.0)))
	_inspect.custom_minimum_size.x = maxf(_inspect_card.custom_minimum_size.x, 230.0 if _inspect_buttons.visible else 0.0)
	var size := _inspect.get_combined_minimum_size()
	_inspect.size = size
	if _mode == Mode.ROW:
		_inspect.position = Vector2(floorf((screen.x - size.x) / 2.0), maxf(hand.position.y - 14.0 - size.y, 8.0))
		_dimmer.position = Vector2.ZERO
		_dimmer.size = Vector2(screen.x, maxf(hand.position.y - 6.0, 0.0))
	else:
		var anchor := _shown.get_global_rect() if _shown and is_instance_valid(_shown) else hand
		var y := clampf(anchor.position.y - 20.0, 64.0, maxf(screen.y - size.y - 12.0, 64.0))
		_inspect.position = Vector2(hand.end.x + 24.0, floorf(y))
		_dimmer.position = Vector2(hand.end.x + 6.0, 0)
		_dimmer.size = Vector2(maxf(screen.x - hand.end.x - 6.0, 0.0), screen.y)


func _place_tray() -> void:
	var screen := _layer.size
	var b := _effects_button.get_global_rect()
	var size := _tray.get_combined_minimum_size()
	_tray.size = size
	if _mode == Mode.ROW:
		_tray.position = Vector2(clampf(b.end.x - size.x, 12.0, screen.x - size.x - 12.0), maxf(b.position.y - 8.0 - size.y, 8.0))
	else:
		_tray.position = Vector2(b.end.x + 10.0, clampf(b.position.y, 8.0, maxf(screen.y - size.y - 8.0, 8.0)))


# --- The hand ------------------------------------------------------------------------------------

func _refresh() -> void:
	_attach_fx()
	var slots := GameSession.powerup_slots()
	visible = GameSession.has_match() and GameSession.status() == "active" and not slots.is_empty()
	_layer.visible = visible
	if not visible:
		if _fx and _fx.is_targeting():
			_fx.cancel_targeting()
		_lower()
		return
	var ids: Array = slots.map(func(s: Dictionary) -> String: return str(s.get("id", "")))
	var fresh := ids != _cards.keys()
	if fresh:
		_lower()
		for card: PowerupCard in _cards.values():
			card.queue_free()
		_cards.clear()
		for id: String in ids:
			var card := PowerupCard.new(id, 80)
			card.pressed.connect(_on_card_pressed)
			card.mouse_entered.connect(_preview.bind(card, true))
			card.mouse_exited.connect(_preview.bind(card, false))
			_cards[id] = card
			_hand.add_child(card)
		_place_cards()
	for slot: Dictionary in slots:
		var id := str(slot.get("id", ""))
		var card: PowerupCard = _cards[id]
		var used: bool = slot.get("used", false)
		if id == _playing or (card.used == used and not fresh):
			continue
		card.used = used
		card.flip(used, 0.0 if fresh else 0.45)  # Spent cards lie face down; Recall turns one back up.
		if used and card == _raised:
			_lower()
	if _raised and _inspect.visible:
		_show_inspect(_raised, true)  # Turns change what may be played.
	_refresh_chips()


func _on_card_pressed(card: PowerupCard) -> void:
	if _fx and _fx.is_targeting():
		_cancel_targeting()
	if card == _raised:
		_activate(card.id)
	else:
		_raise(card)


func _raise(card: PowerupCard) -> void:
	if _raised and _raised != card and is_instance_valid(_raised):
		_raised.selected = false
	_raised = card
	card.selected = true
	_tray.visible = false
	_show_inspect(card, true)


func _lower() -> void:
	if _raised and is_instance_valid(_raised):
		_raised.selected = false
	_raised = null
	_inspect.visible = false
	_dimmer.visible = false


## Desktop: hovering a card shows it big until a card is raised.
func _preview(card: PowerupCard, inside: bool) -> void:
	if _raised != null or UiScale.is_handheld() or DisplayServer.is_touchscreen_available():
		return
	if inside:
		_show_inspect(card, false)
	else:
		_inspect.visible = false


## Shows `card` big; `chosen` adds Play / Close (and why it can't be played right now).
func _show_inspect(card: PowerupCard, chosen: bool) -> void:
	if not _layer.is_inside_tree():
		return
	_shown = card
	_inspect_card.set_id(card.id)
	_inspect_card.used = card.used
	var problem := GameSession.powerup_problem(card.id)
	_inspect_buttons.visible = chosen
	_inspect_note.visible = chosen and problem != ""
	AppTheme.set_pill(_inspect_note, problem, AppTheme.INK)
	_play.disabled = problem != ""
	_play.text = "Pick a target" if not PowerupLibrary.picks(card.id).is_empty() else "Play it!"
	_dimmer.visible = chosen
	var was_visible := _inspect.visible
	_inspect.visible = true
	_place_inspect()
	if not was_visible:
		AppTheme.pop_in(_inspect)


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_lower()
		_dimmer.accept_event()


func _play_raised() -> void:
	if _raised:
		_activate(_raised.id)


func _activate(id: String) -> void:
	var problem := GameSession.powerup_problem(id)
	if problem != "":
		_toast(problem, AppTheme.BLUE)
		return
	if _fx and _fx.is_targeting():
		_fx.cancel_targeting()
	_inspect.visible = false
	_dimmer.visible = false
	_tray.visible = false
	if PowerupLibrary.picks(id).is_empty():
		_use(id, {})
		return
	_pending_id = id
	_prompt_card.set_id(id)
	_attach_fx()
	if _fx:
		_fx.begin_targeting(id)


func _use(id: String, target: Dictionary) -> void:
	var card: PowerupCard = _cards.get(id)
	_playing = id
	var res: Dictionary = await GameSession.use_powerup(id, target)
	if not res.get("ok", false):
		_playing = ""
		_toast(str(res.get("error", "That didn't work.")), AppTheme.RED)
		return
	if card and is_instance_valid(card):
		await card.slam()
	_playing = ""
	_lower()
	_refresh()


func _on_target_picked(target: Dictionary) -> void:
	var id := _pending_id
	_pending_id = ""
	if id != "":
		_use(id, target)


func _on_targeting_changed(prompt: String) -> void:
	var targeting := prompt != ""
	_prompt.visible = targeting
	_prompt_label.text = prompt
	_hand.visible = not targeting
	_header.visible = not targeting and (_title.visible or _effects_button.visible)
	if not targeting and _playing == "":
		_lower()


func _cancel_targeting() -> void:
	_pending_id = ""
	if _fx:
		_fx.cancel_targeting()


# --- What you learned, what they did ------------------------------------------------------------

func _on_result(result: Dictionary) -> void:
	var id := str(result.get("id", ""))
	var p: Dictionary = result.get("private", {}) if result.get("private") is Dictionary else {}
	if p.get("countered", false):
		_banner(id, "Countered!", "Their Counterspell made your %s fizzle." % PowerupLibrary.display_name(id), false)
		return
	var text := ""
	match id:
		"spy_card", "intel_leak", "interrogation":
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
		"sonar_ping":
			var count := int(p.get("count", 0))
			text = "%d enemy %s on your half." % [count, "piece is" if count == 1 else "pieces are"]
		"spy_alarm":
			text = "A Spy stands right next to your pieces!" if p.get("alarm", false) else "No Spy next to your pieces."
		"radar_sweep":
			text = "A General is in that area!" if p.get("found", false) else "No General in that area."
		"code_breaker":
			var cards: Array = []
			for card: Variant in p.get("cards", []):
				cards.append(PowerupLibrary.display_name(str(card)))
			text = ("Their hand: %s." % ", ".join(cards)) if not cards.is_empty() else "Their hand is empty."
		"fortify":
			text = "Shield up for %d turns. They can't see it." % int(p.get("turns", PowerupLibrary.FORTIFY_TURNS))
		"decoy":
			text = "Their intel will say it's a %s." % Ranks.display_name(str(p.get("fake_rank", "")))
		"mine_field":
			text = "Mine buried for %d turns." % int(p.get("turns", PowerupLibrary.MINE_TURNS))
		"quicksand":
			text = "Quicksand hidden for %d turns." % int(p.get("turns", PowerupLibrary.QUICKSAND_TURNS))
		"roadblock":
			text = "Roadblock up for %d of their turns." % int(p.get("turns", PowerupLibrary.ROADBLOCK_TURNS))
		"trench":
			text = "Dug in for %d turns." % int(p.get("turns", PowerupLibrary.TRENCH_TURNS))
		"swap":
			text = "Swapped!"
		"teleport":
			text = "Teleported!"
		"retreat":
			text = "Fell back to safety."
		"reinforcement":
			text = "A Private rejoins the fight."
		"shuffle":
			text = "Two pieces traded ranks in secret."
		"promotion":
			text = "Promoted to Sergeant. Their intel on it is gone."
		"counter_intel":
			var wiped := int(p.get("wiped", 0))
			text = "Their reads on %d of your pieces are gone." % wiped if wiped > 0 else "They knew nothing yet."
		"recall":
			text = "%s is back in your hand!" % PowerupLibrary.display_name(str(p.get("recalled", "")))
		"time_extension":
			text = "+%d s on your next %d turns." % [int(p.get("seconds", 20)), int(p.get("turns", 3))]
		"time_squeeze":
			text = "Their next %d turns: %d s shorter." % [int(p.get("turns", 3)), absi(int(p.get("seconds", -15)))]
		"time_steal":
			text = "%d s stolen from each of their next %d turns." % [int(p.get("seconds", 10)), int(p.get("turns", 2))]
		"blitz":
			text = "Lightning round: both sides get half the time for %d turns." % int(p.get("turns", 2))
		"quick_step":
			text = "No clock on your next turn."
		"haste":
			text = "This turn one piece may dash 2 squares."
		"ceasefire":
			text = "They can't attack on their next turn."
		"counterspell":
			text = "Set. Their next powerup fizzles."
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
	var countered: bool = event.get("countered", false) or p.get("countered", false)
	var detail := ""
	match id:
		"time_extension":
			detail = "+%d s for their next %d turns." % [int(p.get("seconds", 20)), int(p.get("turns", 3))]
		"time_squeeze":
			detail = "Your next %d turns are shorter!" % int(p.get("turns", 3))
		"time_steal":
			detail = "They steal %d s from your next %d turns!" % [int(p.get("seconds", 10)), int(p.get("turns", 2))]
		"blitz":
			detail = "Both sides get half the time for %d turns!" % int(p.get("turns", 2))
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
		"retreat":
			detail = "One of their pieces fell back."
		"roadblock":
			detail = "A roadblock bars a square for %d turns." % int(p.get("turns", PowerupLibrary.ROADBLOCK_TURNS))
		"haste":
			detail = "One of their pieces may dash 2 squares."
		"ceasefire":
			detail = "You can't attack on your next turn!"
		"counter_intel":
			detail = "Your reads on %d of their pieces are gone!" % int(p.get("wiped", 0))
		"recall":
			detail = "They took %s back into their hand!" % PowerupLibrary.display_name(str(p.get("recalled", "")))
		_:
			detail = str(PowerupLibrary.info(id).get("desc", ""))
	var card_name := PowerupLibrary.display_name(id)
	if countered:
		_show_opponent_card(id, "Countered! %s fizzled" % card_name, true)
		_banner(id, "Their %s fizzled!" % card_name, "Your Counterspell stopped it.", true)
		return
	_show_opponent_card(id, "Opponent played %s!" % card_name, false)
	_banner(id, "Opponent: %s!" % card_name, detail, false)


## The opponent's card: face down in the middle of the screen, it flips up, holds a moment, then
## flies off toward their name.
func _show_opponent_card(id: String, caption: String, countered: bool) -> void:
	if not _layer.is_inside_tree() or not PowerupLibrary.info(id).size():
		return
	for old in _stage.get_children():
		old.queue_free()
	var screen := _layer.size
	var holder := AppTheme.vbox(10)
	var card := _still_card(id, floorf(clampf(minf(screen.x * 0.46, screen.y * 0.3), 130.0, 230.0)))
	card.face_down = true
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(card)
	var pill := AppTheme.pill(caption, AppTheme.PURPLE if countered else AppTheme.RED, Color.WHITE, 17 if screen.x < 520.0 else 20)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(pill)
	_stage.add_child(holder)
	var size := holder.get_combined_minimum_size()
	holder.size = size
	holder.position = ((screen - size) / 2.0).floor()
	holder.pivot_offset = size / 2.0
	holder.scale = Vector2.ONE * 0.4
	holder.modulate.a = 0.0
	var t := holder.create_tween().set_parallel()
	t.tween_property(holder, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "modulate:a", 1.0, 0.18)
	await t.finished
	await card.flip(false, 0.36)
	if not is_instance_valid(card):
		return
	if countered:
		card.used = true
	else:
		card.slam()
	await get_tree().create_timer(OPPONENT_CARD_SECONDS).timeout
	if not is_instance_valid(holder):
		return
	var out := holder.create_tween().set_parallel()
	out.tween_property(holder, "modulate:a", 0.0, 0.32)
	out.tween_property(holder, "scale", Vector2.ONE * 0.35, 0.32).set_trans(Tween.TRANS_SINE)
	out.tween_property(holder, "position", Vector2(screen.x - size.x * 0.7, -size.y * 0.3), 0.32).set_trans(Tween.TRANS_SINE)
	out.chain().tween_callback(holder.queue_free)


func _banner(id: String, heading: String, text: String, mine: bool) -> void:
	var width := _banners.custom_minimum_size.x
	var card := AppTheme.card("Row")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := AppTheme.hbox(10)
	card.add_child(row)
	row.add_child(_thumb(id))
	var words := AppTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text_width := maxf(width - 96.0, 100.0)
	var title := AppTheme.label(heading, "", 16, AppTheme.INK if mine else AppTheme.RED)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = text_width
	words.add_child(title)
	if text != "":
		var body := AppTheme.label(text, "", 14)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = text_width
		words.add_child(body)
	row.add_child(words)
	_banners.add_child(card)
	_banners.move_child(card, 0)
	for old in _banners.get_children().slice(1 if _mode == Mode.ROW else 2):
		_banners.remove_child(old)
		old.queue_free()
	_place_overlay()
	AppTheme.pop_in(card)
	var t := card.create_tween()
	t.tween_interval(RESULT_SECONDS)
	t.tween_property(card, "modulate:a", 0.0, 0.4)
	t.tween_callback(_drop_banner.bind(card))


func _drop_banner(card: Control) -> void:
	if card.get_parent() == _banners:
		_banners.remove_child(card)
	card.queue_free()
	_place_overlay()


## A small framed crop of the card's art for banners.
func _thumb(id: String) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PowerupLibrary.dark_color(id)
	style.set_corner_radius_all(9)
	style.set_border_width_all(2)
	style.border_color = AppTheme.INK
	style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art := TextureRect.new()
	var tex := PowerupCard.art(id)
	art.texture = tex if tex else PowerupLibrary.icon(id)
	art.custom_minimum_size = Vector2(52, 39)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	return frame


# --- Effects tray --------------------------------------------------------------------------------

func _toggle_tray() -> void:
	_tray.visible = not _tray.visible
	if _tray.visible:
		_lower()
		_place_tray()
		AppTheme.pop_in(_tray)


func _refresh_chips() -> void:
	var chips := _chip_list()
	for chip in _chips.get_children():
		_chips.remove_child(chip)
		chip.queue_free()
	for c: Array in chips:
		var pill := AppTheme.pill(c[0], c[1], Color.WHITE, 14)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_chips.add_child(pill)
	_effects_button.text = "Effects %d" % chips.size()
	_effects_button.visible = not chips.is_empty()
	if chips.size() > _chip_count and _effects_button.is_visible_in_tree():
		AppTheme.pop_in(_effects_button)
	_chip_count = chips.size()
	_header.visible = not _prompt.visible and (_title.visible or _effects_button.visible)
	if chips.is_empty():
		_tray.visible = false
	elif _tray.visible:
		_place_tray()


## Standing intel and the effects in play, as [text, colour] chips.
func _chip_list() -> Array:
	var chips: Array = []
	var intel := {}
	for entry: Variant in GameSession.intel():
		if entry is Dictionary:
			intel[str(entry.get("type"))] = entry  # The latest of each kind.
	if intel.has("insight"):
		chips.append(["Officers left: %d" % int(intel["insight"].get("officers", 0)), AppTheme.BLUE])
	if intel.has("flag_hunter"):
		chips.append(["Flag: column %s" % _column(int(intel["flag_hunter"].get("x", 0))), AppTheme.PINK])
	if intel.has("sonar_ping"):
		chips.append(["Sonar: %d on your half" % int(intel["sonar_ping"].get("count", 0)), AppTheme.BLUE])
	if intel.has("spy_alarm"):
		var alarm: bool = intel["spy_alarm"].get("alarm", false)
		chips.append(["Spy alarm!" if alarm else "No Spy nearby", AppTheme.RED if alarm else AppTheme.MINT])
	if intel.has("radar_sweep"):
		chips.append(["Radar: General found!" if intel["radar_sweep"].get("found", false) else "Radar: no General", AppTheme.PURPLE])
	if intel.has("code_breaker"):
		for card: Variant in intel["code_breaker"].get("cards", []):
			chips.append(["They hold %s" % PowerupLibrary.display_name(str(card)), AppTheme.PURPLE])
	var me := GameSession.my_side()
	var fx := GameSession.effects()
	var shown := {}
	for e: Variant in fx.get("mine", []):
		if not e is Dictionary:
			continue
		var type := str(e.get("type"))
		match type:
			"fortify":
				chips.append(["Shield %s" % _turns(e), AppTheme.GOLD])
			"trench":
				chips.append(["Dug in %s" % _turns(e), AppTheme.GOLD])
			"decoy":
				chips.append(["Decoy", AppTheme.PURPLE])
			"second_chance":
				chips.append(["2nd chance", AppTheme.MINT])
			"rally_cry":
				chips.append(["Rally ready", AppTheme.GOLD])
			"haste":
				chips.append(["Haste: dash 2", AppTheme.MINT])
			"quick_step":
				chips.append(["No clock", AppTheme.MINT])
			"time_extension":
				chips.append(["+%d s %s" % [int(e.get("seconds", 20)), _turns(e)], AppTheme.MINT])
			"smoke_screen":
				chips.append(["Smoke on" if e.get("active") else "Smoke armed", AppTheme.PURPLE])
			"chaos_order":
				chips.append(["Chaos armed", AppTheme.PURPLE])
			"counterspell":
				chips.append(["Counterspell set", AppTheme.PURPLE])
			"double_march":
				chips.append(["March: 2nd move" if e.get("first_piece_id") != null else "March: 2 moves", AppTheme.PINK])
			"freeze":
				chips.append(["Froze one %s" % _turns(e), Color("5fc8ff")])
			"roadblock":
				chips.append(["Roadblock %s" % _turns(e), AppTheme.PINK])
			"ceasefire":
				chips.append(["Ceasefire on them", AppTheme.PINK])
			"sabotage":
				chips.append(["Sabotaging %s" % _turns(e), AppTheme.PINK])
			"time_squeeze":
				chips.append(["Squeezing %s" % _turns(e), AppTheme.PINK])
			"jammer":
				chips.append(["Jammed them", AppTheme.PINK])
			"blitz", "time_steal":
				if str(e.get("side")) == me and not shown.has(type):
					shown[type] = true
					chips.append(["Blitz %s" % _turns(e) if type == "blitz" else "+%d s %s" % [int(e.get("seconds", 10)), _turns(e)], AppTheme.YELLOW])
	for e: Variant in fx.get("opponent", []):
		if not e is Dictionary:
			continue
		var type := str(e.get("type"))
		match type:
			"freeze":
				chips.append(["Frozen %s" % _turns(e), Color("5fc8ff")])
			"time_squeeze":
				chips.append(["Squeezed %s" % _turns(e), AppTheme.RED])
			"sabotage":
				chips.append(["Sabotaged %s" % _turns(e), AppTheme.RED])
			"jammer":
				chips.append(["Jammed", AppTheme.RED])
			"chaos_order":
				chips.append(["Chaos incoming!", AppTheme.RED])
			"smoke_screen":
				chips.append(["Smoke!", AppTheme.MUTED])
			"double_march":
				chips.append(["They march twice", AppTheme.RED])
			"roadblock":
				chips.append(["Roadblock %s" % _turns(e), AppTheme.RED])
			"haste":
				chips.append(["Their haste", AppTheme.RED])
			"ceasefire":
				chips.append(["Ceasefire: no attacks", AppTheme.RED])
			"blitz", "time_steal":
				if str(e.get("side")) == me and not shown.has(type):
					shown[type] = true
					chips.append(["Blitz %s" % _turns(e) if type == "blitz" else "%d s stolen %s" % [absi(int(e.get("seconds", -10))), _turns(e)], AppTheme.RED])
	var mines := 0
	var sand := 0
	for m: Variant in GameSession.my_mines():
		if m is Dictionary and m.get("kind") == "quicksand":
			sand += 1
		else:
			mines += 1
	if mines > 0:
		chips.append(["Mines: %d" % mines, AppTheme.RED])
	if sand > 0:
		chips.append(["Quicksand: %d" % sand, AppTheme.BRONZE])
	return chips


func _turns(effect: Dictionary) -> String:
	return "(%d)" % int(effect["turns_left"]) if effect.get("turns_left") != null else ""


func _column(x: int) -> String:
	return COLUMN_LETTERS[clampi(x, 0, COLUMN_LETTERS.length() - 1)]


func _toast(text: String, color: Color) -> void:
	if _hud and _hud.ui:
		_hud.ui.toast(text, color)
