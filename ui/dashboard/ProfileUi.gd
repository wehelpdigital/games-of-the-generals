class_name ProfileUi
extends RefCounted
## Shared pieces for the profile screens (dashboard, profile, ranks, leaderboards, guilds):
## coloured candy buttons, play buttons with a subtitle, icon tiles, player rows, notes, and the
## phone frame that keeps text readable in portrait.

## Portrait phones lay screens out at this width, then scale them up to fill the screen.
const PHONE_WIDTH := 600.0
## Below this width (UI pixels) rows drop secondary columns and pages trim their padding.
const NARROW := 520.0

## Set by fit(): true on phone-width screens, so row builders can keep to the essentials.
static var narrow := false


## Covers the viewport with `frame`. In portrait the frame is PHONE_WIDTH wide and scaled up, so
## a 390 px phone shows text at a readable size. Returns true in portrait.
static func fit(frame: Control, view: Vector2, design_width := PHONE_WIDTH) -> bool:
	var portrait := view.y > view.x
	var k := maxf(1.0, view.x / design_width) if portrait else 1.0
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.position = Vector2.ZERO
	frame.scale = Vector2(k, k)
	frame.size = view / k
	narrow = frame.size.x < NARROW
	return portrait


## A scaled frame holding a centred card, shown as a UIRoot overlay (dialogs, sheets).
static func overlay(ui: UIRoot, card: Control, max_width := 480.0, backdrop: Control = null) -> void:
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit(frame, ui.get_viewport().get_visible_rect().size)
	if backdrop:
		frame.add_child(backdrop)
	frame.add_child(AppTheme.centered(card, max_width))
	ui.show_overlay(frame)
	AppTheme.pop_in(card)


## A candy button in any colour (AppTheme only has the named kinds).
static func colored_button(text: String, bg: Color, fg := Color.WHITE, action := Callable(), height := 52.0) -> Button:
	var b := AppTheme.button(text, "Primary", action, height)
	b.add_theme_stylebox_override("normal", candy(bg, false))
	b.add_theme_stylebox_override("hover", candy(bg.lightened(0.12), false))
	b.add_theme_stylebox_override("pressed", candy(bg.darkened(0.06), true))
	b.add_theme_stylebox_override("disabled", candy(bg.lerp(Color("c9c4d9"), 0.7), false))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, fg)
	if fg != Color.WHITE:
		b.add_theme_constant_override("outline_size", 0)
	return b


static func candy(bg: Color, pressed: bool, radius := 18) -> StyleBoxFlat:
	var s := box(bg, radius, 3, AppTheme.INK)
	s.border_width_bottom = 3 if pressed else 7
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10.0 + (4.0 if pressed else 0.0)
	s.content_margin_bottom = 10.0
	return s


