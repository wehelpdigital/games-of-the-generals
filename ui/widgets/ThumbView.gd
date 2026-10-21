class_name ThumbView
extends Control
## A shop item's picture (ShopThumbs): the baked still, or its little clip looping while on screen.
## Falls back to the item's colour swatch until thumbnails are baked.

const FPS := 9.0

var _tex: Texture2D
var _frames := 1
var _frame := 0
var _time := 0.0
var _swatch: Array = []


func _init(category: String, slug: String, height := 118.0, swatch: Array = []) -> void:
	custom_minimum_size = Vector2(0.0, height)  # Fills its container's width; the picture is cropped to fit.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swatch = swatch
	_tex = ShopThumbs.texture(category, slug)
	if _tex != null and ShopThumbs.is_clip(category):
		_frames = ShopThumbs.FRAMES
		_frame = ShopThumbs.POSTER.get(category, 0)
	set_process(_frames > 1)


func has_picture() -> bool:
	return _tex != null


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if _time >= 1.0 / FPS:
		_time = 0.0
		_frame = (_frame + 1) % _frames
		queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if _tex == null:
		var colors := _swatch if not _swatch.is_empty() else [AppTheme.MUTED]
		var w := size.x / colors.size()
		for i in colors.size():
			var c: Variant = colors[i]
			draw_rect(Rect2(i * w, 0.0, w + 1.0, size.y), Color(c) if (c is Color or c is String) else AppTheme.MUTED)
	else:
		var fw := _tex.get_width() / float(_frames)
		var region := Rect2(fw * _frame, 0.0, fw, _tex.get_height())
		# Cover the box, keeping the picture's 2:1 shape (crop the overflow evenly).
		var scale_by := maxf(size.x / region.size.x, size.y / region.size.y)
		var crop := Vector2(size.x, size.y) / scale_by
		region = Rect2(region.position + (region.size - crop) / 2.0, crop)
		draw_texture_rect_region(_tex, box, region)
	draw_rect(box, AppTheme.INK, false, 3.0)
