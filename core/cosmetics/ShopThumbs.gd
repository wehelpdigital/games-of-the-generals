class_name ShopThumbs
extends RefCounted
## Baked shop pictures (tests/ThumbnailBaker.tscn): a 2:1 still for every item and, for animated
## categories, a strip of FRAMES frames side by side that ThumbView plays as a little clip. The
## files are WebP kept as-is in the export (importer "keep") and decoded on demand; the cache only
## holds what the shop is showing.

const DIR := "res://assets/shop_thumbs"
const FRAMES := 8
const ANIMATED := ["aura", "glow", "trail", "kill", "taunt", "ambience"]
## Which frame of a clip stands for the item where only a still fits (search results).
const POSTER := {"trail": 3, "kill": 3, "taunt": 3}

static var _cache: Dictionary = {}  # path -> Texture2D or null


static func path(category: String, slug: String) -> String:
	return "%s/%s/%s.webp" % [DIR, category, slug]


static func is_clip(category: String) -> bool:
	return category in ANIMATED


## The whole baked picture (a still, or a clip strip), or null if it hasn't been baked.
static func texture(category: String, slug: String) -> Texture2D:
	var file := path(category, slug)
	if _cache.has(file):
		return _cache[file]
	var tex: Texture2D = null
	if FileAccess.file_exists(file):
		var image := Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(file)) == OK:
			tex = ImageTexture.create_from_image(image)
	_cache[file] = tex
	return tex


## One frame that stands for the item (the poster frame of a clip).
static func still(category: String, slug: String) -> Texture2D:
	var tex := texture(category, slug)
	if tex == null or not is_clip(category):
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var w := tex.get_width() / float(FRAMES)
	atlas.region = Rect2(w * POSTER.get(category, 0), 0.0, w, tex.get_height())
	return atlas


## A small version of the still (e.g. 48×24) for buttons and lists.
static func icon(category: String, slug: String, width := 48) -> Texture2D:
	var key := "icon/%s/%s/%d" % [category, slug, width]
	if _cache.has(key):
		return _cache[key]
	var full := still(category, slug)
	var small: Texture2D = null
	if full != null:
		var image := full.get_image()
		image.resize(width, maxi(1, int(width * image.get_height() / float(image.get_width()))), Image.INTERPOLATE_LANCZOS)
		small = ImageTexture.create_from_image(image)
	_cache[key] = small
	return small


## Drops decoded pictures (the shop calls it when it closes or switches category).
static func clear() -> void:
	_cache.clear()
