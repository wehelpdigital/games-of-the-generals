class_name ShoutoutMarquee
extends Control
## Paid shoutouts: a themed banner slides down from the top of the screen, the message scrolls
## across it, then it slides away and the next queued shoutout plays. Social keeps one on its own
## canvas layer so it shows over every screen; the shoutout screen embeds another as a looping
## live preview (`ShoutoutMarquee.new(true)` + `preview(data)`).
##
## Shoutout: {id, user: {username, avatar_url, rank_tier}, message, theme, duration}

const BANNER_HEIGHT := 60.0
const SLIDE_IN := 0.45
const SLIDE_OUT := 0.35

## Theme looks. Effects are drawn in code (a few dozen dots and gradients), cheap on phones.
const THEMES := {
	"classic": {"name": "Classic", "top": Color("fff8ec"), "bottom": Color("ffe6c4"), "text": Color("1d1736"),
		"outline": Color("fff8ec"), "badge": Color("ff4f8b"), "fx": "stripes"},
	"fireworks": {"name": "Fireworks", "top": Color("0b1030"), "bottom": Color("2a1660"), "text": Color.WHITE,
		"outline": Color("2a1660"), "badge": Color("ff7a1a"), "fx": "fireworks"},
	"neon": {"name": "Neon Nights", "top": Color("0a0614"), "bottom": Color("1a0b2e"), "text": Color("6ffcff"),
		"outline": Color("c2189b"), "badge": Color("ff2fd0"), "fx": "neon"},
	"gold_royal": {"name": "Royal Gold", "top": Color("2b0b3f"), "bottom": Color("51146b"), "text": Color("ffd75e"),
		"outline": Color("3a1500"), "badge": Color("e0a100"), "fx": "royal"},
	"sakura": {"name": "Sakura Breeze", "top": Color("ffe0ec"), "bottom": Color("ffb3cf"), "text": Color.WHITE,
		"outline": Color("c2185b"), "badge": Color("ff6fa5"), "fx": "petals"},
	"galaxy": {"name": "Galaxy", "top": Color("0c0a2e"), "bottom": Color("2d0f5e"), "text": Color.WHITE,
		"outline": Color("5b2bd6"), "badge": Color("7b5cff"), "fx": "stars"},
	"rainbow": {"name": "Rainbow Rush", "top": Color("ff4f8b"), "bottom": Color("3d8bff"), "text": Color.WHITE,
		"outline": Color("1d1736"), "badge": Color("1d1736"), "fx": "rainbow"},
	"lava": {"name": "Lava Burst", "top": Color("2a0500"), "bottom": Color("b52a00"), "text": Color("ffe066"),
		"outline": Color("3a0a00"), "badge": Color("ff5a00"), "fx": "embers"},
	# Seasonal themes (sold during their occasion; see the server's seasonal shoutout items).
	"spooky": {"name": "Spooky Night", "top": Color("1f1326"), "bottom": Color("3a1a4a"), "text": Color("ff8a1f"),
		"outline": Color("1a0a20"), "badge": Color("8b5cf6"), "fx": "embers"},
	"jolly": {"name": "Jolly Pasko", "top": Color("1f6b3a"), "bottom": Color("b8242e"), "text": Color.WHITE,
		"outline": Color("0d3a1e"), "badge": Color("ffcf3f"), "fx": "stars"},
	"sweetheart": {"name": "Sweetheart", "top": Color("ffd6e4"), "bottom": Color("ff7aa0"), "text": Color.WHITE,
		"outline": Color("a8244f"), "badge": Color("ff2f5f"), "fx": "petals"},
	"lucky_red": {"name": "Lucky Red", "top": Color("7a0f0f"), "bottom": Color("d62828"), "text": Color("ffcf3f"),
		"outline": Color("3a0505"), "badge": Color("ffcf3f"), "fx": "royal"},
	"countdown": {"name": "Countdown", "top": Color("0d0a2a"), "bottom": Color("2a2060"), "text": Color("ffcf3f"),
		"outline": Color("0d0a18"), "badge": Color("ffcf3f"), "fx": "fireworks"},
	"harvest": {"name": "Harvest Gold", "top": Color("c8641e"), "bottom": Color("e8a33a"), "text": Color.WHITE,
		"outline": Color("5a3218"), "badge": Color("8a4a1e"), "fx": "embers"},
	"beach_day": {"name": "Beach Day", "top": Color("2fb8ff"), "bottom": Color("12b8c4"), "text": Color.WHITE,
		"outline": Color("0a6a78"), "badge": Color("ff8a5a"), "fx": "stripes"},
	"kalayaan": {"name": "Kalayaan", "top": Color("0038a8"), "bottom": Color("ce1126"), "text": Color("fcd116"),
		"outline": Color("001a5a"), "badge": Color("fcd116"), "fx": "royal"},
	"fiesta": {"name": "Fiesta", "top": Color("ff3d7f"), "bottom": Color("ff8a1f"), "text": Color.WHITE,
		"outline": Color("6a1f8a"), "badge": Color("27c98f"), "fx": "stripes"},
}

