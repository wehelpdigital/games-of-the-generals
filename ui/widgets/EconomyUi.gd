class_name EconomyUi
extends RefCounted
## Small shared pieces for the economy UI (daily reward, missions, achievements, match rewards).


## "2d 5h", "5h 12m" or "12m" until an ISO-8601 UTC time; "" when unknown.
static func time_left(iso: String) -> String:
	if iso == "":
		return ""
	var target := Time.get_unix_time_from_datetime_string(iso.trim_suffix("Z").left(19))
	var seconds := int(target - Time.get_unix_time_from_system())
	if seconds <= 0:
		return "a moment"
	if seconds >= 86400:
		return "%dd %dh" % [seconds / 86400, (seconds % 86400) / 3600]
	if seconds >= 3600:
		return "%dh %dm" % [seconds / 3600, (seconds % 3600) / 60]
	return "%dm" % maxi(1, ceili(seconds / 60.0))


## An emoji picture (assets/emoji/<code>.png) at a fixed size.
static func emoji(code: String, side := 32.0) -> TextureRect:
	var rect := TextureRect.new()
	var path := EmojiPicker.DIR + code + ".png"
	rect.texture = load(path) if ResourceLoader.exists(path) else EmojiPicker.texture("2b50")
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A rounded chip: coloured background, ink border, short text.
static func chip(text: String, bg: Color, fg := Color.WHITE, size := 14) -> PanelContainer:
	return AppTheme.pill(text, bg, fg, size)
