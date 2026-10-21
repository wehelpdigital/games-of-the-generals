class_name PowerupCard
extends Control
## A powerup as a trading card: a frame in its type's colours with a rarity gem and trim, the name
## banner, the illustration (assets/powerups/art), a type line and the rules text, and a holographic
## sheen on epic and legendary cards. Face down it shows the Salpakan card back. `compact` cards
## (small hands) keep only the name and art.
##
## The control is the card's slot in a layout; the drawn card (`face`) moves inside it, so hover
## lifts, flips and slams never disturb containers.
##
##     var card := PowerupCard.new("spy_card", 180)
##     card.pressed.connect(func(c: PowerupCard) -> void: print(c.id))

signal pressed(card: PowerupCard)

const ASPECT := 1.4  ## Height / width (a 5:7 card).
const HOLO := preload("res://ui/widgets/powerup_card_holo.gdshader")
const BACK_SHIELD := preload("res://assets/brand/layers/shield.png")
const BACK_STAR := preload("res://assets/brand/layers/star.png")
const COMPACT_WIDTH := 120.0

static var _art_cache: Dictionary = {}

var id := ""
var face_down := false
var selected := false: set = set_selected
var used := false: set = set_used
var compact := false
var interactive := true
var hover_lift := true
var lift_direction := Vector2.UP  ## Where a raised card moves (a vertical cascade raises it sideways).
var stack_selected := false  ## A selected card draws over its neighbours (overlapping hands).

var face: Control
var _name: Label
var _type: Label
var _rules: Label
var _holo: ColorRect
var _flash: ColorRect
var _hovered := false
var _tween: Tween
var _base := Vector2.ZERO  ## Where the face rests inside the slot (centred when the slot is bigger).


func _init(powerup_id := "", width := 180.0, down := false) -> void:
	id = powerup_id
	face_down = down
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	set_card_width(width)
	face = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(face)
	face.draw.connect(_draw_face)
	_name = _label(AppTheme.heading_font(), AppTheme.INK)
	_name.add_theme_constant_override("line_spacing", -1)  # Two-line names on small cards.
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type = _label(AppTheme.heading_font(), Color.WHITE)
	_type.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rules = _label(null, AppTheme.INK)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_holo = ColorRect.new()
	_holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shine := ShaderMaterial.new()
	shine.shader = HOLO
	shine.set_shader_parameter("offset", randf())
	_holo.material = shine
	face.add_child(_holo)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(_flash)
	resized.connect(_layout)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _ready() -> void:
	_layout()


## The card's width; its height follows the 5:7 shape.
func set_card_width(width: float) -> void:
	custom_minimum_size = Vector2(width, roundf(width * ASPECT))
	compact = width < COMPACT_WIDTH
	size = custom_minimum_size


func set_id(powerup_id: String) -> void:
	id = powerup_id
	_layout()


## The drawn card: the largest 5:7 card that fits the slot.
func card_size() -> Vector2:
	var w := minf(size.x, size.y / ASPECT)
	return Vector2(w, w * ASPECT)


func set_selected(value: bool) -> void:
	selected = value
	_restack()
	if face:
		face.queue_redraw()
		_animate_to(_lift() if selected else 0.0, 1.06 if selected else 1.0)


func set_used(value: bool) -> void:
	used = value
	modulate = Color(0.62, 0.6, 0.7, 0.85) if used else Color.WHITE
	if _holo:
		_holo.visible = _shows_holo()


