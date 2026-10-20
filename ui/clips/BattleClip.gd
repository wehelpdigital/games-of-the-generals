class_name BattleClip
extends Control
## The cartoon battle scene that plays when two pieces clash: both soldiers march onto a little
## battlefield, the attacker goes for it with their signature move (the Spy sneaks up for a chop,
## Generals blast a megaphone shockwave, Privates swing a rifle...), and someone gets cartoon-KO'd
## with dizzy stars. A tie becomes a dust-cloud brawl that knocks both out.
##
## Fog of war: during a match the viewer only sees ranks they know; a hidden enemy is the "?"
## shadow soldier. A tie reveals it (equal ranks fall together). The post-game recap passes
## reveal = true so both soldiers are shown, e.g. a Spy taking down the 5-star General.
##
##     await clip.play({attacker: {side, rank}, defender: {side, rank}, outcome, viewer, reveal})
## Tap to skip. Emits `finished` either way.

signal finished
signal _advance

const TEAM_COLORS := {Ranks.WHITE: AppTheme.BLUE, Ranks.BLACK: AppTheme.PINK}
const FIGHTER_HEIGHT := 300.0

var _backdrop: Control
var _stage: Node2D
var _fx: Node2D
var _overlay: Control
var _a: CartoonFighter
var _d: CartoonFighter
var _s := 1.0
var _ground := 0.0
var _all: Array[Tween] = []
var _playing := false
var _skipped := false
var _name_pills: Array[PanelContainer] = []


func _ready() -> void:
	# Already in the tree here, so offsets must be reset too or the clip keeps its zero size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_stage = Node2D.new()
	add_child(_stage)
	_fx = Node2D.new()
	add_child(_fx)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	gui_input.connect(_on_gui_input)


## Coroutine. See the class docs for `data`.
func play(data: Dictionary) -> void:
	if _playing:
		_skip()
		await get_tree().process_frame
	_playing = true
	_skipped = false
	_clear()
	visible = true
	modulate.a = 0.0

	var viewer: String = data.get("viewer", Ranks.WHITE)
	var reveal: bool = data.get("reveal", false)
	var attacker: Dictionary = data["attacker"]
	var defender: Dictionary = data["defender"]
	var outcome: String = data.get("outcome", "both")
	var view := get_viewport_rect().size
	_s = clampf(minf(view.y * 0.42 / FIGHTER_HEIGHT, view.x / 620.0), 0.42, 1.5)
	_ground = view.y * 0.84
	_backdrop.ground = _ground
	_backdrop.queue_redraw()

	var mid := view.x * 0.5
	var home := 210.0 * _s
	_a = _fighter(_shown_rank(attacker, viewer, reveal), Vector2(-160.0 * _s, _ground), 1.0)
	_d = _fighter(_shown_rank(defender, viewer, reveal), Vector2(view.x + 160.0 * _s, _ground), -1.0)
	_title(attacker, defender, viewer, reveal)

	var intro := _tw().set_parallel(true)
	intro.tween_property(self, "modulate:a", 1.0, 0.18)
	await _do(intro)
	await _parallel_walk(mid - home, mid + home, 0.55)
	_a.face = "angry"
	_d.face = "angry" if _d.look.get("rank") != "SPY" else "smug"
	await _sleep(0.22)

	match outcome:
		"attacker":
			await _approach(_a, _d, 1.0)
			await _strike(_a, _d, 1.0)
			await _knock_out(_d, 1.0)
			_ko_banner()
			await _victory(_a)
		"defender":
			await _approach(_a, _d, 1.0)
			await _strike(_d, _a, -1.0)
			await _knock_out(_a, -1.0)
			_ko_banner()
			await _victory(_d)
		_:
			await _brawl(mid, attacker, defender, viewer, reveal)
			_ko_banner("DOUBLE K.O.!")
	_caption(BattleClip.caption_text(attacker, defender, outcome, viewer, reveal))
	await _sleep(1.2)
	var out := _tw()
	out.tween_property(self, "modulate:a", 0.0, 0.2)
	await _do(out)
	_finish()


