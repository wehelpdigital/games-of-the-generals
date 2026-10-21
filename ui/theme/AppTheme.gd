class_name AppTheme
extends RefCounted
## The game's UI look, generated in code: chunky "candy" buttons with a pressed-down lip, cream
## cards with plum ink borders and drop shadows, Lilita One headings and Fredoka body text. Screens
## pick a variation ("PrimaryButton", "CardPanel", "TitleLabel"...) and use the small factories
## below so every screen stays consistent.

const INK := Color("1d1736")
const PAPER := Color("fff8ec")
const PINK := Color("ff4f8b")
const BLUE := Color("3d8bff")
const YELLOW := Color("ffcf3f")
const MINT := Color("27c98f")
const PURPLE := Color("8b5cf6")
const RED := Color("ff5a5f")
const MUTED := Color("6e678c")
const GOLD := Color("ffb703")
const SILVER := Color("b9c2d6")
const BRONZE := Color("e08e45")

const BUTTONS := {
	"Primary": {"bg": PINK, "text": Color.WHITE},
	"Secondary": {"bg": BLUE, "text": Color.WHITE},
	"Accent": {"bg": YELLOW, "text": INK},
	"Success": {"bg": MINT, "text": Color.WHITE},
	"Danger": {"bg": RED, "text": Color.WHITE},
	"Ghost": {"bg": PAPER, "text": INK},
}

static var _theme: Theme
static var _heading: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func heading_font() -> Font:
	if _heading == null:
		_heading = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _heading


# --- Factories --------------------------------------------------------------------------------

static func button(text: String, kind := "Primary", action := Callable(), height := 56.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = kind + "Button"
	b.custom_minimum_size.y = height
	b.focus_mode = Control.FOCUS_NONE
	if action.is_valid():
		b.pressed.connect(action)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void: _bounce(b, 1.0 if b.disabled else 1.05))
	b.mouse_exited.connect(func() -> void: _bounce(b, 1.0))
	return b


