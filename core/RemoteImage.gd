class_name RemoteImage
extends RefCounted
## Downloads pictures by URL (profile photos, guild logos, custom flag images) and caches the
## textures for the session. Relative URLs ("/api/media/12") resolve against the API server.
##
##     RemoteImage.fetch(url, func(texture: Texture2D) -> void: if texture: rect.texture = texture)

static var _cache: Dictionary = {}    # absolute url -> Texture2D
static var _waiting: Dictionary = {}  # absolute url -> Array of Callables


## The texture if it is already downloaded, else null.
static func cached(url: String) -> Texture2D:
	return _cache.get(absolute(url))


## Calls `on_done` with the texture, or null when the URL is empty or the download fails.
static func fetch(url: String, on_done: Callable) -> void:
	if url == "":
		on_done.call(null)
		return
	var full := absolute(url)
	if _cache.has(full):
		on_done.call(_cache[full])
		return
	if _waiting.has(full):
		_waiting[full].append(on_done)
		return
	_waiting[full] = [on_done]
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.accept_gzip = not OS.has_feature("web")  # The browser un-gzips for us (see ApiManager).
	ApiManager.add_child(http)
	http.request_completed.connect(func(result: int, status: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var texture: Texture2D = null
		if result == HTTPRequest.RESULT_SUCCESS and status == 200:
			var image := FilePicker._decode(body, _content_type(headers))
			if image:
				image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
				_cache[full] = texture
		_finish(full, texture))
	if http.request(full) != OK:
		http.queue_free()
		_finish(full, null)


## Forget a URL (e.g. after uploading a new photo to the same address).
static func forget(url: String) -> void:
	_cache.erase(absolute(url))


static func absolute(url: String) -> String:
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	return ApiManager.base_url + ("" if url.begins_with("/") else "/") + url


static func _finish(full: String, texture: Texture2D) -> void:
	var callbacks: Array = _waiting.get(full, [])
	_waiting.erase(full)
	for callback: Callable in callbacks:
		if callback.is_valid():
			callback.call(texture)


static func _content_type(headers: PackedStringArray) -> String:
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			return header.substr(13).strip_edges().to_lower()
	return ""
