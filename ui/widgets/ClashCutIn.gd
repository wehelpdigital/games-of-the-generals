class_name ClashCutIn
extends Control
## Fighting-game style "VS" clip played over the board when two pieces clash.
##
## It never shows more than the viewer is allowed to know: a hidden enemy rank is the "?" badge.
## The one exception follows from the rules: when both pieces fall they were the same rank, so the
## "?" flips to match. The post-game recap passes reveal = true to show both ranks.
##
##     await cut_in.play({attacker: {side, rank}, defender: {side, rank}, outcome, viewer, reveal})
## Click/tap skips. Emits `finished` either way.

signal finished

const BADGE := 196.0
const TEAM_COLORS := {Ranks.WHITE: AppTheme.BLUE, Ranks.BLACK: AppTheme.PINK}

var _shade: ColorRect
var _band: ColorRect
var _lines: Array[ColorRect] = []
var _stage: Control
var _left: Control
var _right: Control
var _vs: Label
var _caption: PanelContainer
var _flash: ColorRect
var _burst: CPUParticles2D
var _playing := false
var _tweens: Array[Tween] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_shade = _rect(Color(AppTheme.INK, 0.6))
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_band = _rect(AppTheme.YELLOW)
	add_child(_band)
	for i in 7:
		var line := _rect(Color(1, 1, 1, 0.55))
		_band.add_child(line)
		_lines.append(line)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_flash = _rect(Color(1, 1, 1, 0))
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.amount = 28
	_burst.lifetime = 0.6
	_burst.spread = 180.0
	_burst.gravity = Vector2(0, 500)
	_burst.initial_velocity_min = 300.0
	_burst.initial_velocity_max = 700.0
	_burst.scale_amount_min = 0.25
	_burst.scale_amount_max = 0.6
	_burst.texture = _sparkle()
	var colors := Gradient.new()
	colors.set_color(0, Color.WHITE)
	colors.set_color(1, Color(1, 1, 1, 0))
	_burst.color_ramp = colors
	add_child(_burst)
	gui_input.connect(_on_gui_input)


## Coroutine. See the class docs for `data`.
func play(data: Dictionary) -> void:
	if _playing:
		_stop()
	_playing = true
	visible = true
	_clear_stage()
	var view := get_viewport_rect().size
	var center := view * 0.5
	var viewer: String = data.get("viewer", Ranks.WHITE)
	var reveal: bool = data.get("reveal", false)
	var attacker: Dictionary = data["attacker"]
	var defender: Dictionary = data["defender"]
	var outcome: String = data.get("outcome", "both")

	var att_rank := _visible_rank(attacker, viewer, reveal)
	var def_rank := _visible_rank(defender, viewer, reveal)
	_left = _fighter(attacker, att_rank, viewer)
	_right = _fighter(defender, def_rank, viewer)
	_stage.add_child(_left)
	_stage.add_child(_right)
	var gap := minf(view.x * 0.26, 300.0)
	var left_home := Vector2(center.x - gap - BADGE * 0.5, center.y - BADGE * 0.62)
	var right_home := Vector2(center.x + gap - BADGE * 0.5, center.y - BADGE * 0.62)
	_left.position = Vector2(-BADGE * 1.5, left_home.y)
	_right.position = Vector2(view.x + BADGE * 0.5, right_home.y)

	_vs = AppTheme.label("VS", "TitleLabel", 92)
	_vs.add_theme_color_override("font_color", AppTheme.PINK)
	_stage.add_child(_vs)
	_vs.position = center - Vector2(70, 66)
	_vs.size = Vector2(140, 120)
	_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs.pivot_offset = _vs.size * 0.5
	_vs.scale = Vector2.ZERO

	_band.size = Vector2(view.x * 1.4, BADGE * 1.75)
	_band.position = Vector2(-view.x * 0.2, center.y - _band.size.y * 0.5 - 6.0)
	_band.pivot_offset = _band.size * 0.5
	_band.rotation = deg_to_rad(-5.0)
	_band.scale = Vector2(1, 0)
	for i in _lines.size():
		var line := _lines[i]
		line.size = Vector2(randf_range(80, 220), 5)
		line.position = Vector2(randf_range(0, _band.size.x), 18 + i * (_band.size.y - 36) / (_lines.size() - 1))
	_shade.modulate.a = 0.0
	_flash.color.a = 0.0
	_caption = AppTheme.pill(caption_text(attacker, defender, outcome, viewer, reveal), AppTheme.INK, Color.WHITE, 24)
	_stage.add_child(_caption)
	_caption.modulate.a = 0.0

	var t := _tween()
	t.tween_property(_shade, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(_band, "scale:y", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_left, "position", left_home, 0.3).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_right, "position", right_home, 0.3).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_vs, "scale", Vector2.ONE * 1.25, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_vs, "scale", Vector2.ONE, 0.1)
	t.tween_interval(0.18)
	# Impact: the fighters lunge together, the screen flashes and shakes.
	t.tween_property(_left, "position:x", left_home.x + gap * 0.55, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_right, "position:x", right_home.x - gap * 0.55, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_vs, "modulate:a", 0.0, 0.08)
	t.tween_callback(_impact.bind(center))
	t.tween_property(_left, "position:x", left_home.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_right, "position:x", right_home.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_resolve.bind(outcome, attacker, defender, viewer, reveal, center, view))
	t.tween_interval(1.05)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(_stop)
	_run_speed_lines()
	await finished  # Emitted by _stop(), whether the clip ends or is skipped.