static func label(text: String, kind := "", size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if kind != "":
		l.theme_type_variation = kind if kind.ends_with("Label") else kind + "Label"
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func card(kind := "Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = kind + "Panel"
	return p


## A coloured rounded "pill" (status chips, prices, badges).
static func pill(text: String, bg: Color, fg := Color.WHITE, size := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var style := _box(bg, 999, 3, INK)
	style.set_content_margin_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, "", size, fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", heading_font())
	p.add_child(l)
	return p


## Recolour/retext a pill made by pill().
static func set_pill(p: PanelContainer, text: String, bg: Color, fg := Color.WHITE) -> void:
	var l := p.get_child(0) as Label
	l.text = text
	l.add_theme_color_override("font_color", fg)
	var style := p.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = bg
	p.add_theme_stylebox_override("panel", style)


## JSON numbers arrive as floats; show them as whole numbers ("1200", not "1200.0").
static func num(value: Variant) -> String:
	return str(int(value)) if value is float or value is int else str(value)


static func vbox(separation := 14) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func hbox(separation := 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func field(placeholder: String, secret := false) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.secret = secret
	f.custom_minimum_size.y = 52
	return f


## Centres `child` on screen, capped at `max_width` so wide monitors don't stretch it. When it is
## taller than the screen (short landscape phones, large text) it scrolls instead of running off
## the top and bottom.
static func centered(child: Control, max_width := 520.0) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # At least the scroll's size, so the
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL  # child sits centred while it fits.
	scroll.add_child(center)
	child.custom_minimum_size.x = max_width
	center.add_child(child)
	scroll.resized.connect(_fit_width.bind(scroll, child, max_width))
	return scroll


## A card centred on a scrolling page with a margin. Phones get a slimmer margin and padding so
## the card can use nearly the full width.
static func page_scroll(owner: Control, card: Control, max_width: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_child(card)
	center.add_child(margin)
	scroll.add_child(center)
	var fit := func() -> void:
		var narrow := UiScale.narrow(owner)
		var gap := 8 if narrow else 16
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, gap)
		if narrow and not card.has_meta("compact"):
			var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if style:
				style.set_content_margin_all(14)
				card.add_theme_stylebox_override("panel", style)
			card.set_meta("compact", true)
		card.custom_minimum_size.x = minf(max_width, owner.get_viewport_rect().size.x - gap * 2.0)
	owner.resized.connect(fit)
	fit.call_deferred()
	return scroll


static func _fit_width(scroll: Control, child: Control, max_width: float) -> void:
	child.custom_minimum_size.x = minf(max_width, scroll.size.x - 32.0)


## Soft cream glow behind menu content so text stays readable over the busy 3D board.
static func backdrop_glow(strength := 0.8) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(PAPER, strength))
	gradient.set_color(1, Color(PAPER, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Entrance animation: drop in with a little overshoot.
static func pop_in(control: Control, delay := 0.0) -> void:
	control.modulate.a = 0.0
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * 0.92
	var t := control.create_tween().set_parallel(true)
	t.tween_property(control, "modulate:a", 1.0, 0.18).set_delay(delay)
	t.tween_property(control, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _bounce(control: Control, to: float) -> void:
	if not control.is_inside_tree():
		return
	control.create_tween().tween_property(control, "scale", Vector2.ONE * to, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Theme ------------------------------------------------------------------------------------

static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = CosmeticLibrary.display_font()
	theme.default_font_size = 20

	theme.set_color("font_color", "Label", INK)

	for kind: String in BUTTONS:
		var type := kind + "Button"
		theme.set_type_variation(type, "Button")
		var bg: Color = BUTTONS[kind]["bg"]
		var fg: Color = BUTTONS[kind]["text"]
		theme.set_stylebox("normal", type, _candy(bg, false))
		theme.set_stylebox("hover", type, _candy(bg.lightened(0.12), false))
		theme.set_stylebox("pressed", type, _candy(bg.darkened(0.06), true))
		theme.set_stylebox("disabled", type, _candy(bg.lerp(Color("c9c4d9"), 0.7), false))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_font("font", type, heading_font())
		theme.set_font_size("font_size", type, 24)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(state, type, fg)
		theme.set_color("font_disabled_color", type, Color(fg, 0.7))
		if fg == Color.WHITE:
			theme.set_color("font_outline_color", type, INK)
			theme.set_constant("outline_size", type, 6)

	theme.set_type_variation("CardPanel", "PanelContainer")
	var card_style := _box(PAPER, 28, 4, INK)
	card_style.set_content_margin_all(26)
	card_style.shadow_color = Color(INK, 0.35)
	card_style.shadow_offset = Vector2(0, 8)
	card_style.shadow_size = 2
	theme.set_stylebox("panel", "CardPanel", card_style)

	theme.set_type_variation("RowPanel", "PanelContainer")
	var row := _box(Color.WHITE, 18, 3, INK)
	row.set_content_margin_all(10)
	row.content_margin_left = 14
	row.content_margin_right = 12
	theme.set_stylebox("panel", "RowPanel", row)

	theme.set_type_variation("BarPanel", "PanelContainer")
	var bar := _box(Color(PAPER, 0.94), 22, 3, INK)
	bar.set_content_margin_all(8)
	bar.content_margin_left = 14
	bar.content_margin_right = 14
	theme.set_stylebox("panel", "BarPanel", bar)

	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", heading_font())
	theme.set_font_size("font_size", "TitleLabel", 72)
	theme.set_color("font_color", "TitleLabel", Color.WHITE)
	theme.set_color("font_outline_color", "TitleLabel", INK)
	theme.set_constant("outline_size", "TitleLabel", 16)
	theme.set_color("font_shadow_color", "TitleLabel", Color(INK, 0.6))
	theme.set_constant("shadow_offset_y", "TitleLabel", 6)

	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", heading_font())
	theme.set_font_size("font_size", "HeadingLabel", 36)
	theme.set_color("font_color", "HeadingLabel", INK)

	theme.set_type_variation("MutedLabel", "Label")
	theme.set_font_size("font_size", "MutedLabel", 18)
	theme.set_color("font_color", "MutedLabel", MUTED)

	var input := _box(Color.WHITE, 16, 3, INK)
	input.content_margin_left = 16
	input.content_margin_right = 16
	input.content_margin_top = 10
	input.content_margin_bottom = 10
	theme.set_stylebox("normal", "LineEdit", input)
	var focused := input.duplicate() as StyleBoxFlat
	focused.border_color = PINK
	theme.set_stylebox("focus", "LineEdit", focused)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", PINK)
	theme.set_color("selection_color", "LineEdit", Color(PINK, 0.3))

	var scroll_grab := _box(Color(INK, 0.5), 8, 0, INK)
	scroll_grab.set_content_margin_all(4)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grab)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grab)
	var scroll_bg := _box(Color(INK, 0.08), 8, 0, INK)
	scroll_bg.set_content_margin_all(4)
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)

	# Tooltips: a dark rounded card with light text (Label's ink colour would vanish on them).
	var tip := _box(INK, 12, 3, PAPER)
	tip.content_margin_left = 14
	tip.content_margin_right = 14
	tip.content_margin_top = 8
	tip.content_margin_bottom = 8
	tip.shadow_color = Color(INK, 0.35)
	tip.shadow_size = 4
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", PAPER)
	theme.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	theme.set_font_size("font_size", "TooltipLabel", 18)
	return theme


static func _candy(bg: Color, pressed: bool) -> StyleBoxFlat:
	var s := _box(bg, 18, 3, INK)
	s.border_width_bottom = 3 if pressed else 7
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12.0 + (4.0 if pressed else 0.0)
	s.content_margin_bottom = 12.0
	return s


static func _box(bg: Color, radius: int, border: int, border_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.anti_aliasing = true
	return s