static func box(bg: Color, radius: int, border: int, border_color := AppTheme.INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.anti_aliasing = true
	return s


## A big play button: a chunky title with a smaller line under it.
static func play_button(title: String, subtitle: String, bg: Color, action: Callable, height := 76.0, icon := "") -> Button:
	var b := colored_button("", bg, Color.WHITE, action, height)
	var row := AppTheme.hbox(12)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -14
	row.offset_bottom = -4
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var compact := height < 70.0
	if icon != "":
		var glyph := TileIcon.new(icon, Vector2.ONE * height * (0.42 if compact else 0.5))
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var text := AppTheme.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := AppTheme.label(title, "", 21 if compact else 28, Color.WHITE)
	head.clip_text = true
	head.add_theme_font_override("font", AppTheme.heading_font())
	head.add_theme_color_override("font_outline_color", AppTheme.INK)
	head.add_theme_constant_override("outline_size", 7)
	text.add_child(head)
	if subtitle != "":
		var sub := AppTheme.label(subtitle, "", 14 if compact else 15, Color(1, 1, 1, 0.95))
		sub.add_theme_color_override("font_outline_color", Color(AppTheme.INK, 0.6))
		sub.add_theme_constant_override("outline_size", 4)
		sub.clip_text = true
		text.add_child(sub)
	row.add_child(text)
	b.add_child(row)
	return b


## Square-ish shortcut tile: an icon over a short name.
static func tile(title: String, icon: String, bg: Color, action: Callable) -> Button:
	var b := colored_button("", bg, Color.WHITE, action, 92)
	b.custom_minimum_size.x = 96
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := AppTheme.vbox(2)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 8
	column.offset_bottom = -10
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var glyph := TileIcon.new(icon, Vector2(38, 38))
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(glyph)
	var name_label := AppTheme.label(title, "", 15, Color.WHITE)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.clip_text = true
	name_label.add_theme_color_override("font_outline_color", AppTheme.INK)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	b.add_child(column)
	return b


## Small inline button for rows and headers.
static func small_button(text: String, kind: String, action: Callable, height := 40.0) -> Button:
	var b := AppTheme.button(text, kind, action, height)
	b.add_theme_font_size_override("font_size", 17)
	return b


static func heading(text: String, size := 30) -> Label:
	return AppTheme.label(text, "HeadingLabel", size)


## Small caps label above a section ("NEXT RANK", "HOMETOWN").
static func eyebrow(text: String, color := AppTheme.MUTED) -> Label:
	var l := AppTheme.label(text.to_upper(), "", 14, color)
	l.add_theme_font_override("font", AppTheme.heading_font())
	return l


## Muted, wrapped, centred text for empty, loading and error states.
static func note(text: String, size := 18) -> Label:
	var l := AppTheme.label(text, "MutedLabel", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 120
	return l


static func wrap(text: String, size := 18, color := Color(0, 0, 0, 0)) -> Label:
	var l := AppTheme.label(text, "", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 80
	return l


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Rank position chip: gold, silver and bronze for the podium.
static func position_chip(rank: int) -> Control:
	var colors := [AppTheme.GOLD, AppTheme.SILVER, AppTheme.BRONZE]
	var chip: PanelContainer
	if rank >= 1 and rank <= 3:
		chip = AppTheme.pill(str(rank), colors[rank - 1], AppTheme.INK, 17)
	else:
		chip = AppTheme.pill(str(rank) if rank > 0 else "-", Color(AppTheme.INK, 0.08), AppTheme.INK, 17)
		chip.add_theme_stylebox_override("panel", _plain_chip())
	chip.custom_minimum_size = Vector2(40 if narrow else 50, 0)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


static func _plain_chip() -> StyleBoxFlat:
	var s := box(Color(AppTheme.INK, 0.06), 999, 0)
	s.set_content_margin_all(6)
	return s


## A player line for leaderboards and member lists: position, photo, rank insignia, name with a
## sub line, then stat cells [[text, min_width, caption], ...]. `extra` goes at the end (buttons).
static func player_row(entry: Dictionary, position: int, sub: String, stats: Array, me := false, extra: Control = null) -> PanelContainer:
	var row := AppTheme.card("Row")
	if me:
		row.add_theme_stylebox_override("panel", highlight_style())
	var line := AppTheme.hbox(10)
	row.add_child(line)
	if position >= 0:
		line.add_child(position_chip(position))
	var avatar := AvatarView.new(36 if narrow else 44)
	avatar.set_user(entry)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(avatar)
	var names := AppTheme.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_row := AppTheme.hbox(6)
	if entry.get("rank_tier") != null:
		var insignia := RankInsignia.new(entry["rank_tier"], 22)
		insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(insignia)
	var name_label := AppTheme.label(str(entry.get("username", entry.get("name", "?"))), "", 20)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	if entry.get("title") != null and str(entry["title"]) != "":
		var worn := AppTheme.label(str(entry["title"]), "MutedLabel", 14)
		worn.add_theme_color_override("font_color", AppTheme.PURPLE)
		title_row.add_child(worn)
	names.add_child(title_row)
	if sub != "":
		var sub_label := AppTheme.label(sub, "MutedLabel", 15)
		sub_label.clip_text = true
		names.add_child(sub_label)
	line.add_child(names)
	for stat: Array in stats.slice(0, max_stats()):
		var cell := AppTheme.vbox(0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.custom_minimum_size.x = stat[1] * (0.8 if narrow else 1.0)
		var value := AppTheme.label(str(stat[0]), "", 19)
		value.add_theme_font_override("font", AppTheme.heading_font())
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(value)
		if stat.size() > 2 and str(stat[2]) != "":
			var caption := AppTheme.label(str(stat[2]), "MutedLabel", 13)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(caption)
		line.add_child(cell)
	if extra:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if narrow and extra.get_combined_minimum_size().x > 90.0:
			extra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			names.add_child(extra)  # Phones: wide extras (buttons) go under the name, not beside it.
		else:
			line.add_child(extra)
	return row


## A row that stacks into a centred column on phone-width screens (photo above the details).
static func flex(separation := 12) -> BoxContainer:
	var box := BoxContainer.new()
	box.vertical = narrow
	box.add_theme_constant_override("separation", separation)
	if narrow:
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	return box


## How many stat columns rows show: phones keep the first two.
static func max_stats() -> int:
	return 2 if narrow else 99


static func highlight_style() -> StyleBoxFlat:
	var s := box(Color(AppTheme.YELLOW, 0.38), 18, 3)
	s.set_content_margin_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 12
	return s


## Thousands separators: 12500 -> "12,500".
static func grouped(value: Variant) -> String:
	var n := int(value) if (value is int or value is float) else 0
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## A gap of fixed height (or width inside an HBox).
static func gap(amount: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(amount, amount)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A tab strip that wraps on narrow screens; `on_pick` receives the key. Returns the buttons by key.
static func tabs(parent: Control, entries: Array, on_pick: Callable) -> Dictionary:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	var buttons := {}
	for entry: Array in entries:
		var b := small_button(entry[1], "Ghost", on_pick.bind(entry[0]), 42)
		buttons[entry[0]] = b
		flow.add_child(b)
	return buttons


static func select_tab(buttons: Dictionary, key: String) -> void:
	for k: String in buttons:
		buttons[k].theme_type_variation = "AccentButton" if k == key else "GhostButton"


## A full-height card page: a title row with a Back button over a scrolling body. Returns
## {frame, card, head, title, body, scroll}; call fit_page() from the screen's layout.
static func page(owner: Control, title: String, back: Callable, max_width := 780.0) -> Dictionary:
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(frame)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	frame.add_child(margin)
	var center := AppTheme.hbox(0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)
	var card := AppTheme.card()
	card.add_theme_stylebox_override("panel", _page_style())
	center.add_child(card)
	var column := AppTheme.vbox(12)
	card.add_child(column)
	var head := AppTheme.hbox(10)
	var title_label := heading(title, 34)
	title_label.clip_text = true
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	head.add_child(small_button("Back", "Ghost", back, 44))
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := AppTheme.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	column.add_child(scroll)
	return {"frame": frame, "card": card, "head": head, "title": title_label, "body": body, "scroll": scroll,
		"max_width": max_width}


## Re-fits a page() to the viewport. Returns true in portrait.
static func fit_page(p: Dictionary, view: Vector2) -> bool:
	var frame: Control = p["frame"]
	var portrait := fit(frame, view)
	var card: PanelContainer = p["card"]
	var margin := 6 if narrow else 14
	var holder: MarginContainer = frame.get_child(0)
	for side in ["left", "right", "top", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, margin)
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_content_margin_all(12 if narrow else 20)
	card.custom_minimum_size.x = floorf(minf(float(p["max_width"]), frame.size.x - margin * 2.0))  # Whole pixels: a fraction rounds the page wider than the screen.
	return portrait


static func _page_style() -> StyleBoxFlat:
	var s := box(AppTheme.PAPER, 28, 4)
	s.set_content_margin_all(20)
	s.shadow_color = Color(AppTheme.INK, 0.35)
	s.shadow_offset = Vector2(0, 8)
	s.shadow_size = 2
	return s


## A labelled stat tile: big number over a caption.
static func stat_tile(value: String, caption: String, color := AppTheme.INK) -> PanelContainer:
	var tile_panel := AppTheme.card("Row")
	tile_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := AppTheme.vbox(0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var number := AppTheme.label(value, "", 30, color)
	number.add_theme_font_override("font", AppTheme.heading_font())
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var label := AppTheme.label(caption, "MutedLabel", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	tile_panel.add_child(column)
	return tile_panel


## Round guild logo (falls back to the tag's letters).
static func guild_logo(guild: Dictionary, diameter := 56.0) -> AvatarView:
	var logo := AvatarView.new(diameter)
	var url: Variant = guild.get("logo_url")
	logo.ring_color = AppTheme.MINT
	logo.set_avatar(str(url) if url != null else "", str(guild.get("tag", guild.get("name", "?"))))
	return logo