var embedded := false

var _banner: Banner
var _queue: Array[Dictionary] = []
var _seen: Dictionary = {}
var _playing := false
var _tween: Tween


func _init(is_embedded := false) -> void:
	embedded = is_embedded
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = Banner.new()
	add_child(_banner)
	if embedded:
		custom_minimum_size.y = BANNER_HEIGHT
		clip_contents = true
		_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
		_banner.loop = true
	else:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_banner.offset_bottom = BANNER_HEIGHT
		_banner.visible = false
		_banner.set_process(false)


static func theme_of(slug: String) -> Dictionary:
	return THEMES.get(slug, THEMES["classic"])


## Queues a shoutout (each id plays once).
func enqueue(data: Dictionary) -> void:
	if embedded or str(data.get("message", "")).strip_edges() == "":
		return
	var id: Variant = data.get("id")
	if id != null:
		if _seen.has(str(id)):
			return
		_seen[str(id)] = true
	_queue.append(data)
	if not _playing:
		_play_next()


func queued() -> int:
	return _queue.size() + (1 if _playing else 0)


func is_playing() -> bool:
	return _playing


## Embedded preview: shows `data` now and keeps looping it.
func preview(data: Dictionary) -> void:
	_banner.configure(data)


## Embedded preview: pause the animation while its screen is hidden.
func set_running(running: bool) -> void:
	_banner.set_process(running)


func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		_banner.visible = false
		_banner.set_process(false)
		return
	_playing = true
	var data: Dictionary = _queue.pop_front()
	_banner.visible = true
	_banner.set_process(true)
	_banner.configure(data)
	var hold := maxf(1.5, _banner.pass_seconds() - SLIDE_IN)
	_banner.position.y = -BANNER_HEIGHT - 14.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_banner, "position:y", 0.0, SLIDE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(_banner, "position:y", -BANNER_HEIGHT - 14.0, SLIDE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_play_next)


