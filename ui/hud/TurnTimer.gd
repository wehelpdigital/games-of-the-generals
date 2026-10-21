extends PanelContainer
## The turn clock under the turn banner: a draining ring and the seconds left, pink on your turn
## and blue on theirs, pulsing red in the last 10 seconds. Chips show this turn's modifiers (+20s,
## -15s, no clock).

const WARN_SECONDS := 10.0

var _ring: Control
var _time: Label
var _who: Label
var _mods: HBoxContainer
var _shown_text := ""
var _pulse: Tween


func _ready() -> void:
	theme_type_variation = "BarPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := AppTheme.hbox(8)
	add_child(row)
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(30, 30)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	row.add_child(_ring)
	_time = AppTheme.label("0:45", "", 24)
	_time.add_theme_font_override("font", AppTheme.heading_font())
	_time.custom_minimum_size.x = 58
	row.add_child(_time)
	_who = AppTheme.label("", "MutedLabel", 15)
	row.add_child(_who)
	_mods = AppTheme.hbox(4)
	row.add_child(_mods)
	visible = false
	GameSession.timer_changed.connect(_refresh)
	GameSession.turn_changed.connect(_refresh)
	GameSession.rules_changed.connect(_refresh)


func setup(_hud: Screen) -> void:
	_refresh()


func _refresh() -> void:
	var active := GameSession.status() == "active"
	var has_clock := GameSession.deadline > 0.0 or GameSession.clock_paused()
	visible = active and has_clock
	if not visible:
		_stop_pulse()
		return
	_who.text = "YOUR CLOCK" if GameSession.is_my_turn() else "THEIR CLOCK"
	for chip in _mods.get_children():
		chip.queue_free()
	for label in GameSession.turn_modifiers():
		var color := AppTheme.MINT if label.begins_with("+") else (AppTheme.PURPLE if label == "no clock" else AppTheme.RED)
		_mods.add_child(AppTheme.pill(label, color, Color.WHITE, 14))
	_shown_text = ""
	_process(0.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	var text := "--"
	var left := GameSession.time_left()
	if GameSession.clock_paused():
		text = "∞"
	elif left < INF:
		var whole := maxi(0, ceili(left))
		text = "%d:%02d" % [floori(whole / 60.0), whole % 60]
		var warn := left <= WARN_SECONDS
		if warn and _pulse == null:
			_start_pulse()
		elif not warn and _pulse != null:
			_stop_pulse()
	if text != _shown_text:
		_shown_text = text
		_time.text = text
		var urgent := left <= WARN_SECONDS
		_time.add_theme_color_override("font_color", AppTheme.RED if urgent else AppTheme.INK)
	_ring.queue_redraw()


func _draw_ring() -> void:
	var center := _ring.size / 2.0
	var radius := minf(_ring.size.x, _ring.size.y) / 2.0 - 2.0
	var mine := GameSession.is_my_turn()
	var color := AppTheme.PINK if mine else AppTheme.BLUE
	var fraction := 1.0
	if not GameSession.clock_paused():
		var left := GameSession.time_left()
		fraction = clampf(left / GameSession.turn_total(), 0.0, 1.0) if left < INF else 0.0
		if left <= WARN_SECONDS:
			color = AppTheme.RED
	_ring.draw_circle(center, radius + 2.0, AppTheme.INK, true, -1.0, true)
	_ring.draw_circle(center, radius - 1.0, Color(AppTheme.PAPER, 1.0), true, -1.0, true)
	if fraction > 0.995:
		_ring.draw_circle(center, radius - 1.0, color, true, -1.0, true)
	elif fraction > 0.01:
		var points := PackedVector2Array([center])
		var steps := maxi(3, ceili(48 * fraction))
		for i in steps + 1:
			points.append(center + Vector2.from_angle(-PI / 2.0 + TAU * fraction * i / steps) * (radius - 1.0))
		_ring.draw_colored_polygon(points, color)
	_ring.draw_circle(center, radius * 0.32, AppTheme.INK, true, -1.0, true)


func _start_pulse() -> void:
	pivot_offset = size / 2.0
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2.ONE * 1.1, 0.25).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	scale = Vector2.ONE
