class_name ThumbView
extends Control
## A shop item's picture (ShopThumbs): the baked still, or its little clip looping while on screen.
## Pictures load only once the card is on (or near) the screen, with a soft shimmer while they
## download, and are let go again when the card scrolls far away. Falls back to the item's colour
## swatch when there is no picture.

const FPS := 9.0
const NEAR := 240.0  ## Load this far (UI px) outside the visible area, so scrolling finds them ready.
const RELEASE_AFTER := 4.0  ## Seconds far off screen before the picture is let go.

var _category := ""
var _slug := ""
var _tex: Texture2D
var _frames := 1
var _frame := 0
var _time := 0.0
var _away := 0.0
var _asked := false
var _swatch: Array = []


func _init(category: String, slug: String, height := 118.0, swatch: Array = []) -> void:
	custom_minimum_size = Vector2(0.0, height)  # Fills its container's width; the picture is cropped to fit.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_category = category
	_slug = slug
	_swatch = swatch
	# Pictures are bigger than the card: filter them smoothly (stills have mipmaps for phones).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if ShopThumbs.is_clip(category) else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func has_picture() -> bool:
	return ShopThumbs.exists(_category, _slug)


func _process(delta: float) -> void:
	var view := get_viewport().get_visible_rect().grow(NEAR)
	var near := is_visible_in_tree() and get_global_rect().intersects(view)
	if near:
		_away = 0.0
		if not _asked:
			_asked = true
			ShopThumbs.when_ready(_category, _slug, _on_ready)
	elif _tex != null:
		_away += delta
		if _away > RELEASE_AFTER:
			_tex = null  # Far away: let the cache free it.
			_asked = false
	_time += delta
	if _tex == null:
		if ShopThumbs.is_loading(_category, _slug):
			queue_redraw()  # The shimmer moves.
	elif _frames > 1 and near and _time >= 1.0 / FPS:
		_time = 0.0
		_frame = (_frame + 1) % _frames
		queue_redraw()


func _on_ready() -> void:
	if not is_instance_valid(self) or not _asked:
		return
	_tex = ShopThumbs.texture(_category, _slug)
	_frames = ShopThumbs.FRAMES if _tex != null and ShopThumbs.is_clip(_category) else 1
	_frame = ShopThumbs.POSTER.get(_category, 0) if _frames > 1 else 0
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if _tex == null:
		var colors := _swatch if not _swatch.is_empty() else [AppTheme.MUTED]
		var loading := ShopThumbs.is_loading(_category, _slug) or (not _asked and has_picture())
		var w := size.x / colors.size()
		for i in colors.size():
			var c: Variant = colors[i]
			var fill: Color = Color(c) if (c is Color or c is String) else AppTheme.MUTED
			draw_rect(Rect2(i * w, 0.0, w + 1.0, size.y), fill.lerp(AppTheme.PAPER, 0.55) if loading else fill)
		if loading:
			# A soft light band sweeping across while the picture is on its way.
			var x := fposmod(_time * 0.9, 1.6) - 0.3
			for k in 6:
				var band := Rect2((x + k * 0.03) * size.x, 0.0, size.x * 0.03 + 1.0, size.y)
				draw_rect(band, Color(1.0, 1.0, 1.0, 0.1 + 0.05 * minf(k, 5 - k)))
	else:
		var fw := _tex.get_width() / float(_frames)
		var region := Rect2(fw * _frame, 0.0, fw, _tex.get_height())
		# Cover the box, keeping the picture's 2:1 shape (crop the overflow evenly).
		var scale_by := maxf(size.x / region.size.x, size.y / region.size.y)
		var crop := Vector2(size.x, size.y) / scale_by
		region = Rect2(region.position + (region.size - crop) / 2.0, crop)
		draw_texture_rect_region(_tex, box, region)
	draw_rect(box, AppTheme.INK, false, 3.0)