## The banner itself: themed background + effects, sender badge, scrolling message.
class Banner:
	extends Control

	const MIN_SPEED := 150.0
	const DEFAULT_DURATION := 12.0

	var loop := false
	var look: Dictionary = ShoutoutMarquee.THEMES["classic"]
	var fx := "stripes"
	var duration := DEFAULT_DURATION

	var _t := 0.0
	var _speed := MIN_SPEED
	var _text_width := 0.0
	var _particles: Array = []
	var _spawn := 0.0

	var _badge: PanelContainer
	var _badge_label: Label
	var _avatar: AvatarView
	var _name: Label
	var _clip: Control
	var _text: RichTextLabel
	var _font_size := 30

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 12)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 9)
		add_child(margin)
		var row := AppTheme.hbox(10)
		margin.add_child(row)

		_badge = PanelContainer.new()
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var badge_row := AppTheme.hbox(5)
		var icon := TextureRect.new()
		icon.texture = EmojiPicker.icon("megaphone")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		badge_row.add_child(icon)
		_badge_label = AppTheme.label("SHOUTOUT", "", 15, Color.WHITE)
		_badge_label.add_theme_font_override("font", AppTheme.heading_font())
		_badge_label.add_theme_color_override("font_outline_color", AppTheme.INK)
		_badge_label.add_theme_constant_override("outline_size", 5)
		badge_row.add_child(_badge_label)
		_badge.add_child(badge_row)
		row.add_child(_badge)

		_avatar = AvatarView.new(38.0)
		_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_avatar)
		_name = AppTheme.label("", "", 18)
		_name.add_theme_font_override("font", AppTheme.heading_font())
		_name.add_theme_constant_override("outline_size", 6)
		_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_name)

		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_clip)
		_text = RichTextLabel.new()
		_text.bbcode_enabled = true
		_text.fit_content = true
		_text.scroll_active = false
		_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_text.add_theme_font_override("normal_font", AppTheme.heading_font())
		_clip.add_child(_text)
		resized.connect(_on_resized)

	func configure(data: Dictionary) -> void:
		var slug := str(data.get("theme", "classic"))
		look = ShoutoutMarquee.theme_of(slug)
		fx = str(look["fx"])
		duration = maxf(4.0, float(data.get("duration", DEFAULT_DURATION)))
		var user: Dictionary = data.get("user") if data.get("user") is Dictionary else {}
		_avatar.set_user(user)
		_name.text = str(user.get("username", "Someone"))
		_name.add_theme_color_override("font_color", look["text"])
		_name.add_theme_color_override("font_outline_color", look["outline"])
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = look["badge"]
		badge_style.set_corner_radius_all(999)
		badge_style.set_border_width_all(3)
		badge_style.border_color = AppTheme.INK
		badge_style.content_margin_left = 10
		badge_style.content_margin_right = 12
		badge_style.content_margin_top = 3
		badge_style.content_margin_bottom = 3
		_badge.add_theme_stylebox_override("panel", badge_style)

		var message := str(data.get("message", ""))
		_text.add_theme_font_size_override("normal_font_size", _font_size)
		_text.add_theme_color_override("default_color", look["text"])
		_text.add_theme_color_override("font_outline_color", look["outline"])
		_text.add_theme_constant_override("outline_size", 0 if look["outline"] == look["top"] else 10)
		_text.text = EmojiPicker.bbcode(message, _font_size + 4)
		_text_width = EmojiPicker.measure(message, AppTheme.heading_font(), _font_size, _font_size + 4) + 16.0
		_text.custom_minimum_size.x = _text_width
		_particles.clear()
		_t = 0.0
		_on_resized()
		_text.position.x = _clip.size.x if _clip.size.x > 0.0 else size.x * 0.6

	## Seconds for the message to cross the banner once.
	func pass_seconds() -> float:
		var clip_width := _clip_width()
		_speed = maxf(MIN_SPEED, (clip_width + _text_width) / maxf(1.0, duration - 1.0))
		return (clip_width + _text_width) / _speed

	func _clip_width() -> float:
		return _clip.size.x if _clip.size.x > 0.0 else maxf(200.0, size.x - 260.0)

	func _on_resized() -> void:
		var narrow := size.x < 620.0
		_name.visible = not narrow
		_badge_label.visible = size.x >= 420.0
		_font_size = 24 if narrow else 30
		pass_seconds()

	func _process(delta: float) -> void:
		_t += delta
		_text.position.x -= _speed * delta
		_text.position.y = (_clip.size.y - _text.size.y) / 2.0
		if _text.position.x < -_text_width:
			if loop:
				_text.position.x = _clip.size.x
			else:
				_text.position.x = -_text_width
		_update_fx(delta)
		queue_redraw()

	# --- Effects --------------------------------------------------------------------------------

	func _update_fx(delta: float) -> void:
		_spawn -= delta
		match fx:
			"fireworks":
				if _spawn <= 0.0:
					_spawn = randf_range(0.35, 0.7)
					_burst(Vector2(randf_range(0.05, 0.95) * size.x, randf_range(0.25, 0.7) * size.y))
			"petals":
				if _spawn <= 0.0 and _particles.size() < 26:
					_spawn = 0.18
					_add(Vector2(randf() * size.x, -6.0), Vector2(randf_range(10, 40), randf_range(14, 28)), 4.5,
						[Color("ffffff"), Color("ffc1d9"), Color("ff8fb8")].pick_random(), randf_range(3.0, 5.5))
			"stars":
				if _spawn <= 0.0 and _particles.size() < 40:
					_spawn = 0.08
					_add(Vector2(randf() * size.x, randf() * size.y), Vector2.ZERO, randf_range(1.2, 2.6),
						[Color.WHITE, Color("bfa8ff"), Color("8fd3ff")].pick_random(), randf_range(1.0, 2.2))
			"royal":
				if _spawn <= 0.0 and _particles.size() < 18:
					_spawn = 0.16
					_add(Vector2(randf() * size.x, randf_range(0.15, 0.85) * size.y), Vector2.ZERO, randf_range(0.7, 1.3),
						Color("ffe08a"), randf_range(3.0, 5.5))
			"embers":
				if _spawn <= 0.0 and _particles.size() < 34:
					_spawn = 0.07
					_add(Vector2(randf() * size.x, size.y + 4.0), Vector2(randf_range(-8, 8), randf_range(-40, -20)), randf_range(1.0, 2.0),
						[Color("ffd23f"), Color("ff8a00"), Color("ff4a00")].pick_random(), randf_range(1.5, 3.5))
		for p in _particles:
			p["life"] -= delta
			p["pos"] += p["vel"] * delta
			if fx == "fireworks":
				p["vel"] *= 0.96
				p["vel"].y += 30.0 * delta
			elif fx == "petals":
				p["pos"].x += sin(_t * 3.0 + p["seed"]) * 12.0 * delta
		_particles = _particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0 and p["pos"].y < size.y + 10.0)

	func _add(pos: Vector2, vel: Vector2, life: float, color: Color, radius: float) -> void:
		_particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "color": color, "r": radius, "seed": randf() * TAU})

	func _burst(center: Vector2) -> void:
		var color: Color = [Color("ffcf3f"), Color("ff4f8b"), Color("3dd9ff"), Color("7dff8a"), Color("ff8a3d")].pick_random()
		for i in 14:
			var dir := Vector2.from_angle(TAU * i / 14.0 + randf() * 0.2)
			_add(center, dir * randf_range(45.0, 70.0), randf_range(0.7, 1.0), color, randf_range(1.6, 2.4))

	func _draw() -> void:
		var w := size.x
		var h := size.y
		_gradient(Rect2(0, 0, w, h), look["top"], look["bottom"])
		match fx:
			"stripes":
				var offset := fmod(_t * 40.0, 36.0)
				var x := -36.0 + offset
				while x < w + 36.0:
					draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 14, h), Vector2(x + 26, h - 10), Vector2(x + 12, h - 10)]), Color(AppTheme.PINK, 0.55))
					x += 36.0
			"neon":
				var flicker := 0.75 + 0.25 * sin(_t * 23.0) * sin(_t * 7.0)
				for i in 4:
					var a := (0.5 - i * 0.11) * flicker
					draw_rect(Rect2(0, 2 + i * 2, w, 2), Color(Color("ff2fd0"), a))
					draw_rect(Rect2(0, h - 6 - i * 2, w, 2), Color(Color("3ff5ff"), a))
				for y in range(0, int(h), 4):
					draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.03))
			"royal":
				_gradient(Rect2(0, 0, w, 5), Color("fff1b0"), Color("c98a00"))
				_gradient(Rect2(0, h - 8, w, 5), Color("fff1b0"), Color("c98a00"))
			"galaxy", "stars":
				draw_circle(Vector2(w * 0.25, h * 0.6), h * 0.9, Color(Color("ff4fd8"), 0.08))
				draw_circle(Vector2(w * 0.7, h * 0.3), h * 1.1, Color(Color("3dc8ff"), 0.07))
			"rainbow":
				var bands := 14
				var band := w / bands
				for i in bands + 2:
					var hue := fmod(i / float(bands) + _t * 0.15, 1.0)
					var x0 := (i - 1) * band + fmod(_t * 30.0, band)
					draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + band + 1, 0), Vector2(x0 + band - 14, h), Vector2(x0 - 15, h)]),
						Color.from_hsv(hue, 0.65, 1.0))
				draw_rect(Rect2(0, 0, w, h), Color(AppTheme.INK, 0.12))
			"embers":
				for i in 5:
					var bx := fmod(i * 0.23 + _t * 0.05, 1.0) * w
					draw_circle(Vector2(bx, h + 6), h * 0.55, Color(Color("ff7a00"), 0.25 + 0.1 * sin(_t * 2.0 + i)))
		for p in _particles:
			var fade: float = clampf(p["life"] / p["max"], 0.0, 1.0)
			var color: Color = p["color"]
			match fx:
				"petals":
					var angle: float = _t * 2.0 + p["seed"]
					var r: float = p["r"]
					var pts := PackedVector2Array()
					for k in 8:
						var a := TAU * k / 8.0
						pts.append(p["pos"] + Vector2(cos(a) * r, sin(a) * r * 0.55).rotated(angle))
					draw_colored_polygon(pts, Color(color, 0.9 * fade))
				"stars", "royal":
					var twinkle := absf(sin(_t * 5.0 + p["seed"])) * fade * (1.0 - fade) * 4.0
					_sparkle(p["pos"], p["r"] * (0.6 + twinkle * 0.5), Color(color, clampf(twinkle, 0.0, 1.0)))
				_:
					draw_circle(p["pos"], p["r"], Color(color, fade))
		draw_rect(Rect2(0, h - 3, w, 3), AppTheme.INK)
		draw_rect(Rect2(0, h, w, 5), Color(AppTheme.INK, 0.22))

	func _gradient(rect: Rect2, top: Color, bottom: Color) -> void:
		draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))

	func _sparkle(pos: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r * 0.25, -r * 0.25), pos + Vector2(r, 0),
			pos + Vector2(r * 0.25, r * 0.25), pos + Vector2(0, r), pos + Vector2(-r * 0.25, r * 0.25), pos + Vector2(-r, 0),
			pos + Vector2(-r * 0.25, -r * 0.25)]), color)
