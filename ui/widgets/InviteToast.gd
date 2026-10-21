class_name InviteToast
extends Control
## Offers that need an answer, stacked at the top of the screen over every screen: a friend's game
## invite, an opponent's rematch offer, a friend request. Each card shows who it's from (tap the
## photo for their player card), the powerup rules when it's a game, a countdown bar when it
## expires, and two buttons. Social keeps one on its own canvas layer.
##
##     Social.toasts.show_offer({
##         "key": "invite:12", "user": {...PlayerCard}, "title": "maria invites you to play!",
##         "mode": "random", "expires_at": "2026-10-27T10:00:00Z",  # or "seconds": 20
##         "accept_text": "Play", "decline_text": "Not now",
##         "accept": func() -> void: ..., "decline": func() -> void: ...,
##     })

const WIDTH := 440.0
const TOP := 70.0  ## Under the shoutout banner.
const MAX_SHOWN := 3
const DEFAULT_SECONDS := 20.0
const MAX_SECONDS := 180.0

var _stack: VBoxContainer
var _shown: Dictionary = {}  # key -> {panel, opts, deadline, total, bar, clock}
var _queue: Array[Dictionary] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = AppTheme.get_theme()
	_stack = AppTheme.vbox(10)
	add_child(_stack)


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()


## Shows an offer (or queues it while MAX_SHOWN are up). The same key replaces nothing: an offer
## that's already up stays as it is.
func show_offer(opts: Dictionary) -> void:
	var key := str(opts.get("key", ""))
	if key != "" and (_shown.has(key) or _queue.any(func(o: Dictionary) -> bool: return str(o.get("key", "")) == key)):
		return
	if _shown.size() >= MAX_SHOWN:
		_queue.append(opts)
		return
	_add(opts)


## Removes an offer without answering it (it was cancelled, answered elsewhere or expired).
func dismiss(key: String) -> void:
	_queue = _queue.filter(func(o: Dictionary) -> bool: return str(o.get("key", "")) != key)
	if not _shown.has(key):
		return
	var panel: Control = _shown[key]["panel"]
	_shown.erase(key)
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.18)
	t.tween_callback(panel.queue_free)
	if not _queue.is_empty():
		_add(_queue.pop_front())


func has_offer(key: String) -> bool:
	return _shown.has(key)


func count() -> int:
	return _shown.size() + _queue.size()


func _add(opts: Dictionary) -> void:
	var key := str(opts.get("key", str(Time.get_ticks_usec())))
	var total := _seconds(opts)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := AppTheme.vbox(8)
	panel.add_child(box)

	var line := AppTheme.hbox(12)
	box.add_child(line)
	var user: Dictionary = opts.get("user") if opts.get("user") is Dictionary else {}
	var avatar := AvatarView.new(52)
	avatar.set_user(user)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	avatar.tooltip_text = "See player card"
	avatar.gui_input.connect(_on_avatar_input.bind(user))
	line.add_child(avatar)
	var words := AppTheme.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := ProfileUi.wrap(str(opts.get("title", "")), 19)
	title.add_theme_font_override("font", AppTheme.heading_font())
	words.add_child(title)
	var sub := AppTheme.hbox(8)
	if str(opts.get("mode", "")) != "":
		var rules := GameOptions.mode_pill(str(opts["mode"]), 12, true)
		rules.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sub.add_child(rules)
	var clock := AppTheme.label("", "MutedLabel", 15)
	sub.add_child(clock)
	words.add_child(sub)
	line.add_child(words)

	var bar_back := Panel.new()
	bar_back.custom_minimum_size.y = 6
	bar_back.add_theme_stylebox_override("panel", ProfileUi.box(Color(AppTheme.INK, 0.1), 3, 0))
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", ProfileUi.box(AppTheme.MINT, 3, 0))
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_back.add_child(bar)
	box.add_child(bar_back)

	var buttons := AppTheme.hbox(10)
	var no := AppTheme.button(str(opts.get("decline_text", "No thanks")), "Ghost", _answer.bind(key, false), 46)
	var yes := AppTheme.button(str(opts.get("accept_text", "Accept")), "Success", _answer.bind(key, true), 46)
	for b: Button in [no, yes]:
		b.add_theme_font_size_override("font_size", 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	box.add_child(buttons)

	_stack.add_child(panel)
	panel.tree_exited.connect(_place)
	_shown[key] = {"panel": panel, "opts": opts, "deadline": Time.get_ticks_msec() / 1000.0 + total,
		"total": total, "bar": bar, "clock": clock}
	_tick_one(_shown[key])
	AppTheme.pop_in(panel)
	_place()


func _answer(key: String, accept: bool) -> void:
	if not _shown.has(key):
		return
	var opts: Dictionary = _shown[key]["opts"]
	dismiss(key)
	var action: Variant = opts.get("accept" if accept else "decline")
	if action is Callable and (action as Callable).is_valid():
		(action as Callable).call()


func _process(_delta: float) -> void:
	for key: String in _shown.keys():
		if _tick_one(_shown[key]) <= 0.0:
			dismiss(key)


## Updates an offer's bar and clock; returns the seconds left.
func _tick_one(entry: Dictionary) -> float:
	var left := maxf(0.0, float(entry["deadline"]) - Time.get_ticks_msec() / 1000.0)
	var bar: Panel = entry["bar"]
	bar.anchor_right = clampf(left / float(entry["total"]), 0.0, 1.0)
	bar.offset_right = 0.0
	var clock: Label = entry["clock"]
	clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60] if left >= 60.0 else "%d s" % ceili(left)
	return left


## How long the offer stays up: until expires_at (capped, and never shorter than a few seconds,
## in case the clocks disagree), or `seconds`.
func _seconds(opts: Dictionary) -> float:
	if opts.has("seconds"):
		return maxf(1.0, float(opts["seconds"]))
	var until := GameSession.parse_time(opts.get("expires_at", ""))
	if until <= 0.0:
		return DEFAULT_SECONDS
	return clampf(until - Time.get_unix_time_from_system(), 5.0, MAX_SECONDS)


func _place() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	_stack.custom_minimum_size.x = floorf(minf(WIDTH, view.x - 20.0))
	_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, TOP)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _on_avatar_input(event: InputEvent, user: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ui := get_tree().root.find_child("UI", true, false) as UIRoot
		if ui:
			PlayerCardSheet.open(ui, user)


static func _style() -> StyleBoxFlat:
	var s := ProfileUi.box(AppTheme.PAPER, 22, 3)
	s.set_content_margin_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.shadow_color = Color(AppTheme.INK, 0.35)
	s.shadow_offset = Vector2(0, 6)
	s.shadow_size = 3
	return s