func _visible_rank(piece: Dictionary, viewer: String, reveal: bool) -> String:
	var rank := str(piece.get("rank", ""))
	if reveal or piece.get("side") == viewer:
		return rank
	return ""


func _fighter(piece: Dictionary, rank: String, viewer: String) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(BADGE, 0)
	var mine: bool = piece.get("side") == viewer
	var tag := AppTheme.pill("YOU" if mine else "ENEMY", TEAM_COLORS.get(piece.get("side"), AppTheme.PURPLE), Color.WHITE, 18)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tag)
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.texture = PieceIcons.badge_or_mystery(rank)
	badge.custom_minimum_size = Vector2(BADGE, BADGE)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.pivot_offset = Vector2(BADGE, BADGE) * 0.5
	box.add_child(badge)
	var name_pill := AppTheme.pill(_short(rank), AppTheme.PAPER, AppTheme.INK, 22)
	name_pill.name = "Name"
	name_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(name_pill)
	return box


func _impact(center: Vector2) -> void:
	_flash.color.a = 0.85
	var t := _tween()
	t.tween_property(_flash, "color:a", 0.0, 0.22)
	_burst.position = center
	_burst.restart()
	var shake := _tween()
	for i in 6:
		shake.tween_property(_stage, "position", Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.035)
	shake.tween_property(_stage, "position", Vector2.ZERO, 0.05)