# --- Choreography -----------------------------------------------------------------------------

func _parallel_walk(a_x: float, d_x: float, duration: float) -> void:
	var cycles := [_walk_cycle(_a), _walk_cycle(_d)]
	var t := _tw().set_parallel(true)
	t.tween_property(_a, "position:x", a_x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_d, "position:x", d_x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _do(t)
	for c: Tween in cycles:
		c.kill()
	for f in [_a, _d]:
		_stance(f)


## Walk up to striking distance. The Spy tiptoes in, crouched.
func _approach(actor: CartoonFighter, target: CartoonFighter, dir: float) -> void:
	var sneak: bool = actor.look.get("move") == "chop"
	var reach := (175.0 if actor.look.get("move") in ["megaphone", "rifle", "flag", "saber"] else 135.0) * _s
	if actor.look.get("move") == "megaphone":
		reach = 290.0 * _s
	var to_x := target.position.x - dir * reach
	if absf(to_x - actor.position.x) < 8.0:
		return
	var cycle := _walk_cycle(actor, sneak)
	if sneak:
		actor.lean = 16.0
		actor.face = "smug"
	var t := _tw()
	t.tween_property(actor, "position:x", to_x, 0.75 if sneak else 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _do(t)
	cycle.kill()
	_stance(actor)
	if sneak:
		target.face = "shock"  # Too late!
		await _sleep(0.12)


func _strike(actor: CartoonFighter, target: CartoonFighter, dir: float) -> void:
	var move: String = actor.look.get("move", "punch")
	actor.face = "angry"
	var hit := (actor.position + target.position) * 0.5 + Vector2(0, -190.0 * _s)
	match move:
		"megaphone":
			actor.prop_out = true
			var raise := _tw()
			raise.tween_property(actor, "arm_front", 95.0, 0.14)
			raise.parallel().tween_property(actor, "lean", -6.0, 0.14)
			await _do(raise)
			_shout(actor, str(actor.look.get("shout", "CHARGE!")), dir)
			await _do(_shockwave(actor.position + Vector2(dir * 80.0 * _s, -205.0 * _s), dir, target.position.x))
			hit = target.position + Vector2(-dir * 30.0 * _s, -200.0 * _s)
		"punch":
			var wind := _tw()
			wind.tween_property(actor, "arm_front", -40.0, 0.12)
			wind.parallel().tween_property(actor, "lean", -12.0, 0.12)
			await _do(wind)
			var jab := _tw().set_parallel(true)
			jab.tween_property(actor, "arm_front", 92.0, 0.06)
			jab.tween_property(actor, "lean", 16.0, 0.06)
			jab.tween_property(actor, "position:x", actor.position.x + dir * 34.0 * _s, 0.06)
			await _do(jab)
		_:
			# Wind up overhead, then swing down: chop, baton, saber, rifle butt, flag pole.
			actor.prop_out = move in ["saber", "baton", "rifle", "flag"]
			var up := _tw()
			up.tween_property(actor, "arm_front", 172.0, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			up.parallel().tween_property(actor, "lean", -8.0, 0.13)
			await _do(up)
			var down := _tw().set_parallel(true)
			down.tween_property(actor, "arm_front", 58.0, 0.07)
			down.tween_property(actor, "lean", 14.0, 0.07)
			await _do(down)
			if move == "saber":
				_swish(actor.position + Vector2(dir * 60.0 * _s, -200.0 * _s), dir)
	_impact(hit, FighterLooks.impact_word(move))


func _knock_out(victim: CartoonFighter, dir: float) -> void:
	victim.face = "shock"
	var start := victim.position
	# The body lands lying in `dir`, so the feet barely slide: keeps the KO on screen.
	var land := start + Vector2(dir * 36.0 * _s, 0)
	var t := _tw().set_parallel(true)
	t.tween_property(victim, "position:x", land.x, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(victim, "position:y", start.y - 110.0 * _s, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(victim, "position:y", start.y, 0.26).set_delay(0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(victim, "rotation", dir * deg_to_rad(90.0), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(victim, "arm_front", 150.0, 0.3)
	t.tween_property(victim, "arm_back", 140.0, 0.3)
	t.tween_property(victim, "leg_front", 40.0, 0.3)
	await _do(t)
	_dizzy(victim)


func _dizzy(victim: CartoonFighter) -> void:
	victim.face = "ko"
	victim.prop_out = false
	var spin := _tw().set_loops()
	spin.tween_property(victim, "ko_spin", 360.0, 0.7).from(0.0)


func _victory(winner: CartoonFighter) -> void:
	winner.face = "happy"
	var keep_prop: bool = winner.look.get("move") == "flag"
	winner.prop_out = keep_prop
	var t := _tw()
	t.tween_property(winner, "lean", 0.0, 0.1)
	t.parallel().tween_property(winner, "arm_front", 168.0, 0.12)
	t.parallel().tween_property(winner, "arm_back", 160.0, 0.12)
	for i in 2:
		t.tween_property(winner, "hop", 46.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(winner, "hop", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _do(t)


## Equal ranks: both charge into a cartoon dust cloud and nobody walks out.
func _brawl(mid: float, attacker: Dictionary, defender: Dictionary, viewer: String, reveal: bool) -> void:
	var cycles := [_walk_cycle(_a), _walk_cycle(_d)]
	var rush := _tw().set_parallel(true)
	rush.tween_property(_a, "position:x", mid - 40.0 * _s, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rush.tween_property(_d, "position:x", mid + 40.0 * _s, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _do(rush)
	for c: Tween in cycles:
		c.kill()
	_a.visible = false
	_d.visible = false
	var cloud := DustCloud.new()
	cloud.position = Vector2(mid, _ground - 150.0 * _s)
	cloud.scale = Vector2.ONE * _s
	_fx.add_child(cloud)
	_shake(0.9)
	for word in ["POW!", "BAM!", "OOF!"]:
		_impact(cloud.position + Vector2(randf_range(-150, 150), randf_range(-110, 40)) * _s, word, 0.8)
		await _sleep(0.28)
	# A tie means equal ranks, so a hidden rank is no longer a secret.
	if not reveal:
		var known := str((attacker if attacker.get("side") == viewer else defender).get("rank", ""))
		for f in [_a, _d]:
			f.look = FighterLooks.for_rank(known)
		for pill: PanelContainer in _name_pills:
			var label := pill.get_child(0) as Label
			if label.text == "ENEMY ???":
				label.text = "ENEMY %s" % Ranks.display_name(known).to_upper()
	var pop := _tw()
	pop.tween_property(cloud, "scale", Vector2.ONE * _s * 1.3, 0.12)
	pop.tween_property(cloud, "modulate:a", 0.0, 0.18)
	_a.position.x = mid - 120.0 * _s
	_d.position.x = mid + 120.0 * _s
	for pair in [[_a, -1.0], [_d, 1.0]]:
		var f: CartoonFighter = pair[0]
		f.visible = true
		f.rotation = pair[1] * deg_to_rad(90.0)
		f.arm_front = 150.0
		f.arm_back = 140.0
		_dizzy(f)
	await _do(pop)
	cloud.queue_free()


# --- Effects ----------------------------------------------------------------------------------

func _impact(at: Vector2, word: String, size_scale := 1.0) -> void:
	var burst := Burst.new()
	burst.position = at
	burst.scale = Vector2.ONE * 0.2 * _s
	burst.rotation = randf_range(-0.4, 0.4)
	_fx.add_child(burst)
	var t := _tw()
	t.tween_property(burst, "scale", Vector2.ONE * 1.1 * _s * size_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.25)
	t.tween_property(burst, "modulate:a", 0.0, 0.2)
	t.tween_callback(burst.queue_free)
	var label := AppTheme.label(word, "TitleLabel", int(64 * _s * size_scale) + 8)
	label.add_theme_color_override("font_color", AppTheme.YELLOW if word != "CHOP!" else Color.WHITE)
	label.size = Vector2(320, 120) * _s
	label.position = at - label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	label.rotation = randf_range(-0.25, 0.15)
	label.scale = Vector2.ZERO
	_overlay.add_child(label)
	var lt := _tw()
	lt.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.35)
	lt.tween_property(label, "modulate:a", 0.0, 0.2)
	lt.tween_callback(label.queue_free)
	_shake(0.5 * size_scale)


func _shout(actor: CartoonFighter, text: String, dir: float) -> void:
	var bubble := AppTheme.pill(text, Color.WHITE, AppTheme.INK, int(30 * _s) + 8)
	_overlay.add_child(bubble)
	bubble.position = actor.position + Vector2(dir * 40.0 * _s - (0.0 if dir > 0 else 200.0 * _s), -330.0 * _s)
	AppTheme.pop_in(bubble)
	var t := _tw()
	t.tween_interval(0.6)
	t.tween_property(bubble, "modulate:a", 0.0, 0.15)
	t.tween_callback(bubble.queue_free)


func _shockwave(from: Vector2, dir: float, target_x: float) -> Tween:
	var t := _tw().set_parallel(true)
	for i in 3:
		var ring := Rings.new()
		ring.position = from
		ring.dir = dir
		ring.scale = Vector2.ONE * _s
		_fx.add_child(ring)
		var travel := absf(target_x - from.x) / _s
		t.tween_property(ring, "radius", travel, 0.36).set_delay(i * 0.08).from(20.0)
		t.tween_property(ring, "modulate:a", 0.0, 0.36).set_delay(i * 0.08).from(1.0)
	t.chain().tween_callback(_clear_rings)
	return t


func _clear_rings() -> void:
	for child in _fx.get_children():
		if child is Rings:
			child.queue_free()


func _swish(at: Vector2, dir: float) -> void:
	var arc := Rings.new()
	arc.position = at
	arc.dir = dir
	arc.radius = 80.0
	arc.width = 10.0
	arc.color = Color.WHITE
	arc.scale = Vector2.ONE * _s
	_fx.add_child(arc)
	var t := _tw()
	t.tween_property(arc, "modulate:a", 0.0, 0.25)
	t.tween_callback(arc.queue_free)


func _shake(strength: float) -> void:
	var t := _tw()
	for i in 6:
		t.tween_property(_stage, "position", Vector2(randf_range(-12, 12), randf_range(-8, 8)) * strength * _s, 0.035)
	t.tween_property(_stage, "position", Vector2.ZERO, 0.05)


func _ko_banner(text := "K.O.!") -> void:
	var label := AppTheme.label(text, "TitleLabel", int(110 * _s) + 20)
	label.add_theme_color_override("font_color", AppTheme.RED)
	var view := get_viewport_rect().size
	label.size = Vector2(view.x, 160)
	label.position = Vector2(0, view.y * 0.2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 2.2
	label.modulate.a = 0.0
	_overlay.add_child(label)
	var t := _tw().set_parallel(true)
	t.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 1.0, 0.1)


func _caption(text: String) -> void:
	var pill := AppTheme.pill(text, AppTheme.INK, Color.WHITE, 24)
	_overlay.add_child(pill)
	await get_tree().process_frame
	if not is_instance_valid(pill) or pill.is_queued_for_deletion():
		return  # The clip was skipped and cleared meanwhile.
	var view := get_viewport_rect().size
	pill.position = Vector2((view.x - pill.size.x) * 0.5, view.y - pill.size.y - 18.0)
	AppTheme.pop_in(pill)


func _title(attacker: Dictionary, defender: Dictionary, viewer: String, reveal: bool) -> void:
	var row := AppTheme.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.add_child(_name_pill(attacker, viewer, reveal))
	var vs := AppTheme.label("VS", "TitleLabel", 44)
	vs.add_theme_color_override("font_color", AppTheme.YELLOW)
	row.add_child(vs)
	row.add_child(_name_pill(defender, viewer, reveal))
	_overlay.add_child(row)
	AppTheme.pop_in(row)


func _name_pill(piece: Dictionary, viewer: String, reveal: bool) -> PanelContainer:
	var rank := _shown_rank(piece, viewer, reveal)
	var who := "YOUR" if piece.get("side") == viewer else "ENEMY"
	var title := "%s %s" % [who, Ranks.display_name(rank).to_upper()] if rank != "UNKNOWN" else "ENEMY ???"
	var pill := AppTheme.pill(title, TEAM_COLORS.get(piece.get("side"), AppTheme.PURPLE), Color.WHITE, 22)
	_name_pills.append(pill)
	return pill


# --- Helpers ----------------------------------------------------------------------------------

func _shown_rank(piece: Dictionary, viewer: String, reveal: bool) -> String:
	var rank := str(piece.get("rank", ""))
	if (reveal or piece.get("side") == viewer) and Ranks.INFO.has(rank):
		return rank
	return "UNKNOWN"


func _fighter(rank: String, at: Vector2, facing: float) -> CartoonFighter:
	var f := CartoonFighter.new()
	f.look = FighterLooks.for_rank(rank)
	f.position = at
	f.scale = Vector2(facing, 1.0) * _s
	_stage.add_child(f)
	return f


func _walk_cycle(f: CartoonFighter, sneak := false) -> Tween:
	var step := 0.2 if sneak else 0.13
	var swing := 16.0 if sneak else 28.0
	var t := _tw().set_loops()
	t.tween_property(f, "leg_front", swing, step)
	t.parallel().tween_property(f, "leg_back", -swing, step)
	t.parallel().tween_property(f, "arm_back", 25.0, step)
	t.parallel().tween_property(f, "hop", 8.0, step * 0.5)
	t.tween_property(f, "leg_front", -swing, step)
	t.parallel().tween_property(f, "leg_back", swing, step)
	t.parallel().tween_property(f, "arm_back", -25.0, step)
	t.parallel().tween_property(f, "hop", 0.0, step * 0.5)
	return t


func _stance(f: CartoonFighter) -> void:
	f.leg_front = 6.0
	f.leg_back = -6.0
	f.hop = 0.0
	f.lean = 0.0


func _tw() -> Tween:
	var t := create_tween()
	_all.append(t)
	return t


## Waits for a tween, or returns at once if the clip was skipped.
func _do(t: Tween) -> void:
	if _skipped:
		t.kill()
		return
	t.finished.connect(func() -> void: _advance.emit(), CONNECT_ONE_SHOT)
	await _advance


func _sleep(seconds: float) -> void:
	var t := _tw()
	t.tween_interval(seconds)
	await _do(t)


func _on_gui_input(event: InputEvent) -> void:
	if _playing and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		accept_event()
		_skip()


func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	for t in _all:
		if t.is_valid():
			t.kill()
	_advance.emit()


func _finish() -> void:
	for t in _all:
		if t.is_valid():
			t.kill()
	_all.clear()
	visible = false
	modulate.a = 1.0
	_stage.position = Vector2.ZERO
	_clear()
	_playing = false
	finished.emit()


func _clear() -> void:
	_name_pills.clear()
	for layer: Node in [_stage, _fx, _overlay]:
		for child in layer.get_children():
			child.queue_free()


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


# --- Drawn pieces of the scene ----------------------------------------------------------------

## Cartoon battlefield: sky, sun, clouds, rolling hills, sandbags and a sandy ground.
class Backdrop extends Control:
	var ground := 600.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sky_top := Color("6cc2ff")
		var sky_low := Color("d9f1ff")
		for i in 12:
			var y0 := ground * i / 12.0
			draw_rect(Rect2(0, y0, w, ground / 12.0 + 1.0), sky_top.lerp(sky_low, i / 11.0))
		draw_circle(Vector2(w * 0.82, ground * 0.24), ground * 0.09 + 6, CartoonFighter.INK)
		draw_circle(Vector2(w * 0.82, ground * 0.24), ground * 0.09, Color("ffe066"))
		for c: Vector3 in [Vector3(0.18, 0.2, 1.0), Vector3(0.52, 0.12, 0.8), Vector3(0.68, 0.3, 0.7)]:
			var at := Vector2(w * c.x, ground * c.y)
			var r := ground * 0.05 * c.z
			for o: Vector2 in [Vector2(-1.2, 0.2), Vector2(0, -0.3), Vector2(1.1, 0.15), Vector2(0.2, 0.35)]:
				draw_circle(at + o * r, r, Color(1, 1, 1, 0.92))
		_hill(ground * 0.72, Color("8fd67a"), 0.0)
		_hill(ground * 0.84, Color("6cbf5c"), 1.7)
		draw_rect(Rect2(0, ground, w, h - ground), Color("f0cf8f"))
		draw_line(Vector2(0, ground), Vector2(w, ground), CartoonFighter.INK, 5.0)
		var bag := Vector2(46, 20) * clampf(h / 900.0, 0.5, 1.4)
		var x := -bag.x * 0.5
		while x < w + bag.x:
			_bag(Vector2(x, ground - bag.y * 0.6), bag)
			x += bag.x * 1.02
		for i in 18:
			var px := fposmod(i * 137.0, w)
			draw_circle(Vector2(px, ground + 20 + fposmod(i * 53.0, maxf(1.0, h - ground - 30))), 3.0, Color("d9b26a"))

	func _hill(base: float, color: Color, phase: float) -> void:
		var pts := PackedVector2Array()
		var w := size.x
		for i in 33:
			var x := w * i / 32.0
			pts.append(Vector2(x, base - sin(i * 0.45 + phase) * 26.0 - 20.0))
		pts.append(Vector2(w, ground))
		pts.append(Vector2(0, ground))
		draw_colored_polygon(pts, color)
		draw_polyline(pts.slice(0, 33), CartoonFighter.INK, 4.0, true)

	func _bag(c: Vector2, half: Vector2) -> void:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(c + Vector2(cos(a) * half.x * 0.5, sin(a) * half.y * 0.5))
		draw_colored_polygon(pts, Color("c9a46a"))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, CartoonFighter.INK, 3.0, true)


## Spiky comic impact star.
class Burst extends Node2D:
	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a), sin(a)) * (95.0 if i % 2 == 0 else 52.0))
		draw_colored_polygon(pts, Color("ffe066"))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, CartoonFighter.INK, 7.0, true)
		draw_circle(Vector2.ZERO, 30.0, Color.WHITE)


## Expanding arcs: megaphone shockwave or saber swish.
class Rings extends Node2D:
	var dir := 1.0
	var radius := 20.0:
		set(v):
			radius = v
			queue_redraw()
	var width := 12.0
	var color := Color("ffffff")

	func _draw() -> void:
		var start := -0.55 if dir > 0 else PI - 0.55
		draw_arc(Vector2.ZERO, radius, start, start + 1.1, 18, CartoonFighter.INK, width + 8.0, true)
		draw_arc(Vector2.ZERO, radius, start, start + 1.1, 18, color, width, true)


## A wobbling brawl cloud with stars and fists flying out.
class DustCloud extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var puffs := [Vector2(-90, 10), Vector2(-40, -50), Vector2(30, -60), Vector2(95, 0), Vector2(50, 50), Vector2(-40, 55), Vector2(0, 0)]
		for i in puffs.size():
			var p: Vector2 = puffs[i] + Vector2(sin(_t * 23.0 + i), cos(_t * 19.0 + i * 2.0)) * 9.0
			draw_circle(p, 74.0, CartoonFighter.INK)
		for i in puffs.size():
			var p: Vector2 = puffs[i] + Vector2(sin(_t * 23.0 + i), cos(_t * 19.0 + i * 2.0)) * 9.0
			draw_circle(p, 66.0, Color("f4ead6"))
		for i in 4:
			var a := _t * 6.0 + i * TAU / 4.0
			var at := Vector2(cos(a) * 130.0, sin(a) * 70.0)
			draw_circle(at, 16.0, CartoonFighter.INK)
			draw_circle(at, 11.0, Color("f6c9a0") if i % 2 == 0 else Color("ffe066"))
