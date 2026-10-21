class_name EmojiPicker
extends PanelContainer
## Grid of chat emoji. The game fonts have no colour emoji, so chat text keeps plain Unicode and
## the known emoji are drawn as Twemoji pictures (CC BY 4.0, see assets/emoji/CREDITS.md):
## `bbcode()` turns a message into RichTextLabel markup with inline [img] tags.
##
##     var picker := EmojiPicker.new()
##     picker.picked.connect(func(emoji: String) -> void: field.insert_text_at_caret(emoji))

signal picked(emoji: String)

const DIR := "res://assets/emoji/"
## Offered in the picker, in this order. Hex code points of single-code-point emoji; the picture
## is DIR + hex + ".png".
const PICKER := [
	"1f600", "1f602", "1f923", "1f605", "1f60a", "1f60d", "1f60e", "1f60f",
	"1f914", "1f644", "1f62e", "1f631", "1f622", "1f62d", "1f621", "1f92f",
	"1f976", "1f973", "1f634", "1f92b", "1f608", "1f921", "1f480", "1f47b",
	"1f916", "1fae1", "1f44d", "1f44e", "1f44f", "1f64f", "1f4aa", "1f91d",
	"1f44b", "270c", "1f525", "1f4af", "2b50", "26a1", "1f4a5", "1f4a3",
	"1f3af", "1f3c6", "1f451", "1f389", "2764", "1f494", "1f440", "1f9e0",
	"1f414", "1f410", "1f37f", "2694", "1f6e1", "1f396", "1f6a9", "1f3f3",
]
## Quick row in the match chat.
const QUICK := ["1f602", "1f60e", "1f914", "1f525", "1f44d", "1fae1"]
## Pictures the social UI uses as icons (not offered in the picker).
const ICONS := {
	"mic": "1f399", "muted": "1f507", "speaker": "1f50a", "chat": "1f4ac", "lock": "1f512",
	"megaphone": "1f4e3", "hourglass": "23f3", "swords": "2694", "smile": "1f600", "trophy": "1f3c6",
}
const COLUMNS := 8
const VISIBLE_ROWS := 4  # The rest scrolls, so the picker never crowds out the chat.
const BUTTON_SIZE := 34
const VARIATION_SELECTOR := 0xFE0F

static var _known: Dictionary = {}  # code point -> hex


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(18)
	style.set_border_width_all(3)
	style.border_color = AppTheme.INK
	style.set_content_margin_all(10)
	style.shadow_color = Color(AppTheme.INK, 0.25)
	style.shadow_offset = Vector2(0, 4)
	style.shadow_size = 2
	add_theme_stylebox_override("panel", style)
	var box := AppTheme.vbox(6)
	add_child(box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = VISIBLE_ROWS * (BUTTON_SIZE + 2)
	box.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	center.add_child(grid)
	for hex: String in PICKER:
		grid.add_child(_emoji_button(hex))
	var credit := AppTheme.label("Emoji graphics by Twemoji, CC BY 4.0", "MutedLabel", 11)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credit)


func _emoji_button(hex: String) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = texture(hex)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = char_of(hex)
	b.pressed.connect(func() -> void: picked.emit(char_of(hex)))
	b.mouse_entered.connect(func() -> void: b.modulate = Color(1.15, 1.15, 1.15))
	b.mouse_exited.connect(func() -> void: b.modulate = Color.WHITE)
	return b


# --- Text helpers ------------------------------------------------------------------------------

static func char_of(hex: String) -> String:
	return String.chr(hex.hex_to_int())


static func texture(hex: String) -> Texture2D:
	return load(DIR + hex + ".png")


static func icon(icon_name: String) -> Texture2D:
	return texture(ICONS[icon_name])


static func is_known(code: int) -> bool:
	_index()
	return _known.has(code)


## Chat text → RichTextLabel BBCode: the text is escaped and every known emoji becomes an
## inline picture `size` pixels tall.
static func bbcode(text: String, size := 22) -> String:
	_index()
	var parts := PackedStringArray()
	for i in text.length():
		var code := text.unicode_at(i)
		if code == VARIATION_SELECTOR:
			continue
		if _known.has(code):
			parts.append("[img=%dx%d]%s%s.png[/img]" % [size, size, DIR, _known[code]])
		elif code == 0x5B:  # "[" would start a tag.
			parts.append("[lb]")
		else:
			parts.append(String.chr(code))
	return "".join(parts)


## True for 1–3 known emoji and nothing else (shown big, without a bubble).
static func is_only_emoji(text: String) -> bool:
	_index()
	var count := 0
	for i in text.length():
		var code := text.unicode_at(i)
		if code == VARIATION_SELECTOR or code == 0x20:
			continue
		if not _known.has(code):
			return false
		count += 1
	return count >= 1 and count <= 3


## Width of `text` drawn with `font` where known emoji take `emoji_size` pixels each.
static func measure(text: String, font: Font, font_size: int, emoji_size: int) -> float:
	_index()
	var plain := PackedStringArray()
	var emoji := 0
	for i in text.length():
		var code := text.unicode_at(i)
		if code == VARIATION_SELECTOR:
			continue
		if _known.has(code):
			emoji += 1
		else:
			plain.append(String.chr(code))
	return font.get_string_size("".join(plain), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + emoji * (emoji_size + 2)


static func _index() -> void:
	if not _known.is_empty():
		return
	for hex: String in PICKER + ICONS.values():
		_known[hex.hex_to_int()] = hex