func _resolve(outcome: String, attacker: Dictionary, defender: Dictionary, viewer: String, reveal: bool,
		center: Vector2, view: Vector2) -> void:
	var losers: Array[Control] = []
	if outcome != "attacker":
		losers.append(_left)
	if outcome != "defender":
		losers.append(_right)
	# Equal ranks fall together, so a hidden rank is no longer a secret.
	if outcome == "both" and not reveal:
		var known := str((attacker if attacker.get("side") == viewer else defender).get("rank", ""))
		for fighter: Control in [_left, _right]:
			_flip_to(fighter, known)
	for loser in losers:
		var badge: TextureRect = loser.get_node("Badge")
		var x := AppTheme.label("X", "TitleLabel", 150)
		x.add_theme_color_override("font_color", AppTheme.RED)
		x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		x.size = Vector2(BADGE, BADGE)
		x.pivot_offset = x.size * 0.5
		x.scale = Vector2.ONE * 2.0
		x.modulate.a = 0.0
		badge.add_child(x)
		var t := _tween()
		t.tween_interval(0.2 if outcome == "both" and not reveal else 0.0)
		t.tween_property(x, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(x, "modulate:a", 1.0, 0.1)
		t.tween_property(badge, "modulate", Color(1, 0.55, 0.55, 0.55), 0.3)
		t.parallel().tween_property(badge, "rotation", deg_to_rad(randf_range(-18, 18)), 0.3)
		t.parallel().tween_property(badge, "scale", Vector2.ONE * 0.86, 0.3)
	if losers.size() == 1:
		var winner := _right if losers[0] == _left else _left
		var badge: TextureRect = winner.get_node("Badge")
		var t := _tween()
		t.tween_property(badge, "scale", Vector2.ONE * 1.18, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(badge, "scale", Vector2.ONE, 0.16)
		# A tilted "WINS!" sticker slapped onto the winner's badge.
		var wins := AppTheme.pill("WINS!", AppTheme.MINT, Color.WHITE, 30)
		badge.add_child(wins)
		wins.position = Vector2(BADGE * 0.5 - 62.0, BADGE - 46.0)
		wins.rotation = deg_to_rad(-8.0)
		AppTheme.pop_in(wins)
	# Long captions wrap on narrow (phone) screens instead of running off both edges.
	var caption_label := _caption.get_child(0) as Label
	var max_width := view.x - 40.0
	if caption_label.get_combined_minimum_size().x + 28.0 > max_width:
		caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption_label.custom_minimum_size.x = max_width - 28.0
		_caption.reset_size()
	_caption.position = Vector2(center.x - _caption.size.x * 0.5, minf(view.y - 80.0 - (_caption.size.y - 40.0), center.y + BADGE * 1.02))
	var c := _tween()
	c.tween_property(_caption, "modulate:a", 1.0, 0.18)
	c.parallel().tween_property(_caption, "position:y", _caption.position.y - 16.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flip_to(fighter: Control, rank: String) -> void:
	var badge: TextureRect = fighter.get_node("Badge")
	if badge.texture == PieceIcons.badge_or_mystery(rank):
		return
	var t := _tween()
	t.tween_property(badge, "scale:x", 0.0, 0.1)
	t.tween_callback(_apply_flip.bind(fighter, rank))
	t.tween_property(badge, "scale:x", 1.0, 0.1)


func _apply_flip(fighter: Control, rank: String) -> void:
	(fighter.get_node("Badge") as TextureRect).texture = PieceIcons.badge_or_mystery(rank)
	AppTheme.set_pill(fighter.get_node("Name"), _short(rank), AppTheme.PAPER, AppTheme.INK)


## One-line description of a clash from `viewer`'s point of view (reveal = both ranks known).
static func caption_text(attacker: Dictionary, defender: Dictionary, outcome: String, viewer: String, reveal: bool) -> String:
	var att := Ranks.display_name(str(attacker.get("rank", ""))) if str(attacker.get("rank", "")) != "" else "piece"
	var def := Ranks.display_name(str(defender.get("rank", ""))) if str(defender.get("rank", "")) != "" else "piece"
	var att_owner := "Your" if attacker.get("side") == viewer else "Their"
	var def_owner := "your" if defender.get("side") == viewer else "their"
	if reveal:
		match outcome:
			"attacker":
				return "%s %s eliminated %s %s!" % [att_owner, att, def_owner, def]
			"defender":
				return "%s %s stopped %s %s!" % [def_owner.capitalize(), def, att_owner.to_lower(), att]
		return "%s and %s took each other out!" % [att, def]
	var mine := attacker if attacker.get("side") == viewer else defender
	var rank_name := Ranks.display_name(str(mine.get("rank", "")))
	var i_attacked: bool = attacker.get("side") == viewer
	match outcome:
		"both":
			return "Both %ss fell!" % rank_name
		"attacker":
			return ("Your %s took out an enemy piece!" if i_attacked else "Your %s was taken out!") % rank_name
		_:
			return ("Your %s was defeated!" if i_attacked else "Your %s held the line!") % rank_name


func _short(rank: String) -> String:
	return Ranks.info(rank).get("label", "???") if rank != "" else "???"


func _run_speed_lines() -> void:
	for line in _lines:
		var t := _tween().set_loops(4)
		var speed := randf_range(0.18, 0.32)
		t.tween_property(line, "position:x", _band.size.x, speed).from(-line.size.x)


func _on_gui_input(event: InputEvent) -> void:
	if _playing and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		accept_event()
		_stop()


func _stop() -> void:
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	visible = false
	modulate.a = 1.0
	_stage.position = Vector2.ZERO
	var was_playing := _playing
	_playing = false
	if was_playing:
		finished.emit()


func _tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _clear_stage() -> void:
	for child in _stage.get_children():
		child.queue_free()


## Soft round glint for the impact burst.
func _sparkle() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
