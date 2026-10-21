class_name ShopThumbs
extends RefCounted
## Baked shop pictures (tests/ThumbnailBaker.tscn): a 2:1 still for every item and, for animated
## categories, a strip of FRAMES frames side by side that ThumbView plays as a little clip.
##
## The pictures are big enough to stay sharp on large and high-DPI screens, so they don't ship in
## the game download: the website serves them next to the web build (play/thumbs/<category>/
## <slug>.webp, published by tools/publish_thumbs.py) and they load on demand, a few at a time,
## only for the cards on screen. MANIFEST (in the game) lists every picture with a short hash that
## busts the browser cache when a picture changes. Where the files are in the project (the editor,
## the bakers, tests) they are read straight from disk instead.
##
## Decoded pictures are kept in a cache that drops the least recently used ones past BUDGET_MB.

const DIR := "res://assets/shop_thumbs"
const MANIFEST := "res://assets/shop_thumbs/manifest.json"
const FRAMES := 8
const ANIMATED := ["aura", "glow", "trail", "kill", "taunt", "ambience"]
## Which frame of a clip stands for the item where only a still fits (search results).
const POSTER := {"trail": 3, "kill": 3, "taunt": 3}
const BUDGET_MB := 96.0

static var _cache: Dictionary = {}  # path -> Texture2D or null, least recently used first
static var _bytes := 0.0
static var _manifest: Variant = null  # {"category/slug": hash}
static var _loader: ThumbLoader
static var _waiting: Dictionary = {}  # "category/slug" -> [Callable] to call once it has loaded


static func path(category: String, slug: String) -> String:
	return "%s/%s/%s.webp" % [DIR, category, slug]


static func is_clip(category: String) -> bool:
	return category in ANIMATED


## Whether the item has a picture at all (on disk or on the website).
static func exists(category: String, slug: String) -> bool:
	return FileAccess.file_exists(path(category, slug)) or _manifest_data().has("%s/%s" % [category, slug])


## Whether the picture is on its way from the website.
static func is_loading(category: String, slug: String) -> bool:
	return _waiting.has("%s/%s" % [category, slug])


## The whole baked picture (a still, or a clip strip), or null: not baked, or still downloading
## (when_ready() tells you when it arrives).
static func texture(category: String, slug: String) -> Texture2D:
	var file := path(category, slug)
	if _cache.has(file):
		var hit: Texture2D = _cache[file]
		_cache.erase(file)  # Most recently used goes last.
		_cache[file] = hit
		return hit
	if FileAccess.file_exists(file):
		var image := Image.new()
		_store(file, _texture_of(image, category) if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(file)) == OK else null)
		return _cache[file]
	var key := "%s/%s" % [category, slug]
	var version := str(_manifest_data().get(key, ""))
	if version == "":
		return null
	if not _waiting.has(key):
		_waiting[key] = []
		_get_loader().fetch(key, "%s%s.webp?v=%s" % [base_url(), key, version])
	return null


## Calls `callback` once the picture can be shown (at once if it already can, or if there is no
## picture to wait for).
static func when_ready(category: String, slug: String, callback: Callable) -> void:
	texture(category, slug)
	var key := "%s/%s" % [category, slug]
	if _waiting.has(key):
		(_waiting[key] as Array).append(callback)
	else:
		callback.call()


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
	if full == null:
		return null  # Not here (yet): don't remember that, it may still arrive.
	var image := full.get_image()
	image.resize(width, maxi(1, int(width * image.get_height() / float(image.get_width()))), Image.INTERPOLATE_LANCZOS)
	var small := ImageTexture.create_from_image(image)
	_store(key, small)
	return small


## Drops decoded pictures (the shop calls it when it closes or switches category).
static func clear() -> void:
	_cache.clear()
	_bytes = 0.0


## Where the website serves the pictures: next to the web build, else on the game's server.
static func base_url() -> String:
	if OS.has_feature("web"):
		var here: Variant = JavaScriptBridge.eval("new URL('thumbs/', document.baseURI).href", true)
		if here is String and str(here).begins_with("http"):
			return str(here)
	return ApiManager.base_url + "/play/thumbs/"


static func _texture_of(image: Image, category: String) -> Texture2D:
	if not is_clip(category):
		image.generate_mipmaps()  # Stills shrink a lot on phones; mipmaps keep them smooth.
	return ImageTexture.create_from_image(image)


## Caches a texture and drops the least recently used ones past the budget. Cards on screen keep
## their own reference, so only pictures nobody shows are really freed.
static func _store(key: String, tex: Texture2D) -> void:
	_cache[key] = tex
	if tex != null:
		_bytes += _size_of(tex)
	while _bytes > BUDGET_MB * 1048576.0 and _cache.size() > 1:
		var oldest: String = _cache.keys()[0]
		var gone: Texture2D = _cache[oldest]
		_cache.erase(oldest)
		if gone != null:
			_bytes -= _size_of(gone)


static func _size_of(tex: Texture2D) -> float:
	return tex.get_width() * tex.get_height() * 4.0 * (1.34 if tex.has_mipmaps() else 1.0) if tex is ImageTexture else 0.0


static func _manifest_data() -> Dictionary:
	if _manifest == null:
		_manifest = {}
		if FileAccess.file_exists(MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if parsed is Dictionary:
				_manifest = parsed.get("files", {})
	return _manifest


static func _get_loader() -> ThumbLoader:
	if _loader == null or not is_instance_valid(_loader):
		_loader = ThumbLoader.new()
		_loader.name = "ThumbLoader"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_loader)
		_loader.loaded.connect(_on_loaded)
	return _loader


static func _on_loaded(key: String, image: Image) -> void:
	var category := key.get_slice("/", 0)
	_store(path(category, key.get_slice("/", 1)), _texture_of(image, category) if image != null else null)
	var callbacks: Array = _waiting.get(key, [])
	_waiting.erase(key)
	for callback: Callable in callbacks:
		if callback.is_valid():
			callback.call()