## Turns the card over (face down shows the card back); a zero duration turns it at once.
func flip(down: bool, duration := 0.32) -> void:
	if down == face_down or face == null or duration <= 0.0:
		face_down = down
		_layout()
		return
	var t := create_tween()
	t.tween_property(face, "scale:x", 0.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_turn_over.bind(down))
	t.tween_property(face, "scale:x", 1.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished


func _turn_over(down: bool) -> void:
	face_down = down
	_layout()


## The "played" moment: the card punches up with a flash.
func slam() -> void:
	if face == null:
		return
	var t := create_tween()
	t.tween_property(face, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_flash, "color:a", 0.75, 0.1)
	t.tween_property(face, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_flash, "color:a", 0.0, 0.3)
	await t.finished


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		pressed.emit(self)


func _on_hover(inside: bool) -> void:
	_hovered = inside
	if not interactive or not hover_lift or selected or DisplayServer.is_touchscreen_available():
		return
	_restack()
	_animate_to(_lift() * 0.6 if inside else 0.0, 1.04 if inside else 1.0, deg_to_rad(-1.5) if inside else 0.0)


## A hovered card (or a raised one in an overlapping hand) draws over its neighbours.
func _restack() -> void:
	z_index = 1 if (selected and stack_selected) or (_hovered and interactive and hover_lift) else 0


func _lift() -> float:
	return card_size().y * 0.08


func _animate_to(lift: float, scale_to: float, angle := 0.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(face, "position", _base + lift_direction * lift, 0.16).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(face, "scale", Vector2.ONE * scale_to, 0.16).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(face, "rotation", angle, 0.16).set_trans(Tween.TRANS_SINE)


func _shows_holo() -> bool:
	return not face_down and not used and PowerupLibrary.rarity(id) in ["epic", "legendary"]


func _label(font: Font, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	face.add_child(label)
	return label


# --- Layout and drawing --------------------------------------------------------------------------------

## Card regions, in face coordinates, for the current size.
func _regions() -> Dictionary:
	var cs := card_size()
	var w := cs.x
	var h := cs.y
	var m := w * 0.055
	var inner := Rect2(m, m, w - m * 2.0, h - m * 2.0)
	var pad := w * 0.035
	var radius := w * 0.075
	if compact:
		# Small hands: the art fills the card and the name sits on a plate along the bottom.
		var plate_h := h * 0.29
		var plate := Rect2(inner.position.x + pad, inner.end.y - pad - plate_h, inner.size.x - pad * 2.0, plate_h)
		var top := inner.position.y + pad
		var window := Rect2(plate.position.x, top, plate.size.x, plate.position.y - pad * 0.8 - top)
		return {"m": m, "inner": inner, "banner": plate, "art": window, "type": Rect2(), "rules": Rect2(), "radius": radius}
	var banner := Rect2(inner.position.x + pad, inner.position.y + pad, inner.size.x - pad * 2.0, h * 0.1)
	var art_top := banner.end.y + pad * 0.7
	var art_w := inner.size.x - pad * 2.0
	var art := Rect2(inner.position.x + pad, art_top, art_w, art_w * 0.75)
	var type_line := Rect2(art.position.x, art.end.y + pad * 0.6, art_w, h * 0.068)
	var rules := Rect2(art.position.x, type_line.end.y + pad * 0.6, art_w, inner.end.y - pad - (type_line.end.y + pad * 0.6))
	return {"m": m, "inner": inner, "banner": banner, "art": art, "type": type_line, "rules": rules, "radius": radius}


func _layout() -> void:
	if face == null:
		return
	var cs := card_size()
	_base = ((size - cs) / 2.0).floor()
	face.size = cs
	face.pivot_offset = cs / 2.0
	face.position = _base + lift_direction * (_lift() if selected else 0.0)
	_holo.size = cs
	_flash.size = cs
	var r := _regions()
	var info := PowerupLibrary.info(id)
	var showing := not face_down and not info.is_empty()
	_name.visible = showing
	_type.visible = showing and not compact
	_rules.visible = showing and not compact
	if showing:
		var banner: Rect2 = r["banner"]
		_name.text = str(info.get("name", id))
		if compact:
			_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_fit_block(_name, int(clampf(cs.x * 0.16, 7.0, 18.0)), Rect2(banner.position + banner.size * Vector2(0.04, 0.04), banner.size * Vector2(0.92, 0.92)), 6)
		else:
			_name.autowrap_mode = TextServer.AUTOWRAP_OFF
			var gem_room := banner.size.y * 0.9
			_name.position = banner.position + Vector2(gem_room * 0.25, 0)
			_name.size = Vector2(banner.size.x - gem_room * 1.15, banner.size.y)
			_fit(_name, _name.text, int(clampf(cs.x * 0.082, 8.0, 30.0)), _name.size.x)
		var line: Rect2 = r["type"]
		_type.position = line.position + Vector2(line.size.y * 0.4, 0)
		_type.size = Vector2(line.size.x - line.size.y * 0.8, line.size.y)
		var turn_note := "  ·  USES TURN" if bool(info.get("consumes_turn", false)) else ""
		_type.text = "%s  ·  %s%s" % [PowerupLibrary.KIND_LABELS[PowerupLibrary.kind(id)].to_upper(),
			PowerupLibrary.RARITY_LABELS[PowerupLibrary.rarity(id)].to_upper(), turn_note]
		_fit(_type, _type.text, int(clampf(cs.x * 0.05, 8.0, 15.0)), _type.size.x)
		var box: Rect2 = r["rules"]
		_rules.text = str(info.get("desc", ""))
		_fit_block(_rules, int(clampf(cs.x * 0.064, 8.0, 20.0)), Rect2(box.position + box.size * Vector2(0.05, 0.05), box.size * Vector2(0.9, 0.9)), 7)
	var holo := _holo.material as ShaderMaterial
	holo.set_shader_parameter("size", cs)
	holo.set_shader_parameter("radius", r["radius"])
	holo.set_shader_parameter("strength", 0.45 if PowerupLibrary.rarity(id) == "legendary" else 0.3)
	_holo.visible = _shows_holo()
	face.queue_redraw()


## Shrinks a label's font until `text` fits `width`.
func _fit(label: Label, text: String, max_size: int, width: float) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size := max_size
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


## Places a wrapping label in `box`, shrinking its font until the text fits.
func _fit_block(label: Label, max_size: int, box: Rect2, min_size := 8) -> void:
	var font: Font = label.get_theme_font("font")
	var spacing := label.get_theme_constant("line_spacing")
	var font_size := max_size
	while font_size > min_size:
		var block := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x, font_size)
		var lines := roundf(block.y / font.get_height(font_size))
		if block.y + (lines - 1.0) * spacing <= box.size.y * 0.96 and block.x <= box.size.x:
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	# Clipping keeps a wrapping label from growing to its old (bigger) text before the refit.
	label.clip_text = true
	label.position = box.position
	label.size = box.size


func _draw_face() -> void:
	var r := _regions()
	var cs := card_size()
	var w := cs.x
	var radius: float = r["radius"]
	var ink_w := maxf(1.5, w * 0.018)
	if selected:
		# The selection glow, behind the card so it follows lifts and slams.
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(AppTheme.GOLD, 0.0)
		glow.set_corner_radius_all(int(radius))
		glow.shadow_color = Color(AppTheme.GOLD, 0.85)
		glow.shadow_size = int(maxf(6.0, w * 0.07))
		face.draw_style_box(glow, Rect2(Vector2.ZERO, cs).grow(2.0))
	if face_down or PowerupLibrary.info(id).is_empty():
		_draw_back(radius, ink_w)
		return
	var colors: Array = PowerupLibrary.KIND_COLORS[PowerupLibrary.kind(id)]
	var rarity := PowerupLibrary.rarity(id)
	var trim: Color = PowerupLibrary.RARITY_COLORS[rarity]
	# Frame: ink edge, the type's dark colour, then a lighter inner panel trimmed by rarity.
	face.draw_style_box(_box(colors[1], radius, ink_w, AppTheme.INK), Rect2(Vector2.ZERO, cs))
	var inner: Rect2 = r["inner"]
	face.draw_style_box(_box(colors[0], radius * 0.7, maxf(1.5, w * (0.022 if rarity in ["epic", "legendary"] else 0.012)), trim), inner)
	# Corner studs on legendary cards.
	if rarity == "legendary":
		for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
			face.draw_circle(corner, w * 0.03, trim)
			face.draw_arc(corner, w * 0.03, 0.0, TAU, 16, AppTheme.INK, ink_w * 0.6, true)
	# Name banner (a plate under the art on compact cards).
	var banner: Rect2 = r["banner"]
	face.draw_style_box(_box(AppTheme.PAPER, banner.size.y * (0.22 if compact else 0.35), ink_w * 0.8, AppTheme.INK), banner)
	# Art window.
	var art: Rect2 = r["art"]
	var art_radius := radius * 0.45
	var shape := _rounded(art, art_radius)
	var tex := art(id)
	if tex:
		var uv := _crop(art.size, Vector2(tex.get_size()))
		var uvs := PackedVector2Array()
		for p in shape:
			uvs.append(uv.position + (p - art.position) / art.size * uv.size)
		face.draw_colored_polygon(shape, Color.WHITE, uvs, tex)
	else:
		face.draw_style_box(_box(colors[1].lightened(0.3), art_radius, 0.0, AppTheme.INK), art)
		var icon := PowerupLibrary.icon(id)
		var side := minf(art.size.x, art.size.y) * 0.6
		face.draw_texture_rect(icon, Rect2(art.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false)
	face.draw_polyline(shape + PackedVector2Array([shape[0]]), AppTheme.INK, ink_w * 0.9, true)
	# Rarity gem: in the banner, or on the art's corner on compact cards.
	var gem_r := banner.size.y * 0.32
	var gem_c := Vector2(banner.end.x - gem_r * 1.45, banner.get_center().y)
	if compact:
		gem_r = w * 0.075
		gem_c = Vector2(art.end.x - gem_r * 1.1, art.position.y + gem_r * 1.25)
	var gem := PackedVector2Array([gem_c + Vector2(0, -gem_r), gem_c + Vector2(gem_r * 0.8, 0), gem_c + Vector2(0, gem_r), gem_c + Vector2(-gem_r * 0.8, 0)])
	face.draw_colored_polygon(gem, trim)
	face.draw_polyline(gem + PackedVector2Array([gem[0]]), AppTheme.INK, ink_w * 0.6, true)
	face.draw_line(gem_c + Vector2(-gem_r * 0.3, -gem_r * 0.3), gem_c + Vector2(0, -gem_r * 0.6), Color(1, 1, 1, 0.8), ink_w * 0.5)
	if compact:
		return
	# Type line and rules box.
	var line: Rect2 = r["type"]
	face.draw_style_box(_box(colors[1].darkened(0.15), line.size.y * 0.5, ink_w * 0.6, AppTheme.INK), line)
	var rules: Rect2 = r["rules"]
	face.draw_style_box(_box(AppTheme.PAPER, radius * 0.4, ink_w * 0.7, AppTheme.INK), rules)


## The part of a texture (in UVs) that covers `target` without stretching: a centred crop.
static func _crop(target: Vector2, texture: Vector2) -> Rect2:
	var target_aspect := target.x / maxf(target.y, 1.0)
	var texture_aspect := texture.x / maxf(texture.y, 1.0)
	if target_aspect < texture_aspect:
		var frac := target_aspect / texture_aspect
		return Rect2((1.0 - frac) / 2.0, 0.0, frac, 1.0)
	var frac_h := texture_aspect / target_aspect
	return Rect2(0.0, (1.0 - frac_h) / 2.0, 1.0, frac_h)


func _draw_back(radius: float, ink_w: float) -> void:
	var cs := card_size()
	var w := cs.x
	face.draw_style_box(_box(AppTheme.INK, radius, ink_w, AppTheme.INK), Rect2(Vector2.ZERO, cs))
	var inner := Rect2(Vector2.ONE * w * 0.06, cs - Vector2.ONE * w * 0.12)
	face.draw_style_box(_box(Color("2c2166"), radius * 0.7, maxf(2.0, w * 0.02), AppTheme.GOLD), inner)
	# Diamond lattice.
	var step := w * 0.16
	var lattice := Color(0.55, 0.36, 0.96, 0.35)
	var x := inner.position.x - inner.size.y
	while x < inner.end.x:
		face.draw_line(Vector2(maxf(x, inner.position.x), inner.position.y + maxf(0.0, inner.position.x - x)),
			Vector2(minf(x + inner.size.y, inner.end.x), inner.end.y - maxf(0.0, x + inner.size.y - inner.end.x)), lattice, maxf(1.0, w * 0.008))
		face.draw_line(Vector2(maxf(x, inner.position.x), inner.end.y - maxf(0.0, inner.position.x - x)),
			Vector2(minf(x + inner.size.y, inner.end.x), inner.position.y + maxf(0.0, x + inner.size.y - inner.end.x)), lattice, maxf(1.0, w * 0.008))
		x += step
	# The Salpakan shield in the middle.
	var emblem_w := w * 0.56
	var emblem := Rect2(cs / 2.0 - Vector2(emblem_w, emblem_w * BACK_SHIELD.get_height() / BACK_SHIELD.get_width()) / 2.0,
		Vector2(emblem_w, emblem_w * BACK_SHIELD.get_height() / BACK_SHIELD.get_width()))
	face.draw_texture_rect(BACK_SHIELD, emblem, false)
	var star_w := emblem_w * 0.62
	var star_h := star_w * BACK_STAR.get_height() / BACK_STAR.get_width()
	face.draw_texture_rect(BACK_STAR, Rect2(emblem.get_center() - Vector2(star_w, star_h) / 2.0 - Vector2(0, emblem.size.y * 0.04), Vector2(star_w, star_h)), false)


func _box(bg: Color, radius: float, border: float, border_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(int(radius))
	box.set_border_width_all(int(border))
	box.border_color = border_color
	box.anti_aliasing = true
	return box


static func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [[rect.end.x - radius, rect.position.y + radius, -PI / 2.0], [rect.end.x - radius, rect.end.y - radius, 0.0],
		[rect.position.x + radius, rect.end.y - radius, PI / 2.0], [rect.position.x + radius, rect.position.y + radius, PI]]
	for corner: Array in corners:
		for i in 7:
			var a: float = corner[2] + (PI / 2.0) * i / 6.0
			points.append(Vector2(corner[0], corner[1]) + Vector2(cos(a), sin(a)) * radius)
	return points


## The card's illustration (assets/powerups/art), or null.
static func art(powerup_id: String) -> Texture2D:
	if not _art_cache.has(powerup_id):
		var path := "res://assets/powerups/art/%s.webp" % powerup_id
		_art_cache[powerup_id] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[powerup_id]
